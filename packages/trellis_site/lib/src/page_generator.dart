import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:trellis/trellis.dart';
import 'package:yaml/yaml.dart';

import 'content_discovery.dart' show applyPathPrefixToLinks, stripPathPrefix;
import 'navigation_builder.dart' show humanizeSegment, nodeTitleFor;
import 'page.dart';
import 'paginator.dart';
import 'trellis_site_builder.dart' show BuildWarning;
import 'yaml_utils.dart';

/// Thrown when no layout template can be found for a page.
class TemplateNotFoundException implements Exception {
  /// A human-readable error message.
  final String message;

  /// The URL of the page for which no layout was found, if available.
  final String? pageUrl;

  /// The list of template paths that were tried, in priority order.
  final List<String> tried;

  const TemplateNotFoundException(this.message, {this.pageUrl, this.tried = const []});

  @override
  String toString() {
    final parts = ['TemplateNotFoundException: $message'];
    if (pageUrl != null) parts.add('  page: $pageUrl');
    if (tried.isNotEmpty) parts.add('  tried: ${tried.join(', ')}');
    return parts.join('\n');
  }
}

/// Generates rendered HTML pages from a list of [Page] objects.
///
/// Resolves templates using a priority-ordered lookup, builds the data context
/// (data cascade), renders via the Trellis engine, and writes output files.
///
/// Example:
/// ```dart
/// final generator = PageGenerator(
///   siteDir: '/path/to/my_site',
///   outputDir: '/path/to/my_site/output',
/// );
/// await generator.generateAll(pages);
/// ```
class PageGenerator {
  /// The site root directory (parent of `layouts/`, `data/`, `output/`).
  final String siteDir;

  /// The output directory where rendered pages are written.
  final String outputDir;

  /// The layouts directory. Defaults to `siteDir/layouts`.
  final String layoutsDir;

  /// The global data directory. Defaults to `siteDir/data`.
  final String dataDir;

  /// Site-level params (lowest priority in data cascade).
  final Map<String, dynamic> siteParams;

  /// Items per page for list pages. `null` disables pagination.
  final int? paginate;

  /// Additional layout directories checked after [layoutsDir] (theme fallback).
  final List<String> layoutSearchPaths;

  /// Optional theme data directory (fallback for global data files).
  final String? themeDataDir;

  /// The URL path-prefix carried by emitted [Page.url] values (e.g. `/trellis/`).
  ///
  /// Emitted URLs keep the prefix, but it is stripped when deriving output file
  /// locations so files are written at their unprefixed paths — the host serves
  /// the artifact root under the prefix (see [stripPathPrefix]). Defaults to `''`
  /// (no prefix), which is a literal no-op.
  final String pathPrefix;

  /// Non-fatal warnings accumulated during generation.
  ///
  /// Currently populated by [generateAll] when a page declares a malformed
  /// `weight` front-matter value (treated as unweighted; see [pageWeight]).
  final List<BuildWarning> warnings = [];

  /// Absolute paths of the HTML files the last [generateAll] pass wrote.
  ///
  /// Every entry is a page this generator rendered, so a caller inspecting the
  /// build's own output never picks up a file that was merely copied in from a
  /// `static/` directory. Includes the extra files a paginated page emits.
  /// Reset at the start of each pass.
  final List<String> emittedPages = [];

  late final Trellis _engine;

  /// Per-`sectionPath` memo of [orderedSectionPages], valid for one
  /// [generateAll] pass. Cleared at the start of every pass so a reused
  /// generator never serves an ordering computed from an earlier page set.
  final Map<String, List<Page>> _sectionOrderCache = {};

  /// Creates a [PageGenerator].
  ///
  /// [layoutsDir] defaults to `path.join(siteDir, 'layouts')`.
  /// [dataDir] defaults to `path.join(siteDir, 'data')`.
  /// [siteParams] defaults to an empty map.
  /// [paginate] defaults to `null` (no pagination).
  /// [loader] overrides the default [FileSystemLoader] for theme-aware resolution.
  /// [layoutSearchPaths] adds additional layout directories (e.g., theme layouts).
  /// [themeDataDir] adds a theme data directory as a fallback for global data.
  PageGenerator({
    required this.siteDir,
    required this.outputDir,
    Map<String, dynamic>? siteParams,
    String? layoutsDir,
    String? dataDir,
    this.paginate,
    TemplateLoader? loader,
    List<String>? layoutSearchPaths,
    this.themeDataDir,
    this.pathPrefix = '',
  }) : siteParams = siteParams ?? const {},
       layoutsDir = layoutsDir ?? p.join(siteDir, 'layouts'),
       dataDir = dataDir ?? p.join(siteDir, 'data'),
       layoutSearchPaths = layoutSearchPaths ?? [] {
    _engine = Trellis(loader: loader ?? FileSystemLoader(siteDir));
  }

