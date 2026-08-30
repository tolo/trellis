/// The font contract shared by the three font-bearing themes (Lattice, Folio, Meadow).
///
/// It exists because each suite used to assert whatever its author remembered: Meadow
/// checked the WOFF2 signature and a weight range, Lattice and Folio checked neither, and
/// zeroing all eight of their font files still produced "All tests passed!". Everything
/// here is asserted for every theme, against the shipped bytes rather than against the
/// stylesheet's description of them.
///
/// Two halves:
///
/// * [expectThemeFontContract] — per-file integrity. A face has to be a parseable WOFF2,
///   clear a byte and glyph floor, carry exactly the variation axes the theme expects,
///   name itself after its own filename, and declare a `@font-face` weight range its
///   `fvar` actually covers and a `unicode-range` equal to its own `cmap` — or be named in
///   `unicodeRangeExemptions`, because a descriptor that is simply absent used to skip the
///   check while the loop still read as covering every face.
/// * glyph coverage — every non-ASCII codepoint the theme itself emits has to be drawable
///   by the family that renders it. Emission is derived from `theme.yaml` defaults, the
///   layouts, `data/*.yaml`, the compiled stylesheet's `content:` properties and any
///   `contentPaths` Markdown; the theme's own JavaScript is out of scope, because a string
///   there has no element to resolve a family from.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// What a theme claims about one of its vendored faces.
///
/// The floors are the point: a cap alone is satisfied by an empty file, and a WOFF2
/// signature alone is satisfied by four bytes. [minBytes] and [minGlyphs] sit far enough
/// below the shipped values to survive a small subset change and far enough above zero to
/// fail a stub. [axes] is exact — an instancer run that drops `opsz` leaves a file that is
/// otherwise perfectly valid and renders headings at the wrong width.
typedef VendoredFace = ({int minBytes, int minGlyphs, Set<String> axes});

/// A codepoint the theme emits that the family rendering it cannot draw.
///
/// Every entry is a live defect whose fix is a layout or stylesheet change rather than a
/// font change, so it is pinned here instead of silently tolerated: the contract asserts
/// the gaps it finds are *exactly* this list, so neither a new gap nor a fixed one can
/// pass unnoticed.
typedef GlyphGap = ({int codepoint, String source, String fix});

/// A rule asking a vendored family for a weight its `@font-face` range does not declare.
///
/// The request is first clamped into the declared range, and what happens next turns on one
/// threshold: Chrome applies synthetic bold only when the *used* weight is below 600 and the
/// *requested* weight is at least 600. So a descriptor topping out at 400 or 500 renders a
/// faked heaviness (Folio's original faux bold: EB Garamond vendored at 400, asked for 700),
/// while one topping out at 600 or more renders a real but wrong weight with no sign that
/// anything happened (Folio's masthead clamped 700 to a genuine 600; Meadow's mono clamped
/// 800 to a genuine 700). The symptoms are opposites - too much ink or too little - which is
/// worth knowing before diagnosing one against the other's model, but the fix is the same
/// either way: widen the descriptor to what the file already carries.
///
/// Measured on one Chromium version, by ink count on canvas and by advance width in the DOM;
/// `ctx.fontSynthesis = 'none'` had no effect on the canvas path, so only the DOM route can
/// suppress synthesis. Any case where widening is a design call instead is pinned here and,
/// as with [GlyphGap], the list is asserted to be exactly what the stylesheet does.
typedef WeightGap = ({String selector, String family, int weight, String fix});

