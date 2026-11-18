import 'dart:convert';
import 'dart:io';

import 'bundle.dart';
import 'generate.dart';
import 'tsx_scan.dart';

typedef _Object = Map<String, Object?>;
typedef SyncPinIdentity = ({String tag, String commit});

_Object _object(File file) => (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();

/// One pinned tree and the upstream component names at its commit.
final class SyncTree {
  SyncTree(this.root, this.components);

  final Directory root;
  final Set<String> components;

  late final _Object _pins = _object(file('tool/pins.json'));
  late final _Object _scanReport = _object(file('generated/report.json'));
  late final _Object _source = (_pins['shadcn']! as Map).cast<String, Object?>();
  SyncPinIdentity get identity => (tag: _source['tag']! as String, commit: _source['commit']! as String);
  String get tag => identity.tag;
  String get vendor => 'vendor/shadcn/$tag';

  File file(String path) => File('${root.path}/$path');

  late final ScanResult _scan = ScanResult();
  late final Map<String, List<StyleRule>> _rules = _readRules();

  Map<String, List<StyleRule>> _readRules() {
    for (final name in (_pins['components']! as List).cast<String>()) {
      scanTsx(file('$vendor/ui/$name.tsx').readAsStringSync(), '$name.tsx', _scan);
    }
    final style = _pins['style']! as String;
    final rules = <String, List<StyleRule>>{};
    for (final rule in parseStyleRules(file('$vendor/style-$style.css').readAsStringSync(), style)) {
      if (rule.hooks.any(_scan.allHooks.contains)) (rules[rule.selector] ??= []).add(rule);
    }
    return rules;
  }

  Map<String, String> get _inputs {
    final dir = Directory('${root.path}/$vendor');
    return {
      for (final file in dir.listSync(recursive: true).whereType<File>())
        if (file.uri.pathSegments.last != 'SOURCE.md') file.path.substring(dir.path.length + 1): file.path,
    };
  }

  Set<String> _names(String key) => (_scanReport[key]! as List).cast<String>().toSet();

  Map<String, String> _tokens(String selector) {
    // The generator emits standalone, declaration-only blocks for scheme tokens.
    final css = file('generated/entry.css').readAsStringSync();
    final block = RegExp('^${RegExp.escape(selector)}[ \\t]*\\{([^}]+)\\}', multiLine: true).firstMatch(css)?[1];
    if (block == null) throw FormatException('Generated CSS in $tag has no $selector token block');
    return {for (final value in RegExp(r'(--[\w-]+)\s*:\s*([^;]+);').allMatches(block)) value[1]!: value[2]!.trim()};
  }

  Set<String> get _publicClasses {
    final css = [
      file('generated/trellis.css'),
      ...sourceFiles(Directory('${root.path}/assets/css/hand'), '.css'),
    ].map((file) => file.readAsStringSync()).join('\n');
    final selectors = css
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '')
        .replaceAll(RegExp(r'''(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')'''), '');
    return {
      for (final rule in RegExp(r'([^{};]+)\{').allMatches(selectors))
        for (final match in RegExp(r'(?<!\\)\.(trellis-[\w-]+)').allMatches(rule[1]!)) match[1]!,
    };
  }

  List<_Object> get _ignores => (jsonDecode(file('tool/parity-ignore.json').readAsStringSync()) as List).map((value) {
    final fields = (value as Map).cast<String, Object?>();
    return {for (final key in (fields.keys.toList()..sort())) key: fields[key]};
  }).toList();
}

List<String> _sorted(Iterable<String> values) => values.toSet().toList()..sort();

(int, int) _lineChanges(File? before, File? after) {
  if (before == null) return (after!.readAsLinesSync().length, 0);
  if (after == null) return (0, before.readAsLinesSync().length);
  final arguments = ['diff', '--no-index', '--no-ext-diff', '--numstat', '--', before.path, after.path];
  final result = Process.runSync('git', arguments);
  if (result.exitCode == 0) return (0, 0);
  if (result.exitCode != 1 || (result.stdout as String).trim().isEmpty) {
    throw ProcessException('git', arguments, '${result.stderr}', result.exitCode);
  }
  final columns = (result.stdout as String).split('\t');
  return (int.parse(columns[0]), int.parse(columns[1]));
}

const _requiredGates = ['regression-replay', 'parity', 'regeneration', 'embedding', 'component-gate'];
const _handLimits = {'Template lines': 4, 'Hand CSS lines': 3, 'Config entries': 1, 'Owned JS lines': 0};

