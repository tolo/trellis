import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

void main() {
  late Directory workspaceRoot;

  setUpAll(() async {
    workspaceRoot = await _findWorkspaceRoot();
  });

  String readWorkspaceFile(String path) => File('${workspaceRoot.path}/$path').readAsStringSync();

  group('binary release distribution contracts', () {
    test('publishing step requests semantic latest selection', () {
      final workflow = readWorkspaceFile('.github/workflows/release-binaries.yml');

      expect(workflow, contains(r'gh api --method PATCH "$API_URL" -F draft=false -f make_latest=legacy'));
      expect(workflow, isNot(contains(r'gh release edit "$GITHUB_REF_NAME" --draft=false --latest')));
    });

    test('manual install docs use versioned release asset URLs', () {
      final docs = [readWorkspaceFile('README.md'), readWorkspaceFile('packages/trellis_cli/README.md')].join('\n');

      expect(docs, isNot(contains('/releases/latest/download/')));
      expect(docs, contains(r'/releases/download/v$VERSION'));
      expect(docs, contains(r'/releases/download/v$Version'));
      expect(docs, contains('no leading "v"'));
    });

    test('static-site quick start does not require Dart SDK package resolution', () {
      final docs = [readWorkspaceFile('README.md'), readWorkspaceFile('packages/trellis_cli/README.md')].join('\n');

      expect(docs, isNot(contains('cd my_blog && dart pub get')));
      expect(docs, isNot(contains('cd my_blog\ndart pub get\ntrellis build')));
      expect(docs, contains('cd my_blog && trellis build && trellis serve'));
      expect(docs, contains('cd my_blog\ntrellis build\ntrellis serve'));
    });

    test('Windows checksum snippet compares expected and actual hashes', () {
      final cliReadme = readWorkspaceFile('packages/trellis_cli/README.md');

      expect(cliReadme, contains(r'$Expected = ($Match.Line -split'));
      expect(cliReadme, contains(r'$Actual = (Get-FileHash'));
      expect(cliReadme, contains(r'if ($Actual -ne $Expected) { throw "Checksum mismatch for $Asset" }'));
    });
  });
}

Future<Directory> _findWorkspaceRoot() async {
  final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_cli/trellis_cli.dart'));
  if (packageUri == null || packageUri.scheme != 'file') {
    throw StateError('Could not resolve package:trellis_cli/trellis_cli.dart');
  }

  var dir = File(packageUri.toFilePath()).parent;
  while (true) {
    if (Directory('${dir.path}/packages/trellis_cli').existsSync()) return dir;

    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('Could not find workspace root from resolved package path ${packageUri.toFilePath()}');
    }
    dir = parent;
  }
}
