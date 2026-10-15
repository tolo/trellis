import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

// Fixture pins are composed from these so the test source holds no literal tolo/trellis pin that
// tool/version_lockstep.sh would rewrite at the next bump.
const stale = 'v0.11.0';
const install = 'trellis theme add https://github.com/tolo/trellis';

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

    test('lockstep bump preserves YAML line boundaries around the docs-site hero version', () async {
      final repo = Directory.systemTemp.createTempSync('version_lockstep_contract_');
      addTearDown(() => repo.deleteSync(recursive: true));
      Directory('${repo.path}/tool').createSync();
      Directory('${repo.path}/site').createSync();
      final bin = Directory('${repo.path}/bin')..createSync();
      File('${repo.path}/tool/version_lockstep.sh').writeAsStringSync(readWorkspaceFile('tool/version_lockstep.sh'));
      final fakeDart = File('${bin.path}/dart')..writeAsStringSync('#!/usr/bin/env bash\nexit 0\n');
      expect((await Process.run('chmod', ['+x', fakeDart.path])).exitCode, 0);
      expect((await Process.run('git', ['init', '--quiet'], workingDirectory: repo.path)).exitCode, 0);

      for (final scalar in <String>[
        'trellis 0.10.2 — one dependency',
        '"trellis 0.10.2 — one dependency"',
        "'trellis 0.10.2 — one dependency'",
      ]) {
        final fixture =
            '''
theme_params:
  terminal_card_lines:
    - prefix: "+"
      text: $scalar
      kind: output
''';
        final config = File('${repo.path}/site/trellis_site.yaml')..writeAsStringSync(fixture);
        final result = await Process.run(
          'bash',
          ['tool/version_lockstep.sh', '9.8.7'],
          workingDirectory: repo.path,
          environment: {...Platform.environment, 'PATH': '${bin.path}:${Platform.environment['PATH']}'},
        );

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect(config.readAsStringSync(), fixture.replaceFirst('0.10.2', '9.8.7'), reason: scalar);
      }
    });

    test('install-snippet pubspec constraints in READMEs and docs track the lockstep version', () {
      // Melos rewrites the real pubspecs but not the `trellis*: ^x.y.z` lines in the install
      // snippets of READMEs and docs pages. Those sat at `^0.1.0` until 0.11.1 — a range no
      // published satellite matches (they start at 0.8.1) — so a copied snippet failed
      // `dart pub get`. Exact `^<lockstep>` rather than "admits": that is the shape
      // version_lockstep.sh maintains, and a merely-admitting `^0.11.0` at 0.11.1 would
      // already mean the rewrite was skipped or broken. Same file set as the script's
      // snippet_files() and release.sh's allow-list.
      final lockstep = _pubspecVersion(readWorkspaceFile('packages/trellis/pubspec.yaml'));
      final constraintLine = RegExp(r'^[ \t]+(trellis\w*):[ \t]*(\S+)[ \t]*$', multiLine: true);

      var found = 0;
      for (final path in _installSnippetFiles(workspaceRoot)) {
        for (final match in constraintLine.allMatches(File(path).readAsStringSync())) {
          found++;
          final (package, constraint) = (match.group(1)!, match.group(2)!);
          expect(
            constraint,
            '^$lockstep',
            reason: '$path: `$package: $constraint` is a stale install snippet; run tool/version_lockstep.sh',
          );
        }
      }
      expect(found, greaterThan(0), reason: 'no install-snippet constraint line found; regex or docs drift');
    });

    test('lockstep bump rewrites only the install-snippet constraint lines and permits those files', () async {
      final bumpScript = readWorkspaceFile('tool/version_lockstep.sh');
      final releaseScript = readWorkspaceFile('tool/release.sh');
      expect(bumpScript, contains(r's/^([ \t]+trellis\w*: \^)[0-9][0-9A-Za-z.+-]*$/$1$ENV{VERSION}/'));
      expect(releaseScript, contains('README.md | packages/*/README.md | docs/*.md | site/content/*.md |'));

      final repo = Directory.systemTemp.createTempSync('version_lockstep_snippets_');
      addTearDown(() => repo.deleteSync(recursive: true));
      for (final dir in ['tool', 'site', 'docs/guides', 'packages/trellis_x']) {
        Directory('${repo.path}/$dir').createSync(recursive: true);
      }
      final bin = Directory('${repo.path}/bin')..createSync();
      File('${repo.path}/tool/version_lockstep.sh').writeAsStringSync(bumpScript);
      final fakeDart = File('${bin.path}/dart')..writeAsStringSync('#!/usr/bin/env bash\nexit 0\n');
      expect((await Process.run('chmod', ['+x', fakeDart.path])).exitCode, 0);
      expect((await Process.run('git', ['init', '--quiet'], workingDirectory: repo.path)).exitCode, 0);
      // The hero sync exits non-zero unless it rewrites exactly one line, so the fixture needs one.
      File('${repo.path}/site/trellis_site.yaml').writeAsStringSync('      text: trellis 0.10.2 — one dependency\n');

      // Prose mentioning a constraint inline, a config key that is not a dependency, and a
      // non-trellis dependency must all survive untouched; only the indented pubspec lines move.
      const snippet = '''
Requires `trellis: ^0.1.0` or later.

```yaml
dependencies:
  trellis: ^0.8.0
  trellis_x: ^0.1.0
  shelf: ^1.4.0
trellis_x:
  theme: default
```
''';
      final expected = snippet
          .replaceFirst('  trellis: ^0.8.0', '  trellis: ^9.8.7')
          .replaceFirst('  trellis_x: ^0.1.0', '  trellis_x: ^9.8.7');
      final fixtures = [
        File('${repo.path}/README.md'),
        File('${repo.path}/packages/trellis_x/README.md'),
        File('${repo.path}/docs/guides/install.md'),
      ];
      for (final fixture in fixtures) {
        fixture.writeAsStringSync(snippet);
      }

      final result = await Process.run(
        'bash',
        ['tool/version_lockstep.sh', '9.8.7'],
        workingDirectory: repo.path,
        environment: {...Platform.environment, 'PATH': '${bin.path}:${Platform.environment['PATH']}'},
      );

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      for (final fixture in fixtures) {
        expect(fixture.readAsStringSync(), expected, reason: fixture.path);
      }
    });
  });

  group('--ref pins for tolo/trellis are script-owned', () {
    // The 0.11.1 and 0.12 branches both shipped theme-install pins naming the previous tag
    // because the lockstep script rewrote `trellis*: ^x.y.z` lines but not `--ref v<semver>`.
    // The fixture pins are composed from `$stale` so these test lines are not themselves pins
    // the script would rewrite in this repo.
    test('lockstep bump rewrites every tolo/trellis pin repo-wide and nothing else', () async {
      final repo = _lockstepFixture(workspaceRoot);
      addTearDown(() => repo.parent.deleteSync(recursive: true));
      const thirdParty = 'trellis theme add https://github.com/yourname/trellis-theme-orchard --ref v1.0.0';
      const scpThirdParty = 'trellis theme add git@github.com:acme/t.git --ref v1.0.0';
      const schemelessThirdParty = 'trellis theme add github.com/acme/t --ref v1.0.0';
      const lookAlike = 'trellis theme add https://github.com/tolo/trellis-theme-x --ref v1.0.0';
      const history = '$install --theme lattice --ref $stale';
      const preRelease = '$stale-dev.1';
      final pinned = {
        'README.md': 'Install:\n\n```bash\n$install --theme x --ref $stale\n```\n',
        'docs/guides/theme-usage.md': '$install --theme a --ref $stale\n\nprose\n\n$install --theme b --ref $stale\n',
        'themes/orchard/README.md': '$install --theme orchard --ref $stale\n',
        // A pin ending a sentence keeps its full stop.
        'docs/guides/prose.md': 'Then run $install --theme c --ref $stale.\n',
        // The whole pre-release tag is replaced, not just its X.Y.Z prefix.
        'docs/guides/pre-release.md': '$install --theme d --ref $preRelease\n',
        'docs/guides/two-pins.md': '$install --theme e --ref $stale && $install --theme f --ref $stale\n',
        // Only a third-party source stops the scan: tolo's own links and a bare `git@` in prose do not.
        'docs/guides/tolo-link.md': '$install --theme g # docs at github.com/tolo/trellis/wiki --ref $stale\n',
        'docs/guides/git-at-prose.md': '$install --theme h (or clone via git@ if you prefer) --ref $stale\n',
      };
      final untouched = {
        // The pin scan stops at the next URL or git source, so a third-party pin after a tolo/trellis link keeps
        // its version.
        'docs/guides/mixed.md': 'Built-ins live at https://github.com/tolo/trellis; $thirdParty\n',
        'docs/guides/mixed-scp.md': 'Built-ins live at https://github.com/tolo/trellis; $scpThirdParty\n',
        'docs/guides/mixed-schemeless.md': 'Built-ins live at https://github.com/tolo/trellis; $schemelessThirdParty\n',
        'packages/trellis_x/CHANGELOG.md': '$history\n',
        'dev/state/LEARNINGS.md': 'pinned `--ref $stale` once\n$history\n',
        '.agent_temp/notes.md': '$history\n',
        'docs/guides/third-party.md': '$thirdParty\n$lookAlike\n',
        'docs/guides/no-url.md': 'Pass `--ref $stale` to pick a tag.\n',
      };
      for (final entry in {...pinned, ...untouched}.entries) {
        final file = File('${repo.path}/${entry.key}')..createSync(recursive: true);
        file.writeAsStringSync(entry.value);
      }

      final result = await _bash(repo, ['tool/version_lockstep.sh', '9.8.7']);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      for (final entry in pinned.entries) {
        expect(
          File('${repo.path}/${entry.key}').readAsStringSync(),
          entry.value.replaceAll(preRelease, 'v9.8.7').replaceAll(stale, 'v9.8.7'),
          reason: entry.key,
        );
      }
      for (final entry in untouched.entries) {
        expect(File('${repo.path}/${entry.key}').readAsStringSync(), entry.value, reason: entry.key);
      }
    });

    test('--check-refs names each file and the stale pin, and passes once pins match', () async {
      final repo = _lockstepFixture(workspaceRoot);
      addTearDown(() => repo.parent.deleteSync(recursive: true));
      Directory('${repo.path}/themes/orchard').createSync(recursive: true);
      File('${repo.path}/themes/orchard/README.md').writeAsStringSync('$install --theme orchard --ref $stale\n');
      File('${repo.path}/README.md').writeAsStringSync('$install --theme x --ref v9.8.7\n');

      final stalePins = await _bash(repo, ['tool/version_lockstep.sh', '--check-refs', '9.8.7']);
      expect(stalePins.exitCode, isNot(0));
      final message = '${stalePins.stdout}${stalePins.stderr}';
      expect(message, contains('themes/orchard/README.md'));
      expect(message, contains(stale));
      expect(message, contains('9.8.7'));
      expect(message, isNot(contains('README.md:1: --ref v9.8.7')), reason: 'a matching pin must not be reported');

      File('${repo.path}/themes/orchard/README.md').writeAsStringSync('$install --theme orchard --ref v9.8.7\n');
      final matching = await _bash(repo, ['tool/version_lockstep.sh', '--check-refs', '9.8.7']);
      expect(matching.exitCode, 0, reason: '${matching.stdout}${matching.stderr}');
    });

    test('the repo itself carries pins the scan can see', () async {
      // A regex that drifted from the docs' shape would make rewrite and check vacuous at once.
      final result = await Process.run('bash', [
        'tool/version_lockstep.sh',
        '--list-ref-files',
      ], workingDirectory: workspaceRoot.path);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      final files = (result.stdout as String).trim().split('\n');
      expect(files, contains('docs/guides/theme-usage.md'));
      expect(files, contains('themes/lattice/README.md'));
      expect(files.where((f) => f.contains('CHANGELOG') || f.contains('LEARNINGS')), isEmpty);
      expect(files, isNot(contains('LICENSE')), reason: 'a file without a pin must not be listed');
      final pin = RegExp(r'github\.com/tolo/trellis\s[^\n]*--ref v\d');
      for (final file in files) {
        expect(
          pin.hasMatch(File('${workspaceRoot.path}/$file').readAsStringSync()),
          isTrue,
          reason: '$file has no pin',
        );
      }
    });
  });

  group('release.sh guards on changelogs and --ref pins', () {
    // Runs the real release.sh in a throwaway clone with stub dart/melos/gh. The stub lockstep
    // bumps one pubspec and delegates only the --check-refs/--list-ref-files modes to the real
    // script, so a pin that is stale after the "bump" stays stale.
    test('refuses before bumping when a package changelog has no section for the version', () async {
      // The `## X.Y.Z` sections are the release record, and main takes no fix-up commits after the squash.
      final fixture = await _ReleaseFixture.create(workspaceRoot, omitChangelog: 'trellis_css');
      addTearDown(fixture.dispose);

      final result = await fixture.release('9.8.7');

      expect(result.exitCode, isNot(0), reason: '${result.stdout}');
      expect(result.stderr, contains("no '## 9.8.7' section"));
      expect(result.stderr, contains('trellis_css'));
      expect(await fixture.git(['status', '--porcelain']), isEmpty, reason: 'nothing may be bumped');
      expect(await fixture.git(['tag']), isEmpty);
    });

    test('refuses when a tolo/trellis pin still names another version after the bump', () async {
      final fixture = await _ReleaseFixture.create(workspaceRoot, pin: stale);
      addTearDown(fixture.dispose);

      final result = await fixture.release('9.8.7');

      expect(result.exitCode, isNot(0), reason: '${result.stdout}');
      expect(result.stderr, contains('README.md'));
      expect(result.stderr, contains(stale));
      expect(result.stderr, contains('9.8.7'));
      expect(await fixture.git(['tag']), isEmpty);
      expect(await fixture.git(['rev-list', '--count', 'HEAD']), '1', reason: 'no release commit');
    });

    test('commits and tags when every pin names the version', () async {
      final fixture = await _ReleaseFixture.create(workspaceRoot);
      addTearDown(fixture.dispose);

      final result = await fixture.release('9.8.7');

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(await fixture.git(['tag']), 'v9.8.7');
      expect(await fixture.git(['log', '-1', '--pretty=%s']), 'chore(release): trellis SDK 9.8.7');
    });

    test('a pin-holding file outside the fixed allow-list is still a permitted release change', () async {
      // themes/*/README.md holds pins but is not under docs/, site/content/ or packages/.
      final fixture = await _ReleaseFixture.create(workspaceRoot, bumpRewritesThemeReadme: true);
      addTearDown(fixture.dispose);

      final result = await fixture.release('9.8.7');

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(await fixture.git(['show', '--stat', '--format=', 'HEAD']), contains('themes/orchard/README.md'));
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

/// A throwaway git repo holding the real `tool/version_lockstep.sh`, a hero line it requires and a
/// fake `dart` first on PATH (melos is not run). Its parent directory holds the repo and `bin/`.
Directory _lockstepFixture(Directory workspaceRoot) {
  final root = Directory.systemTemp.createTempSync('version_lockstep_refs_');
  final repo = Directory('${root.path}/repo')..createSync();
  for (final dir in ['tool', 'site']) {
    Directory('${repo.path}/$dir').createSync();
  }
  _writeExecutable('${root.path}/bin/dart', '#!/usr/bin/env bash\nexit 0\n');
  _writeExecutable(
    '${repo.path}/tool/version_lockstep.sh',
    File('${workspaceRoot.path}/tool/version_lockstep.sh').readAsStringSync(),
  );
  File('${repo.path}/site/trellis_site.yaml').writeAsStringSync('      text: trellis 0.10.2 — one dependency\n');
  expect(Process.runSync('git', ['init', '--quiet'], workingDirectory: repo.path).exitCode, 0);
  return repo;
}

void _writeExecutable(String path, String content) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsStringSync(content);
  expect(Process.runSync('chmod', ['+x', path]).exitCode, 0);
}

/// Runs `bash <args>` in [repo] with `<repo>/../bin` first on PATH (fake dart, melos, gh).
Future<ProcessResult> _bash(Directory repo, List<String> args) => Process.run(
  'bash',
  args,
  workingDirectory: repo.path,
  environment: {...Platform.environment, 'PATH': '${repo.parent.path}/bin:${Platform.environment['PATH']}'},
);

/// A clone of a bare origin on `main` with all 8 package changelogs at `## 9.8.7`, the real
/// `tool/release.sh`, and stub `version_lockstep.sh` / `require_green_ci.sh` / dart / melos / gh,
/// so release.sh can run end to end without a network or a real bump.
class _ReleaseFixture {
  _ReleaseFixture._(this.root);

  static const _packages = [
    'trellis',
    'trellis_shelf',
    'trellis_dev',
    'trellis_cli',
    'trellis_css',
    'trellis_site',
    'trellis_dart_frog',
    'trellis_relic',
  ];

  final Directory root;
  Directory get repo => Directory('${root.path}/repo');

  /// [pin] is the `--ref` tag in the root README, [bumpRewritesThemeReadme] makes the stub
  /// bump rewrite a stale pin in `themes/orchard/README.md`, and [omitChangelog] names a package
  /// whose changelog lacks the `## 9.8.7` section.
  static Future<_ReleaseFixture> create(
    Directory workspaceRoot, {
    String pin = 'v9.8.7',
    bool bumpRewritesThemeReadme = false,
    String? omitChangelog,
  }) async {
    final root = Directory.systemTemp.createTempSync('release_guard_');
    final fixture = _ReleaseFixture._(root);
    final repo = fixture.repo..createSync();
    String real(String path) => File('${workspaceRoot.path}/$path').readAsStringSync();

    for (final tool in ['dart', 'melos', 'gh']) {
      _writeExecutable('${root.path}/bin/$tool', '#!/usr/bin/env bash\nexit 0\n');
    }
    _writeExecutable('${repo.path}/tool/release.sh', real('tool/release.sh'));
    _writeExecutable('${repo.path}/tool/real_lockstep.sh', real('tool/version_lockstep.sh'));
    _writeExecutable('${repo.path}/tool/require_green_ci.sh', '#!/usr/bin/env bash\nexit 0\n');
    _writeExecutable('${repo.path}/tool/version_lockstep.sh', '''
#!/usr/bin/env bash
case "\${1:-}" in --*) exec bash "\$(dirname "\$0")/real_lockstep.sh" "\$@" ;; esac
perl -pi -e "s/^version: .*/version: \$1/" packages/trellis/pubspec.yaml
${bumpRewritesThemeReadme ? r"perl -pi -e 's/--ref v\S+/--ref v9.8.7/' themes/orchard/README.md" : ''}
''');
    for (final pkg in _packages) {
      File('${repo.path}/packages/$pkg/pubspec.yaml')
        ..createSync(recursive: true)
        ..writeAsStringSync('name: $pkg\nversion: 0.0.1\n');
      File(
        '${repo.path}/packages/$pkg/CHANGELOG.md',
      ).writeAsStringSync(pkg == omitChangelog ? '## 9.8.6\n\n- older\n' : '## 9.8.7\n\n- change\n');
    }
    File('${repo.path}/README.md').writeAsStringSync('$install --theme x --ref $pin\n');
    if (bumpRewritesThemeReadme) {
      File('${repo.path}/themes/orchard/README.md')
        ..createSync(recursive: true)
        ..writeAsStringSync('$install --theme orchard --ref $stale\n');
    }

    await fixture.run('git', ['init', '--quiet', '--bare', '${root.path}/origin.git'], cwd: root);
    await fixture.git(['init', '--quiet', '-b', 'main']);
    await fixture.git(['config', 'user.name', 'Fixture']);
    await fixture.git(['config', 'user.email', 'fixture@example.invalid']);
    await fixture.git(['config', 'commit.gpgsign', 'false']);
    await fixture.git(['add', '.']);
    await fixture.git(['commit', '--quiet', '-m', 'initial']);
    await fixture.git(['remote', 'add', 'origin', '${root.path}/origin.git']);
    await fixture.git(['push', '--quiet', 'origin', 'main']);
    return fixture;
  }

  void dispose() => root.deleteSync(recursive: true);

  Future<ProcessResult> release(String version) => _bash(repo, ['tool/release.sh', version]);

  Future<String> run(String exe, List<String> args, {Directory? cwd}) async {
    final result = await Process.run(exe, args, workingDirectory: (cwd ?? repo).path);
    expect(result.exitCode, 0, reason: '$exe ${args.join(' ')}: ${result.stderr}');
    return (result.stdout as String).trim();
  }

  Future<String> git(List<String> args) => run('git', args);
}

/// The `version:` of a pubspec, or fails the test.
String _pubspecVersion(String pubspec) {
  final version = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(pubspec)?.group(1);
  expect(version, isNotNull, reason: 'no version: line in pubspec');
  return version!;
}

/// The README and docs pages whose install snippets version_lockstep.sh keeps on the
/// lockstep version: `README.md`, `packages/*/README.md`, every `.md` under `docs/` and
/// `site/content/`. Mirrors the script's `snippet_files()` and release.sh's allow-list.
Iterable<String> _installSnippetFiles(Directory root) sync* {
  final rootReadme = File('${root.path}/README.md');
  if (rootReadme.existsSync()) yield rootReadme.path;
  for (final package in Directory('${root.path}/packages').listSync().whereType<Directory>()) {
    final readme = File('${package.path}/README.md');
    if (readme.existsSync()) yield readme.path;
  }
  for (final dir in ['docs', 'site/content']) {
    final directory = Directory('${root.path}/$dir');
    if (!directory.existsSync()) continue;
    yield* directory.listSync(recursive: true).whereType<File>().map((f) => f.path).where((p) => p.endsWith('.md'));
  }
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
