import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import '../../../tool/ui_gate/release_policy.dart';

void main() {
  final root = Directory.current.parent.parent;
  final policy = ComponentReleasePolicy.read(root);

  test('every component and surface record leaves the screen-reader pairs and Safari to release prep', () {
    final gate = '${root.path}/dev/ui-gate';
    for (final name in releaseComponents) {
      final file = File('$gate/records/$name.json');
      expect(policy.recordIssues(name, jsonDecode(file.readAsStringSync())), isEmpty);
    }
    final apps = '${root.path}/dev/ui-gate/apps';
    List<String> names(String subdir, String extension) => Directory('$apps/$subdir')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith(extension))
        .map((file) => file.uri.pathSegments.last.substring(0, file.uri.pathSegments.last.length - extension.length))
        .toList();

    final subjects = names('manifests', '.yaml');
    expect(subjects, hasLength(7));
    expect(names('records', '.json'), unorderedEquals(subjects));
    for (final subject in subjects) {
      final file = File('$apps/records/$subject.json');
      expect(policy.recordIssues(subject, jsonDecode(file.readAsStringSync()), app: true), isEmpty);
    }
  });
}