/// Asserts the theme's vendored fonts against [faces] and its own emitted glyphs.
///
/// [compiledCss] is `main.scss` compiled with the theme's default parameters, so the
/// `--*` font variables resolve to the vendored families rather than to a test prelude's
/// substitutes.
Future<void> expectThemeFontContract({
  required String themeDir,
  required String compiledCss,
  required Map<String, VendoredFace> faces,
  required int maxTotalBytes,
  required List<GlyphGap> knownGaps,
  required List<WeightGap> knownWeightGaps,

  /// Faces that ship without a `unicode-range` descriptor, each mapped to why.
  ///
  /// The descriptor is only checkable where it exists, so an absent one used to skip the
  /// check silently while the loop still read as covering every face. Naming the exemption
  /// makes the count honest in both directions: a face without the descriptor that is not
  /// named here fails, and so does a named face that has since gained one. Whether these
  /// faces *should* declare a range is a theme-authoring call - it changes what a browser
  /// downloads per face - and is deliberately not decided here.
  Map<String, String> unicodeRangeExemptions = const {},

  /// Markdown trees whose text this theme renders - the docs site's `site/content/**`.
  ///
  /// A theme's own layouts and params are half of what ships: the other half is what an
  /// author types, and a character with no glyph there renders as tofu or drops to a system
  /// font mid-sentence. Each file is placed into the element its layouts bind `page.content`
  /// to and resolved through the same cascade as the layouts' own text, because the family
  /// depends on the construct - a `→` in body prose is Instrument Sans, in a fenced block
  /// Spline Sans Mono, and charging it to both invents a defect.
  List<String> contentPaths = const [],

  /// Configs outside the theme that bind this theme's params - the docs site's own
  /// `site/trellis_site.yaml`, say. A glyph there ships to real visitors rather than
  /// only into a screenshot, so it is the surface that matters most.
  ///
  /// `theme_params` only, deliberately. A consumer's `data/*.yaml` binds through
  /// `tl:text="${data.<file>.<path>}"` to one known element, so the blanket "every vendored
  /// family must draw it" rule this applies to substitutable values is wrong there: the docs
  /// site's `site/data/lattice.yaml` sets `link_label: All themes →`, which renders in
  /// `.showcase-link a.button` - body, so Instrument Sans, the one Lattice face carrying
  /// U+2192. Passing that file here would report two gaps against faces that never draw it.
  /// Covering data files honestly needs the template dataflow resolved, not a wider net.
  List<String> extraConfigPaths = const [],
}) async {
  // Loud comments survive compilation, and Meadow keeps one inside a `@font-face` block
  // whose prose carries both a colon-free semicolon and a `:`. Left in, the declaration
  // parse below swallows `font-weight` into a key made of half a sentence.
  final css = compiledCss.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
  final fontDir = Directory(p.join(themeDir, 'static', 'fonts'));
  final files =
      fontDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.woff2'))
          .map((f) => p.basename(f.path))
          .toList()
        ..sort();
  expect(files, faces.keys.toList()..sort(), reason: 'vendored faces in ${fontDir.path}');

  var totalBytes = 0;
  for (final file in files) {
    final bytes = File(p.join(fontDir.path, file)).readAsBytesSync();
    expect(bytes.take(4), [0x77, 0x4F, 0x46, 0x32], reason: 'wOF2 signature: $file');
    expect(bytes.length, greaterThanOrEqualTo(faces[file]!.minBytes), reason: '$file is ${bytes.length} bytes');
    totalBytes += bytes.length;
  }
  // The payload ships to every deployed site, so it is budgeted.
  expect(totalBytes, lessThanOrEqualTo(maxTotalBytes), reason: '$totalBytes bytes across ${files.length} faces');

  final declared = _declaredFaces(css);
  expect(declared.map((f) => f.file).toSet(), files.toSet(), reason: '@font-face src files');

  final inspected = await _inspect(fontDir.path, files);
  if (inspected == null) return;

  final undeclaredRange = <String>[];
  for (final face in declared) {
    final file = face.file;
    final font = inspected[file]!;
    final stem = p.basenameWithoutExtension(file);

    // A file's own name table has to agree with the name it is filed under and with the
    // family the stylesheet asks for. Without this, JetBrains Mono bytes saved as
    // `fraunces-latin.woff2` pass every structural check there is.
    final expected = _familySlug(stem);
    expect(_slug(font.family), expected, reason: '$file name-table family is "${font.family}"');
    expect(_slug(face.family), expected, reason: '$file is declared as font-family "${face.family}"');
    final italic = stem.contains('-italic');
    expect(font.italicAngle != 0, italic, reason: '$file post.italicAngle is ${font.italicAngle}');
    expect(face.italic, italic, reason: '$file is declared font-style: ${face.italic ? 'italic' : 'normal'}');

    expect(font.numGlyphs, greaterThanOrEqualTo(faces[file]!.minGlyphs), reason: '$file has ${font.numGlyphs} glyphs');
    expect(font.axes.keys.toSet(), faces[file]!.axes, reason: '$file variation axes');

    // The descriptor is what the browser believes, not what the file holds: a request outside
    // it is clamped into it before the `wght` axis is ever set, and above a used weight of
    // 600 nothing is synthesised to cover the difference (see [WeightGap]). Meadow's JetBrains
    // Mono declared `400 700` against a file carrying 400-800 and drew its weight-800 labels
    // at a real 700; Folio's `400 600` clamped a 700 masthead to a real 600. Declaring more
    // than the file carries clamps at the axis instead, with the same silence. A face with
    // `wght` instanced out can only draw its own `usWeightClass`.
    final wght = font.axes['wght'];
    if (wght == null) {
      expect([face.minWeight, face.maxWeight], [font.weightClass, font.weightClass], reason: '$file has no wght axis');
    } else {
      expect(face.minWeight, greaterThanOrEqualTo(wght.first), reason: '$file wght starts at ${wght.first}');
      expect(face.maxWeight, lessThanOrEqualTo(wght.last), reason: '$file wght ends at ${wght.last}');
    }

    // Equality, not containment, in both directions. A range narrower than its file
    // refuses glyphs the file holds and splits a word across two typefaces; a range wider
    // matches the face, pays for the download, finds nothing and reaches the system
    // fallback anyway - a request that reads as coverage and renders as its absence.
    if (face.unicodeRange == null) {
      undeclaredRange.add(file);
    } else {
      expect(
        _formatRange(face.unicodeRange!),
        _formatRange(font.cmap),
        reason: '$file unicode-range must equal its own cmap',
      );
    }
  }

  // Without this the loop above reads as covering every face while doing nothing for the
  // ones that declare no range. An exemption has to be named and reasoned, so the number of
  // faces actually asserted is visible rather than assumed.
  expect(
    undeclaredRange..sort(),
    unicodeRangeExemptions.keys.toList()..sort(),
    reason:
        'unicode-range is asserted for ${declared.length - undeclaredRange.length} of ${declared.length} '
        'faces; the rest must be named as exemptions:\n'
        '${unicodeRangeExemptions.entries.map((e) => '  ${e.key} -> ${e.value}').join('\n')}',
  );

  await _expectGlyphCoverage(
    themeDir: themeDir,
    compiledCss: css,
    declared: declared,
    inspected: inspected,
    knownGaps: knownGaps,
    knownWeightGaps: knownWeightGaps,
    contentPaths: contentPaths,
    extraConfigPaths: extraConfigPaths,
  );
}