  /// Generates all non-draft pages, writing rendered HTML to [outputDir].
  ///
  /// Skips pages with [Page.isDraft] set to `true`.
  /// List pages (section, home, taxonomy term) are paginated when [paginate] is set.
  /// Throws [TemplateNotFoundException] if no layout is found for a page.
  ///
  /// Returns the total number of output HTML files written (including all paginated pages).
  Future<int> generateAll(List<Page> pages) async {
    _sectionOrderCache.clear();
    // A reused generator must not report files from an earlier pass — the output
    // directory is cleaned between builds, so those paths no longer exist.
    emittedPages.clear();
    final globalData = _loadGlobalData();
    final nonDraftPages = pages.where((pg) => !pg.isDraft).toList();
    _collectWeightWarnings(nonDraftPages);
    var outputCount = 0;

    for (final page in nonDraftPages) {
      if (_isListPage(page)) {
        outputCount += await _generatePaginatedPage(page, nonDraftPages, globalData);
      } else {
        final templateName = resolveLayout(page);
        final context = _buildContext(page, nonDraftPages, globalData);
        final html = await _engine.renderFile(templateName, context);
        _writeOutput(page.url, html);
        outputCount++;
      }
    }

    return outputCount;
  }

  /// Scans [pages] once and records a [BuildWarning] for every page whose
  /// `weight` front-matter value is present but not a valid integer.
  ///
  /// Malformed weights are treated as unweighted by [pageWeight]; this pass
  /// exists only to surface the warning (naming the offending page) without the
  /// comparator — called O(n log n) times — emitting duplicates.
  void _collectWeightWarnings(List<Page> pages) {
    for (final page in pages) {
      if (!page.frontMatter.containsKey('weight')) continue;
      if (pageWeight(page) == null) {
        warnings.add(
          BuildWarning(
            "Malformed 'weight' front-matter value "
            '(${page.frontMatter['weight']}); treated as unweighted',
            context: page.url,
          ),
        );
      }
    }
  }

  /// Returns `true` if [page] is a list-type page that should be paginated.
  ///
  /// List pages include section listings, the home page, and taxonomy term
  /// pages (detected by `frontMatter['termName']` set by the taxonomy pipeline).
  bool _isListPage(Page page) {
    if (page.kind == PageKind.section || page.kind == PageKind.home) return true;
    if (page.frontMatter.containsKey('termName')) return true;
    return false;
  }

  /// Returns the child page maps for [page], ready for pagination.
  ///
  /// - Section pages: this section's own-level single pages in canonical order
  ///   (via [orderedSectionPages] — the single ordering source).
  /// - Home pages: all single pages across all sections, canonical order.
  /// - Taxonomy term pages: reads `frontMatter['pages']` injected by S06.
  List<Map<String, dynamic>> _getChildPages(Page page, List<Page> allPages) {
    if (page.frontMatter.containsKey('termName')) {
      final raw = page.frontMatter['pages'];
      if (raw is List) {
        return raw.whereType<Map<String, dynamic>>().toList();
      }
      return const [];
    }

    if (page.kind == PageKind.home) {
      return orderedHomePages(allPages).map(pageToMap).toList();
    }

    // Section page — route through the one canonical ordered-section seam.
    return orderedSectionPages(page.sectionPath, allPages).map(pageToMap).toList();
  }

  /// Generates paginated output pages for a list-type [page].
  ///
  /// Splits child pages into chunks using [paginate] as the page size. Each
  /// chunk is rendered as a separate output file at the appropriate URL.
  /// Returns the number of output files written.
  Future<int> _generatePaginatedPage(Page page, List<Page> allPages, Map<String, dynamic> globalData) async {
    final templateName = resolveLayout(page);
    final childPages = _getChildPages(page, allPages);

    final paginatedPages = const Paginator().paginate<Map<String, dynamic>>(
      items: childPages,
      baseUrl: page.url,
      pageSize: paginate,
    );

    for (final paginatedPage in paginatedPages) {
      final context = _buildContext(
        page,
        allPages,
        globalData,
        paginatedItems: paginatedPage.items,
        pagination: paginatedPage.pagination,
      );
      final html = await _engine.renderFile(templateName, context);
      _writeOutput(paginatedPage.url, html);
    }

    return paginatedPages.length;
  }

