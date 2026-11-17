import 'dart:convert';
import 'dart:io';

import '../visual_baseline.dart';

import 'driver.dart';
import 'manifest.dart';

/// Policy used by fixture servers and checked on the target page.
const strictPolicy =
    "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; "
    "font-src 'self' data:; connect-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'";

const automatedItems = [
  'provenance',
  'self-hosting',
  'strict-csp',
  'semantic-markup',
  'htmx-lifecycle',
  'keyboard',
  'wcag-axe',
  'forced-colors',
  'responsive',
  'zoom',
  'reduced-motion',
  'touch-target',
  'visual',
];
const manualItems = ['screen-reader-voiceover-safari', 'screen-reader-nvda-firefox', 'safari'];

/// An item's observed outcome; unsupported emulation is distinct from success.
final class GateResult {
  const GateResult(this.status, this.evidence, {this.unsupported = false});
  final String status;
  final List<String> evidence;
  final bool unsupported;
  Map<String, Object?> toJson() => {'status': status, 'evidence': evidence, if (unsupported) 'unsupported': true};
}

/// A requested condition was not observed, so its item cannot claim a pass.
final class UnsupportedCondition implements Exception {
  const UnsupportedCondition(this.reason);
  final String reason;
  @override
  String toString() => reason;
}

/// Executes data recipes against one browser, with fresh loads per state.
final class GateSession {
  GateSession(this.manifest, this.driver, this.base);
  final GateManifest manifest;
  final GateDriver driver;
  final Uri base;
  final violations = <String>[];
  final blockedRequests = <String>{};
  final _failures = <String>[];
  bool _loaded = false;

  String normalize(String value) => value
      .replaceAll(base.origin, '')
      .replaceAll(Directory.current.path, '<project>')
      .replaceAll(manifest.file.parent.absolute.path, '<manifest-dir>')
      .replaceAll(RegExp(r'127\.0\.0\.1:\d+'), '127.0.0.1:<port>');

  Future<void> collect() async {
    if (!_loaded) return;
    final entries = await driver.evaluate('window.__uiGate?.violations || []') as List;
    for (final raw in entries) {
      final item = raw as Map;
      blockedRequests.add('${item['blocked']}');
      final text = normalize(
        '${item['directive']} source=${item['source']} blocked=${item['blocked']} line=${item['line']}',
      );
      if (!violations.contains(text)) violations.add(text);
    }
  }

  Future<void> load([String state = 'default']) => configure(state);

  Future<void> configure(
    String state, {
    bool coarse = false,
    bool forcedColors = false,
    bool reducedMotion = false,
    bool dark = false,
  }) async {
    await collect();
    await driver.open(base.resolve(manifest.page));
    _loaded = true;
    final confirmed = await driver.media(
      coarse: coarse,
      forcedColors: forcedColors,
      reducedMotion: reducedMotion,
      dark: dark,
    );
    if (!confirmed)
      throw UnsupportedCondition(
        'condition did not read back: coarse=$coarse forced-colors=$forcedColors reduced-motion=$reducedMotion dark=$dark',
      );
    await steps(manifest.steps(manifest.states[state]), label: 'state $state');
  }

