import 'dart:convert';
import 'dart:io';

import 'pipeline.dart';
import 'tsx_scan.dart';

/// Returns parity diagnostics, failing unexplained drift and empty ignore reasons.
({int failures, List<String> lines}) checkParity(Directory root) {
  final pins = Pipeline(root).pins;
  final tag = (pins['shadcn'] as Map)['tag'] as String;
  final scan = ScanResult();
  for (final name in (pins['components'] as List).cast<String>()) {
    scanTsx(File('${root.path}/vendor/shadcn/$tag/ui/$name.tsx').readAsStringSync(), '$name.tsx', scan);
  }
  final source = Directory('${root.path}/assets/fragments')
      .listSync(followLinks: false)
      .whereType<File>()
      .where((f) => f.path.endsWith('.html'))
      .map((f) => f.readAsStringSync())
      .join('\n');
  final classes = <String>{
    for (final m in RegExp(r'(?<![:\w-])class="([^"]*)"').allMatches(source)) ...m[1]!.split(RegExp(r'\s+')),
  };
  final upstream = {
    'slot': scan.slots,
    'hook': {for (final h in scan.allHooks) h.replaceFirst('cn-', 'trellis-')},
    'marker': scan.markers,
  };
  final actual = {
    'slot': {for (final m in RegExp(r'\bdata-slot="([^"]+)"').allMatches(source)) m[1]!},
    'hook': classes.where((c) => c.startsWith('trellis-')).toSet(),
    'marker': classes.where((c) => RegExp(r'^(group|peer)(/|$)').hasMatch(c)).toSet(),
  };
  final ignores = (jsonDecode(File('${root.path}/tool/parity-ignore.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();
  var failures = 0;
  final lines = <String>[];
  final used = <int>{};
  for (var i = 0; i < ignores.length; i++) {
    if ((ignores[i]['reason'] as String? ?? '').trim().isEmpty) {
      failures++;
      lines.add('Invalid ignore ${ignores[i]['name']}: blank reason');
    }
  }
  for (final kind in upstream.keys) {
    for (final (direction, names) in [
      ('missing', upstream[kind]!.difference(actual[kind]!)),
      ('extra', actual[kind]!.difference(upstream[kind]!)),
    ]) {
      for (final name in (names.toList()..sort())) {
        int? match;
        for (var i = 0; i < ignores.length; i++) {
          final entry = ignores[i];
          final pattern = RegExp('^${RegExp.escape(entry['name'] as String).replaceAll(r'\*', '.*')}\$');
          if (entry['kind'] == kind &&
              entry['direction'] == direction &&
              (entry['tag'] == null || entry['tag'] == tag) &&
              pattern.hasMatch(name) &&
              (entry['reason'] as String? ?? '').trim().isNotEmpty) {
            match = i;
            break;
          }
        }
        if (match == null) {
          failures++;
          lines.add('DRIFT $kind $direction: $name');
        } else {
          used.add(match);
        }
      }
    }
  }
  for (var i = 0; i < ignores.length; i++) {
    if (!used.contains(i) && (ignores[i]['tag'] == null || ignores[i]['tag'] == tag)) {
      lines.add('STALE ignore ${ignores[i]['name']} matches nothing at $tag');
    }
  }
  lines.insert(0, 'Parity vs $tag: $failures unignored drift, ${used.length} used ignores');
  return (failures: failures, lines: lines);
}