  /// Resolves the layout template name for [page].
  ///
  /// Uses a priority-ordered lookup across all layout directories
  /// ([layoutsDir] first, then [layoutSearchPaths] as fallback):
  /// 1. Front matter `layout` field
  /// 2. Type-specific: `{type}/{kindSlug}.html`
  /// 3. Section-specific: `{section}/{kindSlug}.html`
  /// 4. Default: `_default/{kindSlug}.html`
  ///
  /// Home pages use a separate chain:
  /// `home.html` → `index.html` → `_default/list.html`
  ///
  /// Returns the template name (e.g. `layouts/home.html`) that the engine's
  /// loader can resolve via site-first, theme-fallback ordering.
  ///
  /// Throws [TemplateNotFoundException] if no layout is found in any directory.
  String resolveLayout(Page page) {
    final candidates = _layoutCandidates(page);
    final allLayoutDirs = [layoutsDir, ...layoutSearchPaths];
    for (final candidate in candidates) {
      for (final dir in allLayoutDirs) {
        if (File(p.join(dir, candidate)).existsSync()) {
          return 'layouts/$candidate';
        }
      }
    }
    throw TemplateNotFoundException(
      'No layout found for page: ${page.url}',
      pageUrl: page.url,
      tried: candidates.expand((c) => allLayoutDirs.map((d) => p.join(d, c))).toList(),
    );
  }

  /// Builds the template context for [page] using the data cascade.
  ///
  /// Optional [paginatedItems] overrides the `${pages}` list with a paginated
  /// slice. Optional [pagination] injects `${pagination.*}` context variables.
  /// When both are `null`, existing cascade behavior is preserved.
  Map<String, dynamic> _buildContext(
    Page page,
    List<Page> allPages,
    Map<String, dynamic> globalData, {
    List<Map<String, dynamic>>? paginatedItems,
    PaginationContext? pagination,
  }) {
    // Level 5 (lowest): site config params
    final context = Map<String, dynamic>.from(siteParams);

    // Level 4: global data files
    context['data'] = globalData;

    // Level 3: section front matter (_index.md in same section). Match on the
    // full `sectionPath` lineage (not the top-level `section`) so a nested page
    // resolves its OWN section's `_index.md`, not the top-level ancestor's —
    // mirroring [orderedSectionPages]'s own-level scoping.
    final sectionPage = allPages
        .where((pg) => pg.sectionPath == page.sectionPath && pg.kind == PageKind.section)
        .firstOrNull;
    if (sectionPage != null) {
      context.addAll(sectionPage.frontMatter);
    }

    // Level 1 (highest): page front matter
    context.addAll(page.frontMatter);

    // Inject `page` context variable (spread FM + add SSG fields)
    final pageMap = pageToMap(page);
    context['page'] = pageMap;

    // Structured breadcrumb trail: one {url, title} node per ancestor section,
    // additive to the documented cumulative-path `${page.ancestors}` list (which
    // stays a plain list of paths — public API). `url` is the section's prefixed
    // URL (same shape NavigationBuilder emits) and `title` uses the shared 3-tier
    // fallback (`menu_title` → `title` → humanized segment) so breadcrumb labels
    // read like the menu ("Guides", not "docs/guides").
    pageMap['breadcrumbs'] = _buildBreadcrumbs(page, allPages);

    // In-section prev/next (S08): attach immediate neighbors additively for
    // single doc pages only (the non-list render branch of `generateAll`).
    // List pages — section/home/taxonomy — keep their `paginator.dart` prev/next
    // semantics and receive no neighbor keys. Boundary positions omit the
    // absent side; when a template does not read `${page.prev}`/`${page.next}`
    // the added keys change no emitted bytes (backward-compat invariant).
    if (page.kind == PageKind.single && !_isListPage(page)) {
      final neighbors = _resolvePrevNext(page, allPages);
      final prev = neighbors['prev'];
      final next = neighbors['next'];
      if (prev != null) pageMap['prev'] = prev;
      if (next != null) pageMap['next'] = next;
    }

    // Section, home, and list pages receive ${pages}
    if (paginatedItems != null) {
      // Paginated slice provided — use it directly
      context['pages'] = paginatedItems;
    } else if (page.kind == PageKind.home) {
      // Non-paginated home fallback: all single pages across every section.
      context['pages'] = orderedHomePages(allPages).map(pageToMap).toList();
    } else if (page.kind == PageKind.section) {
      // Non-paginated section fallback: this section's own-level pages, in the
      // same canonical order as the paginated path (one ordering source).
      context['pages'] = orderedSectionPages(page.sectionPath, allPages).map(pageToMap).toList();
    }

    // Inject pagination context when available
    if (pagination != null) {
      context['pagination'] = pagination.toMap();
    }

    return context;
  }

