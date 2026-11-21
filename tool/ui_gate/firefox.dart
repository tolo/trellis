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

  /// Reads the location through WebDriver while a document may be unloading.
  Future<Uri> currentUrl() async => Uri.parse(await _wd('GET', '/url') as String);

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

  Future<void> pressShortcut(String key, {required bool command}) {
    final modifier = command ? '\uE03D' : '\uE009';
    return _keyActions([
      {'type': 'keyDown', 'value': modifier},
      {'type': 'keyDown', 'value': key},
      {'type': 'keyUp', 'value': key},
      {'type': 'keyUp', 'value': modifier},
    ]);
  }

  @override
  Future<void> type(String text) => _keyActions([
    for (final rune in text.runes) ...[
      {'type': 'keyDown', 'value': String.fromCharCode(rune)},
      {'type': 'keyUp', 'value': String.fromCharCode(rune)},
    ],
  ]);

  Future<void> _keyActions(List<Map<String, String>> actions) async {
    await _activate();
    await _wd('POST', '/actions', {
      'actions': [
        {'type': 'key', 'id': 'gate-keyboard', 'actions': actions},
      ],
    });
  }

  @override
  Future<void> pointer(String selector, {bool click = false, bool down = false}) =>
      _pointer(selector, 'mouse', click: click, down: down);

  /// Sends a trusted touch tap through W3C WebDriver actions.
  Future<void> tap(String selector) => _pointer(selector, 'touch', click: true);

  Future<void> _pointer(String selector, String type, {bool click = false, bool down = false}) async {
    await _activate();
    await evaluate('Boolean(($pointerTargetScript)(${jsonEncode(selector)}))');
    final element = await _wd('POST', '/element', {'using': 'css selector', 'value': selector}) as Map;
    await _wd('POST', '/actions', {
      'actions': [
        {
          'type': 'pointer',
          'id': 'gate-$type',
          'parameters': {'pointerType': type},
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
  Future<void> dragTouch(String selector, {required int dx, required int dy}) async {
    await _activate();
    await evaluate('Boolean(($pointerTargetScript)(${jsonEncode(selector)}))');
    final element = await _wd('POST', '/element', {'using': 'css selector', 'value': selector}) as Map;
    await _wd('POST', '/actions', {
      'actions': [
        {
          'type': 'pointer',
          'id': 'gate-swipe',
          'parameters': {'pointerType': 'touch'},
          'actions': [
            {'type': 'pointerMove', 'origin': element, 'x': 0, 'y': 0},
            {'type': 'pointerDown', 'button': 0},
            {'type': 'pointerMove', 'origin': 'pointer', 'x': dx, 'y': dy, 'duration': 160},
            {'type': 'pointerUp', 'button': 0},
          ],
        },
      ],
    });
  }

  bool _forcedActive = false;

  Future<void> _releasePseudoActions() async {
    if (_forcedActive) {
      // Releasing WebDriver's forced :active pointer would activate links and
      // htmx controls. Suppress only that synthetic cleanup click, not real input.
      // Remove when Firefox can force :active without held pointer input.
      await evaluate('''(() => {
        window.__gateCancelForcedClick=e=>{e.preventDefault();e.stopImmediatePropagation()};
        document.addEventListener('click',window.__gateCancelForcedClick,true);
      })()''');
    }
    await _wd('DELETE', '/actions');
    if (_forcedActive) {
      await evaluate('''(() => {
        document.removeEventListener('click',window.__gateCancelForcedClick,true);
        delete window.__gateCancelForcedClick;
      })()''');
      _forcedActive = false;
    }
  }

  @override
  Future<void> pseudo(String selector, List<String> states) async {
    await _activate();
    await _releasePseudoActions();
    if (states.isEmpty) {
      await evaluate('document.activeElement?.blur()');
      return;
    }
    // BiDi's native actions need a rendered target. Appearance also captures
    // dormant controls, whose pointer and focus states are inapplicable.
    final visible = await evaluate('''(() => {
      const el=document.querySelector(${jsonEncode(selector)});
      if(!el) throw Error('missing appearance element ' + ${jsonEncode(selector)});
      const rect=el.getBoundingClientRect();
      return Boolean(rect.width && rect.height && getComputedStyle(el).visibility === 'visible');
    })()''');
    if (visible != true) return;
    if (states.contains('hover') || states.contains('active')) {
      _forcedActive = states.contains('active');
      await pointer(selector, down: _forcedActive);
    }
    if (states.contains('focus') || states.contains('focus-visible')) {
      final focusable = await evaluate(
        '''(() => {const el=document.querySelector(${jsonEncode(selector)});
        return !el.disabled && (el.matches('button,input,select,textarea,a[href],summary,[tabindex]') || el.isContentEditable);})()''',
      );
      if (focusable != true) return;
      // Reset the sequential starting point so native Tab enters the control list.
      // A modal makes the body inert, and a one-stop dialog can cancel a Tab sent
      // from its only control before Firefox switches to keyboard focus paint.
      await evaluate('''(() => {
        const element = document.querySelector(${jsonEncode(selector)});
        const start = element.closest('dialog:modal') ?? document.body;
        window.__gateFocusStart = {start, tabindex: start.getAttribute('tabindex')};
        start.tabIndex = -1;
        start.focus();
      })()''');
      try {
        await press('Tab');
        await evaluate('document.querySelector(${jsonEncode(selector)}).focus()');
      } finally {
        await evaluate('''(() => {
          const {start, tabindex} = window.__gateFocusStart;
          if (tabindex === null) start.removeAttribute('tabindex');
          else start.setAttribute('tabindex', tabindex);
          delete window.__gateFocusStart;
        })()''');
      }
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
