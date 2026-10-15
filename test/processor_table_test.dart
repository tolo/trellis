// Pins dev/architecture/template-engine.md's Built-in Processors table and Priority Model block to the code, so the
// architecture doc cannot silently drift from `ProcessorPriority` and the processors' `priority` getters.
//
// Text-vs-source on purpose: the root suite has no dependency on `trellis`. Run from the repository root.
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

const _doc = 'dev/architecture/template-engine.md';
const _api = 'packages/trellis/lib/src/processor_api.dart';
const _processorsDir = 'packages/trellis/lib/src/processors';

typedef _Processor = ({String attribute, String priority});

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) fail('$path not found: run from the repository root');
  return file.readAsStringSync();
}

/// Slot names in declaration order.
List<String> _enumOrder(String source) {
  final body = RegExp(r'enum ProcessorPriority \{(.*?)\}', dotAll: true).firstMatch(source)?[1];
  if (body == null) fail('ProcessorPriority enum not found in $_api');
  return [for (final m in RegExp(r'^\s*(\w+),', multiLine: true).allMatches(body)) m[1]!];
}

/// Class name -> (attribute, priority) for every `extends Processor` class under the processors directory.
Map<String, _Processor> _codeProcessors() {
  final result = <String, _Processor>{};
  final files = Directory(
    _processorsDir,
  ).listSync(followLinks: false).whereType<File>().where((f) => f.path.endsWith('.dart'));
  for (final file in files) {
    final parts = file.readAsStringSync().split(RegExp(r'^class ', multiLine: true)).skip(1);
    for (final part in parts) {
      final name = RegExp(r'^(\w+) extends Processor\b').firstMatch(part)?[1];
      if (name == null) continue;
      final attribute = RegExp(r"String get attribute => '(\w+)'").firstMatch(part)?[1];
      final priority = RegExp(
        r'ProcessorPriority get priority => \.?(?:ProcessorPriority\.)?(\w+);',
      ).firstMatch(part)?[1];
      if (attribute == null || priority == null) fail('${p.basename(file.path)}: cannot read $name attribute/priority');
      result[name] = (attribute: attribute, priority: priority);
    }
  }
  return result;
}

/// Everything the doc's table and Priority Model block get wrong about the code; empty when they agree.
List<String> tableProblems(String doc, List<String> enumOrder, Map<String, _Processor> code) {
  final problems = <String>[];

  // Priority Model block: slot names in enum order, and each processor's tl:<attribute> on its own slot's line.
  final model = <String, String>{};
  final modelOrder = <String>[];
  for (final m in RegExp(r'^ProcessorPriority\.(\w+)\s+←\s*(.*)$', multiLine: true).allMatches(doc)) {
    modelOrder.add(m[1]!);
    model[m[1]!] = m[2]!;
  }
  if (modelOrder.join(',') != enumOrder.join(',')) {
    problems.add('Priority Model order ${modelOrder.join(', ')} != enum ${enumOrder.join(', ')}');
  }
  final count = RegExp(r'defined by `ProcessorPriority` — (\d+) named slots').firstMatch(doc)?[1];
  if (count != '${enumOrder.length}') problems.add('Priority Model says $count slots, enum has ${enumOrder.length}');

  // Built-in Processors table: one row per processor class, priority column equals the getter.
  final rows = <String, ({String attributes, String priority})>{};
  for (final m in RegExp(r'^\|\s*\d+\s*\|\s*`(\w+)`\s*\|([^|]*)\|\s*(\w+)\s*\|', multiLine: true).allMatches(doc)) {
    rows[m[1]!] = (attributes: m[2]!, priority: m[3]!);
  }
  for (final name in {...rows.keys, ...code.keys}) {
    final row = rows[name];
    final processor = code[name];
    if (row == null) {
      problems.add('$name has no table row');
    } else if (processor == null) {
      problems.add('table row $name has no processor class');
    } else {
      if (row.priority != processor.priority) {
        problems.add('$name: table says ${row.priority}, code says ${processor.priority}');
      }
      if (!RegExp('`${processor.attribute}`').hasMatch(row.attributes)) {
        problems.add('$name: table attribute column ${row.attributes.trim()} lacks `${processor.attribute}`');
      }
      if (!(model[processor.priority] ?? '').contains('tl:${processor.attribute}')) {
        problems.add('$name: Priority Model line ${processor.priority} lacks tl:${processor.attribute}');
      }
    }
  }
  return problems;
}

void main() {
  final doc = _read(_doc);
  final order = _enumOrder(_read(_api));
  final code = _codeProcessors();

  test('reads the whole processor set from source', () {
    expect(order, hasLength(8));
    expect(code.keys, hasLength(13));
  });

  test('the architecture doc agrees with ProcessorPriority and the processors', () {
    expect(tableProblems(doc, order, code), isEmpty);
  });

  test('names tl:attrs in the AttrProcessor row and the afterContent slot', () {
    expect(RegExp(r'\|\s*`AttrProcessor`\s*\|[^|]*`attrs`').hasMatch(doc), isTrue);
    expect(RegExp(r'afterContent\s+←[^\n]*tl:attrs').hasMatch(doc), isTrue);
  });

  group('drift is detected', () {
    test('a table row with the wrong priority', () {
      final mutated = doc.replaceFirstMapped(
        RegExp(r'(`EachProcessor`[^|]*\|[^|]*\|\s*)afterConditionals'),
        (m) => '${m[1]}afterIteration',
      );

      expect(mutated, isNot(doc));
      expect(tableProblems(mutated, order, code), contains(contains('EachProcessor: table says afterIteration')));
    });

    test('a Priority Model block listing slots out of enum order', () {
      final lines = RegExp(r'^ProcessorPriority\.afterLocals.*$', multiLine: true);
      final mutated = doc.replaceFirst(lines, 'ProcessorPriority.afterLocals ← (open)\nProcessorPriority.highest ← x');

      expect(tableProblems(mutated, order, code), isNotEmpty);
    });

    test('a processor missing its tl:attribute on the Priority Model line', () {
      final mutated = doc.replaceFirst('tl:each', 'tl:iterate');

      expect(tableProblems(mutated, order, code), contains(contains('EachProcessor: Priority Model line')));
    });

    test('a processor class with no table row', () {
      final mutated = doc.replaceFirst(RegExp(r'^\|[^\n]*`RemoveProcessor`[^\n]*\n', multiLine: true), '');

      expect(tableProblems(mutated, order, code), contains('RemoveProcessor has no table row'));
    });
  });
}