// ---------------------------------------------------------------------------
// Glyph coverage
// ---------------------------------------------------------------------------

Future<void> _expectGlyphCoverage({
  required String themeDir,
  required String compiledCss,
  required List<_DeclaredFace> declared,
  required Map<String, _Woff2> inspected,
  required List<GlyphGap> knownGaps,
  required List<WeightGap> knownWeightGaps,
  List<String> contentPaths = const [],
  List<String> extraConfigPaths = const [],
}) async {
  // `--x: Fraunces, Georgia, serif` makes `--x` the Fraunces variable; a variable fronting
  // a system stack maps to nothing here and its text is not asserted, because no vendored
  // face is responsible for it.
  final vendored = {for (final face in declared) _slug(face.family)};
  final variables = <String, String>{};
  for (final match in RegExp(r'(--[a-z0-9-]+):\s*([^;,]+)[,;]').allMatches(compiledCss)) {
    final family = _slug(_unquote(match.group(2)!));
    if (vendored.contains(family)) variables[match.group(1)!] = family;
  }
  expect(variables.values.toSet(), vendored, reason: 'every vendored family must front a --font variable');

  final rules = _leafRules(compiledCss).where((r) => !r.properties.containsKey('src')).toList();
  final ruleVariable = <String, String>{};
  for (final rule in rules) {
    final declaration = rule.properties['font-family'] ?? rule.properties['font'];
    final variable = declaration == null ? null : RegExp(r'var\((--[a-z0-9-]+)\)').firstMatch(declaration)?.group(1);
    if (variable != null) ruleVariable[rule.selector] = variable;
  }
  final bodyVariable = ruleVariable.entries.firstWhere((e) => _selectors(e.key).contains('body')).value;

  final documents = {
    for (final file in Directory(p.join(themeDir, 'layouts')).listSync(recursive: true).whereType<File>())
      if (file.path.endsWith('.html'))
        p.relative(file.path, from: themeDir): html_parser.parse(file.readAsStringSync()),
  };
  expect(documents, isNotEmpty, reason: '${p.join(themeDir, 'layouts')} has no layouts to scan');
  final resolvers = {
    for (final entry in documents.entries) entry.key: _FontResolver(entry.value, ruleVariable, bodyVariable),
  };
  final italicRules = <String, String>{
    for (final rule in rules)
      if (rule.properties['font-style'] case final style?) rule.selector: style,
  };
  final italicResolvers = {for (final entry in documents.entries) entry.key: _ItalicResolver(entry.value, italicRules)};

  /// Vendored families the rule's text can land in: the family it names itself, or the
  /// families in force wherever the selector matches a layout.
  ///
  /// A selector that matches nothing resolves to nothing rather than to the body's family.
  /// Some rules only ever meet SSG- or highlighter-generated markup - Folio's `.hljs-*`
  /// classes exist solely inside `<pre><code>`, which is the system mono stack, and
  /// charging those to the body serif invents a defect instead of finding one.
  Set<String> familiesFor(_Rule rule) {
    final own = ruleVariable[rule.selector];
    if (own != null) return {?variables[own]};
    final families = <String>{};
    for (final selector in _selectors(rule.selector)) {
      final origin = selector.replaceAll(RegExp(r'::?(before|after)\b'), '').trim();
      for (final entry in documents.entries) {
        for (final element in _safeQuery(entry.value, origin)) {
          final family = variables[resolvers[entry.key]!.variableFor(element)];
          if (family != null) families.add(family);
        }
      }
    }
    return families;
  }

  Set<bool> stylesFor(_Rule rule) {
    final declared = rule.properties['font-style'];
    if (declared == 'italic') return const {true};
    if (declared == 'normal') return const {false};
    final styles = <bool>{};
    for (final selector in _selectors(rule.selector)) {
      final origin = selector.replaceAll(RegExp(r'::?(before|after)\b'), '').trim();
      for (final entry in documents.entries) {
        for (final element in _safeQuery(entry.value, origin)) {
          styles.add(italicResolvers[entry.key]!.italicFor(element));
        }
      }
    }
    return styles.isEmpty ? const {false} : styles;
  }

  // Merged declared range per family and style. Upright and italic faces are
  // selected independently, so unioning them lets a one-weight italic face
  // borrow the upright variable range and hides synthetic bold.
  final weights = <(String, bool), (int, int)>{};
  for (final face in declared) {
    final key = (_slug(face.family), face.italic);
    final current = weights[key];
    weights[key] = current == null
        ? (face.minWeight, face.maxWeight)
        : (min(current.$1, face.minWeight), max(current.$2, face.maxWeight));
  }
  var requestCount = 0;
  final weightGaps = <WeightGap>[];
  for (final rule in rules) {
    // Whole values, not substrings: `font-weight` carries one number outside `@font-face`,
    // and the `font` shorthand's weight is its first token when that token is a weight -
    // `font: 13px/1.75 var(--mono)` sets none.
    final requested = [
      ?int.tryParse(rule.properties['font-weight'] ?? ''),
      ?int.tryParse(
        RegExp(r'^\d{3}$').firstMatch(rule.properties['font']?.split(RegExp(r'\s')).first ?? '')?.group(0) ?? '',
      ),
    ];
    for (final family in requested.isEmpty ? const <String>{} : familiesFor(rule)) {
      for (final italic in stylesFor(rule)) {
        final range = weights[(family, italic)];
        if (range == null) continue;
        for (final weight in requested) {
          requestCount++;
          if (weight < range.$1 || weight > range.$2) {
            weightGaps.add((selector: rule.selector, family: family, weight: weight, fix: ''));
          }
        }
      }
    }
  }
  // A resolver that quietly matched nothing would report zero gaps and read as a pass.
  expect(requestCount, greaterThan(10), reason: 'only $requestCount weighted rules resolved to a vendored family');
  String renderWeight(WeightGap gap) => '${gap.selector} asks ${gap.family} for ${gap.weight}';
  expect(
    weightGaps.map(renderWeight).toList()..sort(),
    knownWeightGaps.map(renderWeight).toList()..sort(),
    reason:
        'a request outside the declared range renders a weight nobody asked for; the known ones are '
        'design calls:\n${knownWeightGaps.map((g) => '  ${renderWeight(g)} -> ${g.fix}').join('\n')}',
  );

  // (codepoint, family slug or null for "any vendored family") -> where it came from.
  final demands = <(int, String?), String>{};
  void demand(int codepoint, String? family, String source) => demands.putIfAbsent((codepoint, family), () => source);

  for (final entry in documents.entries) {
    final resolver = resolvers[entry.key]!;
    for (final (element, text, what) in _renderedText(entry.value.querySelectorAll('*'))) {
      for (final codepoint in _nonAscii(text)) {
        demand(codepoint, variables[resolver.variableFor(element)], '${entry.key} $what');
      }
    }
  }

  // A `content:` string is drawn by the pseudo-element's own font, which inherits from the
  // element the selector names; `::before` never matches a document, so it is stripped and
  // the origin element resolved instead.
  for (final rule in rules) {
    for (final match in RegExp(r'''(["'])(.*?)\1''').allMatches(rule.properties['content'] ?? '')) {
      final codepoints = _nonAscii(match.group(2)!);
      if (codepoints.isEmpty) continue;
      final own = ruleVariable[rule.selector];
      for (final selector in _selectors(rule.selector)) {
        final origin = selector.replaceAll(RegExp(r'::?(before|after)\b'), '').trim();
        final elements = [
          for (final entry in documents.entries)
            for (final element in _safeQuery(entry.value, origin)) (resolvers[entry.key]!, element),
        ];
        for (final codepoint in codepoints) {
          if (own != null || elements.isEmpty) {
            demand(codepoint, variables[own ?? bodyVariable], 'css $selector');
          }
          for (final (resolver, element) in elements) {
            demand(codepoint, variables[own ?? resolver.variableFor(element)], 'css $selector');
          }
        }
      }
    }
  }

  // Parameter defaults and data-file values are substituted into whichever element the
  // layout binds them to, and a site author can move that binding. Resolving the template
  // dataflow to name one family would assert less than requiring all of them to draw it.
  for (final (source, values) in _themeStrings(themeDir, extraConfigPaths)) {
    for (final value in values) {
      for (final codepoint in _nonAscii(value)) {
        demand(codepoint, null, source);
      }
    }
  }

  // Authored Markdown. Unlike a param default this *does* have one binding - the element the
  // layouts give `page.content` - so it is resolved rather than charged to every family: the
  // construct picks the family, and the docs site's `→` sits in body prose (Instrument Sans,
  // which draws it) rather than in the display or mono faces, which do not.
  if (contentPaths.isNotEmpty) {
    final contentFiles = [
      for (final root in contentPaths)
        if (Directory(root).existsSync())
          ...Directory(root).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.md')),
    ];
    expect(contentFiles, isNotEmpty, reason: 'no Markdown found under ${contentPaths.join(', ')}');
    final hosts = [
      for (final entry in documents.entries)
        if (_contentHost(entry.value) != null) entry.key,
    ];
    expect(hosts, isNotEmpty, reason: 'no layout binds page.content, so authored content resolves to nothing');
    for (final file in contentFiles) {
      final source = p.relative(file.path, from: Directory.current.path);
      final (frontMatter, body) = _splitFrontMatter(file.readAsStringSync());
      // Front matter feeds the chrome the layout builds around the content - the `<h1>`, the
      // nav's menu title, a card's summary - so it takes the same blanket rule as a param
      // default rather than the content host's family.
      for (final value in _strings(loadYaml(frontMatter, sourceUrl: file.uri))) {
        for (final codepoint in _nonAscii(value)) {
          demand(codepoint, null, '$source front matter');
        }
      }
      // Every host, not just the one the SSG would pick: which layout renders a file depends
      // on its path and front matter, so a theme whose hosts disagree about fonts has to draw
      // the content under any of them.
      for (final layout in hosts) {
        final document = html_parser.parse(File(p.join(themeDir, layout)).readAsStringSync());
        final host = _contentHost(document)!;
        host.nodes.clear();
        for (final node in html_parser.parseFragment(_contentHtml(body)).nodes.toList()) {
          node.remove();
          host.append(node);
        }
        final resolver = _FontResolver(document, ruleVariable, bodyVariable);
        for (final (element, text, what) in _renderedText([host, ...host.querySelectorAll('*')])) {
          for (final codepoint in _nonAscii(text)) {
            demand(codepoint, variables[resolver.variableFor(element)], '$source $what via $layout');
          }
        }
      }
    }
  }

  final byFamily = <String, List<_DeclaredFace>>{};
  for (final face in declared.where((f) => !f.italic)) {
    byFamily.putIfAbsent(_slug(face.family), () => []).add(face);
  }

  final gaps = <GlyphGap>[];
  for (final entry in demands.entries) {
    final (codepoint, family) = entry.key;
    for (final candidate in family == null ? byFamily.keys : [family]) {
      if (!byFamily.containsKey(candidate)) continue;
      // Last declared face whose range covers the codepoint wins, as in the cascade; a
      // family with no covering face cannot draw it at all.
      final face = byFamily[candidate]!.lastWhere(
        (f) => f.unicodeRange?.contains(codepoint) ?? true,
        orElse: () => byFamily[candidate]!.first,
      );
      final covered =
          (face.unicodeRange?.contains(codepoint) ?? true) && inspected[face.file]!.cmap.contains(codepoint);
      if (!covered) {
        gaps.add((codepoint: codepoint, source: '${entry.value} in $candidate', fix: ''));
      }
    }
  }

  String render(GlyphGap gap) => 'U+${gap.codepoint.toRadixString(16).toUpperCase().padLeft(4, '0')} ${gap.source}';
  expect(
    gaps.map(render).toList()..sort(),
    knownGaps.map(render).toList()..sort(),
    reason:
        'each theme glyph must be drawable by the family that renders it; the known gaps are '
        'layout/stylesheet fixes:\n${knownGaps.map((g) => '  ${render(g)} -> ${g.fix}').join('\n')}',
  );
}

