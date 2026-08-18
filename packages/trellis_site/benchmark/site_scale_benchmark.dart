/// Scale benchmark for the two `trellis_site` hot paths flagged in the tech-debt
/// backlog as "do not optimize without a benchmark" (TD-007, TD-008).
///
/// Both suspects funnel through `orderedSectionPages`, which re-filters and
/// re-sorts the full page list on every call:
///
///   * TD-007 – `_resolvePrevNext` calls it once per rendered single page, so
///     rendering a section of k pages sorts the whole n-page set k times.
///   * TD-008 – `NavigationBuilder._buildLevel` calls it once per section node
///     and rescans the eligible list at every recursion level.
///
/// The question is not "how fast is it" but "how does it *grow*". A quadratic
/// path doubles its per-page cost when the site doubles; a linear one holds
/// steady. So this drives each hot path at several site sizes and reports the
/// growth ratio between adjacent sizes alongside the raw timings. Compare the
/// result against the docs-site PRD NFR – full build < 5 s for 50–100 pages,
/// > 2× regression from baseline is a defect – and the 1000-page stress point
/// the TD entries name.
///
/// Pages are built in memory (`Page` needs no disk), so this measures exactly
/// the two functions and nothing else – no Markdown, no templating, no I/O.
///
/// Usage, from `packages/trellis_site`:
///
///     dart run benchmark/site_scale_benchmark.dart
///     dart run benchmark/site_scale_benchmark.dart --sizes=100,1000,4000
///
/// Not part of `dart test`; run it by hand when touching either code path.
library;

import 'dart:io';
import 'dart:math';

import 'package:trellis_site/src/navigation_builder.dart';
import 'package:trellis_site/src/page.dart';
import 'package:trellis_site/src/page_generator.dart';

/// Site sizes to sweep when `--sizes` is not given. Each step roughly doubles,
/// so a linear path shows a ~2× ratio and a quadratic one ~4×.
const _defaultSizes = [100, 250, 500, 1000, 2000];

/// Wall-clock repetitions per measurement; the minimum is reported to strip
/// GC and scheduling noise.
const _repetitions = 5;

/// Fixed seed so two runs on the same code produce the same page set.
const _seed = 20260817;

Future<void> main(List<String> args) async {
  final sizes = _parseSizes(args) ?? _defaultSizes;

  stdout.writeln('trellis_site scale benchmark');
  stdout.writeln('sizes: $sizes  repetitions: $_repetitions (min reported)');
  stdout.writeln();

  _run(
    label: 'TD-007  orderedSectionPages × every single page (prev/next resolution)',
    sizes: sizes,
    body: (pages) {
      // Mirrors what generateAll does: resolve neighbours for every single page.
      // Loop overhead is negligible next to the sort inside orderedSectionPages.
      var touched = 0;
      for (final page in pages) {
        if (page.kind != PageKind.single) continue;
        touched += orderedSectionPages(page.sectionPath, pages).length;
      }
      return touched;
    },
  );

  _run(
    label: 'TD-008  NavigationBuilder.build (menu tree)',
    sizes: sizes,
    body: (pages) => const NavigationBuilder().build(pages).length,
  );

  // The quadratic term in TD-007 is per section (k pages in the section × n
  // pages sorted per call), so an evenly-spread site hides it. A flat blog
  // with every post in one section is both realistic and the worst case –
  // include it so the number that actually breaches the NFR is on record.
  _run(
    label: 'TD-007  worst case – every page in ONE section (flat blog)',
    sizes: sizes,
    site: _flatSite,
    body: (pages) {
      var touched = 0;
      for (final page in pages) {
        touched += orderedSectionPages(page.sectionPath, pages).length;
      }
      return touched;
    },
  );

  // The three cases above drive the *unmemoized* primitive, which is what
  // shows the growth shape. This one drives the real `generateAll` path on the
  // same flat blog, so the effect of the per-pass memo in `_resolvePrevNext`
  // is measured where it lives. Includes rendering and writing every page, so
  // it is an absolute build number, not a primitive cost – compare it with the
  // worst-case row of the same size above.
  await _runGenerateAll(label: 'TD-007  full generateAll – flat blog, memoized prev/next', sizes: sizes);
}

