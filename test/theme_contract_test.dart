/// Invariants every bundled theme must satisfy, parameterized over `themes/*`.
///
/// Per-theme suites (`*_theme_contract_test.dart`) own what is particular to a
/// theme — its params, its mockup fidelity, its own components. This file owns
/// what is true of all of them, because the defects it covers are bug *classes*:
/// each was found in one theme, fixed there, and left standing in the other
/// five. A per-theme partition cannot catch that shape of defect, so the theme
/// list here is read from disk and never written down — a seventh theme is
/// covered the day it is added, with nobody remembering to add it.
///
/// The three classes:
///  1. Root-relative config values joined onto an asset base, emitting `//path`
///     — which a browser resolves as an *authority*, turning a site-config
///     string into a request to a foreign origin.
///  2. Horizontal overflow (WCAG 1.4.10 reflow), from unbreakable content tokens
///     at narrow widths and from layouts that stop fitting just above their own
///     breakpoints.
///  3. Progressive-enhancement controls that ship `hidden`, and in-page anchors
///     landing under a sticky masthead.
///
/// Classes 2 and 3 are measured in a real headless Chrome (see
/// `browser_reflow_probe.dart`). A stylesheet cannot answer them: a rule can be
/// present and neutralised by a grid track, or absent and compensated by an
/// ancestor. Reading CSS to decide whether a page overflows is how this release
/// twice produced a green suite over a broken page.
///
/// Class 2's widths and pass criterion come from `reflow_sweep.dart`, shared
/// with `site_reflow_test.dart` so the docs site is held to the same bar as the
/// themes rather than to a copy of it.
@Timeout(Duration(minutes: 20))
library;

import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' show Document, Element;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'browser_reflow_probe.dart';
import 'reflow_sweep.dart';

/// An unbreakable identifier and a long URL, the two shapes real content
/// produces: a package name and a deep documentation link.
const _longToken = 'an_unbreakable_token_of_seventy_two_characters_0123456789abcdefghij';
const _longUrl = 'https://example.com/packages/trellis_site/reference/$_longToken/deep/path/';

/// Stand-in for a site-supplied, root-relative asset path.
///
/// The leading slash is the whole point: joined naively onto an asset base that
/// already ends in `/`, it becomes `//img/spec.svg` and the browser fetches
/// `http://img/spec.svg`.
const _rootedAsset = '/img/spec.svg';

