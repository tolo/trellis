import 'dart:async';
import 'dart:convert';

import '../../test/browser_reflow_probe.dart';

/// Browser-independent input and observation used by every gate item.
abstract interface class GateDriver {
  String get name;
  List<String> get requests;
  List<String> get console;
  Future<void> open(Uri url);
  Future<Object?> evaluate(String expression);
  Future<void> viewport(int width, int height);
  Future<bool> media({bool coarse = false, bool forcedColors = false, bool reducedMotion = false, bool dark = false});
  Future<void> press(String key);
  Future<void> type(String text);
  Future<void> pointer(String selector, {bool click = false, bool down = false});
  Future<void> pseudo(String selector, List<String> states);
  Future<int> listeners();
  Future<void> history(int delta);
  Future<void> close();
}

/// Prepares the native pointer target in the viewport, including nested scrollers.
const pointerTargetScript = r'''function(selector) {
  const target = document.querySelector(selector);
  if (!target) throw Error('missing selector: ' + selector);
  target.scrollIntoView({block:'nearest', inline:'nearest', behavior:'instant'});
  return target;
}''';

/// Preload captures page behavior from the first script, including load CSP.
const gatePreload = cspViolationPreload + ';' + gateInstrumentationPreload;

const gateInstrumentationPreload = r'''(() => {
  const live = new WeakMap();
  window.__uiGate = {get violations(){return window.__trellisCsp.violations;}, get controls(){return window.__trellisCsp.controls;}, instances: {}, listeners: () => {
    const targets = [document, window, document.body];
    return targets.reduce((sum, target) => sum + (live.get(target)?.length || 0), 0);
  }};
  const add = EventTarget.prototype.addEventListener, remove = EventTarget.prototype.removeEventListener;
  EventTarget.prototype.addEventListener = function(type, fn, options) {
    if (!fn) return add.call(this, type, fn, options);
    const capture = typeof options === 'boolean' ? options : !!options?.capture;
    const list = live.get(this) || [];
    let record = list.find(x => x.type === type && x.fn === fn && x.capture === capture);
    if (!record) {
      const target = this;
      const forget = () => live.set(target, (live.get(target) || []).filter(x => x !== record));
      record = {type, fn, capture, wrapped: function(event) {
        if (options?.once) forget();
        return typeof fn === 'function' ? fn.call(this, event) : fn.handleEvent(event);
      }};
      if (!options?.signal?.aborted) list.push(record);
      live.set(this, list);
      if (options?.signal) add.call(options.signal, 'abort', forget, {once:true});
    }
    return add.call(this, type, record.wrapped, options);
  };
  EventTarget.prototype.removeEventListener = function(type, fn, options) {
    const capture = typeof options === 'boolean' ? options : !!options?.capture;
    const list = live.get(this) || [];
    const record = list.find(x => x.type === type && x.fn === fn && x.capture === capture);
    live.set(this, list.filter(x => x !== record));
    return remove.call(this, type, record?.wrapped || fn, options);
  };
  const define = customElements.define.bind(customElements);
  customElements.define = (tag, ctor, options) => {
    const connect = ctor.prototype.connectedCallback, disconnect = ctor.prototype.disconnectedCallback;
    const bump = n => window.__uiGate.instances[tag] = (window.__uiGate.instances[tag] || 0) + n;
    ctor.prototype.connectedCallback = function() { bump(1); return connect?.call(this); };
    ctor.prototype.disconnectedCallback = function() { bump(-1); return disconnect?.call(this); };
    define(tag, ctor, options);
  };
})()''';

/// Chrome adapter using the repository's existing CDP process owner.
final class ChromeDriver implements GateDriver {
  ChromeDriver._(this.probe) {
    _subscription = probe.events.listen((event) {
      final params = (event['params'] as Map?) ?? const {};
      if (event['method'] == 'Network.requestWillBeSent') requests.add((params['request'] as Map)['url'] as String);
      if (event['method'] == 'Runtime.consoleAPICalled') console.add(jsonEncode(params['args']));
    });
  }

  final BrowserProbe probe;
  late final StreamSubscription<Map<String, dynamic>> _subscription;
  int _width = 1440;
  int _height = 900;
  @override
  final name = 'chrome';
  @override
  final requests = <String>[];
  @override
  final console = <String>[];

  static Future<ChromeDriver> launch() async {
    final driver = ChromeDriver._(await BrowserProbe.launch());
    await driver.probe.command('Network.enable');
    await driver.probe.command('Runtime.enable');
    await driver.probe.captureSecurityPolicyViolations();
    await driver.probe.preloadScript(gateInstrumentationPreload);
    return driver;
  }

