import 'dart:convert';
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

    test('README manual-download example version tracks the trellis_cli package version', () {
      // Guards M16: melos bumps pubspecs but not the hardcoded example version in the
      // manual-download snippets. Passes today (all 0.9.1). This repo-root contract test
      // (run via `dart test test/`, not CI — CI gating is tracked as TD-010) fails after a
      // lockstep bump if version_lockstep.sh's README rewrite is skipped or broken.
      final pubspec = readWorkspaceFile('packages/trellis_cli/pubspec.yaml');
      final pkgVersion = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)?.group(1);
      expect(pkgVersion, isNotNull, reason: 'no version: line in trellis_cli/pubspec.yaml');

      final readmes = [readWorkspaceFile('README.md'), readWorkspaceFile('packages/trellis_cli/README.md')].join('\n');
      // Same line shapes version_lockstep.sh rewrites: `VERSION=<semver>` (shell) and
      // `$Version = "<semver>"` (PowerShell).
      final shellVersions = RegExp(
        r'^VERSION=([0-9][0-9A-Za-z.+-]*)$',
        multiLine: true,
      ).allMatches(readmes).map((m) => m.group(1)).toList();
      final psVersions = RegExp(
        r'\$Version = "([0-9][0-9A-Za-z.+-]*)"',
      ).allMatches(readmes).map((m) => m.group(1)).toList();

      final exampleVersions = [...shellVersions, ...psVersions];
      expect(exampleVersions, isNotEmpty, reason: 'no manual-download example version lines found in the READMEs');
      for (final version in exampleVersions) {
        expect(version, pkgVersion, reason: 'stale README example version; run tool/version_lockstep.sh to sync');
      }
    });
  });

  group('scoop channel distribution contracts', () {
    test('release workflow defines the Scoop bucket job', () {
      final workflow = readWorkspaceFile('.github/workflows/release-binaries.yml');

      expect(workflow, contains('SCOOP_TAP_REPO: tolo/scoop-trellis'));
      expect(workflow, contains('name: Update Scoop bucket'));
      // Scope `needs:` to the scoop job block: the sibling homebrew job has the
      // identical line, so a whole-file `contains` would pass even if scoop's
      // `needs:` were wrong or missing.
      expect(_jobBlock(workflow, 'scoop'), contains('needs: [version, checksums]'));
      expect(workflow, contains('cp trellis.json bucket-repo/bucket/trellis.json'));
      expect(workflow, contains('git add bucket/trellis.json'));
    });

    test('both READMEs document the Scoop install channel', () {
      final readmes = [readWorkspaceFile('README.md'), readWorkspaceFile('packages/trellis_cli/README.md')];

      for (final readme in readmes) {
        expect(readme, contains('scoop bucket add trellis https://github.com/tolo/scoop-trellis'));
        expect(readme, contains('scoop install trellis'));
      }
    });

    test('render_scoop_manifest emits a well-formed bucket manifest', () async {
      // Renders the manifest end-to-end from a fixture sha sidecar (single fast
      // invocation) and asserts the load-bearing Scoop fields.
      const version = '9.9.9';
      final sha = 'a' * 64;

      final tempDir = Directory.systemTemp.createTempSync('scoop_manifest_contract_');
      addTearDown(() => tempDir.deleteSync(recursive: true));

      final checksumsDir = Directory('${tempDir.path}/checksums')..createSync();
      File(
        '${checksumsDir.path}/trellis-v$version-windows-x64.zip.sha256',
      ).writeAsStringSync('$sha  trellis-v$version-windows-x64.zip\n');
      final outputPath = '${tempDir.path}/trellis.json';

      final result = await Process.run('dart', [
        'run',
        'tool/render_scoop_manifest.dart',
        '--version',
        version,
        '--repo',
        'tolo/trellis',
        '--checksums-dir',
        checksumsDir.path,
        '--output',
        outputPath,
      ], workingDirectory: workspaceRoot.path);
      expect(result.exitCode, 0, reason: 'renderer failed: ${result.stdout}\n${result.stderr}');

      final manifest = jsonDecode(File(outputPath).readAsStringSync()) as Map<String, dynamic>;
      expect(manifest['bin'], 'trellis.exe');
      expect(manifest['version'], version);
      expect(manifest['checkver'], 'github');

      final url = (manifest['architecture'] as Map<String, dynamic>)['64bit'] as Map<String, dynamic>;
      expect(url['url'], endsWith('trellis-v$version-windows-x64.zip'));

      final autoArch = (manifest['autoupdate'] as Map<String, dynamic>)['architecture'] as Map<String, dynamic>;
      final autoUrl = (autoArch['64bit'] as Map<String, dynamic>)['url'] as String;
      expect(autoUrl, contains(r'$version'));
    });
  });
}

/// Extracts a single top-level job block (keyed by [jobId] under `jobs:`) from a
/// GitHub Actions [workflow] — from its `  <jobId>:` header to the next top-level
/// job header (two-space indent) or end of file. Lets a contract assert against
/// one job in isolation, so an identical line in a sibling job can't satisfy it.
String _jobBlock(String workflow, String jobId) {
  final header = RegExp('^  $jobId:\$', multiLine: true).firstMatch(workflow);
  if (header == null) return '';
  final rest = workflow.substring(header.start + 1);
  final nextJob = RegExp(r'^  \w[\w-]*:$', multiLine: true).firstMatch(rest);
  return nextJob == null ? rest : rest.substring(0, nextJob.start);
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
