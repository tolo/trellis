/// Generates the pubspec.yaml content for a new Trellis project.
///
/// `trellis_dev` is a regular dependency because it is imported from `bin/server.dart`.
/// In production, the dev middleware is conditionally added to the pipeline.
String pubspecTemplate(String projectName) =>
    '''
name: $projectName
version: 0.1.0
description: A Trellis-powered web application.

environment:
  sdk: ^3.10.0

dependencies:
  shelf: ^1.4.0
  shelf_router: ^1.1.0
  shelf_static: ^1.1.0
  trellis: ^0.7.0
  trellis_dev: ^0.1.0
  trellis_shelf: ^0.1.0

dev_dependencies:
  lints: ^6.0.0
''';
