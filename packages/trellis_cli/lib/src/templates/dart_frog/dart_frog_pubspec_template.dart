/// Generates the pubspec.yaml content for a Dart Frog + Trellis project.
String dartFrogPubspecTemplate(String projectName) =>
    '''
name: $projectName
version: 0.1.0
description: A Dart Frog + Trellis web application.

environment:
  sdk: ^3.10.0

dependencies:
  dart_frog: ^1.2.0
  trellis: ^0.7.0
  trellis_dart_frog: ^0.1.0
  trellis_dev: ^0.1.0

dev_dependencies:
  lints: ^6.0.0
  test: ^1.25.0
''';
