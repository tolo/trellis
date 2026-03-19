/// Generates the pubspec.yaml content for a Relic + Trellis project.
String relicPubspecTemplate(String projectName) =>
    '''
name: $projectName
version: 0.1.0
description: A Relic + Trellis web application.

environment:
  sdk: ^3.10.0

dependencies:
  relic: ^1.2.0
  trellis: ^0.7.0
  trellis_relic: ^0.1.0

dev_dependencies:
  lints: ^6.0.0
  test: ^1.25.0
''';
