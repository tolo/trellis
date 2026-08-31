/// Rendered-appearance comparator for the bundled theme examples.
///
/// Every theme in `themes/` ships an `example/` site that is the theme's public
/// face — the gallery links it, the screenshots come from it, and the 0.11
/// acceptance scenarios were written against it. Until this file existed those
/// scenarios were checked by hand once: the release-gate review re-ran 11
/// mutations of shipped defects against the suite and 8 survived, because every
/// check asserted the *shape of an artifact* (a class is present, a file is
/// under N bytes) rather than what a browser draws.
///
/// This is the appearance half of that gap. The reflow half — the
/// `documentElement.scrollWidth == clientWidth` sweep — lives with the theme
/// contract suite and shares `test/browser_reflow_probe.dart` with this file.
///
/// ## What gets stored, and why it is not pixels
///
/// A baseline here is a **digest**: for every rendered box on the page, its
/// geometry plus the computed style values that decide what it looks like.
/// Not a PNG. Three reasons, in order of how much they cost us in practice:
///
/// 1. **A luminance pixel diff is blind to the defects this repo ships.** An
///    earlier attempt at a screenshot diff on this branch found ~60% of the
///    differing pixels were glyph-edge antialiasing between two capture
///    environments, while the one genuinely changed region was lime-on-paper —
///    both light, so a luminance hard-flip test scored the noise and missed the
///    change. Computed colour values have no antialiasing: `rgb(212, 241, 95)`
///    either is or is not what the baseline recorded.
/// 2. **A digest says what changed.** `PNG differs at 12,431 pixels` sends a
///    maintainer back to the browser. `body/main0/section1 height 625 -> 830`
///    is the finding. That matters most in the workflow this file exists to
///    support: approving an intentional redesign.
/// 3. **Size.** A full-page 1440px PNG of these examples is 1–2 MB. The digest
///    for the same page is ~15 KB, and it is text, so git stores a delta and a
///    reviewer reads the diff.
///
/// The trade is real and worth naming: a digest cannot see a change that leaves
/// every box and every computed value where it was — a swapped image file with
/// identical dimensions, or a font whose glyphs changed but whose metrics did
/// not. Those belong to the font-integrity and gallery-asset checks, which
/// already hash the bytes.
///
/// ## Comparison rules
///
/// * **Geometry** — compared with a flat ±[boxTolerance] px band per component.
///   The band absorbs sub-pixel rounding, not font substitution: the examples
///   self-host every face as woff2, so metrics come from the file rather than
///   the OS and layout is stable across machines running the same Chrome.
/// * **Computed style and pseudo-elements** — compared exactly. These are CSS
///   resolution results; they do not vary by machine, and they are where a
///   theme's appearance actually lives.
/// * **Overflow** (`scrollWidth - clientWidth` and the vertical twin) —
///   compared exactly *and* flagged as an error when non-zero, because an
///   element that cannot contain its own content is a defect whatever the
///   baseline says. That is how a clipped marker band reads.
/// * **Node set** — exact. An inserted or removed box is a difference.
///
/// ## Portability
///
/// A baseline is per operating system: the file is `<theme>.<platform>.json`
/// and a run reads only the one naming its own `Platform.operatingSystem`.
/// Geometry is not portable across systems — the themes self-host their faces,
/// but every font stack ends in a system fallback and the subsets are known to
/// be missing glyphs the layouts render, so any text that falls back measures
/// differently on another OS. Comparing across platforms has two outcomes and
/// both are worse than not comparing: fail on differences nobody introduced, or
/// widen the tolerance until it hides the ones they did. Recorded goldens are
/// platform-pinned everywhere for this reason.
///
/// Splitting the file per platform is what lets one commit be gated on more
/// than one: `macos` is what a maintainer runs locally, `linux` is what CI
/// runs. A platform with no recording is a failure, not a skip — a theme
/// nothing has rendered on this OS is a theme nothing is watching here. The
/// recorded `platform` field is checked against the file name as well, so a
/// hand-copied or hand-edited baseline is caught rather than silently compared.
///
/// Chrome's version is *not* enforced, only recorded: a browser upgrade can
/// legitimately move layout past the tolerance band, and when it does the
/// mismatch is reported alongside the geometry differences so the cause is
/// visible rather than bisected for.
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Per-component tolerance for `x`/`y`/`width`/`height`, in CSS pixels.
///
/// Deliberately tight. Every rendering defect this harness was built for is a
/// two- to four-digit change (a 205 px band of dead space, a disclosure panel
/// pushing content 1250 px down); the band exists for rounding, not for making
/// failures unlikely. Small-but-real regressions — the 6 px footer overflow at
/// 768 px found on this branch — are caught on the overflow axis, which is
/// exact.
const int boxTolerance = 4;

/// Viewport widths captured for every page.
///
/// 390 is the mobile case the 0.11 acceptance scenarios name; 768 is where this
/// codebase empirically breaks flex rows; 1440 is where three of the four
/// confirmed 0.11 rendering defects manifested and is the width no reflow
/// invariant can speak to, because wide-viewport regressions are shape problems
/// (grid collapse, masthead geometry, card alignment) with no overflow.
const List<int> viewportWidths = [390, 768, 1440];

/// Viewport height for every capture.
///
/// The digest measures the full document, not the visible fold, so this only
/// has to be a stable number. It still matters that it *is* stable: viewport
/// height feeds `vh` units, which several themes use for hero and disclosure
/// sizing.
const int viewportHeight = 900;

/// Colour schemes captured for every page and width.
const List<String> colorSchemes = ['light', 'dark'];

