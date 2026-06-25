import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';
import 'package:trellis_site/src/version.dart';

void main() {
  test('siteVersion matches the pubspec version', () async {
    // Resolve the package's own pubspec independent of the test's working
    // directory (melos runs package tests from varying cwds).
    final libUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/src/version.dart'));
    final packageRoot = File(libUri!.toFilePath()).parent.parent.parent.path;
    final pubspec = File('$packageRoot/pubspec.yaml').readAsStringSync();
    final pubspecVersion = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)?.group(1);

    expect(
      siteVersion,
      pubspecVersion,
      reason:
          'siteVersion ($siteVersion) is out of sync with pubspec version ($pubspecVersion). '
          'Releases must go through tool/version_lockstep.sh, which keeps them aligned.',
    );
  });
}
