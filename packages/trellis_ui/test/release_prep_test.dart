import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../../tool/ui_gate/checks.dart';
import '../../../tool/ui_gate/record.dart';

void main() {
  test('every component and surface record leaves the screen-reader pairs and Safari to release prep', () {
    final gate = Directory('../../dev/ui-gate');
    for (final (folder, expectedCount) in [(gate.path, 25), ('${gate.path}/apps', 7)]) {
      List<String> names(String subdir, String extension) => Directory('$folder/$subdir')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith(extension))
          .map((file) => file.uri.pathSegments.last.substring(0, file.uri.pathSegments.last.length - extension.length))
          .toList();
      final subjects = names('manifests', '.yaml');
      expect(subjects, hasLength(expectedCount), reason: folder);
      expect(names('records', '.json'), unorderedEquals(subjects), reason: folder);
      for (final subject in subjects) {
        final file = File('$folder/records/$subject.json');
        final record = jsonDecode(file.readAsStringSync()) as Map;
        final items = record['items'] as Map;
        expect(record['automated'], 'pass', reason: subject);
        for (final manual in manualItems) {
          expect(validManualResult(items[manual]), isTrue, reason: '$subject $manual');
        }
      }
    }
  });
}