/// Pages captured per theme, counting the home page.
///
/// The reflow sweep covers every page of every example at four widths; this
/// comparator is the expensive half, so it takes the home page — where each
/// theme's distinctive design lives — plus the next [pagesPerTheme] - 1 URLs in
/// sorted order, which for the docs themes is the section index and its first
/// child, i.e. the list and single layouts. Raising this is a storage decision,
/// not a correctness one.
const int pagesPerTheme = 3;

/// A theme in `themes/` together with the example site it bundles.
class ThemeExample {
  ThemeExample({required this.name, required this.themeDir, required this.exampleDir});

  final String name;
  final String themeDir;
  final String exampleDir;
}

/// Every theme under `<repoRoot>/themes` that bundles a buildable example.
///
/// Enumerated from disk and sorted, so a seventh theme is covered the moment it
/// lands rather than when someone remembers to add it to a list.
List<ThemeExample> discoverThemeExamples(String repoRoot) {
  final themesDir = Directory(p.join(repoRoot, 'themes'));
  if (!themesDir.existsSync()) {
    throw StateError('no themes/ directory under $repoRoot');
  }
  final examples = <ThemeExample>[];
  for (final entity in themesDir.listSync().whereType<Directory>()) {
    final name = p.basename(entity.path);
    final exampleDir = p.join(entity.path, 'example');
    if (!File(p.join(exampleDir, 'trellis_site.yaml')).existsSync()) continue;
    examples.add(ThemeExample(name: name, themeDir: entity.path, exampleDir: exampleDir));
  }
  examples.sort((a, b) => a.name.compareTo(b.name));
  if (examples.isEmpty) throw StateError('no theme bundles an example site under $repoRoot/themes');
  return examples;
}

/// Copies [example] into [into] and builds it with the shipped CLI.
///
/// The copy is a copy, never a symlink, and [into] must live outside the
/// repository: an agent on this branch symlinked repo-root entries into a
/// scratch tree and the build wrote through the link over the real `site/`.
/// Returns the built `output/` directory.
///
/// The build shells out to `packages/trellis_cli/bin/trellis.dart` rather than
/// calling `TrellisSite.build()` directly because SASS compilation — including
/// the theme-params bridge that decides the palette — lives in the CLI's build
/// command, not in the SSG. Calling the SSG alone produces a site with no
/// `css/main.css`, which renders in Times New Roman and would have made every
/// baseline here a measurement of the browser's default stylesheet.
Future<Directory> buildExample(ThemeExample example, {required Directory into, required String repoRoot}) async {
  final siteDir = Directory(p.join(into.path, example.name))..createSync(recursive: true);
  _copyTree(Directory(example.exampleDir), siteDir, skip: const {'output', '.trellis', '.dart_tool'});
  _copyTree(
    Directory(example.themeDir),
    Directory(p.join(siteDir.path, 'themes', example.name)),
    skip: const {'example'},
  );

  final result = await Process.run(Platform.resolvedExecutable, [
    'run',
    p.join(repoRoot, 'packages', 'trellis_cli', 'bin', 'trellis.dart'),
    'build',
  ], workingDirectory: siteDir.path);
  if (result.exitCode != 0) {
    throw StateError('building the ${example.name} example failed:\n${result.stdout}\n${result.stderr}');
  }
  final output = Directory(p.join(siteDir.path, 'output'));
  if (!File(p.join(output.path, 'css', 'main.css')).existsSync()) {
    throw StateError('the ${example.name} example built without css/main.css — the digest would measure unstyled HTML');
  }
  return output;
}

/// Builds the theme's `example/fixtures/` as a site of their own, or returns
/// null when the theme ships none.
///
/// Fixtures are the deliberately awkward content — long copy, absent optional
/// sections, unbreakable tokens — and they are where the appearance defects
/// this branch shipped actually showed up. Meadow's `copy-long` was found
/// clipped in its *own bundled fixture*: `white-space: nowrap` on the hero
/// marker meeting `overflow: clip` on the hero, rendering "a durable product
/// dire". None of that reaches the example site's own pages, whose copy is
/// short enough to fit.
///
/// Each fixture is a `<name>/_index.md`, so pointing `contentDir` at the
/// fixtures directory turns the set into one page per fixture in a single
/// build. The example site is built separately and left alone: folding
/// fixtures into it would add a section to every navigation and change the
/// baselines of the pages being compared.
Future<Directory?> buildFixtureSite(ThemeExample example, {required Directory into, required String repoRoot}) async {
  if (!Directory(p.join(example.exampleDir, 'fixtures')).existsSync()) return null;
  final siteDir = Directory(p.join(into.path, '${example.name}-fixtures'))..createSync(recursive: true);
  _copyTree(Directory(example.exampleDir), siteDir, skip: const {'output', '.trellis', '.dart_tool'});
  _copyTree(
    Directory(example.themeDir),
    Directory(p.join(siteDir.path, 'themes', example.name)),
    skip: const {'example'},
  );

  final config = File(p.join(siteDir.path, 'trellis_site.yaml'));
  config.writeAsStringSync('${config.readAsStringSync()}\ncontentDir: fixtures\n');

  final result = await Process.run(Platform.resolvedExecutable, [
    'run',
    p.join(repoRoot, 'packages', 'trellis_cli', 'bin', 'trellis.dart'),
    'build',
  ], workingDirectory: siteDir.path);
  if (result.exitCode != 0) {
    throw StateError('building the ${example.name} fixtures failed:\n${result.stdout}\n${result.stderr}');
  }
  return Directory(p.join(siteDir.path, 'output'));
}

