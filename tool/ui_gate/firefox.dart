import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../visual_baseline.dart' show forceFocusScript;
import 'driver.dart';

/// Raw W3C WebDriver/BiDi adapter; owns only the geckodriver it starts.
final class FirefoxDriver implements GateDriver {
  FirefoxDriver._(this._process, this._endpoint);

  final Process _process;
  final Uri _endpoint;
  String? _session;
  WebSocket? _socket;
  String? _context;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  int _id = 0;
  int _width = 1440;
  int _height = 900;
  String _mode = '';
  Uri? _url;
  @override
  final name = 'firefox';
  @override
  final requests = <String>[];
  @override
  final console = <String>[];

  /// GECKODRIVER wins; otherwise use an executable already on PATH.
  static String? locateGeckodriver() {
    final configured = Platform.environment['GECKODRIVER'];
    if (configured != null && File(configured).existsSync()) return configured;
    for (final path in (Platform.environment['PATH'] ?? '').split(Platform.isWindows ? ';' : ':')) {
      final file = File('$path/geckodriver${Platform.isWindows ? '.exe' : ''}');
      if (file.existsSync()) return file.path;
    }
    return null;
  }

  static String? locateFirefox() {
    for (final file in [
      Platform.environment['FIREFOX_PATH'],
      '/Applications/Firefox.app/Contents/MacOS/firefox',
      '/usr/bin/firefox',
      '/snap/bin/firefox',
    ]) {
      if (file != null && File(file).existsSync()) return file;
    }
    return null;
  }

  static Future<FirefoxDriver> launch() async {
    final binary = locateGeckodriver();
    if (binary == null || locateFirefox() == null) throw StateError('Firefox or geckodriver is not installed');
    final process = await Process.start(binary, ['--host', '127.0.0.1', '--port', '0', '--websocket-port', '0']);
    final listening = Completer<Uri>();
    final log = StringBuffer();
    void line(String text) {
      log.writeln(text);
      final match = RegExp(r'Listening on (127\.0\.0\.1:\d+)').firstMatch(text);
      if (match != null && !listening.isCompleted) listening.complete(Uri.parse('http://${match[1]}'));
    }

    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(line);
    process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(line);
    FirefoxDriver? driver;
    try {
      driver = FirefoxDriver._(process, await listening.future.timeout(const Duration(seconds: 20)));
      await driver._start();
      return driver;
    } on Object {
      if (driver != null) {
        await driver.close();
      } else {
        process.kill();
        await process.exitCode;
      }
      stderr.write(log);
      rethrow;
    }
  }