/// The upstream identities and ordered row headings emitted by the generator, before human triage.
final class SyncReportInventory {
  SyncReportInventory(this.previous, this.current, this.entries);

  static const path = 'tool/sync-inventory.json';

  final SyncPinIdentity previous;
  final SyncPinIdentity current;
  final List<(String, String)> entries;

  String get heading => '# Sync ${previous.tag} to ${current.tag}';
  String get commits => 'Commits `${previous.commit}` to `${current.commit}`.';

  String encode() =>
      '${const JsonEncoder.withIndent('  ').convert({
        'previous': {'tag': previous.tag, 'commit': previous.commit},
        'current': {'tag': current.tag, 'commit': current.commit},
        'entries': [
          for (final (heading, kind) in entries) {'heading': heading, 'kind': kind},
        ],
      })}\n';

  factory SyncReportInventory.read(Directory root) {
    final Object? data = jsonDecode(File('${root.path}/$path').readAsStringSync());
    SyncPinIdentity pin(Object? value) {
      if (value case {'tag': final String tag, 'commit': final String commit}) {
        return (tag: tag, commit: commit);
      }
      throw const FormatException('Invalid sync inventory pin');
    }

    if (data case {
      'previous': final Object? previous,
      'current': final Object? current,
      'entries': final List<Object?> rows,
    }) {
      final entries = <(String, String)>[];
      for (final row in rows) {
        if (row case {'heading': final String heading, 'kind': final String kind}) {
          entries.add((heading, kind));
        } else {
          throw const FormatException('Invalid sync inventory entry');
        }
      }
      return SyncReportInventory(pin(previous), pin(current), entries);
    }
    throw const FormatException('Invalid sync inventory');
  }
}

