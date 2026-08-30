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
      // manual-download snippets. This repo-root contract test (run by ci.yml's `check`
      // job and by tool/release.sh) fails after a lockstep bump if version_lockstep.sh's
      // README rewrite is skipped or broken.
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

    test('lockstep bump syncs and permits only the docs-site hero version', () {
      final bumpScript = readWorkspaceFile('tool/version_lockstep.sh');
      final releaseScript = readWorkspaceFile('tool/release.sh');

      expect(bumpScript, contains('SITE_CONFIG="\${ROOT}/site/trellis_site.yaml"'));
      expect(bumpScript, contains(r'(["\x27]?)'));
      expect(bumpScript, contains(r'$ENV{VERSION}'));
      expect(bumpScript, contains(r'END { exit 1 unless $updated == 1 }'));
      expect(releaseScript, contains('site/trellis_site.yaml) EXPECTED_CHANGED+='));
    });
  });

  group('release gate contracts', () {
    // Pushing a `vX.Y.Z` tag IS the publish (pub.dev cannot unpublish) and main
    // has no branch protection, so the tag workflows carry their own gate: a
    // first job (release-gate.yml) that requires a green ci.yml run for the
    // tagged commit. These assert the wiring stays in place — dropping a
    // `needs:` would silently return to "a red build can publish".
    test('publish.yml gates every package publish on the release gate', () {
      final workflow = readWorkspaceFile('.github/workflows/publish.yml');

      expect(_jobBlock(workflow, 'ci-gate'), contains('uses: ./.github/workflows/release-gate.yml'));
      expect(_jobBlock(workflow, 'publish'), contains('needs: ci-gate'));
    });

    test('release-binaries.yml gates its first job on the release gate and verifies at the end', () {
      final workflow = readWorkspaceFile('.github/workflows/release-binaries.yml');

      expect(_jobBlock(workflow, 'ci-gate'), contains('uses: ./.github/workflows/release-gate.yml'));
      expect(_jobBlock(workflow, 'version'), contains('needs: ci-gate'));
      expect(_jobBlock(workflow, 'verify'), contains('tool/verify_release.sh'));
    });

    test('release binaries resolve only the committed dependency graph', () {
      final workflow = readWorkspaceFile('.github/workflows/release-binaries.yml');
      final gets = RegExp(r'^\s*run: dart pub get([^\n]*)$', multiLine: true).allMatches(workflow).toList();

      expect(File('${workspaceRoot.path}/pubspec.lock').existsSync(), isTrue);
      expect(gets, isNotEmpty);
      expect(gets.map((match) => match.group(1)), everyElement(contains('--enforce-lockfile')));
      expect(readWorkspaceFile('.gitignore'), contains('!/pubspec.lock'));
    });

    test('every job in both tag workflows is downstream of the gate', () {
      // The gate only helps if nothing runs beside it: a job added later without
      // `needs:` would start on the raw tag push, ungated. Transitive chains
      // (build -> version -> ci-gate) are fine; a missing `needs:` is not.
      for (final path in ['.github/workflows/publish.yml', '.github/workflows/release-binaries.yml']) {
        final workflow = readWorkspaceFile(path);
        final jobIds = RegExp(
          r'^  ([\w-]+):$',
          multiLine: true,
        ).allMatches(_jobsSection(workflow)).map((m) => m.group(1)!);
        expect(jobIds, contains('ci-gate'), reason: '$path has no ci-gate job');
        for (final jobId in jobIds.where((id) => id != 'ci-gate')) {
          expect(
            _jobBlock(workflow, jobId),
            matches(RegExp(r'^    needs:', multiLine: true)),
            reason: '$path job `$jobId` has no `needs:` — it would run on the tag push without the gate',
          );
        }
      }
    });

    test('release-gate.yml is a reusable workflow that runs the shared gate script', () {
      final workflow = readWorkspaceFile('.github/workflows/release-gate.yml');

      expect(workflow, contains('workflow_call:'));
      expect(workflow, contains('tool/require_green_ci.sh "\$GITHUB_REF_NAME"'));
    });

    test('local release gate runs every root test with CI guards enabled', () {
      final releaseScript = readWorkspaceFile('tool/release.sh');
      final rootTestCommands = RegExp(
        r'^CI=true dart test([^\n]*) \|\| gate_failed$',
        multiLine: true,
      ).allMatches(releaseScript).toList();

      expect(rootTestCommands, hasLength(1), reason: 'release.sh must have one fail-closed root test command');
      expect(
        rootTestCommands.single.group(1),
        isEmpty,
        reason: 'the local release gate must run the complete root suite without selectors or exclusions',
      );
      expect(
        releaseScript,
        contains('" M" | "M ") ;;'),
        reason: 'the bump allow-list must reject deletion, addition, rename and copy statuses',
      );
      expect(releaseScript, contains('python3 tool/subset_fonts.py --verify'));
      expect(releaseScript, isNot(contains('git add -A')));
      expect(releaseScript, contains('git add -- "\${EXPECTED_CHANGED[@]}"'));
    });

    test('tap publication authenticates both clone and push without embedding a token in the URL', () {
      final workflow = readWorkspaceFile('.github/workflows/release-binaries.yml');
      for (final name in ['Publish formula to tap', 'Publish manifest to bucket']) {
        final step = RegExp(
          '      - name: ${RegExp.escape(name)}\\n([\\s\\S]*?)(?=\\n      - name:|\\n  [a-z][a-z-]*:)',
        ).firstMatch(workflow)?.group(1);
        expect(step, isNotNull, reason: '$name step must exist');
        expect(step, contains(r'GH_TOKEN: ${{ secrets.TAP_TOKEN }}'));
        final setup = step!.indexOf('gh auth setup-git');
        final clone = step.indexOf('gh repo clone');
        final push = step.indexOf('git push');
        expect(setup, greaterThanOrEqualTo(0), reason: '$name must configure Git authentication');
        expect(clone, greaterThan(setup), reason: '$name must configure authentication before cloning');
        expect(push, greaterThan(clone), reason: '$name must keep the helper configured through push');
        expect(step, isNot(contains(r'GH_TOKEN="$TAP_TOKEN"')));
        expect(step, isNot(contains('x-access-token')));
      }
    });

    test('green-CI gate defaults to the workflow that owns the check tier', () {
      final gateScript = readWorkspaceFile('tool/require_green_ci.sh');
      final workflow = RegExp(
        r'^CI_WORKFLOW="\$\{CI_WORKFLOW:-([^}]+)\}"$',
        multiLine: true,
      ).firstMatch(gateScript)?.group(1);

      expect(workflow, 'ci.yml');
      final ci = readWorkspaceFile('.github/workflows/$workflow');
      expect(_jobBlock(ci, 'check'), allOf(contains('melos run --no-select analyze'), contains('dart test')));
    });

    test('ci.yml and release-binaries.yml pin the same Dart SDK', () {
      // CI's analyze/format/test evidence only speaks for the release toolchain
      // if both use the same SDK; and release-binaries must take it from the
      // single `env.DART_SDK`, not a per-job literal that can drift.
      String pin(String path) {
        final match = RegExp(r'^\s*DART_SDK:\s*(\S+)', multiLine: true).firstMatch(readWorkspaceFile(path));
        expect(match, isNotNull, reason: 'no DART_SDK env in $path');
        return match!.group(1)!;
      }

      expect(pin('.github/workflows/release-binaries.yml'), pin('.github/workflows/ci.yml'));
      final releaseWorkflow = readWorkspaceFile('.github/workflows/release-binaries.yml');
      expect(
        RegExp(r'^\s*sdk:\s*[0-9]', multiLine: true).hasMatch(releaseWorkflow),
        isFalse,
        reason: r'release-binaries.yml has a literal `sdk:` pin; use `sdk: ${{ env.DART_SDK }}`',
      );
      expect(releaseWorkflow, contains(r'sdk: ${{ env.DART_SDK }}'));
    });

    test('ci.yml pins the actions whose conclusion gates a release', () {
      final ci = readWorkspaceFile('.github/workflows/ci.yml');
      final releaseWorkflow = readWorkspaceFile('.github/workflows/release-binaries.yml');
      final checkoutPin = RegExp(r'actions/checkout@([0-9a-f]{40})').firstMatch(releaseWorkflow)!.group(1);
      final dartPin = RegExp(r'dart-lang/setup-dart@([0-9a-f]{40})').firstMatch(releaseWorkflow)!.group(1);

      expect(ci, isNot(matches(RegExp(r'uses: (?:actions/checkout|dart-lang/setup-dart|actions/setup-node)@v\d'))));
      expect(RegExp('actions/checkout@$checkoutPin').allMatches(ci), hasLength(2));
      expect(RegExp('dart-lang/setup-dart@$dartPin').allMatches(ci), hasLength(2));
      expect(ci, contains('actions/setup-node@820762786026740c76f36085b0efc47a31fe5020 # v7'));
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

/// The `jobs:` section of a GitHub Actions [workflow] (from `jobs:` to end of
/// file), so job-id scans do not pick up same-indent keys elsewhere.
String _jobsSection(String workflow) {
  final jobs = RegExp(r'^jobs:$', multiLine: true).firstMatch(workflow);
  return jobs == null ? '' : workflow.substring(jobs.end);
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