/// Every URL path in [output] that resolves to an `index.html`, sorted.
List<String> discoverPages(Directory output) {
  final pages = <String>[];
  for (final file in output.listSync(recursive: true).whereType<File>()) {
    if (p.basename(file.path) != 'index.html') continue;
    final relative = p.relative(p.dirname(file.path), from: output.path);
    pages.add(relative == '.' ? '/' : '/${p.split(relative).join('/')}/');
  }
  pages.sort();
  return pages;
}

/// The [pagesPerTheme] pages this comparator baselines, home first.
List<String> baselinePages(Directory output) {
  final pages = discoverPages(output);
  if (!pages.contains('/')) throw StateError('${output.path} has no home page');
  final rest = pages.where((page) => page != '/').toList();
  return ['/', ...rest.take(pagesPerTheme - 1)];
}

/// The expression evaluated in the page to produce one capture.
///
/// Emits every rendered box in document order. A box is recorded when it
/// generates a non-inline box, or when it carries a `::before`/`::after` with
/// content — decorative bands, rules and grids live on pseudo-elements in these
/// themes, and the Meadow hero marker that clipped its own text on this branch
/// is one of them.
///
/// Style values are recorded only where they carry information: an inherited
/// property appears when it differs from the parent's resolved value, and a
/// non-inherited one when it differs from its initial value. That keeps the
/// record to what the theme actually asserts, and keeps a diff to the nodes a
/// change touched.
///
/// URLs inside computed values (`background-image`, `box-shadow`) are stripped
/// of the server origin, which carries an ephemeral port and would otherwise
/// make every capture unique.
///
/// ## Settling
///
/// The script does not measure once. It freezes transitions and animations,
/// then measures repeatedly until two consecutive measurements are byte-equal,
/// and **throws** if that never happens. This is the difference between a
/// baseline and a coin flip. Three separate races showed up on the first
/// recording of these six themes, and none of them is visible in the CSS:
///
/// * Arbor's docs search input records `opacity: 0.6` or nothing at all,
///   depending on whether `search.js` had finished fetching the index and
///   enabled the field.
/// * Folio's docs page settles 85 px shorter or taller between runs.
/// * Lattice's home page reports 72 px of horizontal overflow at 390 px until
///   the headline-fitting script runs, and none afterwards.
///
/// `document.fonts.ready` — which the probe already awaits — does not cover any
/// of these, because none of them is a font. Measuring to stability does, and
/// failing loudly when the page never stabilises is the point: a harness that
/// silently records whichever frame it landed on is the failure this whole
/// package exists to end.
const String digestScript = r'''
async function () {
  const freeze = document.createElement('style');
  freeze.textContent = '*, *::before, *::after { transition: none !important; animation: none !important; }';
  document.head.appendChild(freeze);

  const origin = location.origin;
  const norm = (v) => (v == null ? '' : String(v).split(origin).join(''));
  const px = (v) => Math.round(v || 0);
  const INHERITED = ['color', 'fontFamily', 'fontSize', 'fontWeight', 'lineHeight', 'whiteSpace',
                     'textAlign', 'letterSpacing', 'textTransform'];
  const DEFAULTS = {
    display: 'block', backgroundColor: 'rgba(0, 0, 0, 0)', backgroundImage: 'none', boxShadow: 'none',
    opacity: '1', overflowX: 'visible', overflowY: 'visible', position: 'static', transform: 'none',
    visibility: 'visible', zIndex: 'auto', borderRadius: '0px', minHeight: '0px', maxHeight: 'none',
    textOverflow: 'clip',
    maxWidth: 'none', flexDirection: 'row', flexWrap: 'nowrap', alignItems: 'normal',
    justifyContent: 'normal', gridTemplateColumns: 'none', gap: 'normal', aspectRatio: 'auto',
    mixBlendMode: 'normal', filter: 'none', clipPath: 'none',
  };
  const PSEUDO = ['backgroundColor', 'backgroundImage', 'color', 'width', 'height', 'inset',
                  'transform', 'opacity', 'borderRadius', 'position'];

  function edges(cs, prefix, suffix) {
    const v = [cs[prefix + 'Top' + suffix], cs[prefix + 'Right' + suffix],
               cs[prefix + 'Bottom' + suffix], cs[prefix + 'Left' + suffix]];
    return v.every((x) => x === v[0]) ? v[0] : v.join(' ');
  }

  function paint(cs, parent) {
    const out = {};
    for (const prop of INHERITED) {
      if (!parent || parent[prop] !== cs[prop]) out[prop] = cs[prop];
    }
    for (const prop in DEFAULTS) {
      const v = norm(cs[prop]);
      if (v !== DEFAULTS[prop]) out[prop] = v;
    }
    const width = edges(cs, 'border', 'Width');
    if (width !== '0px') {
      out.borderWidth = width;
      out.borderColor = edges(cs, 'border', 'Color');
      out.borderStyle = edges(cs, 'border', 'Style');
    }
    return out;
  }

  function pseudo(el, which) {
    const cs = getComputedStyle(el, which);
    if (cs.content === 'none' || cs.display === 'none') return null;
    const out = {content: cs.content};
    for (const prop of PSEUDO) {
      const v = norm(cs[prop]);
      if (v !== DEFAULTS[prop]) out[prop] = v;
    }
    return out;
  }

  function measure() {
    const nodes = [];
    function walk(el, path, parentStyle) {
      const cs = getComputedStyle(el);
      const rect = el.getBoundingClientRect();
      const before = pseudo(el, '::before');
      const after = pseudo(el, '::after');
      const rendered = cs.display !== 'none' && (rect.width > 0 || rect.height > 0);
      const boxy = cs.display !== 'inline' && cs.display !== 'contents';
      if (rendered && (boxy || before || after)) {
        const entry = {k: path, b: [px(rect.x), px(rect.y), px(rect.width), px(rect.height)], s: paint(cs, parentStyle)};
        const cls = (el.getAttribute('class') || '').split(/\s+/).filter(Boolean).sort().join(' ');
        if (cls) entry.c = cls;
        if (el.id) entry.i = el.id;
        const ox = el.scrollWidth - el.clientWidth;
        const oy = el.scrollHeight - el.clientHeight;
        if (ox) entry.ox = ox;
        if (oy) entry.oy = oy;
        if (before) entry.pb = before;
        if (after) entry.pa = after;
        nodes.push(entry);
      }
      let n = 0;
      for (const child of el.children) walk(child, path + '/' + child.tagName.toLowerCase() + n++, cs);
    }
    walk(document.body, 'body', null);
    const de = document.documentElement;
    return {doc: {sw: de.scrollWidth, cw: de.clientWidth, sh: de.scrollHeight}, nodes: nodes};
  }

  const frame = () => new Promise((resolve) =>
    requestAnimationFrame(() => requestAnimationFrame(() => setTimeout(resolve, 40))));

  let previousJson = null;
  for (let attempt = 0; attempt < 30; attempt++) {
    for (const animation of document.getAnimations()) {
      try { animation.finish(); } catch (e) { /* infinite animations cannot finish; the freeze rule holds them */ }
    }
    await frame();
    const current = measure();
    const json = JSON.stringify(current);
    if (json === previousJson) return current;
    previousJson = json;
  }
  throw new Error('page did not settle after 30 measurements; the last two differ, so any recorded value is a coin flip');
}
''';