void main() {
  final root = Directory.current.path;
  final themes = _discoverThemes(root);
  final workspace = Directory.systemTemp.createTempSync('theme_contract_');
  final cli = p.join(workspace.path, 'trellis_cli.dill');

  BrowserProbe? probe;
  final defaultBuilds = <String, String>{};

  setUpAll(() async {
    // One kernel snapshot for every build below: `dart run <source>` re-JITs the
    // CLI each time (2.4s), `dart run <dill>` does not (0.4s).
    final compile = await Process.run('dart', [
      'compile',
      'kernel',
      p.join(root, 'packages', 'trellis_cli', 'bin', 'trellis.dart'),
      '-o',
      cli,
    ], workingDirectory: root);
    expect(compile.exitCode, 0, reason: '${compile.stdout}${compile.stderr}');

    for (final theme in themes) {
      defaultBuilds[theme.name] = await _build(
        theme,
        cli: cli,
        workspace: workspace,
        label: 'default',
        rewriteMarkdown: _appendLongToken,
      );
    }
    if (BrowserProbe.locateChrome() != null) probe = await BrowserProbe.launch();
  });

  tearDownAll(() async {
    await probe?.close();
    if (workspace.existsSync()) workspace.deleteSync(recursive: true);
  });

  test('every theme on disk is under contract', () {
    // The failure this file exists to prevent starts with a hardcoded list, so
    // the list is derived — and this asserts the derivation actually found the
    // themes rather than silently matching nothing.
    final onDisk = Directory(p.join(root, 'themes'))
        .listSync()
        .whereType<Directory>()
        .map((entry) => p.basename(entry.path))
        .where((name) => !name.startsWith('.'))
        .toSet();
    expect(themes.map((theme) => theme.name).toSet(), onDisk);
    expect(themes, isNotEmpty);
    for (final theme in themes) {
      expect(theme.manifestName, theme.name, reason: '${theme.name}/theme.yaml declares a different name');
    }
  });

  for (final theme in themes) {
    group(theme.name, () {
      // ── Class 1 ────────────────────────────────────────────────────────────
      test('root-relative config values never emit a protocol-relative URL', () async {
        for (final prefix in ['', '/trellis/']) {
          final output = await _build(
            theme,
            cli: cli,
            workspace: workspace,
            label: 'rooted${prefix.isEmpty ? 'Root' : 'Prefix'}',
            pathPrefix: prefix,
            rootAllAssetPaths: true,
          );
          for (final page in builtPages(output)) {
            final document = html_parser.parse(File(p.join(output, page)).readAsStringSync());
            for (final (element, name, value) in _urlAttributes(document)) {
              expect(
                _pathOf(value),
                isNot(contains('//')),
                reason:
                    '${theme.name} $page (pathPrefix "$prefix"): '
                    '<${element.localName} $name="$value"> — a browser reads a leading // as an authority',
              );
            }
          }
        }
      });

      test('every asset-base join decides what to do with a leading slash', () {
        // The rendered check above can only cover joins the bundled example
        // exercises; a join whose value the example never sets is exactly the one
        // that ships unguarded. This one covers every join in the source, and asks
        // only that the value passes through a `#strings.startsWith` test — either
        // shedding a leading slash before the join, or reaching the join solely on
        // a branch where it cannot have one. Whether the decision is *correct* is
        // what the rendered check answers.
        final unguarded = <String>[];
        for (final layout in theme.layouts) {
          final source = File(layout).readAsStringSync();
          final bases = _assetBaseNames(source);
          if (bases.isEmpty) continue;
          for (final element in html_parser.parse(source).querySelectorAll('*')) {
            final bindings = _withBindings(element);
            for (final attribute in element.attributes.entries) {
              for (final (base, variable) in _assetBaseJoins(attribute.value, bases)) {
                if (_decidesOnLeadingSlash(attribute.value, variable, bindings)) continue;
                unguarded.add(
                  '${p.relative(layout, from: root)} '
                  '<${element.localName} ${attribute.key}>: \${$base} + \${$variable}',
                );
              }
            }
          }
        }
        expect(unguarded, isEmpty, reason: 'asset-base joins that never test for a leading slash');
      });

      // ── Class 2 ────────────────────────────────────────────────────────────
      test('content with unbreakable tokens does not overflow a narrow viewport', () async {
        final browser = probe;
        if (browser == null) {
          requireChromeInCi('${theme.name} narrow-viewport reflow');
          markTestSkipped('no Chrome/Chromium found – narrow-viewport reflow not measured');
          return;
        }
        final outputs = <String, String>{'example': defaultBuilds[theme.name]!};
        for (final fixture in theme.fixtures) {
          outputs['fixtures/$fixture'] = await _build(
            theme,
            cli: cli,
            workspace: workspace,
            label: 'fixture-$fixture',
            fixture: fixture,
          );
        }
        for (final entry in outputs.entries) {
          await expectNoOverflow(
            browser,
            servedRoot: entry.value,
            pages: builtPages(entry.value),
            viewports: narrowViewports,
            label: '${theme.name} ${entry.key}',
          );
        }
      });

      test('the layout does not overflow just above its own breakpoints', () async {
        final browser = probe;
        if (browser == null) {
          requireChromeInCi('${theme.name} breakpoint-band reflow');
          markTestSkipped('no Chrome/Chromium found – breakpoint-band reflow not measured');
          return;
        }
        final output = defaultBuilds[theme.name]!;
        final probeWidths = breakpointProbeWidths([File(p.join(output, 'css', 'main.css'))]);
        // Without this, a sheet the width parser cannot read shrinks the sweep to
        // the fixed narrow widths and still reports green. Every theme here is
        // responsive and declares breakpoints; none legitimately declares zero.
        expect(
          probeWidths,
          isNotEmpty,
          reason: '${theme.name}: no @media width breakpoints parsed out of the compiled sheet',
        );
        await expectNoOverflow(
          browser,
          servedRoot: output,
          pages: representativePages(output),
          viewports: {...narrowViewports, for (final width in probeWidths) width: 900},
          label: '${theme.name} breakpoint bands',
        );
      });

      // ── Class 3 ────────────────────────────────────────────────────────────
      test('no control is left visible for a reader whose JavaScript never ran', () async {
        // Two shapes of the same defect. `hidden` is the one a stray `display`
        // rule silently defeats — adding `display: flex` to a shell that ships
        // `hidden` reveals a broken control with the suite green. `disabled` is the
        // one Arbor shipped: a static site has no server-side form state, so a
        // control that arrives disabled can only be waiting for a script, and if
        // that script never runs the reader is looking at a dead affordance.
        final browser = probe;
        final output = defaultBuilds[theme.name]!;
        final pages = builtPages(output).where((page) {
          return html_parser
              .parse(File(p.join(output, page)).readAsStringSync())
              .querySelectorAll('[hidden], [disabled]')
              .isNotEmpty;
        }).toList();
        if (pages.isEmpty) return; // A theme with no such control asserts nothing.
        if (browser == null) {
          requireChromeInCi('${theme.name} script-less control visibility');
          markTestSkipped('no Chrome/Chromium found – control visibility not measured');
          return;
        }
        final server = await StaticSiteServer.serve(Directory(output));
        addTearDown(server.close);
        for (final page in pages) {
          final revealed = await browser.evaluate(
            pageUrl(server.baseUrl, page),
            r'''Array.from(document.querySelectorAll('[hidden], [disabled]'))
                 .filter((el) => el.getClientRects().length > 0)
                 .map((el) => (el.hasAttribute('hidden') ? 'hidden ' : 'disabled ') +
                      el.tagName.toLowerCase() + '.' + (el.className || '(no class)'))''',
            width: 390,
            height: 844,
            // The whole question is what a reader without JavaScript sees. Leaving
            // scripts on races them: search.js reveals its shell after a fetch that
            // resolves some time after the load event, so the same assertion reads
            // the pre-script DOM on one run and the post-script DOM on the next.
            disableScripts: true,
          );
          expect(
            revealed,
            isEmpty,
            reason:
                '${theme.name} $page: this control is visible to a reader whose JavaScript never ran. '
                'Ship the shell `hidden` and reveal it from the script, and normalize with '
                '`[hidden] { display: none !important; }` so an author `display` rule cannot '
                'silently beat the UA sheet.',
          );
        }
      });

      test('in-page anchors land clear of a sticky masthead', () async {
        final browser = probe;
        if (browser == null) {
          requireChromeInCi('${theme.name} sticky-header anchor offset');
          markTestSkipped('no Chrome/Chromium found – anchor offset not measured');
          return;
        }
        final output = defaultBuilds[theme.name]!;
        final pages = builtPages(output);

        final server = await StaticSiteServer.serve(Directory(output));
        addTearDown(server.close);
        final offenders = <String>[];
        var sticky = false;
        var checked = 0;
        for (final page in pages) {
          var navigated = false;
          // A masthead is tallest where it wraps, and that is not the same width for
          // every theme: Verdant's is 67px at 390 and 103px at 320, so a single-width
          // check passes on an offset that is too small for a phone.
          for (final viewport in narrowViewports.entries) {
            final measurement =
                (navigated
                        ? await browser.evaluateHere(
                            _anchorOffsetExpression,
                            width: viewport.key,
                            height: viewport.value,
                          )
                        : await browser.evaluate(
                            pageUrl(server.baseUrl, page),
                            _anchorOffsetExpression,
                            width: viewport.key,
                            height: viewport.value,
                          ))!
                    as Map;
            navigated = true;
            if (measurement['sticky'] != true) continue;
            sticky = true;
            checked += measurement['checked'] as int;
            offenders.addAll((measurement['offenders'] as List).map((entry) => '$page at ${viewport.key}px $entry'));
          }
        }
        expect(
          offenders,
          isEmpty,
          reason:
              '${theme.name}: the heading these in-page links target sits under the sticky masthead. '
              'Set scroll-padding-top on the scrolling element (or scroll-margin-top on headings) to at '
              'least the masthead height.',
        );
        // Every anchor landing at scroll 0 means nothing was actually measured — a
        // theme whose sheet lost its offset would still report green here.
        if (sticky) {
          expect(checked, greaterThan(0), reason: '${theme.name}: sticky masthead, but no anchor scrolled the page');
        }
      });
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Discovery
// ─────────────────────────────────────────────────────────────────────────────

/// A bundled theme, as found on disk.
class _Theme {
  _Theme(this.dir, this.manifest);

  final String dir;
  final Map<String, Object?> manifest;

  String get name => p.basename(dir);
  String get manifestName => manifest['name'] as String? ?? '';

  Map<String, Object?> get params => (manifest['params'] as Map?)?.cast<String, Object?>() ?? const {};

  /// Every layout template the theme ships, at any nesting depth.
  List<String> get layouts => Directory(p.join(dir, 'layouts')).existsSync()
      ? (Directory(p.join(dir, 'layouts'))
            .listSync(recursive: true)
            .whereType<File>()
            .map((f) => f.path)
            .where((path) => path.endsWith('.html'))
            .toList()
          ..sort())
      : const [];

  /// Config and front-matter keys whose value this theme turns into a URL.
  ///
  /// Two sources, both derived: the generic naming convention, and the theme's
  /// own layouts — every value it joins onto an asset base or feeds to the
  /// leading-slash guard. Reading the emitting source is what covers a key a
  /// convention would miss (Lattice's `screenshot_light`), and it keeps a
  /// seventh theme's vocabulary in scope without an edit here.
  Set<String> get urlValuedKeys {
    final keys = <String>{};
    for (final layout in layouts) {
      final source = File(layout).readAsStringSync();
      for (final base in _assetBaseNames(source)) {
        for (final match in RegExp(
          r'\$\{'
          '$base'
          r'\}\s*\+\s*\$\{([\w.]+)\}',
        ).allMatches(source)) {
          keys.add(match[1]!.split('.').last);
        }
      }
      for (final match in RegExp(r'#strings\.(?:startsWith|substring)\(\s*([\w.]+)\s*,').allMatches(source)) {
        keys.add(match[1]!.split('.').last);
      }
    }
    return {...keys, ..._conventionalUrlKeys};
  }

  static const _conventionalUrlKeys = {'url', 'href', 'src', 'logo', 'favicon', 'image', 'icon', 'poster'};

  /// Names under `example/fixtures/`, each a replacement `content/_index.md`.
  List<String> get fixtures {
    final dir = Directory(p.join(this.dir, 'example', 'fixtures'));
    if (!dir.existsSync()) return const [];
    return dir
        .listSync()
        .whereType<Directory>()
        .where((entry) => File(p.join(entry.path, '_index.md')).existsSync())
        .map((entry) => p.basename(entry.path))
        .toList()
      ..sort();
  }
}

List<_Theme> _discoverThemes(String root) {
  final themesDir = Directory(p.join(root, 'themes'));
  final themes =
      themesDir
          .listSync()
          .whereType<Directory>()
          .where((entry) => File(p.join(entry.path, 'theme.yaml')).existsSync())
          .map(
            (entry) => _Theme(
              entry.path,
              (loadYaml(File(p.join(entry.path, 'theme.yaml')).readAsStringSync()) as YamlMap).cast<String, Object?>(),
            ),
          )
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));
  return themes;
}

// ─────────────────────────────────────────────────────────────────────────────
// Building
// ─────────────────────────────────────────────────────────────────────────────

/// Build a theme's bundled example into [workspace], returning the output dir.
///
/// The theme is reached through a symlink, as the per-theme suites do, and the
/// output goes to a sibling directory — never through the link, so a build can
/// never write back into the repository.
Future<String> _build(
  _Theme theme, {
  required String cli,
  required Directory workspace,
  required String label,
  String pathPrefix = '',
  String? fixture,
  bool rootAllAssetPaths = false,
  String Function(String body)? rewriteMarkdown,
}) async {
  final site = Directory(p.join(workspace.path, '${theme.name}-$label'))..createSync(recursive: true);
  final example = p.join(theme.dir, 'example');

  if (fixture == null) {
    _copy(Directory(p.join(example, 'content')), Directory(p.join(site.path, 'content')));
  } else {
    Directory(p.join(site.path, 'content')).createSync(recursive: true);
    File(p.join(example, 'fixtures', fixture, '_index.md')).copySync(p.join(site.path, 'content', '_index.md'));
  }
  for (final extra in ['static', 'data', 'layouts']) {
    final source = Directory(p.join(example, extra));
    if (source.existsSync()) _copy(source, Directory(p.join(site.path, extra)));
  }
  // Theme-level data is a whole-file default a site replaces; copying it into
  // the site's own data/ is how a site overrides it, and the only way this
  // suite can rewrite the URLs it carries without touching the repository.
  final themeData = Directory(p.join(theme.dir, 'data'));
  if (themeData.existsSync()) {
    final siteData = Directory(p.join(site.path, 'data'))..createSync(recursive: true);
    for (final file in themeData.listSync().whereType<File>()) {
      final target = File(p.join(siteData.path, p.basename(file.path)));
      if (!target.existsSync()) file.copySync(target.path);
    }
  }
  Directory(p.join(site.path, 'themes')).createSync(recursive: true);
  Link(p.join(site.path, 'themes', theme.name)).createSync(theme.dir);

  var config = (_plain(loadYaml(File(p.join(example, 'trellis_site.yaml')).readAsStringSync()))! as Map)
      .cast<String, Object?>();
  if (rootAllAssetPaths) {
    final urlKeys = theme.urlValuedKeys;
    config = (_rootAssetPaths(config, urlKeys)! as Map).cast<String, Object?>();
    final params = (config['theme_params'] as Map?)?.cast<String, Object?>() ?? <String, Object?>{};
    // Params the example leaves unset are exactly the joins that ship
    // unexercised, so set every URL-valued string param the manifest declares.
    for (final entry in theme.params.entries) {
      final declared = entry.value;
      final isString = declared is Map && declared['type'] == 'string';
      if (isString && urlKeys.contains(entry.key)) params[entry.key] = _rootedAsset;
    }
    config['theme_params'] = params;
    for (final data
        in Directory(p.join(site.path, 'data')).existsSync()
            ? Directory(p.join(site.path, 'data')).listSync(recursive: true).whereType<File>()
            : <File>[]) {
      if (!data.path.endsWith('.yaml') && !data.path.endsWith('.yml')) continue;
      data.writeAsStringSync(jsonEncode(_rootAssetPaths(_plain(loadYaml(data.readAsStringSync())), urlKeys)));
    }
  }
  // JSON is valid YAML, so re-emitting the transformed tree needs no writer.
  File(p.join(site.path, 'trellis_site.yaml')).writeAsStringSync(jsonEncode(config));

  for (final markdown in Directory(
    p.join(site.path, 'content'),
  ).listSync(recursive: true).whereType<File>().where((file) => file.path.endsWith('.md'))) {
    var source = markdown.readAsStringSync();
    if (rootAllAssetPaths) source = _rootFrontMatterAssetPaths(source, theme.urlValuedKeys);
    if (rewriteMarkdown != null) source = rewriteMarkdown(source);
    markdown.writeAsStringSync(source);
  }

  final output = p.join(site.path, 'built');
  final build = await Process.run('dart', [
    'run',
    cli,
    'build',
    '--verbose',
    '--path-prefix',
    pathPrefix,
    '--output',
    output,
  ], workingDirectory: site.path);
  expect(build.exitCode, 0, reason: '${theme.name}/$label: ${build.stdout}${build.stderr}');
  expect('${build.stdout}${build.stderr}'.toLowerCase(), isNot(contains('warning')), reason: '${theme.name}/$label');
  return output;
}

/// Put the long token everywhere real content could carry one.
///
/// Appending to the Markdown body alone only reaches prose. A landing page's
/// copy lives in front matter and renders into cards, grids and terminal panes —
/// the min-content-sized tracks where `overflow-wrap: break-word` is *not*
/// enough and `anywhere` is. Prose values are recognised by containing a space,
/// which leaves identifiers (`layout: home`), enums and URLs untouched.
String _appendLongToken(String source) {
  final match = RegExp(r'^---\r?\n([\s\S]*?)\r?\n---\r?\n').firstMatch(source);
  final body =
      '${match == null ? source : source.substring(match.end)}'
      '\n\nReference: $_longUrl and $_longToken.\n';
  if (match == null) return body;
  final front = _plain(loadYaml(match[1]!));
  if (front == null) return '---\n${match[1]}\n---\n$body';
  return '---\n${jsonEncode(_lengthenProse(front))}\n---\n$body';
}

Object? _lengthenProse(Object? node, [String? key]) => switch (node) {
  final Map<Object?, Object?> map => {
    for (final entry in map.entries) entry.key: _lengthenProse(entry.value, entry.key as String?),
  },
  final List<Object?> list => [for (final item in list) _lengthenProse(item, key)],
  final String text when text.contains(' ') && !_looksLikeUrl(text) => '$text $_longToken',
  _ => node,
};

bool _looksLikeUrl(String value) => value.startsWith('/') || value.startsWith('#') || value.contains('://');

void _copy(Directory source, Directory destination) {
  destination.createSync(recursive: true);
  for (final entity in source.listSync()) {
    final target = p.join(destination.path, p.basename(entity.path));
    if (entity is Directory) {
      _copy(entity, Directory(target));
    } else if (entity is File) {
      entity.copySync(target);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Class 1 helpers
// ─────────────────────────────────────────────────────────────────────────────

/// True for a value the site serves itself, as opposed to an external URL, an
/// in-page fragment, or a non-http scheme.
bool _isSiteRelative(String value) =>
    value.isNotEmpty &&
    !value.contains('://') &&
    !value.startsWith('#') &&
    !RegExp(r'^[a-zA-Z][\w+.-]*:').hasMatch(value);

Object? _rootAssetPaths(Object? node, Set<String> urlKeys) => switch (node) {
  final Map<Object?, Object?> map => {
    for (final entry in map.entries)
      entry.key:
          (entry.key is String &&
              urlKeys.contains(entry.key) &&
              entry.value is String &&
              _isSiteRelative(entry.value! as String))
          ? '/${(entry.value! as String).replaceFirst(RegExp('^/+'), '')}'
          : _rootAssetPaths(entry.value, urlKeys),
  },
  final List<Object?> list => [for (final item in list) _rootAssetPaths(item, urlKeys)],
  _ => node,
};

/// Rewrite the YAML front matter of [source], leaving the Markdown body alone.
String _rootFrontMatterAssetPaths(String source, Set<String> urlKeys) {
  final match = RegExp(r'^---\r?\n([\s\S]*?)\r?\n---\r?\n').firstMatch(source);
  if (match == null) return source;
  final front = loadYaml(match[1]!);
  if (front == null) return source;
  return '---\n${jsonEncode(_rootAssetPaths(_plain(front), urlKeys))}\n---\n${source.substring(match.end)}';
}

/// Strip the `Yaml*` wrapper types so the tree is plain maps, lists and scalars.
Object? _plain(Object? node) => switch (node) {
  final YamlMap map => {for (final entry in map.entries) entry.key: _plain(entry.value)},
  final YamlList list => list.map(_plain).toList(),
  final YamlScalar scalar => scalar.value,
  _ => node,
};

/// Attributes whose value is a URL and could therefore carry an authority.
///
/// Values containing whitespace are prose (a meta description, a viewport
/// directive) rather than URLs — checking them would report `//` in a sentence.
Iterable<(Element, String, String)> _urlAttributes(Document document) sync* {
  const names = {'src', 'href', 'content', 'poster', 'action', 'formaction'};
  for (final element in document.querySelectorAll('*')) {
    for (final entry in element.attributes.entries) {
      final name = entry.key.toString();
      if (!names.contains(name) && !name.startsWith('data-')) continue;
      final value = entry.value;
      if (value.contains(RegExp(r'\s')) || !value.contains('/')) continue;
      yield (element, name, value);
    }
  }
}

/// The path component of [value], with any scheme and authority removed, so a
/// legitimate `https://host/a` is not read as containing `//`.
String _pathOf(String value) {
  if (value.startsWith('//')) return value; // Protocol-relative: the defect itself.
  final scheme = RegExp(r'^[a-zA-Z][\w+.-]*://[^/]*').firstMatch(value);
  return scheme == null ? value : value.substring(scheme.end);
}

/// Names bound to the asset-base idiom (`pathPrefix`, or `/` at a root deploy).
Iterable<String> _assetBaseNames(String layout) => RegExp(
  r'([\w]+)\s*=\s*\$\{site\.pathPrefix\}\s*==\s*'
  "''"
  r'\s*\?\s*'
  "'/'"
  r'\s*:\s*\$\{site\.pathPrefix\}',
).allMatches(layout).map((match) => match[1]!).toSet();

/// Every `${base} + ${variable}` join in one attribute value, for any of [bases].
///
/// A join onto a string literal (`${assetBase} + 'css/main.css'`) cannot carry a
/// leading slash and is not reported.
Iterable<(String, String)> _assetBaseJoins(String value, Iterable<String> bases) sync* {
  for (final base in bases) {
    for (final match in RegExp(r'\$\{' + RegExp.escape(base) + r'\}\s*\+\s*\$\{([\w.]+)\}').allMatches(value)) {
      yield (base, match[1]!);
    }
  }
}

/// The `tl:with` bindings declared on [element], as name to expression.
Map<String, String> _withBindings(Element element) {
  final source = element.attributes.entries
      .firstWhere((entry) => entry.key.toString() == 'tl:with', orElse: () => const MapEntry('', ''))
      .value;
  final bindings = <String, String>{};
  for (final binding in _splitTopLevel(source)) {
    final separator = binding.indexOf('=');
    if (separator > 0) bindings[binding.substring(0, separator).trim()] = binding.substring(separator + 1);
  }
  return bindings;
}

/// Split on commas that are not inside `(...)` or `${...}`.
///
/// `#strings.substring(theme.logo, 1)` carries a comma of its own; splitting on
/// every comma would cut a binding in half.
List<String> _splitTopLevel(String source) {
  final parts = <String>[];
  final buffer = StringBuffer();
  var depth = 0;
  for (final rune in source.runes) {
    final character = String.fromCharCode(rune);
    if (character == '(' || character == '{') depth++;
    if (character == ')' || character == '}') depth--;
    if (character == ',' && depth == 0) {
      parts.add(buffer.toString());
      buffer.clear();
    } else {
      buffer.write(character);
    }
  }
  if (buffer.isNotEmpty) parts.add(buffer.toString());
  return parts;
}

/// True when [variable] reaches its join having been tested for a leading slash.
///
/// Either the attribute itself branches on the value's first character (Meadow's
/// nav joins only on `#`-anchors), or the value was rebound through the
/// shed-the-slash idiom — possibly a binding or two back, as Lattice's
/// light/dark screenshot pair is.
bool _decidesOnLeadingSlash(String attributeValue, String variable, Map<String, String> bindings, [int depth = 0]) {
  if (attributeValue.contains('#strings.startsWith(')) return true;
  if (depth > 3) return false;
  final binding = bindings[variable];
  if (binding == null) return false;
  if (binding.contains('#strings.startsWith(')) return true;
  return RegExp(r'\$\{([\w.]+)\}')
      .allMatches(binding)
      .map((match) => match[1]!)
      .any((reference) => _decidesOnLeadingSlash('', reference, bindings, depth + 1));
}

// ─────────────────────────────────────────────────────────────────────────────
// Sticky-anchor measurement
// ─────────────────────────────────────────────────────────────────────────────

/// Scroll to every distinct in-page anchor on the loaded page and report the ones
/// whose target ends up behind the sticky masthead.
///
/// Runs entirely in the page so a whole document's anchors cost one navigation.
/// Notes on the two ways this measurement goes wrong:
///  * `scroll-behavior: smooth` makes `location.hash` scroll over several frames,
///    so a rect read straight afterwards is mid-animation. Forced to `auto` first.
///  * An anchor whose target is already at the document top cannot be hidden by
///    anything — the page has nowhere above 0 to scroll to. Those are skipped
///    rather than counted, and `checked` reports how many really were measured.
const _anchorOffsetExpression = r'''(() => {
  const header = document.querySelector('header, [role="banner"]');
  if (header === null || getComputedStyle(header).position !== 'sticky') return {sticky: false};
  document.documentElement.style.scrollBehavior = 'auto';
  const skipLink = document.querySelector('a[href^="#"][class*="skip"]');
  const skipTarget = skipLink === null ? null : skipLink.getAttribute('href');
  const fragments = [];
  for (const anchor of document.querySelectorAll('a[href^="#"]')) fragments.push(anchor.getAttribute('href'));
  // Headings the SSG gave an id to are deep-linkable whether or not the theme
  // renders a table of contents, so a theme without one is still measured rather
  // than silently passing on an empty anchor list.
  for (const heading of document.querySelectorAll('main :is(h1,h2,h3,h4,h5,h6)[id]')) {
    fragments.push('#' + heading.id);
  }
  const offenders = [];
  const seen = new Set();
  let checked = 0;
  for (const href of fragments) {
    if (href === '#' || href === skipTarget || seen.has(href)) continue;
    seen.add(href);
    const target = document.getElementById(decodeURIComponent(href.slice(1)));
    if (target === null) continue;
    window.scrollTo(0, 0);
    location.hash = href;
    if (window.scrollY === 0) continue;
    checked++;
    const top = target.getBoundingClientRect().top;
    const headerBottom = header.getBoundingClientRect().bottom;
    if (top < headerBottom - 0.5) {
      offenders.push(href + ' (target top ' + Math.round(top) + ', masthead bottom ' + Math.round(headerBottom) + ')');
    }
  }
  return {sticky: true, checked, offenders};
})()''';
