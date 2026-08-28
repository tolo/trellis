/// The horizontal-overflow (WCAG 1.4.10 reflow) sweep, shared by every suite
/// that holds a built site to it.
///
/// Two suites do: `theme_contract_test.dart` over each bundled theme's built
/// example, and `site_reflow_test.dart` over the built docs site. The widths and
/// the pass criterion live here rather than in either of them because a copy is
/// how the two bars drift apart — and they already had: the docs site reached a
/// release overflowing a 320px viewport on its flagship page while the theme
/// sweep was green, because nothing swept `site/` at all (TD-039).
///
/// `browser_reflow_probe.dart` stays assertion-free — it is the transport. This
/// is the assertion built on top of it.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import 'browser_reflow_probe.dart';

/// Viewports every layout is swept at regardless of its own breakpoints.
///
/// Unbreakable-token overflow is a narrow-viewport failure: at wide widths a
/// long token fits its track and the measurement cannot discriminate.
const narrowViewports = {320: 568, 375: 667, 390: 844};

/// Every HTML page under [servedRoot], as origin-relative paths.
List<String> builtPages(String servedRoot) =>
    Directory(servedRoot)
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.html'))
        .map((file) => p.relative(file.path, from: servedRoot))
        .toList()
      ..sort();

/// One page per layout shape, without needing to know the layout names: the
/// landing page, the most deeply nested page (a docs or post page), and the
/// largest page (the one with the most components on it).
///
/// The landing page is the shallowest `index.html` rather than literally
/// `index.html`, because a path-prefixed site's home lives one directory down
/// inside the served tree.
List<String> representativePages(String servedRoot) {
  final pages = builtPages(servedRoot);
  if (pages.isEmpty) return pages;
  final deepest = pages.reduce((a, b) => p.split(b).length > p.split(a).length ? b : a);
  final largest = pages.reduce(
    (a, b) => File(p.join(servedRoot, b)).lengthSync() > File(p.join(servedRoot, a)).lengthSync() ? b : a,
  );
  final indexes = pages.where((page) => p.basename(page) == 'index.html');
  final landing = indexes.isEmpty
      ? pages.first
      : indexes.reduce((a, b) => p.split(b).length < p.split(a).length ? b : a);
  return {landing, deepest, largest}.toList();
}

/// Widths just inside the wide side of each layout switch [stylesheets] declare.
///
/// A layout is tightest at the first width where its multi-column form is back
/// and the content has the least room — that band is where a flex row that no
/// longer fits shows up (Meadow's footer overflowed 6px in exactly one). Derived
/// from the compiled sheets themselves, so a breakpoint added later is swept
/// with no list here to update.
///
/// Both directions matter and reading only one is a silent hole: Folio and
/// Meadow write `max-width` (narrow rules stop above N, so the band starts at
/// N+1) while Arbor, Bloom and Verdant are mobile-first `min-width` (wide rules
/// start at exactly N). A `max-width`-only reading returns nothing at all for
/// the latter three, and their sweep quietly shrinks to the fixed widths.
Set<int> breakpointProbeWidths(Iterable<File> stylesheets) {
  final widths = <int>{};
  for (final sheet in stylesheets) {
    if (!sheet.existsSync()) continue;
    // Comments can contain commas, colons and px values; a selector/query parser
    // that keeps them will confidently match text that styles nothing.
    final source = sheet.readAsStringSync().replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    for (final query in RegExp(r'@media[^{]*').allMatches(source)) {
      for (final match in RegExp(r'(max|min)-width\s*:\s*(\d+)px').allMatches(query[0]!)) {
        final edge = int.parse(match[2]!);
        widths.addAll(match[1] == 'max' ? [edge + 1, edge + 8] : [edge, edge + 8]);
      }
    }
  }
  return widths;
}

Uri pageUrl(Uri base, String page) => base.replace(path: '/${page.replaceFirst(RegExp(r'index\.html$'), '')}');

