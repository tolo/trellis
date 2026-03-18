/// Generates the pubspec.yaml content for a new blog project.
String blogPubspecTemplate(String projectName) =>
    '''
name: $projectName
version: 0.1.0
description: A blog built with Trellis.

environment:
  sdk: ^3.10.0

dependencies:
  trellis_site: ^0.1.0

dev_dependencies:
  lints: ^6.0.0
''';