/// One page rendered at one width in one colour scheme.
class Capture {
  Capture({required this.page, required this.width, required this.scheme, required this.doc, required this.nodes});

  /// Rebuilds a capture from the stored form, resolving a dark [deltaOf] record
  /// against the light capture it was recorded against.
  factory Capture.fromJson(Map<String, Object?> json, {Capture? deltaOf}) {
    final page = json['page']! as String;
    final width = json['width']! as int;
    final scheme = json['scheme']! as String;
    final rawNodes = (json['nodes']! as List).cast<Map<String, Object?>>();
    if (deltaOf == null) {
      return Capture(
        page: page,
        width: width,
        scheme: scheme,
        doc: (json['doc']! as Map).cast<String, Object?>(),
        nodes: rawNodes,
      );
    }
    return Capture(
      page: page,
      width: width,
      scheme: scheme,
      doc: _applyDelta(deltaOf.doc, (json['doc']! as Map).cast<String, Object?>()),
      nodes: _applyNodeDelta(deltaOf.nodes, rawNodes),
    );
  }

  final String page;
  final int width;
  final String scheme;
  final Map<String, Object?> doc;
  final List<Map<String, Object?>> nodes;

  String get id => '$page@${width}px/$scheme';

  /// The stored form. When [against] is given the capture is written as the
  /// difference from it — dark records against their light twin.
  ///
  /// Light and dark differ in paint on roughly half the boxes and in geometry
  /// on almost none, so storing dark whole would repeat every coordinate and
  /// make one layout change show up twice in a review diff.
  Map<String, Object?> toJson({Capture? against}) => {
    'page': page,
    'width': width,
    'scheme': scheme,
    if (against != null) 'delta_of': against.scheme,
    'doc': against == null ? doc : _diff(against.doc, doc),
    'nodes': against == null ? nodes : _nodeDelta(against.nodes, nodes),
  };
}

Map<String, Object?> _diff(Map<String, Object?> from, Map<String, Object?> to) {
  final out = <String, Object?>{};
  for (final entry in to.entries) {
    if (!_deepEquals(from[entry.key], entry.value)) out[entry.key] = entry.value;
  }
  for (final key in from.keys) {
    if (!to.containsKey(key)) out[key] = null;
  }
  return out;
}

Map<String, Object?> _applyDelta(Map<String, Object?> base, Map<String, Object?> delta) {
  final out = Map<String, Object?>.of(base);
  for (final entry in delta.entries) {
    if (entry.value == null) {
      out.remove(entry.key);
    } else {
      out[entry.key] = entry.value;
    }
  }
  return out;
}

/// Dark-vs-light node delta: one entry per node whose record differs, keyed by
/// `k`, holding only the changed fields. Nodes present in only one scheme are
/// written whole (added) or as `{k, "removed": true}`.
List<Map<String, Object?>> _nodeDelta(List<Map<String, Object?>> base, List<Map<String, Object?>> target) {
  final baseByKey = {for (final node in base) node['k']! as String: node};
  final targetKeys = <String>{};
  final out = <Map<String, Object?>>[];
  for (final node in target) {
    final key = node['k']! as String;
    targetKeys.add(key);
    final previous = baseByKey[key];
    if (previous == null) {
      out.add(node);
      continue;
    }
    final changed = _diff(previous, node);
    if (changed.isNotEmpty) out.add({'k': key, ...changed});
  }
  for (final node in base) {
    final key = node['k']! as String;
    if (!targetKeys.contains(key)) out.add({'k': key, 'removed': true});
  }
  return out;
}

List<Map<String, Object?>> _applyNodeDelta(List<Map<String, Object?>> base, List<Map<String, Object?>> delta) {
  final byKey = {for (final node in base) node['k']! as String: Map<String, Object?>.of(node)};
  final order = [for (final node in base) node['k']! as String];
  for (final change in delta) {
    final key = change['k']! as String;
    if (change['removed'] == true) {
      byKey.remove(key);
      order.remove(key);
      continue;
    }
    final existing = byKey[key];
    if (existing == null) {
      byKey[key] = Map<String, Object?>.of(change);
      order.add(key);
      continue;
    }
    byKey[key] = _applyDelta(existing, change);
  }
  return [for (final key in order) byKey[key]!];
}

