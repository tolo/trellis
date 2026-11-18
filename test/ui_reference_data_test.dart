import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../tool/generate_ui_reference.dart';
import '../tool/ui_gate/checks.dart' show GateResult, automatedItems, manualItems;
import '../tool/ui_gate/record.dart' show encodeRecord, gateRecord;
import '../tool/ui_gate/release_policy.dart' show releaseComponents, releasePolicyPath;

const _records = 'dev/ui-gate/records';
const _suite = 'packages/trellis_ui';
const _data = 'site/data/ui_components.yaml';
const _pages = 'site/content/docs/ui/components';

void main() {
  late Directory fixture;
  late UiReferenceGenerator generator;

  File file(String relativePath) => File(p.join(fixture.path, relativePath));
  void write(String relativePath, String contents) {
    file(relativePath)
      ..createSync(recursive: true)
      ..writeAsStringSync(contents);
  }

  void copy(String relativePath) => write(relativePath, File(relativePath).readAsStringSync());
  YamlMap generated() => loadYaml(file(_data).readAsStringSync()) as YamlMap;

  void fixtureComponents(Iterable<String> names) {
    final pass = {
      for (final item in automatedItems) item: const GateResult('pass', ['Observed a passing check']),
    };
    for (final name in names) {
      write('$_records/$name.json', encodeRecord(gateRecord(name, {'chrome': pass, 'firefox': pass})));
      write(
        '$_suite/assets/fragments/$name.html',
        '<div class="trellis-$name" tl:fragment="sample(...attrs)" tl:attrs="\${attrs}"></div>',
      );
      write('$_pages/$name.md', 'Reference page for $name');
    }
  }

  void editRecord(String name, void Function(Map<String, dynamic>) edit) {
    final record = file('$_records/$name.json');
    final json = jsonDecode(record.readAsStringSync()) as Map<String, dynamic>;
    edit(json);
    record.writeAsStringSync(jsonEncode(json));
  }

  setUp(() {
    fixture = Directory.systemTemp.createTempSync('trellis_ui_reference_data_');
    addTearDown(() => fixture.deleteSync(recursive: true));
    write(releasePolicyPath, '#### Optional component release dispositions\n\n```text\n```\n');
    generator = UiReferenceGenerator(fixture.path);
  });

  test('committed data matches its sources and regenerates byte for byte', () {
    final names = Directory(_records)
        .listSync(followLinks: false)
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .map((file) => p.basenameWithoutExtension(file.path))
        .toList();
    expect(names, unorderedEquals(releaseComponents));
    copy(releasePolicyPath);
    for (final name in names) {
      copy('$_records/$name.json');
      final fragment = '$_suite/assets/fragments/$name.html';
      if (File(fragment).existsSync()) copy(fragment);
    }
    for (final page in Directory(_pages).listSync(followLinks: false).whereType<File>()) {
      if (page.path.endsWith('.md')) copy(page.path);
    }
    copy('$_suite/generated/trellis.min.css');
    for (final css in Directory('$_suite/assets/css/hand').listSync(followLinks: false).whereType<File>()) {
      if (css.path.endsWith('.css')) copy(css.path);
    }
    copy(_data);
    expect(generator.check(), isEmpty);
    final expected = file(_data).readAsBytesSync();
    generator.write();
    expect(file(_data).readAsBytesSync(), expected);
    generator.write();
    expect(file(_data).readAsBytesSync(), expected);

    final dialog = file('$_suite/assets/fragments/dialog.html');
    final source = dialog.readAsStringSync();
    final changed = source.replaceFirst(
      'dialog(id, title, description, open, ...attrs)',
      'dialog(id, title, description, open, rounding, ...attrs)',
    );
    expect(changed, isNot(source));
    dialog.writeAsStringSync(changed);
    expect(generator.check(), [contains('Regenerate with: dart run tool/generate_ui_reference.dart')]);
  });

  test('a failing record is not qualified and a stale file names the regeneration command', () {
    fixtureComponents(['button', 'badge']);
    write('$_suite/generated/trellis.min.css', '.trellis-button {} .trellis-badge {}');
    generator.write();
    expect(generator.check(), isEmpty);

    editRecord('button', (record) => record['automated'] = 'fail');
    expect(generator.check(), [
      contains('Regenerate with: dart run tool/generate_ui_reference.dart'),
      'Unexpected reference page: button',
    ]);
    generator.write();
    expect((generated()['button'] as YamlMap)['qualified'], isFalse);
    expect((generated()['badge'] as YamlMap)['qualified'], isTrue);
    expect(generator.check(), ['Unexpected reference page: button']);
    file('$_pages/button.md').deleteSync();
    expect(generator.check(), isEmpty);
  });

  test('a manual gate failure removes the published component inventory and page', () {
    fixtureComponents(['button', 'badge']);
    write('$_suite/generated/trellis.min.css', '.trellis-button {} .trellis-badge {}');
    generator.write();
    expect(generator.check(), isEmpty);

    editRecord('button', (record) {
      (record['items'] as Map)['safari'] = {
        'status': 'fail',
        'evidence': ['Focus was lost after closing.'],
      };
    });
    expect(generator.check(), [
      contains('Regenerate with: dart run tool/generate_ui_reference.dart'),
      'Unexpected reference page: button',
    ]);
    generator.write();
    expect(generated().keys, [
      'badge',
    ], reason: 'The publication drops the failing subject and keeps its gate evidence.');
    expect(generator.check(), ['Unexpected reference page: button']);
    file('$_pages/button.md').deleteSync();
    expect(generator.check(), isEmpty);
  });

  test('an explicitly removed component keeps its record without requiring a fragment', () {
    fixtureComponents(['button', 'badge']);
    write('$_suite/generated/trellis.min.css', '.trellis-button {} .trellis-badge {}');
    editRecord('badge', (record) {
      record['automated'] = 'fail';
      final visual = (record['items'] as Map)['visual'] as Map;
      visual['status'] = 'fail';
      (visual['browsers'] as Map)['firefox'] = {
        'status': 'fail',
        'evidence': ['The badge clips its text'],
      };
    });
    final evidence = file('$_records/badge.json').readAsBytesSync();
    file('$_suite/assets/fragments/badge.html').deleteSync();
    file('$_pages/badge.md').deleteSync();
    write(
      releasePolicyPath,
      '#### Optional component release dispositions\n\n```text\nbadge | removed | visual\n```\n',
    );
    generator.write();
    expect(generated().keys, ['button']);
    expect(generator.check(), isEmpty);
    expect(file('$_records/badge.json').readAsBytesSync(), evidence);
    file('$_records/badge.json').deleteSync();
    expect(
      generator.check,
      throwsA(isA<UiReferenceException>().having((error) => error.message, 'message', contains('badge'))),
    );
  });

  test('part classes go to the longest matching component name', () {
    fixtureComponents(['alert', 'alert-dialog']);
    write('$_suite/generated/trellis.min.css', '''
      .trellis-alert { color: red; }
      .trellis-alert-title, .trellis-alert-dialog-title { color: blue; }
      [data-slot="alert-dialog"].trellis-alert-dialog { color: green; }
      .trellis-alerts, .trellis-alert-dialogue { color: gray; }
      /* .trellis-alert-comment is not a selector. */
    ''');
    write('$_suite/assets/css/hand/alert-dialog.css', '.trellis-alert-dialog-action > button { margin: 0; }');
    generator.write();
    final data = generated();
    expect((data['alert'] as YamlMap)['part_classes'], [
      'trellis-alert',
      'trellis-alert-dialogue',
      'trellis-alert-title',
    ]);
    expect((data['alert-dialog'] as YamlMap)['part_classes'], [
      'trellis-alert-dialog',
      'trellis-alert-dialog-action',
      'trellis-alert-dialog-title',
    ]);
  });

  test('support requires every manual result and preserves all recorded statuses', () {
    fixtureComponents(['button']);
    write('$_suite/generated/trellis.min.css', '.trellis-button {}');
    for (final status in ['pass', 'fail', 'not-run', 'release-prep']) {
      editRecord('button', (record) {
        final items = record['items'] as Map<String, dynamic>;
        for (final name in manualItems) {
          items[name] = {
            'status': name == 'safari' ? status : 'pass',
            'evidence': ['Manual result retained'],
          };
        }
      });
      final recordBefore = file('$_records/button.json').readAsBytesSync();
      generator.write();
      expect(file('$_records/button.json').readAsBytesSync(), recordBefore);
      if (status == 'fail') {
        expect(generated(), isEmpty);
        continue;
      }
      final data = generated()['button'] as YamlMap;
      expect(data['qualified'], isTrue);
      expect(data['supported'], status == 'pass');
      final items = (data['items'] as YamlList).cast<YamlMap>();
      expect(items.singleWhere((item) => item['name'] == 'safari')['status'], status);
    }
    editRecord('button', (record) {
      final items = record['items'] as Map<String, dynamic>;
      items['safari'] = {
        'status': 'pass',
        'evidence': [42],
      };
    });
    expect(
      generator.write,
      throwsA(isA<UiReferenceException>().having((e) => e.message, 'message', contains('safari'))),
    );
  });

  test('a passing automated item cannot hide a failing browser result', () {
    fixtureComponents(['button']);
    write('$_suite/generated/trellis.min.css', '.trellis-button {}');
    editRecord('button', (record) {
      final items = record['items'] as Map<String, dynamic>;
      final keyboard = items['keyboard'] as Map<String, dynamic>;
      final browsers = keyboard['browsers'] as Map<String, dynamic>;
      browsers['firefox'] = {
        'status': 'fail',
        'evidence': ['Arrow focus failed'],
      };
    });
    expect(
      generator.write,
      throwsA(isA<UiReferenceException>().having((e) => e.message, 'message', contains('button: keyboard'))),
    );
  });
}