/// Times a full [PageGenerator.generateAll] over a flat blog of each size,
/// using a minimal layout that still triggers prev/next resolution.
Future<void> _runGenerateAll({required String label, required List<int> sizes}) async {
  stdout.writeln(label);
  stdout.writeln('  ${'pages'.padLeft(6)}  ${'min ms'.padLeft(9)}  ${'µs/page'.padLeft(9)}');
  stdout.writeln('  ${'-' * 6}  ${'-' * 9}  ${'-' * 9}');

  final site = Directory.systemTemp.createTempSync('trellis_bench_');
  try {
    final layouts = Directory('${site.path}/layouts/_default')..createSync(recursive: true);
    File('${layouts.path}/single.html').writeAsStringSync(
      '<a tl:if="\${page.prev}" tl:href="\${page.prev.url}">p</a>'
      '<a tl:if="\${page.next}" tl:href="\${page.next.url}">n</a>',
    );
    File('${layouts.path}/list.html').writeAsStringSync('<ul></ul>');

    for (final size in sizes) {
      final pages = [
        Page(
          sourcePath: 'blog/_index.md',
          url: '/blog/',
          section: 'blog',
          sectionPath: 'blog',
          kind: PageKind.section,
          isDraft: false,
          isBundle: false,
          bundleAssets: const [],
          frontMatter: const {'title': 'Blog'},
        ),
        ..._flatSite(size),
      ];
      final generator = PageGenerator(siteDir: site.path, outputDir: '${site.path}/out');
      await generator.generateAll(pages); // warm

      var best = 1 << 62;
      for (var i = 0; i < _repetitions; i++) {
        final sw = Stopwatch()..start();
        await generator.generateAll(pages);
        sw.stop();
        best = min(best, sw.elapsedMicroseconds);
      }
      stdout.writeln(
        '  ${size.toString().padLeft(6)}  '
        '${(best / 1000).toStringAsFixed(2).padLeft(9)}  '
        '${(best / size).toStringAsFixed(1).padLeft(9)}',
      );
    }
  } finally {
    site.deleteSync(recursive: true);
  }
  stdout.writeln();
}

/// Runs [body] against a synthetic site of each size in [sizes] and prints a
/// table of min wall time, time per page, and growth ratio vs. the previous size.
///
/// [site] builds the page set for a given size; defaults to the nested docs
/// shape ([_syntheticSite]).
void _run({
  required String label,
  required List<int> sizes,
  required int Function(List<Page> pages) body,
  List<Page> Function(int pageCount) site = _syntheticSite,
}) {
  stdout.writeln(label);
  stdout.writeln(
    '  ${'pages'.padLeft(6)}  ${'min ms'.padLeft(9)}  ${'µs/page'.padLeft(9)}  ${'growth'.padLeft(7)}  ratio/size',
  );
  stdout.writeln('  ${'-' * 6}  ${'-' * 9}  ${'-' * 9}  ${'-' * 7}  ----------');

  int? previousMicros;
  int? previousSize;

  for (final size in sizes) {
    final pages = site(size);

    // Warm up once so JIT and allocation patterns settle before timing.
    body(pages);

    var best = 1 << 62;
    var checksum = 0;
    for (var i = 0; i < _repetitions; i++) {
      final sw = Stopwatch()..start();
      checksum = body(pages);
      sw.stop();
      best = min(best, sw.elapsedMicroseconds);
    }
    // Keep the result observable so the work is not dead-code eliminated.
    if (checksum < 0) stdout.writeln('unreachable');

    final perPage = best / size;
    final growth = previousMicros == null ? '—' : '${(best / previousMicros).toStringAsFixed(2)}×';
    final sizeRatio = previousSize == null ? '—' : '${(size / previousSize).toStringAsFixed(2)}×';

    stdout.writeln(
      '  ${size.toString().padLeft(6)}  '
      '${(best / 1000).toStringAsFixed(2).padLeft(9)}  '
      '${perPage.toStringAsFixed(1).padLeft(9)}  '
      '${growth.padLeft(7)}  '
      '$sizeRatio',
    );

    previousMicros = best;
    previousSize = size;
  }
  stdout.writeln();
}