/// One theme's recorded appearance, as stored in `test/visual_baselines/`.
class Baseline {
  Baseline({required this.theme, required this.platform, required this.chrome, required this.captures});

  factory Baseline.fromJson(Map<String, Object?> json) {
    final resolved = <String, Capture>{};
    final captures = <Capture>[];
    for (final raw in (json['captures']! as List).cast<Map<String, Object?>>()) {
      final deltaOf = raw['delta_of'] as String?;
      final base = deltaOf == null ? null : resolved['${raw['page']}@${raw['width']}/$deltaOf'];
      if (deltaOf != null && base == null) {
        throw StateError('capture ${raw['page']}@${raw['width']}/${raw['scheme']} references a missing $deltaOf base');
      }
      final capture = Capture.fromJson(raw, deltaOf: base);
      resolved['${capture.page}@${capture.width}/${capture.scheme}'] = capture;
      captures.add(capture);
    }
    return Baseline(
      theme: json['theme']! as String,
      platform: json['platform']! as String,
      chrome: json['chrome']! as String,
      captures: captures,
    );
  }

  final String theme;

  /// `Platform.operatingSystem` of the machine that recorded this file.
  ///
  /// Geometry is only portable as far as font metrics are. The themes self-host
  /// their faces as woff2, so those metrics travel — but every stack ends in a
  /// system fallback (`-apple-system`, `Georgia`, `Consolas`), and the subset
  /// fonts are known to be missing glyphs the layouts render (`←` in Meadow's
  /// back-link). Any text that falls back measures differently on another OS,
  /// so a baseline is a record of one platform, the way a Flutter golden is.
  ///
  /// Redundant with the file name by design: it is what catches a recording
  /// copied or renamed into another platform's slot instead of re-recorded.
  final String platform;

  final String chrome;
  final List<Capture> captures;

  /// Where [theme]'s recording for *this* host lives.
  ///
  /// There is deliberately no way to ask for another platform's file: every
  /// caller either records what it just rendered or compares against what this
  /// machine can reproduce, and both are this one.
  static String pathFor(String repoRoot, String theme) =>
      p.join(repoRoot, 'test', 'visual_baselines', '$theme.${Platform.operatingSystem}.json');

  /// Operating systems [theme] has a committed recording for, sorted.
  ///
  /// Only used to say something useful when this host is not one of them: a
  /// bare "no baseline" reads as "nobody recorded this theme", which is the
  /// wrong diagnosis when five other themes just compared fine.
  static List<String> recordedPlatforms(String repoRoot, String theme) {
    final dir = Directory(p.join(repoRoot, 'test', 'visual_baselines'));
    if (!dir.existsSync()) return const [];
    final platforms = <String>[];
    for (final file in dir.listSync().whereType<File>()) {
      final name = p.basename(file.path);
      if (name.startsWith('$theme.') && name.endsWith('.json')) {
        platforms.add(name.substring(theme.length + 1, name.length - '.json'.length));
      }
    }
    platforms.sort();
    return platforms;
  }

  /// Serialized one node per line.
  ///
  /// `jsonEncode` would emit the whole file as a single line, which turns any
  /// change into a whole-file diff and makes the review step of an intentional
  /// baseline update impossible. One node per line means `git diff` names the
  /// boxes that moved.
  String encode() {
    final buffer = StringBuffer()
      ..writeln('{')
      ..writeln('"theme": ${jsonEncode(theme)},')
      ..writeln('"platform": ${jsonEncode(platform)},')
      ..writeln('"chrome": ${jsonEncode(chrome)},')
      ..writeln('"tolerance_px": $boxTolerance,')
      ..writeln('"captures": [');
    Capture? lightOf(Capture capture) => capture.scheme == 'light'
        ? null
        : captures.firstWhere(
            (other) => other.page == capture.page && other.width == capture.width && other.scheme == 'light',
          );
    for (var i = 0; i < captures.length; i++) {
      final json = captures[i].toJson(against: lightOf(captures[i]));
      final nodes = (json.remove('nodes')! as List).cast<Map<String, Object?>>();
      buffer
        ..writeln('{')
        ..write(json.entries.map((e) => '${jsonEncode(e.key)}: ${jsonEncode(e.value)}').join(',\n'))
        ..writeln(',')
        ..writeln('"nodes": [');
      for (var n = 0; n < nodes.length; n++) {
        buffer.writeln('${jsonEncode(nodes[n])}${n == nodes.length - 1 ? '' : ','}');
      }
      buffer
        ..writeln(']')
        ..writeln('}${i == captures.length - 1 ? '' : ','}');
    }
    return (buffer
          ..writeln(']')
          ..writeln('}'))
        .toString();
  }
}

/// One recorded-versus-rendered difference.
class Difference {
  Difference(this.capture, this.where, this.detail);

  final String capture;
  final String where;
  final String detail;

  @override
  String toString() => '$capture  $where  $detail';
}