/// The font variable in force for any element of one layout document.
///
/// Font family inherits, so the nearest ancestor carrying a rule wins; among rules on the
/// same element the last one in the stylesheet wins. Specificity is not modelled - the
/// themes set fonts with element and single-class selectors, where source order decides.
class _FontResolver {
  _FontResolver(this._document, Map<String, String> ruleVariable, this.fallback) {
    for (final entry in ruleVariable.entries) {
      for (final selector in _selectors(entry.key)) {
        _matches.add((_safeQuery(_document, selector).toSet(), entry.value));
      }
    }
  }

  final Document _document;
  final String fallback;
  final List<(Set<Element>, String)> _matches = [];

  String variableFor(Element element) {
    for (Element? node = element; node != null; node = node.parent) {
      for (final (elements, variable) in _matches.reversed) {
        if (elements.contains(node)) return variable;
      }
    }
    return fallback;
  }
}

/// The font style in force for an element, including the user-agent semantics
/// of `<em>`/`<i>` when the theme does not override it.
class _ItalicResolver {
  _ItalicResolver(this._document, Map<String, String> ruleStyles) {
    for (final entry in ruleStyles.entries) {
      if (entry.value != 'italic' && entry.value != 'normal') continue;
      for (final selector in _selectors(entry.key)) {
        _matches.add((_safeQuery(_document, selector).toSet(), entry.value == 'italic'));
      }
    }
  }

