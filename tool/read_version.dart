import 'dart:io';

/// Reads and cross-checks the `trellis_cli` release version.
///
/// The CLI version lives in two places that must agree (lockstep, ADR-009):
/// `packages/trellis_cli/pubspec.yaml` (`version:`) and
/// `packages/trellis_cli/lib/src/version.dart` (`cliVersion`). This is the
/// single source of truth for [build_release] and the packaging renderers; a
/// drift between the two files is a release bug, so we fail loudly here rather
/// than ship a binary whose `--version` disagrees with its pubspec.
///
/// Runnable directly (`dart run tool/read_version.dart`) to print the version.
String readCliVersion() {
  final pubspecVersion = _pubspecVersion();
  final constantVersion = _versionConstant();
  if (pubspecVersion != constantVersion) {
    throw StateError(
      'Version drift: trellis_cli pubspec.yaml is $pubspecVersion but '
      'lib/src/version.dart cliVersion is $constantVersion. Re-run '
      'tool/version_lockstep.sh to realign.',
    );
  }
  return pubspecVersion;
}

String _pubspecVersion() {
  final file = File('packages/trellis_cli/pubspec.yaml');
  if (!file.existsSync()) {
    throw StateError('pubspec.yaml not found at ${file.path} (run from repo root)');
  }
  for (final line in file.readAsLinesSync()) {
    final match = RegExp(r'^version:\s*([^\s#]+)').firstMatch(line);
    if (match != null) return match.group(1)!;
  }
  throw StateError('No `version:` field found in ${file.path}');
}

String _versionConstant() {
  final file = File('packages/trellis_cli/lib/src/version.dart');
  if (!file.existsSync()) {
    throw StateError('version.dart not found at ${file.path} (run from repo root)');
  }
  final match = RegExp(r"cliVersion\s*=\s*'([^']+)'").firstMatch(file.readAsStringSync());
  if (match == null) throw StateError('No `cliVersion` constant found in ${file.path}');
  return match.group(1)!;
}

void main() {
  stdout.writeln(readCliVersion());
}