/// Compares a freshly rendered [actual] against the recorded [expected].
///
/// Geometry gets [boxTolerance]; everything else is exact. Overflow is reported
/// even when it matches the baseline, because a box that cannot contain its own
/// content is a defect whether or not it was recorded as one.
List<Difference> compareCaptures(Capture expected, Capture actual) {
  final differences = <Difference>[];
  final id = actual.id;

  for (final key in {...expected.doc.keys, ...actual.doc.keys}) {
    final e = expected.doc[key];
    final a = actual.doc[key];
    if (e is int && a is int) {
      if ((e - a).abs() > boxTolerance) differences.add(Difference(id, 'document.$key', '$e -> $a'));
    } else if (!_deepEquals(e, a)) {
      differences.add(Difference(id, 'document.$key', '$e -> $a'));
    }
  }
  if (actual.doc['sw'] != actual.doc['cw']) {
    differences.add(
      Difference(
        id,
        'document',
        'horizontal overflow: scrollWidth ${actual.doc['sw']} vs clientWidth ${actual.doc['cw']}',
      ),
    );
  }

  final expectedByKey = {for (final node in expected.nodes) node['k']! as String: node};
  final actualByKey = {for (final node in actual.nodes) node['k']! as String: node};
  for (final key in expectedByKey.keys) {
    if (!actualByKey.containsKey(key)) differences.add(Difference(id, key, 'box no longer rendered'));
  }
  for (final key in actualByKey.keys) {
    if (!expectedByKey.containsKey(key)) differences.add(Difference(id, key, 'new box: ${_label(actualByKey[key]!)}'));
  }

  for (final entry in actualByKey.entries) {
    final e = expectedByKey[entry.key];
    if (e == null) continue;
    differences.addAll(_compareNode(id, entry.key, e, entry.value));
  }
  return differences;
}

String _label(Map<String, Object?> node) {
  final classes = node['c'] as String?;
  final id = node['i'] as String?;
  return [if (id != null) '#$id', if (classes != null) '.${classes.split(' ').join('.')}'].join(' ');
}

List<Difference> _compareNode(String capture, String key, Map<String, Object?> expected, Map<String, Object?> actual) {
  final differences = <Difference>[];
  const boxNames = ['x', 'y', 'width', 'height'];
  final e = (expected['b']! as List).cast<int>();
  final a = (actual['b']! as List).cast<int>();
  for (var i = 0; i < 4; i++) {
    if ((e[i] - a[i]).abs() > boxTolerance) {
      differences.add(Difference(capture, key, '${boxNames[i]} ${e[i]} -> ${a[i]}'));
    }
  }

  final style = (actual['s'] as Map?)?.cast<String, Object?>() ?? const {};
  for (final axis in const ['ox', 'oy']) {
    final expectedOverflow = (expected[axis] ?? 0) as int;
    final actualOverflow = (actual[axis] ?? 0) as int;
    final name = axis == 'ox' ? 'horizontal' : 'vertical';
    if (expectedOverflow != actualOverflow) {
      differences.add(Difference(capture, key, '$name overflow $expectedOverflow -> $actualOverflow px'));
      continue;
    }
    if (actualOverflow != 0 && _hidesOverflow(style, axis) && _isVisibleBox(a)) {
      differences.add(Difference(capture, key, 'content clipped: $actualOverflow px of $name overflow'));
    }
  }

  for (final field in const ['c', 'i']) {
    if (expected[field] != actual[field]) {
      differences.add(
        Difference(capture, key, '${field == 'c' ? 'class' : 'id'} "${expected[field]}" -> "${actual[field]}"'),
      );
    }
  }

  for (final group in const ['s', 'pb', 'pa']) {
    final expectedGroup = (expected[group] as Map?)?.cast<String, Object?>() ?? const {};
    final actualGroup = (actual[group] as Map?)?.cast<String, Object?>() ?? const {};
    const labels = {'s': '', 'pb': '::before ', 'pa': '::after '};
    for (final property in {...expectedGroup.keys, ...actualGroup.keys}) {
      if (_deepEquals(expectedGroup[property], actualGroup[property])) continue;
      differences.add(
        Difference(capture, key, '${labels[group]}$property ${expectedGroup[property]} -> ${actualGroup[property]}'),
      );
    }
  }
  return differences;
}

/// Boxes in [capture] that hide their own content.
///
/// An invariant, not a comparison: nothing is stored and no baseline blesses a
/// hit. That is what makes it the right check for the pages a stored baseline
/// cannot afford to cover — every page of every example plus every fixture.
///
/// It is also the only check that can see this defect class at all. A hero with
/// `overflow: clip` swallowing its own heading does **not** make the document
/// scroll horizontally, so the `scrollWidth == clientWidth` reflow sweep is
/// blind to it by construction; the text simply disappears.
List<Difference> scanClipping(Capture capture) {
  final differences = <Difference>[];
  for (final node in capture.nodes) {
    final box = (node['b']! as List).cast<int>();
    if (!_isVisibleBox(box)) continue;
    final style = (node['s'] as Map?)?.cast<String, Object?>() ?? const {};
    if (_isDeliberatelyTruncated(style)) continue;
    for (final axis in const ['ox', 'oy']) {
      final overflow = (node[axis] ?? 0) as int;
      if (overflow == 0 || !_hidesOverflow(style, axis)) continue;
      differences.add(
        Difference(
          capture.id,
          node['k']! as String,
          'content clipped: $overflow px of ${axis == 'ox' ? 'horizontal' : 'vertical'} overflow '
          'in a ${box[2]}x${box[3]} box',
        ),
      );
    }
  }
  return differences;
}

/// Whether the element truncates on purpose and says so on screen.
///
/// `text-overflow: ellipsis` is a designed truncation with a visible marker —
/// Meadow's `.nav-cta span` uses it. Reporting it would be reporting the
/// feature.
bool _isDeliberatelyTruncated(Map<String, Object?> style) => style['textOverflow'] == 'ellipsis';

