@Timeout(Duration(minutes: 5))
// Tagged so CI and a maintainer's local loop can exclude this host-specific
// tier. tool/release.sh is its required executor and enables CI guards so a
// missing browser or baseline fails the release instead of skipping.
@Tags(['visual'])
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../tool/visual_baseline.dart';
import 'browser_reflow_probe.dart';

/// Compares every bundled theme example against its recorded appearance.
///
/// Rationale, storage format and comparison rules are documented in
/// `tool/visual_baseline.dart`. This file is the wiring: it owns the browser,
/// the scratch tree, and the update-versus-check decision.
///
/// ## Updating a baseline on purpose
///
///     UPDATE_VISUAL_BASELINES=1 dart test test/visual_baseline_test.dart
///     git diff test/visual_baselines/            # read what moved
///
/// Scope a re-record with `VISUAL_BASELINE_THEMES=folio,meadow`.
///
/// The committed baselines are recorded on macOS, where the release gate runs.
/// They encode browser and system-font metrics, so CI deliberately excludes the
/// `visual` tag rather than comparing them on a drifting Linux runner image.
///
/// **How CI tells an intended change from a regression:** it cannot be told at
/// runtime, and does not try. CI never sets `UPDATE_VISUAL_BASELINES`, so the
/// only way a new appearance reaches `main` is as a committed diff under
/// `test/visual_baselines/` that a human read — the same rail as any other
/// change. A regression is a red check; an approved redesign is a reviewed
/// diff. Two guards keep that rail honest:
///
/// * update mode refuses to run when `CI=true`, so it cannot be switched on in
///   a workflow to make a failure disappear;
/// * update mode exits non-zero whenever it rewrote anything, so it cannot be
///   mistaken for a passing run in a script.
void main() {
  final repoRoot = Directory.current.path;
  final update = Platform.environment['UPDATE_VISUAL_BASELINES'] == '1';
  final only = Platform.environment['VISUAL_BASELINE_THEMES']
      ?.split(',')
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty)
      .toSet();

  test('every visual baseline belongs to a bundled theme', () {
    final themes = discoverThemeExamples(repoRoot).map((example) => example.name).toSet();
    final orphans =
        Directory(p.join(repoRoot, 'test', 'visual_baselines'))
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.json'))
            .map((file) => p.basename(file.path).split('.').first)
            .where((name) => !themes.contains(name))
            .toList()
          ..sort();
    expect(orphans, isEmpty, reason: 'baseline files for themes that no longer exist');
  });

  if (update && Platform.environment['CI'] == 'true') {
    test('visual baselines are not re-recorded in CI', () {
      fail(
        'UPDATE_VISUAL_BASELINES is set in CI. Re-recording there would turn every '
        'rendering regression into a silently accepted new baseline.',
      );
    });
    return;
  }

  if (BrowserProbe.locateChrome() == null) {
    test('theme appearance matches the recorded baselines', () {
      requireChromeInCi('the visual baseline comparator');
      markTestSkipped('no Chrome/Chromium found - visual baseline comparator skipped');
    });
    return;
  }

  late BrowserProbe probe;
  late Directory scratch;
  late _ProbeRenderHost host;

  setUpAll(() async {
    probe = await BrowserProbe.launch();
    // Outside the repository on purpose: a build that resolves through a
    // scratch tree into `themes/` or `site/` overwrites the real thing.
    scratch = Directory.systemTemp.createTempSync('trellis_visual_baseline_');
    host = _ProbeRenderHost(probe);
  });

  tearDownAll(() async {
    await host.dispose();
    await probe.close();
    if (scratch.existsSync()) scratch.deleteSync(recursive: true);
  });

  for (final example in discoverThemeExamples(Directory.current.path)) {
    if (only != null && !only.contains(example.name)) continue;
    test('${example.name} renders as recorded at ${viewportWidths.join('/')}px in light and dark', () async {
      final run = await runVisualBaselines(
        repoRoot: repoRoot,
        host: host,
        scratch: scratch,
        update: update,
        onlyThemes: {example.name},
      );
      // A run that measured nothing must not read as a pass: assert the matrix
      // was actually walked before believing its verdict.
      expect(run.pageCount, greaterThan(0), reason: '${example.name} rendered no pages');
      expect(
        run.captureCount,
        run.pageCount * viewportWidths.length * colorSchemes.length + run.scannedPageCount * viewportWidths.length,
        reason: 'capture matrix is incomplete',
      );
      if (update) {
        // The clipped-content sweep is an invariant, not a comparison, so
        // re-recording must not launder it: a box that hides its own content is
        // a defect in both modes.
        expect(run.differences, isEmpty, reason: run.describe());
        expect(
          run.rewritten,
          isEmpty,
          reason:
              'Re-recorded ${run.rewritten.join(', ')} from ${run.captureCount} captures on Chrome ${run.chrome}. '
              'Review the diff and commit it; this run fails by design so a re-record is never read as a pass.',
        );
        return;
      }
      expect(run.isClean, isTrue, reason: run.describe());
    });
  }
}

/// [RenderHost] over the shared CDP client.
class _ProbeRenderHost implements RenderHost {
  _ProbeRenderHost(this._probe);

  final BrowserProbe _probe;
  final _servers = <StaticSiteServer>[];

  @override
  Future<Uri> serve(Directory root) async {
    final server = await StaticSiteServer.serve(root);
    _servers.add(server);
    return server.baseUrl;
  }

  @override
  Future<Object?> evaluate(
    Uri url,
    String expression, {
    required int width,
    required int height,
    required String colorScheme,
  }) => _probe.evaluate(url, expression, width: width, height: height, colorScheme: colorScheme);

  @override
  Future<void> dispose() async {
    for (final server in _servers) {
      await server.close();
    }
    _servers.clear();
  }
}
