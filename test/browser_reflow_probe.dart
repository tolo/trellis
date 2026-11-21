/// Rendering primitive for layout assertions: a built site served over loopback
/// and measured in a real headless Chrome through the DevTools protocol.
///
/// Layout facts — overflow, wrapping, sticky offsets — cannot be read off the
/// stylesheet. A rule can be present and neutralised by a grid track, or absent
/// and compensated by an ancestor, so every claim about them has to come from a
/// browser that laid the page out. This file is the only place that talks to
/// one; assertions live in the suites that call it.
///
/// Dependency-free on purpose: `dart:io` ships a WebSocket client and an HTTP
/// server, so the DevTools protocol needs no package and the SDK keeps its
/// "no Node toolchain" property (ADR-001 minimal dependencies). It does need a
/// Chrome/Chromium binary on the machine — see [locateChrome].
///
/// Chrome's `--dump-dom` CLI is not an alternative: it silently ignores
/// `--window-size` and lays every page out at a fixed 500px viewport, so it
/// returns a plausible number for the wrong viewport.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Guard for the branch that skips a rendered check because Chrome is missing.
///
/// Locally that skip is a convenience. In CI it is a silent hole — the run
/// reports "All tests passed!" with [what] never executed, which is exactly how
/// a suite that cannot fail goes green. Fail loudly there instead.
///
/// Shared by every rendered check so there is one gate, not one per suite.
void requireChromeInCi(String what) {
  if (Platform.environment['CI'] == 'true') {
    throw StateError('Chrome is required in CI: $what did not run');
  }
}

/// Shared load-time CSP capture, also usable as a Firefox BiDi preload.
/// Deliberate policy controls are kept separate from page violations.
const cspViolationPreload = r'''(() => {
  window.__trellisCsp = {violations:[], controls:[]};
  document.addEventListener('securitypolicyviolation', e => {
    const reports = e.target?.id === 'ui-gate-policy-control' ? window.__trellisCsp.controls : window.__trellisCsp.violations;
    reports.push({directive:e.effectiveDirective, source:e.sourceFile.replace(location.origin,''),
      blocked:e.blockedURI.replace(location.origin,''), line:e.lineNumber, sample:e.sample});
  });
})()''';

/// A headless Chrome process driven over the DevTools protocol.
///
/// One instance per suite: process startup dominates the cost of a measurement,
/// while [evaluate] reuses a single tab and re-navigates.
class BrowserProbe {
  BrowserProbe._(this._process, this._socket, this._profile, this._output) {
    _socket.listen(
      _dispatch,
      onDone: () {
        for (final pending in _pending.values) {
          if (!pending.isCompleted) pending.completeError(StateError('DevTools connection closed'));
        }
        _pending.clear();
      },
    );
  }

  final Process _process;
  final WebSocket _socket;
  final Directory _profile;
  final List<StreamSubscription<Object?>> _output;
  final _pending = <int, Completer<Map<String, dynamic>>>{};
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  var _nextId = 0;
  String? _sessionId;

  /// Events from the attached page, for request and console observation.
  Stream<Map<String, dynamic>> get events => _events.stream.where((event) => event['sessionId'] == _sessionId);

  /// Sends a page-scoped command through the shared DevTools connection.
  ///
  /// Gate input and instrumentation reuse this lifecycle instead of launching
  /// a second browser client with different profile and shutdown behavior.
  Future<Map<String, dynamic>> command(String method, [Map<String, Object?> params = const {}]) =>
      _send(method, params, session: true);

  /// Arms instrumentation before any script in the next document executes.
  Future<void> preloadScript(String script) async {
    await command('Page.addScriptToEvaluateOnNewDocument', {'source': script});
  }

  /// Captures violations from the first page script, before the next navigation.
  Future<void> captureSecurityPolicyViolations() => preloadScript(cspViolationPreload);

  /// Structured CSP violations from the current document, excluding controls.
  Future<List<Map<String, Object?>>> securityPolicyViolations() async =>
      (await evaluateHere('window.__trellisCsp?.violations || []') as List)
          .map((item) => (item as Map).cast<String, Object?>())
          .toList();

  /// Native listeners on an object, including ones installed by page scripts.
  Future<int> listenerCount([String expression = 'document']) async {
    final object = await command('Runtime.evaluate', {'expression': expression});
    final result = await command('DOMDebugger.getEventListeners', {'objectId': (object['result'] as Map)['objectId']});
    return (result['listeners'] as List).length;
  }