  /// Builds [page]'s structured breadcrumb trail: one `{url, title}` node per
  /// ancestor section, ordered shallow→deep (matching `${page.ancestors}`).
  ///
  /// Each ancestor `sectionPath` is resolved to its section `_index.md` page (if
  /// any). `url` is that section page's (already prefixed) URL, or `''` when the
  /// section has no `_index.md` (a synthesized folder, mirroring the menu). Titles
  /// use the shared [nodeTitleFor] 3-tier fallback, so a labelled breadcrumb never
  /// shows a raw slash-joined path.
  List<Map<String, dynamic>> _buildBreadcrumbs(Page page, List<Page> allPages) {
    if (page.sectionPath.isEmpty) return const [];
    final sectionByPath = <String, Page>{
      for (final pg in allPages)
        if (pg.kind == PageKind.section) pg.sectionPath: pg,
    };

    final crumbs = <Map<String, dynamic>>[];
    final segments = page.sectionPath.split('/');
    for (var i = 0; i < segments.length; i++) {
      final ancestorPath = segments.sublist(0, i + 1).join('/');
      final sectionPage = sectionByPath[ancestorPath];
      crumbs.add(<String, dynamic>{
        'url': sectionPage?.url ?? '',
        'title': sectionPage != null ? nodeTitleFor(sectionPage, segments[i]) : humanizeSegment(segments[i]),
      });
    }
    return crumbs;
  }

  /// Resolves [page]'s immediate in-section neighbors as `{prev, next}` submaps.
  ///
  /// The neighbor sequence is the canonical, weight-aware own-level ordering
  /// produced by [orderedSectionPages] — the single ordering source S02's
  /// `NavigationBuilder` and the `${pages}` listing also consume. This helper
  /// adds no comparator or lineage filter of its own; it locates [page]'s index
  /// in that sequence and returns the flanking pages' `{url, title}` submaps.
  ///
  /// Boundaries are handled by absence: `prev` is omitted at index 0, `next` at
  /// the last index, and a single-element sequence yields neither key. When
  /// [page] is not found in the sequence (defensive; should not occur for a
  /// single doc page), an empty map is returned.
  ///
  /// The section ordering is memoized per `sectionPath` for the duration of one
  /// [generateAll] pass. Without that, every single page re-sorted its whole
  /// section: O(k · n log n) per section, which the scale benchmark
  /// (`benchmark/site_scale_benchmark.dart`) showed breaching the 5 s build NFR
  /// at ~4000 posts in a single flat section (8.4 s) – see TD-007.
  Map<String, Map<String, dynamic>> _resolvePrevNext(Page page, List<Page> allPages) {
    final ordered = _sectionOrderCache.putIfAbsent(
      page.sectionPath,
      () => orderedSectionPages(page.sectionPath, allPages),
    );
    final index = ordered.indexWhere((pg) => identical(pg, page) || pg.url == page.url);
    if (index < 0) return const {};

    final result = <String, Map<String, dynamic>>{};
    if (index > 0) result['prev'] = _neighborRef(ordered[index - 1]);
    if (index < ordered.length - 1) result['next'] = _neighborRef(ordered[index + 1]);
    return result;
  }

  /// Builds a neighbor reference submap (`{url, title}`) for [page].
  ///
  /// `title` uses the shared [nodeTitleFor] 3-tier fallback (`menu_title` →
  /// front-matter `title` → humanized last URL segment), matching the menu and
  /// breadcrumbs, so the key is always a non-empty string (never null) even for a
  /// titleless page.
  Map<String, dynamic> _neighborRef(Page page) => <String, dynamic>{
    'url': page.url,
    'title': nodeTitleFor(page, _lastUrlSegment(page.url)),
  };

