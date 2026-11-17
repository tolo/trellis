import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../../tool/ui_gate/checks.dart';
import '../../../tool/ui_gate/manifest.dart';

const cssOnlyComponents = [
  'alert',
  'badge',
  'breadcrumb',
  'button',
  'card',
  'checkbox',
  'cluster',
  'container',
  'field',
  'grid',
  'input',
  'native-select',
  'pagination',
  'radio',
  'separator',
  'stack',
  'switch',
  'table',
  'textarea',
];

List<String> qualificationIssues(Directory pages, Directory manifests, Directory records) {
  final issues = <String>[];
  for (final page in pages.listSync().whereType<File>().where((f) => f.path.endsWith('.html'))) {
    final name = page.uri.pathSegments.last.replaceFirst('.html', '');
    final recipe = File('${manifests.path}/$name.yaml');
    if (!recipe.existsSync()) {
      issues.add('$name: missing manifest');
      continue;
    }
    GateManifest.load(recipe);
    final file = File('${records.path}/$name.json');
    if (!file.existsSync()) {
      issues.add('$name: missing record');
      continue;
    }
    final record = jsonDecode(file.readAsStringSync()) as Map;
    if (record['component'] != name || record['automated'] != 'pass') issues.add('$name: automated verdict');
    final items = record['items'] as Map;
    for (final item in automatedItems) {
      final value = items[item] as Map?;
      if (value?['status'] != 'pass') issues.add('$name: $item');
      final browsers = value?['browsers'] as Map? ?? const {};
      for (final browser in ['chrome', 'firefox']) {
        final result = browsers[browser] as Map?;
        if (result?['status'] != 'pass' &&
            !(result?['unsupported'] == true && browsers.values.any((v) => (v as Map)['status'] == 'pass'))) {
          issues.add('$name: $item/$browser');
        }
      }
    }
    // The CLI preserves maintainer-entered manual outcomes across automated reruns.
    for (final item in manualItems) {
      if (items[item] case {
        'status': 'pass' || 'fail' || 'not-run' || 'release-prep',
        'evidence': final List<Object?> evidence,
      } when evidence.every((entry) => entry is String)) {
        continue;
      }
      issues.add('$name: $item invalid manual result');
    }
  }
  return issues;
}

void main() {
  final root = Directory.current.parent.parent;
  final pages = Directory('gallery/pages');
  final manifests = Directory('${root.path}/dev/ui-gate/manifests');
  final records = Directory('${root.path}/dev/ui-gate/records');

  test('every gallery page has a loadable manifest', () {
    expect(
      pages.listSync().whereType<File>().map((f) => f.uri.pathSegments.last.replaceFirst('.html', '')),
      containsAll(cssOnlyComponents),
    );
    for (final page in pages.listSync().whereType<File>().where((f) => f.path.endsWith('.html'))) {
      final name = page.uri.pathSegments.last.replaceFirst('.html', '');
      final manifest = GateManifest.load(File('${manifests.path}/$name.yaml'));
      expect(manifest.name, name);
      expect(manifest.page, '/components/$name');
      expect(manifest.keyboard, isNotEmpty, reason: name);
      expect(manifest.data['semantics'], isNotEmpty, reason: name);
      expect(manifest.htmx?['region'], '#demo');
      expect(manifest.htmx?['swap'], isNotEmpty);
      expect(manifest.htmx?['navigate'], isNotEmpty);
    }
  });

  test('every record passes every automated item in each browser it ran and leaves manual items for release prep', () {
    expect(qualificationIssues(pages, manifests, records), isEmpty);
  });

  test('a page without a manifest or a failing record fails', () {
    final scratch = Directory.systemTemp.createTempSync('component_records_');
    addTearDown(() => scratch.deleteSync(recursive: true));
    final fakePages = Directory('${scratch.path}/pages')..createSync();
    final fakeManifests = Directory('${scratch.path}/manifests')..createSync();
    final fakeRecords = Directory('${scratch.path}/records')..createSync();
    File('${fakePages.path}/unqualified.html').writeAsStringSync('<h1>Unqualified</h1>');
    expect(qualificationIssues(fakePages, fakeManifests, fakeRecords), ['unqualified: missing manifest']);
    File('${fakePages.path}/unqualified.html').deleteSync();
    File('${fakePages.path}/button.html').writeAsStringSync('<h1>Button</h1>');
    File('${manifests.path}/button.yaml').copySync('${fakeManifests.path}/button.yaml');
    final copied = File('${fakeRecords.path}/button.json');
    File('${records.path}/button.json').copySync(copied.path);
    expect(qualificationIssues(fakePages, fakeManifests, fakeRecords), isEmpty);
    final data = jsonDecode(copied.readAsStringSync()) as Map;
    final items = data['items'] as Map;
    final originalManual = {for (final item in manualItems) item: items[item]};
    items['safari'] = {
      'status': 'pass',
      'evidence': ['Maintainer checked Safari'],
    };
    items['screen-reader-voiceover-safari'] = {
      'status': 'fail',
      'evidence': ['Focus order failed'],
    };
    items['screen-reader-nvda-firefox'] = {
      'status': 'not-run',
      'evidence': ['NVDA unavailable'],
    };
    copied.writeAsStringSync(jsonEncode(data));
    expect(
      qualificationIssues(fakePages, fakeManifests, fakeRecords),
      isEmpty,
      reason: 'Human-entered manual outcomes do not change the automated verdict',
    );
    items['safari'] = {'status': 'unknown', 'evidence': <String>[]};
    items['screen-reader-voiceover-safari'] = {
      'status': 'pass',
      'evidence': [1],
    };
    items.remove('screen-reader-nvda-firefox');
    copied.writeAsStringSync(jsonEncode(data));
    expect(
      qualificationIssues(fakePages, fakeManifests, fakeRecords),
      unorderedEquals([for (final item in manualItems) 'button: $item invalid manual result']),
    );
    items.addAll(originalManual);
    (items['keyboard'] as Map)['status'] = 'fail';
    copied.writeAsStringSync(jsonEncode(data));
    expect(qualificationIssues(fakePages, fakeManifests, fakeRecords), contains('button: keyboard'));
    copied.deleteSync();
    expect(qualificationIssues(fakePages, fakeManifests, fakeRecords), ['button: missing record']);
  });
}
