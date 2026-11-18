import 'dart:convert';

import '../visual_baseline.dart';
import 'checks.dart';
import 'firefox.dart';

/// Deterministic state captures, reusable before and after an upstream sync.
Future<Map<String, Object?>> captureAppearance(GateSession session) async {
  final states = <String, Object?>{}, tokens = <String, Object?>{}, invariants = <String>[];
  final driver = session.driver, manifest = session.manifest;
  await driver.viewport(1440, 900);
  Future<bool> capture(
    String key, {
    String? focusSelector,
    bool keepDocumentFocused = false,
    bool watchHoverBlur = false,
  }) async {
    final snapshot =
        '($digestScript)(${jsonEncode(manifest.elements)}, ${jsonEncode(focusSelector)}, $keepDocumentFocused)';
    final rendered = await driver.evaluate(
      watchHoverBlur
          ? '''(async () => {
            const sample = await $snapshot;
            return window.__uiGateHoverFocus.lost || !document.hasFocus() ? null : sample;
          })()'''
          : snapshot,
    );
    if (rendered == null) return false;
    final raw = (rendered as Map).cast<String, Object?>();
    states[key] = {
      'doc': raw['doc'],
      'nodes': raw['nodes'],
      'elements': raw['elements'],
      if (raw['focus'] != null) 'focus': raw['focus'],
    };
    final measured = Capture(
      page: manifest.page,
      width: 1440,
      scheme: key,
      doc: (raw['doc'] as Map).cast<String, Object?>(),
      nodes: (raw['nodes'] as List).cast<Map<String, Object?>>(),
    );
    invariants.addAll(scanClipping(measured).map((d) => '$key ${d.where} ${d.detail}'));
    final doc = raw['doc'] as Map;
    if (doc['sw'] != doc['cw']) invariants.add('$key document horizontal overflow');
    final overlap =
        await driver.evaluate('''(() => {const issues=[];
      for(const group of ${jsonEncode(manifest.data['distinct'] ?? const [])}) {
        const elements=[...new Set(group.flatMap(s=>[...document.querySelectorAll(s)]))].filter(e=>{const r=e.getBoundingClientRect();return r.width&&r.height&&getComputedStyle(e).visibility!=='hidden';});
        for(let i=0;i<elements.length;i++)for(let j=i+1;j<elements.length;j++){
          const a=elements[i].getBoundingClientRect(),b=elements[j].getBoundingClientRect();
          if(Math.min(a.right,b.right)>Math.max(a.left,b.left)+1&&Math.min(a.bottom,b.bottom)>Math.max(a.top,b.top)+1)
            issues.push((elements[i].id?'#'+elements[i].id:group.join(', '))+' overlaps '+(elements[j].id?'#'+elements[j].id:group.join(', ')));
        }
      }return issues;})()''')
            as List;
    invariants.addAll(overlap.map((issue) => '$key $issue'));
    return true;
  }

  Future<void> loadState(String state, {bool dark = false}) async {
    // A visible Firefox window can lose focus during the native recipe itself.
    // Replay only that failed measurement; native keyboard and lifecycle checks
    // continue to run their recipes directly. Remove this retry when Firefox can
    // hold document activation across the whole recipe.
    for (var attempt = 1; ; attempt++) {
      try {
        await session.configure(state, dark: dark);
        return;
      } on GateRecipeError {
        if (driver is! FirefoxDriver ||
            attempt == 3 ||
            await driver.evaluate('window.__uiGate.lostVisibleFocus && !document.hasFocus()') != true) {
          rethrow;
        }
      }
    }
  }

  Future<void> captureFirefoxHover(String state, MapEntry<String, String> element) async {
    final key = '$state/hover:${element.key}';
    // Native focusout can dismiss a real popup when another window takes focus.
    // Replay the complete recipe instead of trying to reopen the changed DOM.
    for (var attempt = 0; attempt < 3; attempt++) {
      await loadState(state);
      await driver.evaluate('''(() => {
        const guard = {lost: !document.hasFocus(), onBlur: () => guard.lost = true};
        window.__uiGateHoverFocus = guard;
        window.addEventListener('blur', guard.onBlur);
      })()''');
      try {
        await driver.pseudo(element.value, ['hover']);
        if (await capture(key, watchHoverBlur: true)) return;
      } finally {
        await driver.evaluate('''(() => {
          window.removeEventListener('blur', window.__uiGateHoverFocus.onBlur);
          delete window.__uiGateHoverFocus;
        })()''');
        await driver.pseudo(element.value, []);
      }
    }
    throw StateError('$key: Firefox lost document focus during three hover captures');
  }

  for (final state in manifest.states.keys) {
    await loadState(state);
    await capture(state);
    for (final element in manifest.elements.entries) {
      for (final pseudo in ['hover', 'focus-visible', 'active', 'disabled']) {
        if (pseudo == 'hover' && driver is FirefoxDriver) {
          await captureFirefoxHover(state, element);
          continue;
        }
        await loadState(state);
        Object? originalDisabled;
        if (pseudo == 'disabled') {
          originalDisabled = await driver.evaluate(
            '''(() => {const el=document.querySelector(${jsonEncode(element.value)});
            return {native:'disabled' in el,value:el.disabled,aria:el.getAttribute('aria-disabled')};})()''',
          );
          await driver.evaluate('''(() => {const el=document.querySelector(${jsonEncode(element.value)});
            if('disabled' in el)el.disabled=true; else el.setAttribute('aria-disabled','true');})()''');
        } else if (pseudo != 'focus-visible' ||
            await driver.evaluate('($modalAllowsFocusScript)(document.querySelector(${jsonEncode(element.value)}))') ==
                true) {
          await driver.pseudo(element.value, pseudo == 'focus-visible' ? ['focus', 'focus-visible'] : [pseudo]);
        }
        await capture(
          '$state/$pseudo:${element.key}',
          focusSelector: pseudo == 'focus-visible' ? element.value : null,
          keepDocumentFocused: pseudo == 'active' && driver is FirefoxDriver,
        );
        if (pseudo == 'disabled') {
          await driver.evaluate(
            '''(() => {const el=document.querySelector(${jsonEncode(element.value)});
            const original=${jsonEncode(originalDisabled)};
            if(original.native)el.disabled=original.value;
            else if(original.aria===null)el.removeAttribute('aria-disabled');else el.setAttribute('aria-disabled',original.aria);})()''',
          );
        }
        await driver.pseudo(element.value, []);
      }
    }
    await loadState(state, dark: true);
    await driver.evaluate("document.documentElement.classList.add('dark')");
    await capture('$state/dark');
    for (final dark in [false, true]) {
      await loadState(state, dark: dark);
      await driver.evaluate("document.documentElement.classList.toggle('dark',$dark)");
      tokens['${dark ? 'dark' : 'light'}'] = await driver.evaluate(
        '''(() => {const s=getComputedStyle(document.documentElement);
        return Object.fromEntries([...s].filter(p=>p.startsWith('--')).sort().map(p=>[p,s.getPropertyValue(p).trim()]));})()''',
      );
    }
  }
  await session.collect();
  return {
    'browser': driver.name,
    'states': states,
    'tokens': tokens,
    'invariants': invariants.toSet().toList()..sort(),
  };
}