  @override
  Future<void> open(Uri url) async {
    await probe.command('Emulation.setFocusEmulationEnabled', {'enabled': false});
    await probe.evaluate(url, 'true', width: _width, height: _height);
  }

  @override
  Future<Object?> evaluate(String expression) => probe.evaluateHere(expression);

  @override
  Future<void> viewport(int width, int height) async {
    _width = width;
    _height = height;
    await probe.command('Emulation.setDeviceMetricsOverride', {
      'width': width,
      'height': height,
      'deviceScaleFactor': 1,
      'mobile': false,
    });
  }

  @override
  Future<bool> media({
    bool coarse = false,
    bool forcedColors = false,
    bool reducedMotion = false,
    bool dark = false,
  }) async {
    await probe.command('Emulation.setTouchEmulationEnabled', {'enabled': coarse});
    await probe.command('Emulation.setEmulatedMedia', {
      'features': [
        {'name': 'forced-colors', 'value': forcedColors ? 'active' : 'none'},
        {'name': 'prefers-reduced-motion', 'value': reducedMotion ? 'reduce' : 'no-preference'},
        {'name': 'prefers-color-scheme', 'value': dark ? 'dark' : 'light'},
      ],
    });
    return await evaluate('''matchMedia('(pointer: coarse)').matches === $coarse &&
      matchMedia('(forced-colors: active)').matches === $forcedColors &&
      matchMedia('(prefers-reduced-motion: reduce)').matches === $reducedMotion &&
      matchMedia('(prefers-color-scheme: dark)').matches === $dark''') ==
        true;
  }

  @override
  Future<void> press(String key) async {
    const codes = {
      'Tab': 9,
      'Enter': 13,
      'Escape': 27,
      ' ': 32,
      'Home': 36,
      'End': 35,
      'ArrowLeft': 37,
      'ArrowUp': 38,
      'ArrowRight': 39,
      'ArrowDown': 40,
      'Backspace': 8,
    };
    final code = codes[key] ?? (key.length == 1 ? key.toUpperCase().codeUnitAt(0) : 0);
    for (final type in ['keyDown', 'keyUp']) {
      await probe.command('Input.dispatchKeyEvent', {
        'type': type,
        'key': key,
        'windowsVirtualKeyCode': code,
        if (type == 'keyDown' && (key.length == 1 || key == 'Enter')) 'text': key == 'Enter' ? '\r' : key,
      });
    }
  }

  @override
  Future<void> type(String text) async {
    await probe.command('Input.insertText', {'text': text});
  }

  @override
  Future<void> pointer(String selector, {bool click = false, bool down = false}) async {
    final box =
        (await evaluate('''(() => {
      const r=($pointerTargetScript)(${jsonEncode(selector)}).getBoundingClientRect();
      return [r.x+r.width/2, r.y+r.height/2]; })()''')
                as List)
            .cast<num>();
    await probe.command('Input.dispatchMouseEvent', {'type': 'mouseMoved', 'x': box[0], 'y': box[1]});
    if (click || down) {
      await probe.command('Input.dispatchMouseEvent', {
        'type': 'mousePressed',
        'x': box[0],
        'y': box[1],
        'button': 'left',
        'clickCount': 1,
      });
      if (!down)
        await probe.command('Input.dispatchMouseEvent', {
          'type': 'mouseReleased',
          'x': box[0],
          'y': box[1],
          'button': 'left',
          'clickCount': 1,
        });
    }
  }

  @override
  Future<void> pseudo(String selector, List<String> states) async {
    final focus = states.contains('focus') || states.contains('focus-visible');
    // Keep document activation part of the forced state, including when another
    // owned browser window is open. Navigation and non-focus states undo it.
    await probe.command('Emulation.setFocusEmulationEnabled', {'enabled': focus});
    if (focus) {
      await probe.command('Page.bringToFront');
    }
    await probe.command('DOM.enable');
    await probe.command('CSS.enable');
    final document = await probe.command('DOM.getDocument');
    final matches = await probe.command('DOM.querySelectorAll', {
      'nodeId': (document['root'] as Map)['nodeId'],
      'selector': selector,
    });
    if ((matches['nodeIds'] as List).isEmpty) throw StateError('missing selector: $selector');
    for (final node in matches['nodeIds'] as List) {
      await probe.command('CSS.forcePseudoState', {'nodeId': node, 'forcedPseudoClasses': states});
    }
  }

  @override
  Future<int> listeners() async =>
      await probe.listenerCount('document') +
      await probe.listenerCount('window') +
      await probe.listenerCount('document.body');

  @override
  Future<void> history(int delta) async {
    await evaluate('history.go($delta)');
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await probe.close();
  }
}