  /// Declarative input is shared by both browser drivers.
  Future<void> steps(List<Map<String, Object?>> steps, {String label = 'script'}) async {
    for (var index = 0; index < steps.length; index++) {
      final entry = steps[index].entries.single;
      final value = entry.value;
      try {
        switch (entry.key) {
          case 'focus':
            await driver.evaluate('''(() => {const el=document.querySelector(${jsonEncode(value)});
              if(!el) throw Error('missing selector: '+${jsonEncode(value)}); el.focus();})()''');
          case 'click':
            await driver.pointer(value! as String, click: true);
          case 'hover':
            await driver.pointer(value! as String);
          case 'type':
            await driver.type(value! as String);
          case 'press':
            await driver.press(value! as String);
          case 'eval':
            await driver.evaluate(value! as String);
          case 'wait':
            if (value is num) {
              await Future<void>.delayed(Duration(milliseconds: value.toInt()));
            } else {
              await waitFor(value! as String);
            }
          case 'expect':
            final assertion = value! as Map;
            final actual = await driver.evaluate(assertion['expression'] as String);
            if (jsonEncode(actual) != jsonEncode(assertion['equals']))
              throw StateError('expected ${jsonEncode(assertion['equals'])}, actual ${jsonEncode(actual)}');
          case 'state':
            if (!manifest.states.containsKey(value)) throw StateError('unknown state: $value');
            await this.steps(manifest.steps(manifest.states[value]), label: 'state $value');
          case 'axe':
            final issues = await axe();
            if (issues.isNotEmpty) throw StateError(issues.join('; '));
        }
      } on Object catch (error) {
        throw StateError('$label step ${index + 1} ${entry.key}: ${normalize('$error')}');
      }
    }
  }