  final Document _document;
  final List<(Set<Element>, bool)> _matches = [];

  bool italicFor(Element element) {
    for (Element? node = element; node != null; node = node.parent) {
      for (final (elements, italic) in _matches.reversed) {
        if (elements.contains(node)) return italic;
      }
      if (node.localName == 'em' || node.localName == 'i') return true;
    }
    return false;
  }
}

/// Text a visitor reads, with the element whose font draws it.
///
/// `<title>` is chrome rather than page text, `<script>`/`<style>` are not drawn, and HTML
/// comments carry most of a theme's em dashes while rendering nothing. Attribute literals
/// count: a `tl:text` expression's quoted parts are concatenated into the output, and a
/// `placeholder` is drawn in the field's own font.
Iterable<(Element, String, String)> _renderedText(Iterable<Element> elements) sync* {
  for (final element in elements) {
    if (const {'title', 'script', 'style'}.contains(element.localName)) continue;
    for (final node in element.nodes.whereType<Text>()) {
      if (node.data.trim().isNotEmpty) yield (element, node.data, 'text in <${element.localName}>');
    }
    for (final entry in element.attributes.entries) {
      final name = entry.key.toString();
      if (name == 'placeholder') {
        yield (element, entry.value, '@placeholder');
      } else if (name.endsWith(':text') || name.endsWith(':utext') || name.endsWith(':attr')) {
        for (final literal in RegExp(r"'([^']*)'").allMatches(entry.value)) {
          yield (element, literal.group(1)!, '$name literal');
        }
      }
    }
  }
}

