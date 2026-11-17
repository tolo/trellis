import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../tool/generate_ui_reference.dart';
import '../tool/ui_gate/checks.dart' show manualItems;

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

  void copyComponents(Iterable<String> names) {
    for (final name in names) {
      copy('$_records/$name.json');
      copy('$_suite/assets/fragments/$name.html');
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
    generator = UiReferenceGenerator(fixture.path);
  });

  test('committed data matches its sources and regenerates byte for byte', () {
    final names = Directory(_records)
        .listSync(followLinks: false)
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .map((file) => p.basenameWithoutExtension(file.path))
        .toList();
    expect(names, hasLength(25));
    copyComponents(names);
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

    final button = file('$_suite/assets/fragments/button.html');
    final source = button.readAsStringSync();
    final changed = source.replaceFirst('button(variant, size, ...attrs)', 'button(variant, size, rounding, ...attrs)');
    expect(changed, isNot(source));
    button.writeAsStringSync(changed);
    expect(generator.check(), [contains('Regenerate with: dart run tool/generate_ui_reference.dart')]);
  });

  test('a failing record is not qualified and a stale file names the regeneration command', () {
    copyComponents(['button', 'badge']);
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

  test('part classes go to the longest matching component name', () {
    copyComponents(['alert', 'alert-dialog']);
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
    copyComponents(['button']);
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
      generator.write();
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
    copyComponents(['button']);
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
