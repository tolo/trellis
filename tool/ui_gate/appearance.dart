import 'dart:convert';

import '../visual_baseline.dart';
import 'checks.dart';
import 'firefox.dart';

/// A stable capture or its baseline comparison is unavailable.
final class VisualCaptureUnavailable implements Exception {
  const VisualCaptureUnavailable(this.reason);
  final String reason;

  @override
  String toString() => reason;
}

/// Deterministic state captures, reusable before and after an upstream sync.
///
/// [comparePartial] checks captured states if a later emulation limit interrupts the run.
Future<Map<String, Object?>> captureAppearance(
  GateSession session, {
  List<String> Function(Map<String, Object?>)? comparePartial,
}) async {
  final states = <String, Object?>{}, tokens = <String, Object?>{}, invariants = <String>[];
  final driver = session.driver, manifest = session.manifest;
  Map<String, Object?> snapshot() => {
    'browser': driver.name,
    'states': states,
    'tokens': tokens,
    'invariants': invariants.toSet().toList()..sort(),
  };

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
    try {
      await session.configureForMeasurement(state, dark: dark);
    } on UnsupportedCondition catch (error) {
      // A later emulation limit cannot waive a defect already measured in this browser.
      final failures = invariants.toSet().toList()..sort();
      if (failures.isEmpty) failures.addAll(comparePartial?.call(snapshot()) ?? const []);
      if (failures.isEmpty) rethrow;
      throw GateConditionError([...failures, error.reason].join('\n'));
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
    throw VisualCaptureUnavailable('$key: Firefox lost document focus during three hover captures');
  }

  final recipes = manifest.states.keys;
  for (final state in recipes) {
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
  }

  // The baseline stores token samples for the final recipe only.
  if (recipes.isNotEmpty) {
    final state = recipes.last;
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
  return snapshot();
}

/// Names each changed state/element/property and token, plus fresh invariants.
///
/// A partial capture compares only states and token modes that were reached.
List<String> compareAppearance(Map<String, Object?> expected, Map<String, Object?> actual, {bool partial = false}) {
  final differences = <String>[];
  final invalid = <String>[];
  final before = expected['states'];
  final after = (actual['states'] as Map).cast<String, Object?>();
  if (before is Map<String, Object?>) {
    for (final key in {...before.keys, ...after.keys}) {
      final recorded = before.containsKey(key);
      if (recorded && !_validRecordedState(before[key])) {
        invalid.add('invalid appearance state $key');
        continue;
      }
      if (partial && !after.containsKey(key)) {
        continue;
      }
      if (!recorded || !after.containsKey(key)) {
        differences.add('$key state added/removed');
        continue;
      }
      final left = before[key] as Map, right = after[key] as Map;
      if (jsonEncode(left['focus']) != jsonEncode(right['focus'])) {
        differences.add('$key focus state ${left['focus']} -> ${right['focus']}');
      }
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
          if (ls[property] != rs[property]) {
            differences.add('$key ${(re[name] as Map)['selector']} $property ${ls[property]} -> ${rs[property]}');
          }
        }
      }
    }
  } else {
    invalid.add('invalid appearance states');
  }

  final lt = expected['tokens'];
  final rt = (actual['tokens'] as Map).cast<String, Object?>();
  if (lt is Map<String, Object?>) {
    for (final mode in {...lt.keys, ...rt.keys}) {
      if (lt.containsKey(mode) && !_validStyleMap(lt[mode])) {
        invalid.add('invalid appearance $mode tokens');
        continue;
      }
      if (partial && !rt.containsKey(mode)) {
        continue;
      }
      final left = (lt[mode] as Map?) ?? const {}, right = (rt[mode] as Map?) ?? const {};
      for (final token in {...left.keys, ...right.keys}) {
        if (left[token] != right[token]) {
          differences.add('token $mode $token ${left[token]} -> ${right[token]}');
        }
      }
    }
  } else {
    invalid.add('invalid appearance tokens');
  }

  differences.addAll((actual['invariants'] as List).cast<String>());
  // An invalid saved sample prevents qualification, without erasing differences measured against other samples.
  if (differences.isEmpty && invalid.isNotEmpty) {
    throw FormatException(invalid.join('\n'));
  }
  return differences.toSet().toList()..sort();
}

bool _validRecordedState(Object? state) {
  if (state
      case final Map<String, Object?> sample &&
          {
            'doc': {'sw': int _, 'cw': int _, 'sh': int _},
            'nodes': List<Object?> nodes,
            'elements': Map<String, Object?> elements,
          }) {
    final validFocus = switch (sample['focus']) {
      {'applicable': true, 'document': bool _, 'target': bool _, 'visible': bool _} => true,
      null || {'applicable': false} => true,
      _ => false,
    };
    return validFocus &&
        nodes.every(_validRecordedNode) &&
        elements.values.every(
          (element) => switch (element) {
            {'selector': String _, 'style': final style} => _validStyleMap(style),
            _ => false,
          },
        );
  }
  return false;
}

bool _validRecordedNode(Object? node) {
  if (node case final Map<String, Object?> fields && {'k': String _, 'b': [int _, int _, int _, int _]}) {
    return (fields['ox'] ?? 0) is int &&
        (fields['oy'] ?? 0) is int &&
        (fields['c'] ?? '') is String &&
        (fields['i'] ?? '') is String &&
        const ['s', 'pb', 'pa'].every((key) => fields[key] == null || _validStyleMap(fields[key]));
  }
  return false;
}

bool _validStyleMap(Object? value) => value is Map<String, Object?> && value.values.every((value) => value is String);