  /// Extracts the last path segment of a root-absolute [url] (e.g.
  /// `/docs/guides/a/` → `a`); empty string for the root URL.
  String _lastUrlSegment(String url) {
    final trimmed = url.replaceAll(RegExp(r'^/|/$'), '');
    if (trimmed.isEmpty) return '';
    return trimmed.split('/').last;
  }

  /// Loads global data from `dataDir/*.yaml`, with optional theme data fallback.
  ///
  /// Theme data files are loaded first (lower priority). Site data files are
  /// loaded second and overwrite theme data at the same key (per-file, not deep merge).
  ///
  /// Exposed as a public method so tests can verify data-merge behaviour
  /// without running a full build.
  Map<String, dynamic> loadGlobalData() => _loadGlobalData();

  Map<String, dynamic> _loadGlobalData() {
    final result = <String, dynamic>{};

    // Load theme data first (lower priority fallback)
    if (themeDataDir != null) {
      final themeData = Directory(themeDataDir!);
      if (themeData.existsSync()) {
        for (final file in themeData.listSync().whereType<File>()) {
          if (p.extension(file.path) != '.yaml') continue;
          final stem = p.basenameWithoutExtension(file.path);
          final dynamic yaml = loadYaml(file.readAsStringSync());
          if (yaml == null) continue;
          result[stem] = convertYaml(yaml);
        }
      }
    }

    // Load site data second (higher priority — overwrites theme data per file)
    final siteDataDir = Directory(dataDir);
    if (siteDataDir.existsSync()) {
      for (final file in siteDataDir.listSync().whereType<File>()) {
        if (p.extension(file.path) != '.yaml') continue;
        final stem = p.basenameWithoutExtension(file.path);
        final dynamic yaml = loadYaml(file.readAsStringSync());
        if (yaml == null) continue;
        result[stem] = convertYaml(yaml);
      }
    }

    return result;
  }

  /// Writes [html] to the output file for [url].
  ///
  /// The [pathPrefix] is stripped before deriving the on-disk location so files
  /// land at unprefixed paths (the host serves the artifact root under the
  /// prefix); the emitted `${page.url}` inside [html] keeps the prefix.
  void _writeOutput(String url, String html) {
    final localUrl = stripPathPrefix(url, pathPrefix);
    final relativePath = localUrl.replaceAll(RegExp(r'^/|/$'), '');
    final outputFile = relativePath.isEmpty
        ? p.join(outputDir, 'index.html')
        : p.join(outputDir, relativePath, 'index.html');
    Directory(p.dirname(outputFile)).createSync(recursive: true);
    // Prefix root-absolute internal links/assets in the emitted HTML so hand-
    // written content links and theme literals resolve under the sub-path. No-op
    // when pathPrefix is empty (default), keeping root-served output unchanged.
    File(outputFile).writeAsStringSync(applyPathPrefixToLinks(html, pathPrefix));
    emittedPages.add(outputFile);
  }

  /// Returns layout candidate paths (relative to [layoutsDir]) in priority order.
  List<String> _layoutCandidates(Page page) {
    // Home page uses its own chain
    if (page.kind == PageKind.home) {
      return [
        if (page.frontMatter['layout'] is String) '${page.frontMatter['layout'] as String}.html',
        'home.html',
        'index.html',
        '_default/list.html',
      ];
    }

    final kindSlug = page.kind == PageKind.section ? 'list' : 'single';
    final fmType = page.frontMatter['type'];
    final type = (fmType is String && fmType.isNotEmpty) ? fmType : page.section;

    // Taxonomy virtual pages have extra lookup candidates before generic fallbacks.
    final taxName = page.frontMatter['taxonomyName'];
    if (taxName is String && taxName.isNotEmpty) {
      // Term pages: {taxonomy}/term.html, then _default/taxonomy.html
      // Listing pages: {taxonomy}/list.html, then _default/taxonomy.html
      final taxKind = page.frontMatter.containsKey('termName') ? 'term' : 'list';
      return [
        if (page.frontMatter['layout'] is String) '${page.frontMatter['layout'] as String}.html',
        '$taxName/$taxKind.html',
        '$taxName/$kindSlug.html',
        '_default/taxonomy.html',
        '_default/$kindSlug.html',
      ];
    }

    return [
      if (page.frontMatter['layout'] is String) '${page.frontMatter['layout'] as String}.html',
      if (type.isNotEmpty) '$type/$kindSlug.html',
      if (page.section.isNotEmpty && page.section != type) '${page.section}/$kindSlug.html',
      '_default/$kindSlug.html',
    ];
  }
}