/// The element a layout binds `page.content` to, or null when it binds none.
///
/// Content is written into exactly one place per layout, and that place is what decides the
/// families authored text can land in.
Element? _contentHost(Document document) {
  for (final element in document.querySelectorAll('*')) {
    for (final entry in element.attributes.entries) {
      if (entry.key.toString().endsWith(':utext') && entry.value.contains('page.content')) return element;
    }
  }
  return null;
}

/// A content file split into (front matter, body); front matter is `''` when there is none.
///
/// The halves land in different elements - front matter in the chrome the layout builds,
/// the body in the content host - so they cannot be scanned as one string.
(String, String) _splitFrontMatter(String source) {
  final match = RegExp(r'^---[ \t]*\r?\n(.*?)\r?\n---[ \t]*\r?\n', dotAll: true).firstMatch(source);
  return match == null ? ('', source) : (match.group(1)!, source.substring(match.end));
}

/// Markdown as the elements the SSG renders it into.
///
/// Only the constructs that change font are modelled: a fenced block is `<pre><code>`, a
/// backtick span is `<code>`, an ATX heading is `<hN>`, and every other line is paragraph
/// text. Emphasis, links and list markers draw in the family already in force, so they are
/// left as text. Text is escaped, so the HTML examples the docs are full of stay text
/// instead of parsing into elements that would resolve fonts of their own.
String _contentHtml(String markdown) {
  final out = StringBuffer();
  var fenced = false;
  for (final line in const LineSplitter().convert(markdown)) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      out.write(fenced ? '</code></pre>' : '<pre><code>');
      fenced = !fenced;
    } else if (fenced) {
      out.writeln(_escapeHtml(line));
    } else {
      final heading = RegExp(r'^\s{0,3}(#{1,6})\s+(.*)$').firstMatch(line);
      final level = heading?.group(1)!.length;
      final inline = _inlineCode(heading?.group(2) ?? line);
      out.write(level == null ? '<p>$inline</p>' : '<h$level>$inline</h$level>');
    }
  }
  if (fenced) out.write('</code></pre>');
  return out.toString();
}

/// Backtick spans as `<code>`; an unclosed backtick just runs to the end of the line.
String _inlineCode(String line) {
  final out = StringBuffer();
  var code = false;
  for (final part in line.split('`')) {
    out.write(code ? '<code>${_escapeHtml(part)}</code>' : _escapeHtml(part));
    code = !code;
  }
  return out.toString();
}

String _escapeHtml(String value) => value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