/// Generates the static report and unresolved gates without machine-local data.
({String markdown, SyncReportInventory inventory}) buildSyncReport(SyncTree previous, SyncTree next) {
  final rows = <(String, String)>[];
  final inventory = SyncReportInventory(previous.identity, next.identity, rows);
  final report = StringBuffer('${inventory.heading}\n\n')
    ..writeln(inventory.commits)
    ..writeln('\n## Vendored inputs\n')
    ..writeln('| Input | Old lines | New lines | Added | Removed |')
    ..writeln('| --- | ---: | ---: | ---: | ---: |');
  final entries = <(String, String)>[];
  void entry(String title, [String kind = 'mechanical']) => entries.add((title, kind));
  final a = previous._inputs, b = next._inputs;
  for (final name in _sorted([...a.keys, ...b.keys])) {
    final old = a[name] == null ? null : File(a[name]!);
    final current = b[name] == null ? null : File(b[name]!);
    final (added, removed) = _lineChanges(old, current);
    report.writeln(
      '| `$name` | ${old?.readAsLinesSync().length ?? 0} | '
      '${current?.readAsLinesSync().length ?? 0} | $added | $removed |',
    );
    if (added + removed > 0) {
      entry('Input `$name` (+$added/-$removed)', name.endsWith('.tsx') ? 'hand-layer candidate' : 'mechanical');
    }
  }

  report
    ..writeln('\n## Generated outputs\n')
    ..writeln('| Output | Old bytes | New bytes | Added lines | Removed lines |')
    ..writeln('| --- | ---: | ---: | ---: | ---: |');
  for (final name in ['entry.css', 'trellis.css', 'trellis.min.css', 'report.json']) {
    final old = previous.file('generated/$name'), current = next.file('generated/$name');
    final (added, removed) = _lineChanges(old, current);
    report.writeln('| `$name` | ${old.lengthSync()} | ${current.lengthSync()} | $added | $removed |');
  }

  for (final (key, label) in [('slots', 'Slot'), ('dataAttrs', 'Data attribute'), ('hooks', 'Hook')]) {
    final a = previous._names(key), b = next._names(key);
    for (final name in _sorted(b.difference(a))) {
      entry('$label added: `$name`', 'hand-layer candidate');
    }
    for (final name in _sorted(a.difference(b))) {
      entry('$label removed: `$name`', 'hand-layer candidate');
    }
  }
  for (final name in _sorted(next.components.difference(previous.components))) {
    entry('Upstream component added: `$name`', 'new component');
  }
  for (final name in _sorted(previous.components.difference(next.components))) {
    entry('Upstream component removed: `$name`', 'hand-layer candidate');
  }
  for (final name in _sorted(previous._publicClasses.difference(next._publicClasses))) {
    entry('BREAKING public class removed: `$name`', 'hand-layer candidate');
  }

  String ruleText(List<StyleRule>? rules) => (rules ?? []).map((rule) => rule.text).join('\n');
  final oldRules = previous._rules, newRules = next._rules;
  for (final selector in _sorted([...oldRules.keys, ...newRules.keys])) {
    if (ruleText(oldRules[selector]) != ruleText(newRules[selector])) {
      final change = oldRules[selector] == null
          ? 'added'
          : newRules[selector] == null
          ? 'removed'
          : 'changed';
      entry('In-scope rule $change: `$selector`');
    }
  }

  report
    ..writeln('\n## Token changes\n')
    ..writeln('| Mode | Token | Previous | New |')
    ..writeln('| --- | --- | --- | --- |');
  var tokenCount = 0;
  for (final (mode, selector) in [('light', ':root'), ('dark', '.dark')]) {
    final a = previous._tokens(selector), b = next._tokens(selector);
    for (final name in _sorted([...a.keys, ...b.keys])) {
      if (a[name] == b[name]) continue;
      report.writeln('| $mode | `$name` | ${a[name] ?? 'absent'} | ${b[name] ?? 'absent'} |');
      entry('$mode token changed: `$name`');
      tokenCount++;
    }
  }
  if (tokenCount == 0) report.writeln('\nNo pinned colour or radius tokens changed.');

  final skips = (next._pins['structuralSkip'] as Map?)?.cast<String, Object?>() ?? const <String, Object?>{};
  for (final hook in _sorted(skips.keys)) {
    String rules(Map<String, List<StyleRule>> bySelector) => bySelector.values
        .expand((list) => list)
        .where((rule) => rule.hooks.contains(hook))
        .map((rule) => rule.text)
        .join('\n');
    final old = previous._scan.hooks[hook]?.structural.toList();
    final current = next._scan.hooks[hook]?.structural.toList();
    final changed = rules(oldRules) != rules(newRules) || jsonEncode(old) != jsonEncode(current);
    entry(
      'Revisit structuralSkip `$hook` (${changed ? 'upstream changed' : 'upstream unchanged'})',
      'hand-layer candidate',
    );
  }

  final oldIgnores = previous._ignores.map(jsonEncode).toSet(), newIgnores = next._ignores.map(jsonEncode).toSet();
  report.writeln('\nParity ignores: ${oldIgnores.length} previous, ${newIgnores.length} new.');
  for (final (kind, changes) in [
    ('added', newIgnores.difference(oldIgnores)),
    ('removed', oldIgnores.difference(newIgnores)),
  ]) {
    for (final row in _sorted(changes)) {
      entry('Parity ignore $kind: `$row`', 'hand-layer candidate');
    }
  }

  report
    ..writeln('\n## Upstream triage\n')
    ..writeln('Upstream entries: ${entries.length}');
  for (final (index, (title, kind)) in entries.indexed) {
    final heading = 'U${(index + 1).toString().padLeft(3, '0')} $title';
    rows.add((heading, kind));
    report.writeln(
      '\n### $heading\n\n'
      'Kind: $kind\nTriage: pending\nDisposition: pending\nReason:',
    );
  }
  report.writeln('\n## Gates');
  for (final gate in _requiredGates) {
    report.writeln('\n### Gate $gate\n\nResult: pending\nDisposition:\nReason:');
  }
  report
    ..writeln('\n## Appearance findings\n')
    ..writeln('Appearance entries: 0')
    ..writeln('\n## Hand edits\n');
  for (final label in _handLimits.keys) {
    report.writeln('$label: 0');
  }
  report.writeln('\nOwner review: release-prep');
  return (markdown: report.toString(), inventory: inventory);
}

