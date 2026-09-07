import '../version.dart';

/// Generates the pubspec.yaml content for a new Trellis project.
///
/// `trellis_dev` is a regular dependency because it is imported from `bin/server.dart`.
/// In production, the dev middleware is conditionally added to the pipeline.
///
/// Trellis packages are constrained to the CLI's own [cliVersion]: under lockstep (ADR-009) that is the SDK version.
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
  trellis: ^$cliVersion
  trellis_dev: ^$cliVersion
  trellis_shelf: ^$cliVersion

dev_dependencies:
  lints: ^6.0.0
''';