/// Assert no page in [pages] pushes the document past the viewport at any of
/// [viewports], in either color scheme.
///
/// [servedRoot] is the directory published as the origin root, which is not
/// always the build output: a path-prefixed build emits `/prefix/…` URLs while
/// writing files at unprefixed disk paths, so it only resolves when the output
/// sits *under* that prefix inside the served tree.
///
/// One navigation per page: re-applying device metrics and emulated media on the
/// live document re-runs layout, so the sweep costs a page load per page rather
/// than per combination.
Future<void> expectNoOverflow(
  BrowserProbe browser, {
  required String servedRoot,
  required List<String> pages,
  required Map<int, int> viewports,
  required String label,
}) async {
  // The offender list is the whole diagnostic value of a failure read from CI
  // output, so it is filtered and ranked rather than reported in document order.
  // Unfiltered and unranked it names whatever overhangs first in the DOM — for
  // the docs site that is the decorative `<svg>` lattice, whose parent clips it
  // and which cannot widen the document at all, while the grid track that
  // actually did is pushed past the fifth slot. Two rules: an element under a
  // clipping or fixed-position ancestor contributes nothing to `scrollWidth`,
  // and the biggest overhang is the likeliest cause. The filter falls back to
  // the unfiltered list rather than reporting nothing, since a wrong heuristic
  // must not cost the failure its evidence.
  const expression = '''(() => {
    const root = document.documentElement;
    const contributes = (element) => {
      for (let node = element; node !== null && node !== root; node = node.parentElement) {
        const style = getComputedStyle(node);
        if (style.position === 'fixed') return false;
        if (node !== element && style.overflowX !== 'visible') return false;
      }
      return true;
    };
    const selectorOf = (element) => {
      const classes = typeof element.className === 'string' ? element.className.trim() : '';
      return element.tagName.toLowerCase() + (classes ? '.' + classes.split(/\\s+/).join('.') : '');
    };
    // Keyed by selector, worst box per key: a grid of eight identical cards is
    // one defect, and reporting it eight times spends every slot on one of them.
    const all = new Map();
    const contributing = new Map();
    const record = (into, key, entry) => {
      const worst = into.get(key);
      if (worst === undefined || entry.overhang > worst.overhang) into.set(key, entry);
    };
    if (root.scrollWidth > root.clientWidth) {
      for (const element of document.querySelectorAll('*')) {
        const box = element.getBoundingClientRect();
        if (box.width === 0) continue;
        const overhang = Math.max(box.right - root.clientWidth, -box.left);
        if (overhang <= 0.5) continue;
        const key = selectorOf(element);
        const entry = {
          overhang,
          text: key + ' [' + Math.round(box.left) + '..' + Math.round(box.right) + '] +' +
            Math.round(overhang) + 'px',
        };
        record(all, key, entry);
        if (contributes(element)) record(contributing, key, entry);
      }
    }
    const ranked = [...(contributing.size > 0 ? contributing : all).values()]
      .sort((a, b) => b.overhang - a.overhang);
    return {
      scrollWidth: root.scrollWidth,
      clientWidth: root.clientWidth,
      offenders: ranked.slice(0, 5).map((entry) => entry.text),
    };
  })()''';

  final server = await StaticSiteServer.serve(Directory(servedRoot));
  try {
    for (final page in pages) {
      final url = pageUrl(server.baseUrl, page);
      var navigated = false;
      for (final viewport in viewports.entries) {
        for (final scheme in const ['light', 'dark']) {
          final measured =
              (navigated
                      ? await browser.evaluateHere(
                          expression,
                          width: viewport.key,
                          height: viewport.value,
                          colorScheme: scheme,
                        )
                      : await browser.evaluate(
                          url,
                          expression,
                          width: viewport.key,
                          height: viewport.value,
                          colorScheme: scheme,
                        ))!
                  as Map;
          navigated = true;
          expect(
            measured['scrollWidth'],
            measured['clientWidth'],
            reason:
                '$label $page at ${viewport.key}px ($scheme): document is '
                '${(measured['scrollWidth'] as int) - (measured['clientWidth'] as int)}px wider than the '
                'viewport. Widest boxes: ${measured['offenders']}',
          );
        }
      }
    }
  } finally {
    await server.close();
  }
}