/// Lists all unresolved, missing or invalid classifications and gate results.
List<String> syncReportIssues(String report, SyncReportInventory inventory) {
  final issues = <String>[];
  report = _visibleMetadata(report);
  if (!report.startsWith('${inventory.heading}\n\n${inventory.commits}\n')) {
    issues.add('Sync report pin transition does not match the generated inventory');
  }
  String? value(String section, String key) {
    final fields = RegExp('^${RegExp.escape(key)}:[ \\t]*(.*)\$', multiLine: true).allMatches(section).toList();
    return fields.length == 1 ? fields.single[1]!.trim() : null;
  }

  void disposition(String section, String id) {
    const allowed = {'expected', 'fixed', 'deferred'};
    final outcome = value(section, 'Disposition');
    if (!allowed.contains(outcome)) issues.add('$id: unresolved disposition');
    if ((value(section, 'Reason') ?? '').isEmpty) issues.add('$id: missing reason');
  }

  final headings = <String>{};
  final upstream = <int>{}, appearance = <int>{};
  final reportedEntries = <(String, String?)>[];
  final gates = <String>{};
  for (final block in report.split(RegExp(r'^### ', multiLine: true)).skip(1)) {
    final heading = block.split('\n').first;
    final title = heading.split(' ').first;
    if (!headings.add(heading)) issues.add('Duplicate report heading $heading');
    if (heading.startsWith('Gate ')) {
      final gate = heading.substring(5);
      gates.add(gate);
      switch (value(block, 'Result')) {
        case 'pass':
          if (value(block, 'Disposition') != '') issues.add('$heading: passing result needs a blank disposition');
        case 'fail' || 'not-run':
          disposition(block, heading);
        default:
          issues.add('$heading: unresolved result');
      }
    } else if (RegExp(r'^[UA]\d{3,}$').hasMatch(title)) {
      final upstreamEntry = title.startsWith('U');
      if (!(upstreamEntry ? upstream : appearance).add(int.parse(title.substring(1)))) {
        issues.add('Duplicate report entry $title');
      }
      if (upstreamEntry) {
        final kind = value(block, 'Kind');
        reportedEntries.add((heading, kind));
        final triage = value(block, 'Triage');
        final allowed = switch (kind) {
          'new component' => {'port', 'defer', 'skip'},
          'mechanical' || 'hand-layer candidate' => {'mechanical', 'hand-layer edit'},
          _ => <String>{},
        };
        if (!allowed.contains(triage)) issues.add('$title: unresolved triage');
      }
      disposition(block, title);
    } else {
      issues.add('Unrecognized report entry $heading');
    }
  }
  final triageSections = report
      .split(RegExp(r'^## ', multiLine: true))
      .where((section) => section.startsWith('Upstream triage\n'))
      .toList();
  if (triageSections.length != 1 ||
      RegExp(r'^### U\d{3,} ', multiLine: true).allMatches(triageSections.single).length != reportedEntries.length ||
      reportedEntries.length != inventory.entries.length ||
      reportedEntries.indexed.any((entry) => entry.$2 != inventory.entries[entry.$1])) {
    issues.add('Upstream triage does not match the generated inventory');
  }
  for (final (label, values) in [('Upstream entries', upstream), ('Appearance entries', appearance)]) {
    final count = int.tryParse(value(report, label) ?? '');
    if (count != values.length || List.generate(values.length, (i) => i + 1).any((i) => !values.contains(i))) {
      issues.add('$label: count or numbering does not match entries');
    }
  }
  for (final gate in _requiredGates.where((gate) => !gates.contains(gate))) {
    issues.add('Gate $gate: missing result');
  }
  for (final label in _handLimits.keys) {
    final fields = (value(report, label) ?? '').split(' | ');
    final count = int.tryParse(fields.first);
    if (count == null || count < 0) {
      issues.add('$label: missing count');
    } else if (count > _handLimits[label]! && (fields.length < 2 || fields.skip(1).join().trim().isEmpty)) {
      issues.add('$label: $count exceeds ${_handLimits[label]} without a reason');
    }
  }
  if (!{'pass', 'release-prep'}.contains(value(report, 'Owner review'))) issues.add('Owner review: missing status');
  return issues;
}

String _visibleMetadata(String report) {
  // The maintainer must be able to see each triage row in its section. Fenced
  // evidence and Markdown comments cannot supply a heading or a field.
  final comments = RegExp(r'<!--[\s\S]*?(?:-->|$)');
  final fence = RegExp(r'^ {0,3}(`{3,}|~{3,})(.*)$');
  final visible = StringBuffer();
  String? openFence;
  for (final line in report.replaceAll('\r\n', '\n').replaceAll(comments, '').split('\n')) {
    final match = fence.firstMatch(line);
    if (openFence == null) {
      if (match == null) {
        visible.writeln(line);
      } else {
        openFence = match[1];
      }
    } else if (match != null && match[1]!.startsWith(openFence) && match[2]!.trim().isEmpty) {
      openFence = null;
    }
  }
  return visible.toString();
}