/// Whether a box is large enough for overflow to mean "the user sees clipped
/// content".
///
/// The screen-reader-only pattern every theme here uses — a 1x1 px absolutely
/// positioned label with `overflow: hidden` — reports hundreds of pixels of
/// overflow by construction. Flagging it would make the unconditional
/// clipped-content check permanently red on all six themes and train everyone
/// to ignore it, which is the failure mode this harness exists to end.
bool _isVisibleBox(List<int> box) => box[2] >= 24 && box[3] >= 16;

/// Whether [style] hides overflow on [axis] (`ox` or `oy`).
///
/// `scrollWidth > clientWidth` on an `overflow: visible` box means content
/// extends past the padding box, which is ordinary and hides nothing — every
/// heading whose line box rounds up reports a pixel or two of it. Content is
/// only *clipped* when the element also refuses to show the overflow, which is
/// the combination that made Meadow's `white-space: nowrap` marker meet
/// `overflow: clip` and render "a durable product dire".
///
/// `auto` and `scroll` do not count: the content is reachable, just not all at
/// once. Folio's mobile docs disclosure is exactly that — a `46vh` cap with
/// `overflow: auto`, deliberately taller than its box.
bool _hidesOverflow(Map<String, Object?> style, String axis) {
  final value = style[axis == 'ox' ? 'overflowX' : 'overflowY'];
  return value == 'hidden' || value == 'clip';
}