/// Every string a theme substitutes into its layouts: `theme.yaml` parameter defaults, the
/// values of any `data/*.yaml` file, and the `theme_params` its own bridged example sets.
///
/// Comments are dropped by the YAML parse, so a note in the source is not mistaken for
/// rendered text - and, more usefully, `"\u2713"` is decoded to `✓` before it gets here.
/// Lattice shipped exactly that: the terminal-card prefixes were fixed in `theme.yaml` and
/// missed in the example, where they were escape-encoded, so a grep for the literal glyph
/// read clean and a non-ASCII byte scan saw six ASCII characters. Parsing sees through both.
///
/// The example's `theme_params` are in scope because the example is what the theme's own
/// `screenshots/` and the docs-site gallery copies are captured from, so a glyph that falls
/// back there ships as a picture. Example *content* (`example/content/**`) is not: that is
/// authored demo prose standing in for a site author's, and Meadow's `VENDORED.md` already
/// records its pictographs as knowingly reaching the system font.
Iterable<(String, Iterable<String>)> _themeStrings(String themeDir, List<String> extraConfigPaths) sync* {
  final manifest = loadYaml(File(p.join(themeDir, 'theme.yaml')).readAsStringSync()) as YamlMap;
  final params = manifest['params'];
  yield (
    'theme.yaml default',
    [
      if (params is YamlMap)
        for (final param in params.values)
          if (param is YamlMap) ..._strings(param['default']),
    ],
  );
  final example = File(p.join(themeDir, 'example', 'trellis_site.yaml'));
  if (example.existsSync()) {
    final config = loadYaml(example.readAsStringSync());
    yield ('example theme_params', config is YamlMap ? _strings(config['theme_params']) : const <String>[]);
  }
  for (final path in extraConfigPaths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final config = loadYaml(file.readAsStringSync());
    yield ('${p.basename(path)} theme_params', config is YamlMap ? _strings(config['theme_params']) : const <String>[]);
  }
  final dataDir = Directory(p.join(themeDir, 'data'));
  if (!dataDir.existsSync()) return;
  for (final file in dataDir.listSync().whereType<File>().where((f) => f.path.endsWith('.yaml'))) {
    yield ('data/${p.basename(file.path)}', _strings(loadYaml(file.readAsStringSync())));
  }
}

Iterable<String> _strings(Object? value) sync* {
  if (value is String) {
    yield value;
  } else if (value is YamlList) {
    for (final item in value) {
      yield* _strings(item);
    }
  } else if (value is YamlMap) {
    for (final item in value.values) {
      yield* _strings(item);
    }
  }
}

// ---------------------------------------------------------------------------
// Parsing
// ---------------------------------------------------------------------------

class _DeclaredFace {
  _DeclaredFace({
    required this.file,
    required this.family,
    required this.italic,
    required this.minWeight,
    required this.maxWeight,
    required this.unicodeRange,
  });

  final String file;
  final String family;
  final bool italic;
  final int minWeight;
  final int maxWeight;
  final Set<int>? unicodeRange;
}

List<_DeclaredFace> _declaredFaces(String css) {
  final faces = <_DeclaredFace>[];
  for (final block in RegExp(r'@font-face\s*\{([^}]*)\}').allMatches(css)) {
    final properties = _properties(block.group(1)!);
    final weights = properties['font-weight']!.split(RegExp(r'\s+')).map(int.parse).toList();
    final range = properties['unicode-range'];
    faces.add(
      _DeclaredFace(
        file: p.basename(RegExp(r'''url\(["']?([^"')]+)''').firstMatch(properties['src']!)!.group(1)!),
        family: _unquote(properties['font-family']!),
        italic: properties['font-style'] == 'italic',
        minWeight: weights.first,
        maxWeight: weights.last,
        unicodeRange: range == null ? null : _parseRange(range),
      ),
    );
  }
  expect(faces, isNotEmpty, reason: 'no @font-face blocks in the compiled stylesheet');
  return faces;
}

