import '../../version.dart';

/// Generates the pubspec.yaml content for a Relic + Trellis project.
///
/// Trellis packages are constrained to the CLI's own [cliVersion]: under lockstep (ADR-009) that is the SDK version.
String relicPubspecTemplate(String projectName) =>
    '''
name: $projectName
version: 0.1.0
description: A Relic + Trellis web application.

environment:
  sdk: ^3.10.0

dependencies:
  relic: ^1.2.0
  trellis: ^$cliVersion
  trellis_relic: ^$cliVersion

dev_dependencies:
  lints: ^6.0.0
  test: ^1.25.0
''';
