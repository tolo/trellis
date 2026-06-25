import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

void main() {
  test('cliVersion matches the pubspec version', () async {
    // Resolve the package's own pubspec independent of the test's working
    // directory (melos runs package tests from varying cwds).
    final libUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_cli/trellis_cli.dart'));
    final packageRoot = File(libUri!.toFilePath()).parent.parent.path;
    final pubspec = File('$packageRoot/pubspec.yaml').readAsStringSync();
    final pubspecVersion = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)?.group(1);

    expect(
      cliVersion,
      pubspecVersion,
      reason:
          'cliVersion ($cliVersion) is out of sync with pubspec version ($pubspecVersion). '
          'Releases must go through tool/version_lockstep.sh, which keeps them aligned.',
    );
  });
}
