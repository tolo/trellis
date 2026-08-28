@Timeout(Duration(minutes: 5))
// Tagged so a maintainer can drop the slowest tier from a local loop
// (`dart test --exclude-tags=visual`). CI and tool/release.sh run it: baselines
// are committed per platform (`<theme>.macos.json`, `<theme>.linux.json`), so
// there is no host among those two where this suite has nothing to compare
// against and skipping it would be honest.
@Tags(['visual'])
library;

import 'dart:io';

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
/// Baselines are one file per platform (see `tool/visual_baseline.dart`
/// § Portability), so a re-record only rewrites the recording for the OS it ran
/// on. An appearance change therefore has to be re-recorded **on both** macOS
/// and Linux before CI is green again — `.linux.json` is the set CI compares.
///
/// ## Re-recording the Linux set without a Linux machine
///
/// The image mirrors the `check` job: Ubuntu 24.04 (what `ubuntu-latest`
/// resolves to), `google-chrome-stable` from Google's apt repo, and the
/// `DART_SDK` the workflow pins, copied out of the official image. Write it to
/// a scratch path — it is a recording tool, not a shipped artifact:
///
///     FROM --platform=linux/amd64 dart:3.13 AS sdk
///     FROM --platform=linux/amd64 ubuntu:24.04
///     COPY --from=sdk /usr/lib/dart /usr/lib/dart
///     ENV PATH="/usr/lib/dart/bin:${PATH}"
///     RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
///      && curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
///           | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg \
///      && echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] \
///           https://dl.google.com/linux/chrome/deb/ stable main' > /etc/apt/sources.list.d/google-chrome.list \
///      && apt-get update && apt-get install -y --no-install-recommends google-chrome-stable fonts-noto-color-emoji
///
///     docker build --platform linux/amd64 -t trellis-visual-linux <dir with that Dockerfile>
///     rsync -a --exclude .git/ --exclude .dart_tool/ ./ /tmp/trellis-linux/   # writable copy
///     docker run --rm --platform linux/amd64 --shm-size=2g -v /tmp/trellis-linux:/work -w /work \
///       -e UPDATE_VISUAL_BASELINES=1 trellis-visual-linux \
///       bash -lc 'dart pub get && dart test test/visual_baseline_test.dart'
///     cp /tmp/trellis-linux/test/visual_baselines/*.linux.json test/visual_baselines/
///
/// Three of those flags are load-bearing:
///
/// * `linux/amd64` — GitHub's runners are x86_64 and `google-chrome-stable` has
///   no arm64 package, so an arm64 recording would be a different browser.
/// * `--shm-size=2g` — Docker's default 64 MB `/dev/shm` starves Chrome's
///   renderers and the page never fires its load event; it surfaces as a
///   30-second navigation timeout, not as an out-of-memory error.
/// * a writable copy rather than a bind mount of the checkout — the container
///   writes `.dart_tool/` with paths from its own pub cache, which would leave
///   the host checkout unable to resolve `package:test`.
///
/// The recording is insensitive to the host's font set within the ±4 px
/// tolerance, which is what makes it safe to record here and compare there:
/// adding `fonts-noto-color-emoji` leaves it byte-identical, and adding 200 more
/// families moves only the `font-family: monospace` code block, by 2 px.
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