/// Returns a section's own-level content pages in canonical order.
///
/// This is the single reusable ordered-section seam — the one ordering source
/// the plan's "single-source page ordering" decision requires. `_getChildPages`
/// (section branch) and the non-paginated `_buildContext` fallback both route
/// through it, and downstream consumers (S02's `NavigationBuilder`, S08's
/// `_resolvePrevNext`) call it verbatim so every derived ordering matches the
/// `${pages}` listing exactly.
///
/// Contract:
/// - Returns the [PageKind.single] pages whose `sectionPath` equals
///   [sectionPath] — i.e. the section's *own level* only, excluding sibling
///   sub-sections' pages. For a top-level section (`sectionPath == 'posts'`)
///   this matches today's `section`-based grouping; for a nested section
///   (`sectionPath == 'docs/guides'`) it excludes `docs/tutorials/*`.
/// - Order is the canonical weight-aware order (see [_comparePagesByDateDesc]):
///   integer-weighted pages first by ascending weight, then all unweighted
///   pages in the existing date-desc-then-URL order.
/// - Draft filtering is the caller's responsibility (callers pass an already
///   draft-filtered [allPages]); this function does not filter drafts.
/// - An empty [sectionPath] selects the root level: the top-level single pages
///   whose `sectionPath` is `''` (e.g. `content/about.md`) — this is what
///   `NavigationBuilder._buildLevel('')` and the root `${pages}` listing use. A
///   [sectionPath] that matches no page yields an empty list.
List<Page> orderedSectionPages(String sectionPath, List<Page> allPages) {
  final pages = allPages.where((pg) => pg.sectionPath == sectionPath && pg.kind == PageKind.single).toList()
    ..sort(_comparePagesByDateDesc);
  return pages;
}

/// Returns every content page for the home listing, in canonical order.
///
/// The home page lists all [PageKind.single] pages across every section (not
/// scoped to one `sectionPath`), sorted by the same canonical weight-aware
/// comparator as [orderedSectionPages]. Both `_getChildPages` (home branch) and
/// the non-paginated `_buildContext` home fallback route through it so the two
/// paths can never diverge.
List<Page> orderedHomePages(List<Page> allPages) {
  return allPages.where((pg) => pg.kind == PageKind.single).toList()..sort(_comparePagesByDateDesc);
}

/// Reads the effective integer `weight` for [page], or `null` when absent or
/// malformed.
///
/// A page participates in weight-primary ordering only when this returns a
/// non-null value. Non-integer or otherwise malformed values (e.g. a quoted
/// string, a double, a list) return `null` and the page is treated as
/// unweighted; [PageGenerator.generateAll] separately emits a build warning
/// naming such a page.
int? pageWeight(Page page) {
  final raw = page.frontMatter['weight'];
  if (raw is int) return raw;
  return null;
}

/// Compares pages in the canonical order: weight-primary, then date descending
/// (ISO 8601 string), then URL ascending.
///
/// Integer-weighted pages sort ahead of unweighted pages, ascending by weight.
/// Ties among weighted pages, and all unweighted pages, fall through to the
/// existing date-desc-then-URL comparison — no new tiebreak is introduced for
/// unweighted sections (byte-for-byte identical to the pre-weight order when no
/// page declares a `weight`).
int _comparePagesByDateDesc(Page a, Page b) {
  final weightA = pageWeight(a);
  final weightB = pageWeight(b);

  if (weightA != null && weightB != null) {
    final cmp = weightA.compareTo(weightB); // ascending
    if (cmp != 0) return cmp;
    // Equal weights fall through to date-desc-then-URL.
  } else if (weightA != null) {
    return -1; // a weighted, b not — a goes first
  } else if (weightB != null) {
    return 1; // b weighted, a not — b goes first
  }

  final dateA = a.frontMatter['date'];
  final dateB = b.frontMatter['date'];

  if (dateA is String && dateB is String) {
    final cmp = dateB.compareTo(dateA); // descending
    if (cmp != 0) return cmp;
  } else if (dateA is String) {
    return -1; // a has date, b doesn't — a goes first
  } else if (dateB is String) {
    return 1; // b has date, a doesn't — b goes first
  }

  return a.url.compareTo(b.url);
}