  /// Absolute path of a Chrome/Chromium binary, or null when none is installed.
  ///
  /// `CHROME_PATH`/`CHROME_BIN` win so a CI image can point at its own build.
  static String? locateChrome() {
    for (final key in const ['CHROME_PATH', 'CHROME_BIN']) {
      final value = Platform.environment[key];
      if (value != null && value.isNotEmpty && File(value).existsSync()) return value;
    }
    const candidates = [
      '/usr/bin/google-chrome-stable',
      '/usr/bin/google-chrome',
      '/usr/bin/chromium-browser',
      '/usr/bin/chromium',
      '/snap/bin/chromium',
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      '/Applications/Chromium.app/Contents/MacOS/Chromium',
    ];
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) return candidate;
    }
    return null;
  }

  /// Start headless Chrome and attach to a fresh tab.
  ///
  /// The profile is a throwaway temp directory: a shared profile would let a
  /// previous run's cache answer for a rebuilt stylesheet.
  static Future<BrowserProbe> launch({List<String> extraArguments = const []}) async {
    final executable = locateChrome();
    if (executable == null) throw StateError('no Chrome/Chromium binary found');
    final profile = Directory.systemTemp.createTempSync('trellis_probe_profile_');
    Process? process;
    BrowserProbe? probe;
    final output = <StreamSubscription<Object?>>[];
    try {
      process = await Process.start(executable, [
        '--headless=new',
        '--remote-debugging-port=0',
        '--user-data-dir=${profile.path}',
        // Scrollbars would eat a browser-specific slice of clientWidth and make
        // an exact width comparison depend on the platform's scrollbar policy.
        '--hide-scrollbars',
        '--no-first-run',
        '--no-default-browser-check',
        '--no-sandbox',
        '--disable-gpu',
        '--disable-extensions',
        '--disable-sync',
        '--disable-background-networking',
        '--use-mock-keychain',
        ...extraArguments,
        'about:blank',
      ]);

      final endpoint = Completer<String>();
      output.add(
        process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
          final match = RegExp(r'ws://\S+').firstMatch(line);
          if (match != null && !endpoint.isCompleted) {
            endpoint.complete(match[0]);
          }
        }),
      );
      output.add(process.stdout.listen((_) {}));

      final url = await endpoint.future.timeout(const Duration(seconds: 30));
      probe = BrowserProbe._(process, await WebSocket.connect(url), profile, output);
      await probe._attach();
      return probe;
    } on Object {
      if (probe != null) {
        await probe.close();
      } else {
        process?.kill(ProcessSignal.sigkill);
        if (process != null) {
          await process.exitCode;
        }
        for (final subscription in output) {
          await subscription.cancel();
        }
        await _removeProfile(profile);
      }
      rethrow;
    }
  }

  Future<void> _attach() async {
    final target = await _send('Target.createTarget', {'url': 'about:blank'});
    final targetId = target['targetId'] as String;
    final attached = await _send('Target.attachToTarget', {'targetId': targetId, 'flatten': true});
    _sessionId = attached['sessionId'] as String;
    await _send('Page.enable', const {}, session: true);
  }

  /// Load [url] at a [width] x [height] viewport under `prefers-color-scheme:
  /// [colorScheme]` and return the JSON value of [expression].
  ///
  /// [expression] is evaluated after the load event and after `document.fonts.
  /// ready`, because a fallback font measures differently from the webfont the
  /// page ships. It may itself evaluate to a Future/Promise.
  /// Set [disableScripts] to load the page as a reader with JavaScript off would
  /// see it. Without it, a progressive-enhancement check races the page's own
  /// scripts: the load event fires before a `fetch` resolves, so the same
  /// assertion sees the pre-script DOM on one run and the post-script DOM on the
  /// next. The expression itself still evaluates — this blocks the page's
  /// scripts, not the injected one, the same as DevTools' "Disable JavaScript".
  Future<Object?> evaluate(
    Uri url,
    String expression, {
    required int width,
    required int height,
    String colorScheme = 'light',
    String reducedMotion = 'no-preference',
    bool disableScripts = false,
  }) async {
    await _send('Emulation.setScriptExecutionDisabled', {'value': disableScripts}, session: true);
    await _send('Emulation.setDeviceMetricsOverride', {
      'width': width,
      'height': height,
      'deviceScaleFactor': 1,
      'mobile': false,
    }, session: true);
    await _send('Emulation.setEmulatedMedia', {
      'features': [
        {'name': 'prefers-color-scheme', 'value': colorScheme},
        {'name': 'prefers-reduced-motion', 'value': reducedMotion},
      ],
    }, session: true);
    await _loadPage('Page.navigate', {'url': url.toString()});
    return _evaluate(expression, url.toString());
  }

  /// Reload the attached document without changing its URL or history entry.
  Future<void> reload() => _loadPage('Page.reload');

  Future<void> _loadPage(String method, [Map<String, Object?> params = const {}]) async {
    final loaded = _events.stream.firstWhere(
      (event) => event['method'] == 'Page.loadEventFired' && event['sessionId'] == _sessionId,
    );
    await _send(method, params, session: true);
    await loaded.timeout(const Duration(seconds: 30));
  }

  /// Re-measure the page [evaluate] last loaded, optionally under a different
  /// viewport or color scheme, without navigating again.
  ///
  /// Both overrides re-run layout and re-resolve media queries on the live
  /// document, so a sweep over widths and schemes costs one navigation per page
  /// instead of one per combination. Use [evaluate] when the page's own load-time
  /// JavaScript is part of what is being measured.
  Future<Object?> evaluateHere(
    String expression, {
    int? width,
    int? height,
    String? colorScheme,
    String reducedMotion = 'no-preference',
  }) async {
    if (width != null && height != null) {
      await _send('Emulation.setDeviceMetricsOverride', {
        'width': width,
        'height': height,
        'deviceScaleFactor': 1,
        'mobile': false,
      }, session: true);
    }
    if (colorScheme != null || reducedMotion != 'no-preference') {
      await _send('Emulation.setEmulatedMedia', {
        'features': [
          if (colorScheme != null) {'name': 'prefers-color-scheme', 'value': colorScheme},
          {'name': 'prefers-reduced-motion', 'value': reducedMotion},
        ],
      }, session: true);
    }
    return _evaluate(expression, 'the current document');
  }

  Future<Object?> _evaluate(String expression, String where) async {
    final result = await _send('Runtime.evaluate', {
      'expression': 'document.fonts.ready.then(() => ($expression))',
      'awaitPromise': true,
      'returnByValue': true,
    }, session: true);
    if (result['exceptionDetails'] != null) {
      throw StateError('evaluate failed on $where: ${result['exceptionDetails']}');
    }
    return (result['result'] as Map<String, dynamic>)['value'];
  }

  /// PNG bytes of the current viewport.
  ///
  /// Viewport size and emulated color scheme are whatever the last [evaluate]
  /// established, so capture directly after the measurement it belongs to.
  Future<Uint8List> screenshot() async {
    final result = await _send('Page.captureScreenshot', const {'format': 'png'}, session: true);
    return base64Decode(result['data'] as String);
  }

  /// Force the focus-visible pseudo-state on every interactive control.
  ///
  /// Programmatic `focus()` does not consistently put links into Chrome's
  /// keyboard modality. DevTools' forced pseudo-state is the same mechanism the
  /// browser inspector uses and makes the computed focus ring deterministic.
  Future<void> forceFocusVisible() async {
    await _send('DOM.enable', const {}, session: true);
    await _send('CSS.enable', const {}, session: true);
    final document = await _send('DOM.getDocument', const {}, session: true);
    final root = (document['root'] as Map)['nodeId'] as int;
    final matches = await _send('DOM.querySelectorAll', {
      'nodeId': root,
      'selector': 'a[href], button, input, summary, select, textarea',
    }, session: true);
    for (final nodeId in (matches['nodeIds'] as List).cast<int>()) {
      await _send('CSS.forcePseudoState', {
        'nodeId': nodeId,
        'forcedPseudoClasses': ['focus', 'focus-visible'],
      }, session: true);
    }
  }

  /// Shut the browser down and remove its throwaway profile.
  Future<void> close() async {
    try {
      // Chrome can close the connection before acknowledging Browser.close.
      // Process exit, not that acknowledgement, determines shutdown completion.
      unawaited(_send('Browser.close', const {}).then<void>((_) {}, onError: (Object _) {}));
    } on Object {
      // The transport may already be closed; the process deadline still applies.
    }
    try {
      await _process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      _process.kill(ProcessSignal.sigkill);
      await _process.exitCode;
    } finally {
      // Descendants can retain these writers after the main browser exits.
      // Release our readers rather than waiting for an EOF they may never send.
      for (final subscription in _output) {
        await subscription.cancel();
      }
      await _socket.close();
      await _events.close();
      await _removeProfile(_profile);
    }
  }

  /// Delete the throwaway profile, tolerating Chrome outliving its own process.
  ///
  /// Killing the browser process does not reap its zygote and renderer children
  /// on Linux; they keep writing into the profile for a moment afterwards, so a
  /// recursive delete races them and throws `Directory not empty`. That is
  /// deterministic on Linux (every run of every probe-backed suite in a
  /// container) and unseen on macOS, and it surfaced as a `tearDownAll` failure
  /// — a suite reporting a cleanup race as a rendering defect, which is exactly
  /// the noise that teaches a team to ignore a red rendered check.
  ///
  /// The profile is a temp directory, so not removing it is litter the OS
  /// reaps, not a broken assertion: retry briefly, then say so and move on.
  static Future<void> _removeProfile(Directory profile) async {
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!profile.existsSync()) {
        return;
      }
      try {
        profile.deleteSync(recursive: true);
        return;
      } on FileSystemException {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    stderr.writeln('browser probe: ${profile.path} still busy after the browser exited; left for the OS to reap');
  }

  void _dispatch(Object? data) {
    final message = jsonDecode(data! as String) as Map<String, dynamic>;
    final id = message['id'];
    if (id is int) {
      final pending = _pending.remove(id);
      if (pending == null || pending.isCompleted) return;
      final error = message['error'];
      if (error != null) {
        pending.completeError(StateError('DevTools error: $error'));
      } else {
        pending.complete((message['result'] as Map).cast<String, dynamic>());
      }
    } else if (!_events.isClosed) {
      _events.add(message);
    }
  }

  Future<Map<String, dynamic>> _send(String method, Map<String, Object?> params, {bool session = false}) {
    final id = ++_nextId;
    final completer = Completer<Map<String, dynamic>>();
    _pending[id] = completer;
    _socket.add(jsonEncode({'id': id, 'method': method, 'params': params, if (session) 'sessionId': _sessionId}));
    return completer.future.timeout(const Duration(seconds: 60));
  }
}