  Future<void> waitFor(String expression) async {
    for (var n = 0; n < 100; n++) {
      if (await driver.evaluate(expression) == true) return;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError('wait timed out: $expression');
  }

  Future<GateResult> measured(Future<void> Function() check) async {
    _failures.clear();
    try {
      await check();
    } on UnsupportedCondition catch (error) {
      await collect();
      if (_failures.isNotEmpty) return GateResult('fail', [..._failures, error.reason]);
      return GateResult('not-run', [error.reason], unsupported: true);
    } on Object catch (error) {
      _failures.add(normalize('$error'));
    }
    await collect();
    return GateResult(_failures.isEmpty ? 'pass' : 'fail', _failures.isEmpty ? ['checks completed'] : [..._failures]);
  }

  void require(bool condition, String evidence) {
    if (!condition) _failures.add(evidence);
  }

  Future<GateResult> security() => measured(() async {
    final client = HttpClient();
    String? policy;
    try {
      final response = await (await client.getUrl(base.resolve(manifest.page))).close();
      policy = response.headers.value('content-security-policy');
      await response.drain<void>();
    } finally {
      client.close(force: true);
    }
    final directives = <String, String>{};
    for (final part in (policy ?? '').split(';')) {
      final fields = part.trim().split(RegExp(r'\s+'));
      if (fields.first.isNotEmpty) directives[fields.first] = fields.skip(1).join(' ');
    }
    for (final part in strictPolicy.split(';')) {
      final fields = part.trim().split(RegExp(r'\s+'));
      require(
        directives[fields.first] == fields.skip(1).join(' '),
        'policy ${fields.first}: expected ${fields.skip(1).join(' ')}, actual ${directives[fields.first] ?? 'missing'}',
      );
    }
    if (directives.keys.any(
      (key) => {'script-src-elem', 'script-src-attr', 'style-src-elem', 'style-src-attr'}.contains(key),
    )) {
      for (final key in ['script-src-elem', 'script-src-attr', 'style-src-elem', 'style-src-attr']) {
        if (directives[key] != null)
          require(directives[key] == "'self'" || directives[key] == "'none'", 'policy $key relaxes the strict policy');
      }
    }
    // The deliberate script control is labelled and collected separately from
    // page defects; it must be blocked before zero reports can mean a pass.
    await driver.evaluate('''(() => {window.__uiGateControlRan=false;
      const control=document.createElement('script');control.id='ui-gate-policy-control';
      control.textContent='window.__uiGateControlRan=true';document.head.append(control);})()''');
    await Future<void>.delayed(const Duration(milliseconds: 40));
    final enforced = await driver.evaluate(
      "!window.__uiGateControlRan && window.__uiGate.controls.some(v=>v.directive.startsWith('script-src'))",
    );
    require(enforced == true, 'policy control was not blocked');
    await driver.evaluate("document.getElementById('ui-gate-policy-control').remove()");
    await collect();
    _failures.addAll(violations);
  });

  GateResult selfHosting() {
    final external = <String>{};
    for (final request in [...driver.requests, ...blockedRequests]) {
      final uri = Uri.tryParse(request);
      if (uri != null && {'http', 'https'}.contains(uri.scheme) && uri.origin != base.origin)
        external.add(normalize(request));
    }
    return GateResult(
      external.isEmpty ? 'pass' : 'fail',
      external.isEmpty ? ['all requests same-origin'] : external.toList()
        ..sort(),
    );
  }

  Future<List<String>> axe() async {
    await driver.evaluate('(() => {${File('tool/ui_gate/vendor/axe.min.js').readAsStringSync()}; return true;})()');
    final disabled = ((manifest.data['axe'] as Map?)?['disable'] as Map?) ?? const {};
    final raw =
        await driver.evaluate('''axe.run(document.querySelector(${jsonEncode(manifest.root)}), {
      runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21a','wcag21aa','wcag22aa']},
      rules:${jsonEncode({
              for (final key in disabled.keys) key: {'enabled': false},
            })}}).then(r=>r.violations.map(v=>v.id+': '+v.nodes.map(n=>n.target.join(' ')).join(', ')))''')
            as List;
    return raw.cast<String>();
  }

  Future<GateResult> accessibility() => measured(() async {
    for (final state in manifest.states.keys) {
      await load(state);
      _failures.addAll((await axe()).map((issue) => '$state: $issue'));
    }
  });

  Future<GateResult> semantics() => (manifest.data['semantics'] as List? ?? const []).isEmpty
      ? Future.value(const GateResult('not-run', ['no semantics assertions declared']))
      : measured(() async {
          for (final state in manifest.states.keys) {
            await load(state);
            for (final raw in manifest.data['semantics'] as List? ?? const []) {
              final assertion = raw as Map;
              final expression =
                  assertion['expression'] as String? ??
                  'document.querySelector(${jsonEncode(assertion['selector'])})?.getAttribute(${jsonEncode(assertion['attribute'])})';
              final actual = await driver.evaluate(expression);
              require(
                jsonEncode(actual) == jsonEncode(assertion['equals']),
                '$state semantics ${assertion['selector'] ?? expression}: expected ${assertion['equals']}, actual $actual',
              );
            }
          }
        });

  Future<GateResult> keyboard({bool reload = true}) => manifest.keyboard.isEmpty
      ? Future.value(const GateResult('not-run', ['no keyboard script declared']))
      : measured(() async {
          if (reload) await load();
          await steps(manifest.keyboard, label: 'keyboard');
        });

  Future<GateResult> lifecycle() => manifest.htmx == null
      ? Future.value(const GateResult('not-run', ['no HTMX lifecycle recipe declared']))
      : measured(() async {
          final recipe = manifest.htmx!;
          await load();
          Future<void> swap() async {
            for (final state in manifest.states.values) {
              await steps(manifest.steps(state), label: 'pre-swap state');
            }
            await driver.evaluate('''(() => {
              window.__uiGateSwap=false;const selector=${jsonEncode(recipe['region'])};
              if(!document.querySelector(selector))throw Error('swap region missing: '+selector);
              const settled=e=>{const region=document.querySelector(selector);
                if(region && [e.target,e.detail?.target].some(t=>t&&(t===region||region.contains(t)||t.contains?.(region)))) {
                  window.__uiGateSwap=true;document.removeEventListener('htmx:afterSettle',settled);
                }};
              document.addEventListener('htmx:afterSettle',settled);
            })()''');
            await steps(manifest.steps(recipe['swap']), label: 'swap');
            try {
              await waitFor('window.__uiGateSwap === true');
            } on StateError {
              throw StateError('swap region ${recipe['region']} did not settle');
            }
            await collect();
          }

          Future<Object?> instances() =>
              driver.evaluate('''({live:window.__uiGate.instances, selectors:Object.fromEntries(
      ${jsonEncode(manifest.data['instances'] ?? const [])}.map(s=>[s,document.querySelectorAll(s).length]))})''');
          // Warm up htmx's request lifecycle before comparing persistent listeners.
          await swap();
          final beforeListeners = await driver.listeners();
          final beforeInstances = jsonEncode(await instances());
          for (var n = 0; n < 20; n++) {
            await swap();
          }
          require(
            await driver.listeners() == beforeListeners,
            'listener counts changed: $beforeListeners -> ${await driver.listeners()} after 20 swaps',
          );
          require(
            jsonEncode(await instances()) == beforeInstances,
            'instance counts changed after 20 swaps: $beforeInstances -> ${jsonEncode(await instances())}',
          );
          final probe = (recipe['probe'] as Map?)?.cast<String, Object?>();
          if (probe != null) {
            await steps(manifest.steps(probe['steps']), label: 'single-fire probe');
            final actual = await driver.evaluate(probe['expression'] as String);
            require(
              jsonEncode(actual) == jsonEncode(probe['equals']),
              'single-fire probe: expected ${probe['equals']}, actual $actual',
            );
          }
          final initial = await driver.evaluate('location.pathname + location.search');
          await steps(manifest.steps(recipe['navigate']), label: 'boosted navigation');
          await waitFor('location.pathname + location.search !== ${jsonEncode(initial)}');
          final next = await driver.evaluate('location.pathname + location.search');
          await driver.history(-1);
          await waitFor('location.pathname + location.search === ${jsonEncode(initial)}');
          if (recipe['transient'] != null) {
            require(
              await driver.evaluate('document.querySelector(${jsonEncode(recipe['transient'])}) === null') == true,
              'stale transient UI after history restore: ${recipe['transient']}',
            );
          }
          await driver.history(1);
          await waitFor('location.pathname + location.search === ${jsonEncode(next)}');
          await driver.history(-1);
          await waitFor('location.pathname + location.search === ${jsonEncode(initial)}');
          require(
            await driver.listeners() == beforeListeners,
            'listener counts changed after history restore: $beforeListeners -> ${await driver.listeners()}',
          );
          require(jsonEncode(await instances()) == beforeInstances, 'instance counts changed after history restore');
          await steps(manifest.keyboard, label: 'keyboard after lifecycle');
        });

  Future<GateResult> reflow(List<int> widths) => measured(() async {
    for (final width in widths) {
      await driver.viewport(width, 900);
      for (final state in manifest.states.keys) {
        await load(state);
        final actualWidth = await driver.evaluate('innerWidth');
        if (actualWidth != width) throw UnsupportedCondition('viewport $width did not read back: $actualWidth');
        final issues =
            await driver.evaluate('''(() => {
          const issues=[], width=innerWidth, height=innerHeight;
          if(document.documentElement.scrollWidth>document.documentElement.clientWidth+1) issues.push('document horizontal overflow');
          const root=document.querySelector(${jsonEncode(manifest.root)});
          for(const el of [root,...root.querySelectorAll('*')]) {
            const r=el.getBoundingClientRect(),cs=getComputedStyle(el);
            if(!r.width||!r.height||cs.visibility==='hidden') continue;
            const name=el.id?'#'+el.id:el.tagName.toLowerCase();
            if(r.left < -1 || r.right > width+1) issues.push(name+' outside horizontal viewport');
            if(el.matches('[role=menu],[role=listbox],[popover]:popover-open,dialog[open]') && (r.top < -1||r.bottom>height+1)) issues.push(name+' popup outside vertical viewport');
          }
          return issues;
        })()''')
                as List;
        _failures.addAll(issues.map((issue) => '$width/$state: $issue'));
      }
      await load();
      await steps(manifest.keyboard, label: 'keyboard at width $width');
    }
  });

  Future<GateResult> touchTargets() => measured(() async {
    for (final coarse in [false, true]) {
      final minimum = coarse ? 44 : 24;
      for (final state in manifest.states.keys) {
        await configure(state, coarse: coarse);
        final issues =
            await driver.evaluate('''(() => {
          const root=document.querySelector(${jsonEncode(manifest.root)}),issues=[];
          for(const el of [root,...root.querySelectorAll('*')].filter(el=>el.matches('a[href],button,input,select,textarea,summary,[role=button],[tabindex]'))) {
            const r=el.getBoundingClientRect(),cs=getComputedStyle(el);
            if(!r.width||!r.height||cs.visibility==='hidden') continue;
            const name=el.id?'#'+el.id:el.tagName.toLowerCase();
            if(r.width<$minimum-0.1||r.height<$minimum-0.1) issues.push(name+' '+r.width+'x'+r.height+' below $minimum px');
            if($coarse && el.matches('input,select,textarea') && parseFloat(cs.fontSize)<16) issues.push(name+' input font below 16px');
          }return issues;
        })()''')
                as List;
        _failures.addAll(issues.map((issue) => '${coarse ? 'coarse' : 'fine'}/$state: $issue'));
      }
    }
  });

  Future<GateResult> forcedColors() => measured(() async {
    for (final state in manifest.states.keys) {
      await configure(state, forcedColors: true);
      final selectors =
          await driver.evaluate('''(() => {const root=document.querySelector(${jsonEncode(manifest.root)});
        return [root,...root.querySelectorAll('*')].filter(el=>el.matches('button,input,select,textarea,a[href],summary,[tabindex]')).filter(el=>{
          const r=el.getBoundingClientRect();return r.width&&r.height&&!el.disabled;
        }).map((el,i)=>{el.setAttribute('data-ui-gate-focus',String(i));return '[data-ui-gate-focus="'+i+'"]';});})()''')
              as List;
      for (final selector in selectors.cast<String>()) {
        final before = await driver.evaluate(_focusPaint(selector));
        await driver.pseudo(selector, ['focus', 'focus-visible']);
        final after = await driver.evaluate(_focusPaint(selector, focused: true)) as Map;
        final focus = after['focus'] as Map;
        if (focus['applicable'] != true ||
            focus['document'] != true ||
            focus['target'] != true ||
            focus['visible'] != true) {
          throw StateError('$state $selector focus did not remain confirmed for forced-colors paint: $focus');
        }
        final outline = after['outline'] as List;
        require(
          (outline[0] as num) > 0 && outline[1] != 'none' && outline[2] != 'rgba(0, 0, 0, 0)' ||
              jsonEncode((before as Map)['border']) != jsonEncode(after['border']),
          '$state $selector has no outline/border focus indicator under forced-colors',
        );
        await driver.pseudo(selector, []);
      }
    }
  });

  String _focusPaint(String selector, {bool focused = false}) =>
      '''(async () => {const focus=$focused ? await ($forceFocusScript)(${jsonEncode(selector)}) : null;
    const s=getComputedStyle(document.querySelector(${jsonEncode(selector)}));
    return {focus,outline:[parseFloat(s.outlineWidth),s.outlineStyle,s.outlineColor],border:[s.borderColor,s.borderStyle,s.borderWidth]};})()''';

  Future<GateResult> reducedMotion() => measured(() async {
    for (final state in manifest.states.keys) {
      await configure(state, reducedMotion: true);
      final moving =
          await driver.evaluate('''(() => {const root=document.querySelector(${jsonEncode(manifest.root)});
        return [root,...root.querySelectorAll('*')].filter(el=>{const s=getComputedStyle(el);
          return (s.animationName!=='none'&&s.animationDuration.split(',').some(x=>parseFloat(x)>0.01)) ||
            (s.transitionProperty!=='none'&&s.transitionDuration.split(',').some(x=>parseFloat(x)>0.01));
        }).map(el=>el.id?'#'+el.id:el.tagName.toLowerCase());})()''')
              as List;
      require(moving.isEmpty, '$state reduced-motion keeps animation/transition: ${moving.join(', ')}');
    }
  });
}