  Future<Object?> _http(String method, String path, [Object? body]) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, _endpoint.resolve(path));
      request.headers.contentType = ContentType.json;
      if (method == 'POST') request.write(jsonEncode(body ?? {}));
      final response = await request.close().timeout(const Duration(seconds: 45));
      final text = await utf8.decodeStream(response);
      final decoded = text.isEmpty ? <String, Object?>{} : jsonDecode(text) as Map;
      if (response.statusCode >= 400) throw StateError('WebDriver $method $path: ${decoded['value']}');
      return decoded['value'];
    } finally {
      client.close(force: true);
    }
  }

  Future<Object?> _wd(String method, String path, [Object? body]) => _http(method, '/session/$_session$path', body);

  Future<Map<String, dynamic>> _bidi(String method, Map<String, Object?> params) async {
    final id = ++_id;
    final response = _pending[id] = Completer<Map<String, dynamic>>();
    _socket!.add(jsonEncode({'id': id, 'method': method, 'params': params}));
    try {
      final value = await response.future.timeout(const Duration(seconds: 20));
      if (value['type'] == 'error') throw StateError('BiDi $method: ${value['error']} ${value['message']}');
      return (value['result'] as Map).cast<String, dynamic>();
    } finally {
      _pending.remove(id);
    }
  }

  Future<void> _start({
    bool coarse = false,
    bool forcedColors = false,
    bool reducedMotion = false,
    bool dark = false,
  }) async {
    final created =
        await _http('POST', '/session', {
              'capabilities': {
                'alwaysMatch': {
                  'browserName': 'firefox',
                  'webSocketUrl': true,
                  'moz:firefoxOptions': {
                    'binary': locateFirefox(),
                    'args': ['-headless'],
                    'prefs': {
                      'ui.primaryPointerCapabilities': coarse ? 1 : 6,
                      'browser.display.document_color_use': forcedColors ? 2 : 1,
                      'ui.prefersReducedMotion': reducedMotion ? 1 : 0,
                      'ui.systemUsesDarkTheme': dark ? 1 : 0,
                    },
                  },
                },
              },
            })
            as Map;
    _session = created['sessionId'] as String;
    final caps = created['capabilities'] as Map;
    _socket = await WebSocket.connect(caps['webSocketUrl'] as String);
    _socket!.listen((Object? raw) {
      final message = (jsonDecode(raw! as String) as Map).cast<String, dynamic>();
      final id = message['id'];
      if (id is int) {
        _pending[id]?.complete(message);
      } else {
        final params = (message['params'] as Map?) ?? const {};
        if (message['method'] == 'network.beforeRequestSent') requests.add((params['request'] as Map)['url'] as String);
        if (message['method'] == 'log.entryAdded') console.add('${params['text']}');
      }
    });
    final tree = await _bidi('browsingContext.getTree', {});
    _context = ((tree['contexts'] as List).first as Map)['context'] as String;
    await _bidi('session.subscribe', {
      'events': ['network.beforeRequestSent', 'log.entryAdded'],
    });
    await _bidi('script.addPreloadScript', {
      'functionDeclaration': '() => {$gatePreload}',
      'contexts': [_context],
    });
    await _wd('POST', '/timeouts', {'script': 30000, 'pageLoad': 30000, 'implicit': 0});
    _mode = '$coarse/$forcedColors/$reducedMotion/$dark';
    await viewport(_width, _height);
  }

  Future<void> _endSession() async {
    await _socket?.close();
    _socket = null;
    if (_session != null) await _http('DELETE', '/session/$_session');
    _session = null;
  }

  Future<void> _activate() async {
    // DOM activeElement survives when Firefox backgrounds the document, while
    // :focus and :focus-visible do not. Native input needs the owned context active.
    await _bidi('browsingContext.activate', {'context': _context});
  }

  @override
  Future<void> open(Uri url) async {
    _url = url;
    await _wd('POST', '/url', {'url': '$url'});
    await _activate();
    await evaluate('document.fonts.ready.then(() => true)');
  }

  @override
  Future<Object?> evaluate(String expression) async {
    final response =
        await _wd('POST', '/execute/async', {
              'script':
                  'const done=arguments[arguments.length-1]; Promise.resolve().then(() => ($expression))'
                  '.then(value => done({value}), error => done({error:String(error)+String.fromCharCode(10)+(error.stack || "")}));',
              'args': [],
            })
            as Map;
    if (response.containsKey('error')) throw StateError('Firefox script: ${response['error']}');
    return response['value'];
  }

  @override
  Future<void> viewport(int width, int height) async {
    _width = width;
    _height = height;
    await _bidi('browsingContext.setViewport', {
      'context': _context,
      'viewport': {'width': width, 'height': height},
      'devicePixelRatio': 1,
    });
  }

  @override
  Future<bool> media({
    bool coarse = false,
    bool forcedColors = false,
    bool reducedMotion = false,
    bool dark = false,
  }) async {
    if (_mode != '$coarse/$forcedColors/$reducedMotion/$dark') {
      await _endSession();
      await _start(coarse: coarse, forcedColors: forcedColors, reducedMotion: reducedMotion, dark: dark);
      if (_url != null) await open(_url!);
    }
    return await evaluate('''matchMedia('(pointer: coarse)').matches === $coarse &&
      matchMedia('(forced-colors: active)').matches === $forcedColors &&
      matchMedia('(prefers-reduced-motion: reduce)').matches === $reducedMotion &&
      matchMedia('(prefers-color-scheme: dark)').matches === $dark''') ==
        true;
  }

  @override
  Future<void> press(String key) async {
    const keys = {
      'Tab': '\uE004',
      'Enter': '\uE007',
      'Escape': '\uE00C',
      'Home': '\uE011',
      'End': '\uE010',
      'ArrowDown': '\uE015',
      'ArrowUp': '\uE013',
      'ArrowLeft': '\uE012',
      'ArrowRight': '\uE014',
      'Backspace': '\uE003',
    };
    await type(keys[key] ?? key);
  }

  @override
  Future<void> type(String text) async {
    await _activate();
    await _wd('POST', '/actions', {
      'actions': [
        {
          'type': 'key',
          'id': 'gate-keyboard',
          'actions': [
            for (final rune in text.runes) ...[
              {'type': 'keyDown', 'value': String.fromCharCode(rune)},
              {'type': 'keyUp', 'value': String.fromCharCode(rune)},
            ],
          ],
        },
      ],
    });
  }

  @override
  Future<void> pointer(String selector, {bool click = false, bool down = false}) async {
    await _activate();
    final element = await _wd('POST', '/element', {'using': 'css selector', 'value': selector}) as Map;
    await _wd('POST', '/actions', {
      'actions': [
        {
          'type': 'pointer',
          'id': 'gate-mouse',
          'parameters': {'pointerType': 'mouse'},
          'actions': [
            {'type': 'pointerMove', 'origin': element, 'x': 0, 'y': 0},
            if (click || down) {'type': 'pointerDown', 'button': 0},
            if (click && !down) {'type': 'pointerUp', 'button': 0},
          ],
        },
      ],
    });
  }

  @override
  Future<void> pseudo(String selector, List<String> states) async {
    await _activate();
    await _wd('DELETE', '/actions');
    if (states.isEmpty) {
      await evaluate('document.activeElement?.blur()');
      return;
    }
    if (states.contains('hover') || states.contains('active')) await pointer(selector, down: states.contains('active'));
    if (states.contains('focus') || states.contains('focus-visible')) {
      final focusable = await evaluate(
        '''(() => {const el=document.querySelector(${jsonEncode(selector)});
        return !el.disabled && (el.matches('button,input,select,textarea,a[href],summary,[tabindex]') || el.isContentEditable);})()''',
      );
      if (focusable != true) return;
      // Reset the sequential-focus starting point to the body. Blurring alone
      // retains the previous control's position and can Tab into browser chrome.
      await evaluate(
        "(() => {window.__gateBodyTabIndex=document.body.getAttribute('tabindex');document.body.tabIndex=-1;document.body.focus();})()",
      );
      await press('Tab');
      await evaluate('''(() => {document.querySelector(${jsonEncode(selector)}).focus();
        if(window.__gateBodyTabIndex===null)document.body.removeAttribute('tabindex');
        else document.body.setAttribute('tabindex',window.__gateBodyTabIndex);})()''');
      final applied = await evaluate('($forceFocusScript)(${jsonEncode(selector)})') as Map;
      if (applied['applicable'] != true) throw StateError('focus-visible did not take effect: $selector');
    }
  }

  @override
  Future<int> listeners() async => (await evaluate('window.__uiGate.listeners()') as num).toInt();

  @override
  Future<void> history(int delta) async {
    for (var n = 0; n < delta.abs(); n++) {
      await _wd('POST', delta < 0 ? '/back' : '/forward');
    }
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  @override
  Future<void> close() async {
    try {
      await _endSession();
    } finally {
      _process.kill();
      await _process.exitCode.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          _process.kill(ProcessSignal.sigkill);
          return _process.exitCode;
        },
      );
    }
  }
}