/// A read-only HTTP server over a built site directory.
///
/// Root-absolute asset URLs (`/css/main.css`) are what the themes emit, and
/// `file://` resolves those against the filesystem root, so a built site can
/// only be laid out correctly over HTTP. Binds an ephemeral loopback port so
/// concurrent suites never collide.
class StaticSiteServer {
  StaticSiteServer._(
    this._server,
    this._root,
    this._headers,
    this._statusCodes,
    this._disconnectPaths,
    this._beforeResponses,
  );

  final HttpServer _server;
  final Directory _root;
  final Map<String, String> _headers;
  final Map<String, int> _statusCodes;
  final Set<String> _disconnectPaths;
  final Map<String, Future<void>> _beforeResponses;

  static Future<StaticSiteServer> serve(
    Directory root, {
    Map<String, String> headers = const {},
    Map<String, int> statusCodes = const {},
    Set<String> disconnectPaths = const {},
    Map<String, Future<void>> beforeResponses = const {},
  }) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final instance = StaticSiteServer._(
      server,
      root,
      Map.unmodifiable(headers),
      Map.unmodifiable(statusCodes),
      Set.unmodifiable(disconnectPaths),
      Map.unmodifiable(beforeResponses),
    );
    unawaited(instance._listen());
    return instance;
  }

  /// Origin the site is reachable at, e.g. `http://127.0.0.1:54321`.
  Uri get baseUrl => Uri.parse('http://127.0.0.1:${_server.port}');

  Future<void> close() => _server.close(force: true);

  Future<void> _listen() async {
    await for (final request in _server) {
      if (_beforeResponses[request.uri.path] case final ready?) {
        unawaited(ready.then((_) => _respond(request)));
      } else {
        await _respond(request);
      }
    }
  }

  Future<void> _respond(HttpRequest request) async {
    if (_disconnectPaths.contains(request.uri.path)) {
      final socket = await request.response.detachSocket(writeHeaders: false);
      socket.destroy();
      return;
    }
    _headers.forEach(request.response.headers.set);
    if (_statusCodes[request.uri.path] case final status?) {
      request.response.statusCode = status;
      await request.response.close();
      return;
    }
    final relative = Uri.decodeComponent(request.uri.path).replaceFirst(RegExp('^/'), '');
    var file = File('${_root.path}/$relative');
    if (relative.isEmpty || file.statSync().type == FileSystemEntityType.directory) {
      file = File('${_root.path}/$relative${relative.endsWith('/') || relative.isEmpty ? '' : '/'}index.html');
    }
    if (!file.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
    } else {
      request.response.headers.contentType = _contentTypeFor(file.path);
      // No caching: a suite rebuilds the same origin's stylesheet between
      // measurements, and a 304 would silently measure the previous build.
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      request.response.add(file.readAsBytesSync());
    }
    await request.response.close();
  }

  static ContentType _contentTypeFor(String path) => switch (path.split('.').last.toLowerCase()) {
    'html' => ContentType.html,
    'css' => ContentType('text', 'css', charset: 'utf-8'),
    'js' => ContentType('text', 'javascript', charset: 'utf-8'),
    'json' => ContentType.json,
    'svg' => ContentType('image', 'svg+xml'),
    'woff2' => ContentType('font', 'woff2'),
    'png' => ContentType('image', 'png'),
    'webp' => ContentType('image', 'webp'),
    'jpg' || 'jpeg' => ContentType('image', 'jpeg'),
    'xml' => ContentType('application', 'xml', charset: 'utf-8'),
    _ => ContentType.binary,
  };
}
