import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:trellis/trellis.dart';
import 'package:yaml/yaml.dart';

import 'page.dart';
import 'paginator.dart';
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

  late final Trellis _engine;

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
    final globalData = _loadGlobalData();
    final nonDraftPages = pages.where((pg) => !pg.isDraft).toList();
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
  /// - Section pages: single pages in the same section, date-desc sorted.
  /// - Home pages: all single pages across all sections, date-desc sorted.
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
      return (allPages.where((pg) => pg.kind == PageKind.single).toList()..sort(_comparePagesByDateDesc))
          .map(pageToMap)
          .toList();
    }

    // Section page
    return (allPages.where((pg) => pg.section == page.section && pg.kind == PageKind.single).toList()
          ..sort(_comparePagesByDateDesc))
        .map(pageToMap)
        .toList();
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

    // Level 3: section front matter (_index.md in same section)
    final sectionPage = allPages.where((pg) => pg.section == page.section && pg.kind == PageKind.section).firstOrNull;
    if (sectionPage != null) {
      context.addAll(sectionPage.frontMatter);
    }

    // Level 1 (highest): page front matter
    context.addAll(page.frontMatter);

    // Inject `page` context variable (spread FM + add SSG fields)
    context['page'] = pageToMap(page);

    // Section, home, and list pages receive ${pages}
    if (paginatedItems != null) {
      // Paginated slice provided — use it directly
      context['pages'] = paginatedItems;
    } else if (page.kind == PageKind.section || page.kind == PageKind.home) {
      // Non-paginated fallback: all children sorted by date desc
      final children = allPages.where((pg) => pg.section == page.section && pg.kind == PageKind.single).toList()
        ..sort(_comparePagesByDateDesc);
      context['pages'] = children.map(pageToMap).toList();
    }

    // Inject pagination context when available
    if (pagination != null) {
      context['pagination'] = pagination.toMap();
    }

    return context;
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
  void _writeOutput(String url, String html) {
    final relativePath = url.replaceAll(RegExp(r'^/|/$'), '');
    final outputFile = relativePath.isEmpty
        ? p.join(outputDir, 'index.html')
        : p.join(outputDir, relativePath, 'index.html');
    Directory(p.dirname(outputFile)).createSync(recursive: true);
    File(outputFile).writeAsStringSync(html);
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

/// Compares pages by date descending (ISO 8601 string), then URL ascending.
int _comparePagesByDateDesc(Page a, Page b) {
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