bool _deepEquals(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

/// The rendering capability this comparator needs, and nothing more.
///
/// Kept as an interface so this file never imports the CDP client: the client
/// (`test/browser_reflow_probe.dart`) is owned by the theme contract suite and
/// shared with the reflow sweep, and a second one would be a second set of
/// browser-lifecycle bugs.
abstract interface class RenderHost {
  /// Serves [root] and returns its base URL. The server stays up until
  /// [dispose].
  Future<Uri> serve(Directory root);

  /// Renders [url] at [width] x [viewportHeight] under `prefers-color-scheme:
  /// [colorScheme]` and returns the decoded JSON value of [expression].
  Future<Object?> evaluate(
    Uri url,
    String expression, {
    required int width,
    required int height,
    required String colorScheme,
  });

  Future<void> dispose();
}

/// What a comparator run produced.
class VisualBaselineRun {
  VisualBaselineRun({
    required this.differences,
    required this.missingBaselines,
    required this.rewritten,
    required this.chrome,
    required this.recordedChrome,
    required this.pageCount,
    required this.scannedPageCount,
    required this.captureCount,
  });

  /// Recorded-versus-rendered differences, in capture order.
  final List<Difference> differences;

  /// Themes with no baseline for *this* platform, each with the platforms it
  /// was recorded on. In check mode this is a failure: a theme nothing has
  /// rendered on this OS is a theme nothing is watching here.
  final List<String> missingBaselines;

  /// Baseline files whose content changed during an update run.
  final List<String> rewritten;

  /// Chrome that rendered this run.
  final String chrome;

  /// Chrome versions the compared baselines were recorded with.
  final Set<String> recordedChrome;

  /// Pages baselined, summed over the selected themes.
  final int pageCount;

  /// Pages swept by the clipped-content invariant, summed over the selected
  /// themes. Disjoint from [pageCount]: the baselined pages already carry the
  /// same check through [compareCaptures].
  final int scannedPageCount;

  final int captureCount;

  bool get isClean => differences.isEmpty && missingBaselines.isEmpty;

  /// A failure message naming what moved, and — when the browser changed under
  /// the baselines — saying so before the maintainer starts bisecting CSS.
  String describe() {
    final buffer = StringBuffer();
    if (missingBaselines.isNotEmpty) {
      buffer.writeln(
        'No recorded baseline for: ${missingBaselines.join('; ')}. Record it on this platform with '
        'UPDATE_VISUAL_BASELINES=1 dart test test/visual_baseline_test.dart and commit the result — a '
        'baseline from another OS cannot stand in for it.',
      );
    }
    final drifted = recordedChrome.where((version) => _major(version) != _major(chrome)).toList();
    if (drifted.isNotEmpty) {
      buffer.writeln(
        'Chrome changed since these baselines were recorded '
        '(${drifted.join(', ')} -> $chrome). A browser upgrade can move layout past the '
        '${boxTolerance}px tolerance; check that before treating geometry differences as a regression.',
      );
    }
    if (differences.isNotEmpty) {
      buffer.writeln('${differences.length} difference(s) from the recorded appearance:');
      for (final difference in differences.take(60)) {
        buffer.writeln('  $difference');
      }
      if (differences.length > 60) buffer.writeln('  ... and ${differences.length - 60} more');
    }
    buffer.writeln(
      'If this is an intended design change, re-record with '
      'UPDATE_VISUAL_BASELINES=1 dart test test/visual_baseline_test.dart and review the diff under '
      'test/visual_baselines/ before committing.',
    );
    return buffer.toString();
  }

  static String _major(String version) => version.split('.').first;
}

/// Renders every theme example and either compares it with the recorded
/// baselines or, when [update] is set, re-records them.
///
/// [scratch] must be outside the repository; each example is copied into it and
/// built there.
Future<VisualBaselineRun> runVisualBaselines({
  required String repoRoot,
  required RenderHost host,
  required Directory scratch,
  bool update = false,
  Set<String>? onlyThemes,
}) async {
  final examples = discoverThemeExamples(
    repoRoot,
  ).where((example) => onlyThemes == null || onlyThemes.contains(example.name)).toList();
  if (examples.isEmpty) throw StateError('no theme examples selected (filter: $onlyThemes)');

  final differences = <Difference>[];
  final missing = <String>[];
  final rewritten = <String>[];
  final recordedChrome = <String>{};
  var chrome = 'unknown';
  var pageCount = 0;
  var scannedPageCount = 0;
  var captureCount = 0;

  for (final example in examples) {
    final output = await buildExample(example, into: scratch, repoRoot: repoRoot);
    final baseUrl = await host.serve(output);
    if (chrome == 'unknown') chrome = await _chromeVersion(host, baseUrl);

    final captures = <Capture>[];
    final pages = baselinePages(output);
    pageCount += pages.length;
    for (final page in pages) {
      for (final width in viewportWidths) {
        for (final scheme in colorSchemes) {
          final raw =
              await host.evaluate(
                    baseUrl.replace(path: page),
                    '($digestScript)()',
                    width: width,
                    height: viewportHeight,
                    colorScheme: scheme,
                  )
                  as Map<String, Object?>;
          captures.add(
            Capture(
              page: page,
              width: width,
              scheme: scheme,
              doc: (raw['doc']! as Map).cast<String, Object?>(),
              nodes: (raw['nodes']! as List).cast<Map<String, Object?>>(),
            ),
          );
          captureCount++;
        }
      }
    }

    // Clipped-content sweep over everything the baselines do not cover: the
    // example's remaining pages and every fixture. Light only — clipping is a
    // geometry property, and light/dark geometry was identical on 95% of boxes
    // across these six themes, while the baselined pages cover both schemes.
    final fixtures = await buildFixtureSite(example, into: scratch, repoRoot: repoRoot);
    final sweep = <(Uri, String)>[
      for (final page in discoverPages(output).where((page) => !pages.contains(page))) (baseUrl, page),
      if (fixtures != null)
        for (final page in discoverPages(fixtures)) (await host.serve(fixtures), page),
    ];
    scannedPageCount += sweep.length;
    for (final (origin, page) in sweep) {
      for (final width in viewportWidths) {
        final raw =
            await host.evaluate(
                  origin.replace(path: page),
                  '($digestScript)()',
                  width: width,
                  height: viewportHeight,
                  colorScheme: 'light',
                )
                as Map<String, Object?>;
        captureCount++;
        differences.addAll(
          scanClipping(
            Capture(
              page: page,
              width: width,
              scheme: 'light',
              doc: (raw['doc']! as Map).cast<String, Object?>(),
              nodes: (raw['nodes']! as List).cast<Map<String, Object?>>(),
            ),
          ),
        );
      }
    }

    final file = File(Baseline.pathFor(repoRoot, example.name));
    final fresh = Baseline(theme: example.name, platform: Platform.operatingSystem, chrome: chrome, captures: captures);
    if (update) {
      final encoded = fresh.encode();
      final changed = !file.existsSync() || file.readAsStringSync() != encoded;
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(encoded);
      if (changed) rewritten.add(p.relative(file.path, from: repoRoot));
      continue;
    }
    if (!file.existsSync()) {
      final elsewhere = Baseline.recordedPlatforms(repoRoot, example.name);
      missing.add(
        elsewhere.isEmpty
            ? '${example.name} (never recorded)'
            : '${example.name} on ${Platform.operatingSystem} (recorded on ${elsewhere.join(', ')})',
      );
      continue;
    }
    final recorded = Baseline.fromJson(jsonDecode(file.readAsStringSync()) as Map<String, Object?>);
    if (recorded.platform != Platform.operatingSystem) {
      throw StateError(
        '${p.relative(file.path, from: repoRoot)} says it was recorded on ${recorded.platform}, but its name '
        'claims ${Platform.operatingSystem} — it was copied or renamed into the slot for this platform rather '
        'than recorded here. Font fallback differs between operating systems, so the geometry in a baseline is only '
        'meaningful on the platform that recorded it. Re-record on ${Platform.operatingSystem} with '
        'UPDATE_VISUAL_BASELINES=1 and commit the result. '
        'Comparing across platforms would either fail on differences nobody introduced or need a '
        'tolerance wide enough to hide the ones they did.',
      );
    }
    recordedChrome.add(recorded.chrome);
    final recordedById = {for (final capture in recorded.captures) capture.id: capture};
    for (final capture in captures) {
      final expected = recordedById.remove(capture.id);
      if (expected == null) {
        differences.add(Difference(capture.id, '(capture)', 'not in ${example.name}.json'));
        continue;
      }
      differences.addAll(compareCaptures(expected, capture));
    }
    for (final orphan in recordedById.keys) {
      differences.add(Difference(orphan, '(capture)', 'recorded but no longer rendered'));
    }
  }

  return VisualBaselineRun(
    differences: differences,
    missingBaselines: missing,
    rewritten: rewritten,
    chrome: chrome,
    recordedChrome: recordedChrome,
    pageCount: pageCount,
    scannedPageCount: scannedPageCount,
    captureCount: captureCount,
  );
}

Future<String> _chromeVersion(RenderHost host, Uri baseUrl) async {
  final agent =
      await host.evaluate(baseUrl, 'navigator.userAgent', width: 1440, height: viewportHeight, colorScheme: 'light')
          as String;
  return RegExp(r'Chrom(?:e|ium)/(\S+)').firstMatch(agent)?.group(1) ?? 'unknown';
}

void _copyTree(Directory from, Directory to, {Set<String> skip = const {}}) {
  to.createSync(recursive: true);
  for (final entity in from.listSync(followLinks: false)) {
    final name = p.basename(entity.path);
    if (skip.contains(name) || name == '.DS_Store') continue;
    if (entity is Link) continue;
    if (entity is Directory) {
      _copyTree(entity, Directory(p.join(to.path, name)));
    } else if (entity is File) {
      entity.copySync(p.join(to.path, name));
    }
  }
}