/// Builds a page set shaped like a real docs site: a handful of top-level
/// sections, each with nested sub-sections two levels deep, and single pages
/// spread across every level. Roughly a third of pages carry a `weight` so the
/// weight-aware comparator's mixed branch is exercised, not just the
/// date-desc fallback.
List<Page> _syntheticSite(int pageCount) {
  final rng = Random(_seed);
  final pages = <Page>[];

  // Section skeleton: 6 top-level sections × 4 sub-sections × 3 leaf sections.
  // Each gets an `_index.md` (section page) so NavigationBuilder has real
  // section nodes to weight and recurse into.
  final sectionPaths = <String>[];
  for (var a = 0; a < 6; a++) {
    final top = 'sec$a';
    sectionPaths.add(top);
    for (var b = 0; b < 4; b++) {
      final mid = '$top/sub$b';
      sectionPaths.add(mid);
      for (var c = 0; c < 3; c++) {
        sectionPaths.add('$mid/leaf$c');
      }
    }
  }
  for (final sp in sectionPaths) {
    pages.add(
      Page(
        sourcePath: '$sp/_index.md',
        url: '/$sp/',
        section: sp.split('/').first,
        sectionPath: sp,
        kind: PageKind.section,
        isDraft: false,
        isBundle: false,
        bundleAssets: const [],
        frontMatter: {'title': sp, if (rng.nextInt(3) == 0) 'weight': rng.nextInt(50)},
      ),
    );
  }

  // Single pages spread evenly across all sections, with a spread of dates so
  // the date-desc branch has real work to do.
  final base = DateTime(2024, 1, 1);
  for (var i = 0; i < pageCount; i++) {
    final sp = sectionPaths[i % sectionPaths.length];
    pages.add(
      Page(
        sourcePath: '$sp/page$i.md',
        url: '/$sp/page$i/',
        section: sp.split('/').first,
        sectionPath: sp,
        kind: PageKind.single,
        isDraft: false,
        isBundle: false,
        bundleAssets: const [],
        frontMatter: {
          'title': 'Page $i',
          'date': base.add(Duration(days: rng.nextInt(700))).toIso8601String(),
          if (rng.nextInt(3) == 0) 'weight': rng.nextInt(50),
        },
      ),
    );
  }

  return pages;
}

/// Every page in a single `blog` section – the flat-blog shape that maximises
/// TD-007's per-section quadratic term.
List<Page> _flatSite(int pageCount) {
  final rng = Random(_seed);
  final base = DateTime(2024, 1, 1);
  return [
    for (var i = 0; i < pageCount; i++)
      Page(
        sourcePath: 'blog/post$i.md',
        url: '/blog/post$i/',
        section: 'blog',
        sectionPath: 'blog',
        kind: PageKind.single,
        isDraft: false,
        isBundle: false,
        bundleAssets: const [],
        frontMatter: {
          'title': 'Post $i',
          'date': base.add(Duration(days: rng.nextInt(700))).toIso8601String(),
        },
      ),
  ];
}

List<int>? _parseSizes(List<String> args) {
  for (final arg in args) {
    if (arg.startsWith('--sizes=')) {
      return arg.substring('--sizes='.length).split(',').map((s) => int.parse(s.trim())).toList();
    }
  }
  return null;
}
