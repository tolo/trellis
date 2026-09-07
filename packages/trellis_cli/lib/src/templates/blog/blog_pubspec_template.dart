import '../../version.dart';

/// Generates the pubspec.yaml content for a new blog project.
///
/// Trellis packages are constrained to the CLI's own [cliVersion]: under lockstep (ADR-009) that is the SDK version.
String blogPubspecTemplate(String projectName) =>
    '''
name: $projectName
version: 0.1.0
description: A blog built with Trellis.

environment:
  sdk: ^3.10.0

dependencies:
  trellis_site: ^$cliVersion

dev_dependencies:
  lints: ^6.0.0
''';