/// Names each changed state/element/property and token, plus fresh invariants.
List<String> compareAppearance(Map<String, Object?> expected, Map<String, Object?> actual) {
  final differences = <String>[];
  final before = (expected['states'] as Map).cast<String, Object?>(),
      after = (actual['states'] as Map).cast<String, Object?>();
  for (final key in {...before.keys, ...after.keys}) {
    if (!before.containsKey(key) || !after.containsKey(key)) {
      differences.add('$key state added/removed');
      continue;
    }
    final left = before[key] as Map, right = after[key] as Map;
    if (jsonEncode(left['focus']) != jsonEncode(right['focus']))
      differences.add('$key focus state ${left['focus']} -> ${right['focus']}');
    Capture capture(Map raw) => Capture(
      page: '/',
      width: 1440,
      scheme: key,
      doc: (raw['doc'] as Map).cast<String, Object?>(),
      nodes: (raw['nodes'] as List).map((e) => (e as Map).cast<String, Object?>()).toList(),
    );
    differences.addAll(compareCaptures(capture(left), capture(right)).map((d) => '$key ${d.where} ${d.detail}'));
    final le = left['elements'] as Map, re = right['elements'] as Map;
    for (final name in {...le.keys, ...re.keys}) {
      if (!le.containsKey(name) || !re.containsKey(name)) {
        differences.add('$key $name element added/removed');
        continue;
      }
      final ls = (le[name] as Map)['style'] as Map, rs = (re[name] as Map)['style'] as Map;
      for (final property in {...ls.keys, ...rs.keys}) {
        if (ls[property] != rs[property])
          differences.add('$key ${(re[name] as Map)['selector']} $property ${ls[property]} -> ${rs[property]}');
      }
    }
  }
  final lt = expected['tokens'] as Map, rt = actual['tokens'] as Map;
  for (final mode in {...lt.keys, ...rt.keys}) {
    final left = (lt[mode] as Map?) ?? const {}, right = (rt[mode] as Map?) ?? const {};
    for (final token in {...left.keys, ...right.keys}) {
      if (left[token] != right[token]) differences.add('token $mode $token ${left[token]} -> ${right[token]}');
    }
  }
  differences.addAll((actual['invariants'] as List).cast<String>());
  return differences.toSet().toList()..sort();
}