/// A declaration block as property -> whole value.
///
/// Substring matching on a rule body has a family of prefix traps - `column` inside
/// `column-reverse`, `pre-wrap` inside `pre-wrap nowrap` - so every read here goes through
/// a parsed value. The split tracks nesting and quoting because `url(data:…;base64,…)` and
/// `content: 'a;b'` both put a semicolon inside one declaration.
Map<String, String> _properties(String body) {
  final declarations = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  String? quote;
  for (final rune in body.runes) {
    final character = String.fromCharCode(rune);
    if (quote != null) {
      if (character == quote) quote = null;
    } else if (character == '"' || character == "'") {
      quote = character;
    } else if (character == '(') {
      depth++;
    } else if (character == ')') {
      depth--;
    } else if (character == ';' && depth == 0) {
      declarations.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(character);
  }
  declarations.add(buffer.toString());
  return {
    for (final declaration in declarations)
      if (declaration.contains(':'))
        declaration.substring(0, declaration.indexOf(':')).trim(): declaration
            .substring(declaration.indexOf(':') + 1)
            .trim(),
  };
}

Set<int> _parseRange(String value) {
  final out = <int>{};
  for (final token in value.split(',')) {
    final match = RegExp(r'^U\+([0-9A-Fa-f]+)(?:-([0-9A-Fa-f]+))?$').firstMatch(token.trim());
    expect(match, isNotNull, reason: 'unicode-range token "${token.trim()}"');
    final start = int.parse(match!.group(1)!, radix: 16);
    for (var cp = start; cp <= int.parse(match.group(2) ?? match.group(1)!, radix: 16); cp++) {
      out.add(cp);
    }
  }
  return out;
}

/// Codepoints as `U+XXXX`/`U+XXXX-YYYY` tokens, so a mismatch reads as the descriptor to
/// write rather than as two lists of several hundred integers.
String _formatRange(Iterable<int> codepoints) {
  final sorted = codepoints.toList()..sort();
  final tokens = <String>[];
  for (var i = 0; i < sorted.length; i++) {
    var end = i;
    while (end + 1 < sorted.length && sorted[end + 1] == sorted[end] + 1) {
      end++;
    }
    String hex(int cp) => 'U+${cp.toRadixString(16).toUpperCase().padLeft(4, '0')}';
    tokens.add(i == end ? hex(sorted[i]) : '${hex(sorted[i])}-${hex(sorted[end])}');
    i = end;
  }
  return tokens.join(', ');
}

typedef _Rule = ({String selector, Map<String, String> properties});

/// Declaration blocks in compiled CSS, skipping at-rule wrappers (whose bodies contain `{`).
///
/// Every rule is kept, including the ones nested in `@media`, and each is read through its
/// own selector. Looking a selector up instead - "the first rule that matches `.x`" - picks
/// whichever rule happens to come first, which may be a grouped rule declaring nothing of
/// what is being asserted.
List<_Rule> _leafRules(String css) => [
  for (final match in RegExp(r'([^{}]+)\{([^{}]*)\}').allMatches(css))
    // A leading `@charset`/at-rule opener shares the regex's first group.
    (selector: match.group(1)!.split(RegExp(r'[;}]')).last.trim(), properties: _properties(match.group(2)!)),
];

List<String> _selectors(String selector) => selector.split(',').map((s) => s.trim()).toList();

/// `querySelectorAll` for selectors csslib may not implement; an unsupported one matches
/// nothing rather than failing the suite for a rule that sets no font.
List<Element> _safeQuery(Document document, String selector) {
  try {
    return document.querySelectorAll(selector);
  } on Object {
    return const [];
  }
}

List<int> _nonAscii(String value) => [
  for (final rune in value.runes)
    if (rune > 0x7E && rune != 0xA0) rune,
];

String _unquote(String value) => value.trim().replaceAll(RegExp('''["']'''), '').split(',').first.trim();

String _slug(String? name) => (name ?? '').toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-');

/// `<family>-latin`, `<family>-latin-ext` and `<family>-italic-latin` all belong to
/// `<family>`; the style and subset suffixes are the only ones the vendoring uses.
String _familySlug(String stem) =>
    stem.replaceFirst(RegExp(r'-latin(-ext)?$'), '').replaceFirst(RegExp(r'-italic$'), '');

// ---------------------------------------------------------------------------
// WOFF2 inspection
// ---------------------------------------------------------------------------

typedef _Woff2 = ({
  String? family,
  double italicAngle,
  int numGlyphs,
  int weightClass,
  Map<String, List<num>> axes,
  Set<int> cmap,
});

/// Reads each face through `test/woff2_inspect.js`, or returns null when node is missing.
Future<Map<String, _Woff2>?> _inspect(String fontDir, List<String> files) async {
  final script = p.join(Directory.current.path, 'test', 'woff2_inspect.js');
  final ProcessResult result;
  try {
    result = await Process.run('node', [script, for (final file in files) p.join(fontDir, file)]);
  } on ProcessException {
    _requireNodeInCi();
    markTestSkipped('system node not found - the vendored font contract did not run');
    return null;
  }
  expect(result.exitCode, 0, reason: 'woff2_inspect.js failed: ${result.stdout}${result.stderr}');
  final decoded = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  return {
    for (final entry in decoded.entries)
      entry.key: (
        family: (entry.value as Map<String, dynamic>)['family'] as String?,
        italicAngle: ((entry.value as Map<String, dynamic>)['italicAngle'] as num).toDouble(),
        numGlyphs: (entry.value as Map<String, dynamic>)['numGlyphs'] as int,
        weightClass: (entry.value as Map<String, dynamic>)['weightClass'] as int,
        axes: {
          for (final axis in ((entry.value as Map<String, dynamic>)['axes'] as Map<String, dynamic>).entries)
            axis.key: (axis.value as List<dynamic>).cast<num>(),
        },
        cmap: ((entry.value as Map<String, dynamic>)['cmap'] as List<dynamic>).cast<int>().toSet(),
      ),
  };
}

/// Skipping a node-gated check is a local convenience; in CI it is a silent hole - the run
/// reports "All tests passed!" with the whole font contract never executed. Fail loudly
/// there instead, so the gate cannot go green on assertions that did not run.
void _requireNodeInCi() {
  if (Platform.environment['CI'] == 'true') {
    fail('node is required in CI: the vendored font contract did not run');
  }
}
