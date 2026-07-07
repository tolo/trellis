import 'page.dart';
import 'page_generator.dart' show orderedSectionPages, pageWeight;

/// Builds the hierarchical navigation tree exposed to templates as `${site.menu}`.
///
/// The tree is a nested list of plain map nodes, each shaped exactly
/// `{title, url, children}`, mirroring the content section hierarchy. It is
/// built once per build and shared across every page render, so it carries **no**
/// per-page active state: a theme marks the active page and its ancestor trail at
/// render time by comparing each node's `url` against `${page.url}` (there is no
/// engine-emitted `active`/`activeTrail` flag — the shared tree cannot know which
/// page is currently rendering).
///
/// Ordering is single-sourced: each section's own-level content pages are obtained
/// by calling [orderedSectionPages] (S01's canonical weight-aware ordered-section
/// seam), so the sidebar order can never diverge from the `${pages}` listing or
/// S08's prev/next order. The builder holds no comparator or lineage filter of its
/// own — it delegates own-level ordering to that seam and nests strictly by each
/// page's [Page.sectionPath] lineage.
///
/// Exclusion mirrors the page generator: drafts are dropped (respecting the
/// post-`includeDrafts` [Page.isDraft] state) and pages carrying `menu_exclude:
/// true` in front matter are dropped. Excluding a section page that still has
/// non-excluded children drops only that section's own node and **hoists** its
/// surviving children to the excluded node's parent (they are neither orphaned
/// nor silently dropped).
///
/// An empty or fully-excluded content set yields an empty list (never null), so a
/// `tl:each` over `${site.menu}` emits nothing without a null-dereference.
class NavigationBuilder {
  /// Creates a [NavigationBuilder].
  const NavigationBuilder();

  /// Front-matter key (bool) that removes a page from the navigation tree.
  static const String menuExcludeKey = 'menu_exclude';

  /// Front-matter key (string) that overrides a node's derived title.
  static const String menuTitleKey = 'menu_title';

  /// Builds the nested navigation tree from [pages].
  ///
  /// [pages] is the full discovered page set (drafts already resolved via
  /// `includeDrafts`). Draft and `menu_exclude: true` pages are filtered here.
  /// Returns a list of `{title, url, children}` map nodes; the top level holds
  /// root pages and top-level section nodes. Returns `[]` when no page is
  /// menu-eligible.
  List<Map<String, dynamic>> build(List<Page> pages) {
    // Exclusion: mirror the generator's `!isDraft` filter, plus the menu opt-out.
    final eligible = pages.where((pg) => !pg.isDraft && !_isMenuExcluded(pg)).toList();

    // Eligible section pages (`_index.md`) keyed by section lineage, used for a
    // section node's title/url.
    final sectionPageByPath = <String, Page>{
      for (final pg in eligible)
        if (pg.kind == PageKind.section) pg.sectionPath: pg,
    };

    // Section lineages whose `_index.md` existed in the full set but was filtered
    // out (draft or `menu_exclude`). These sections are *dropped* and their
    // surviving children hoisted — distinct from a folder that never had an
    // `_index.md`, which still yields a synthesized node (humanized folder title).
    final excludedSectionPaths = <String>{
      for (final pg in pages)
        if (pg.kind == PageKind.section && !sectionPageByPath.containsKey(pg.sectionPath)) pg.sectionPath,
    };

    return _buildLevel('', eligible, sectionPageByPath, excludedSectionPaths);
  }

  /// Builds the nodes owned directly by [parentPath] (root when empty).
  ///
  /// Own-level content pages come from [orderedSectionPages] (canonical order);
  /// each immediate child section becomes a nested node whose children are built
  /// recursively. Two absence cases diverge: a section whose `_index.md` was
  /// menu-excluded (in [excludedSectionPaths]) is dropped and its surviving
  /// children hoisted here; a folder that never had an `_index.md` still yields a
  /// synthesized node titled from its humanized folder segment.
  List<Map<String, dynamic>> _buildLevel(
    String parentPath,
    List<Page> eligible,
    Map<String, Page> sectionPageByPath,
    Set<String> excludedSectionPaths,
  ) {
    final nodes = <Map<String, dynamic>>[];

    // Own-level content pages, ordered by the single canonical seam. Pass the
    // eligible set so excluded/draft pages never enter the tree.
    for (final page in orderedSectionPages(parentPath, eligible)) {
      nodes.add(<String, dynamic>{
        'title': _titleFor(page, _lastSegment(page.url)),
        'url': page.url,
        'children': const <Map<String, dynamic>>[],
      });
    }

    // Immediate child sections (lineage exactly one level below parentPath),
    // ordered by their section page's `weight` (from the `_index.md` front
    // matter) and then lexically by trailing segment. This mirrors the single-
    // page weight rule ([pageWeight]/[orderedSectionPages]): weighted sections
    // first by ascending weight, then unweighted sections lexically. Sections
    // with no `_index.md` (no page → no weight) sort as unweighted. When no
    // section declares a weight, the order is the previous pure-lexical order.
    final childSectionPaths = _immediateChildSections(parentPath, eligible)
      ..sort((a, b) {
        final wa = _sectionWeight(a, sectionPageByPath);
        final wb = _sectionWeight(b, sectionPageByPath);
        if (wa != null && wb != null && wa != wb) return wa.compareTo(wb);
        if (wa != null && wb == null) return -1; // weighted before unweighted
        if (wa == null && wb != null) return 1;
        return a.compareTo(b); // lexical fallback (and tiebreak within a weight)
      });

    for (final childPath in childSectionPaths) {
      final children = _buildLevel(childPath, eligible, sectionPageByPath, excludedSectionPaths);

      if (excludedSectionPaths.contains(childPath)) {
        // The section's own `_index.md` opted out — drop this node but hoist any
        // surviving children so their pages stay reachable.
        nodes.addAll(children);
        continue;
      }

      final sectionPage = sectionPageByPath[childPath];
      nodes.add(<String, dynamic>{
        // No `_index.md` (sectionPage == null) → synthesize a node titled from
        // the humanized folder segment; url is empty (nothing to link to).
        'title': sectionPage != null
            ? _titleFor(sectionPage, _lastSegment(childPath))
            : humanizeSegment(_lastSegment(childPath)),
        'url': sectionPage?.url ?? '',
        'children': children,
      });
    }

    return nodes;
  }

  /// Returns the distinct section paths that are immediate children of
  /// [parentPath], derived from every eligible page's lineage (so a folder with
  /// no `_index.md` is still discovered from the pages nested under it).
  List<String> _immediateChildSections(String parentPath, List<Page> eligible) {
    final result = <String>{};
    for (final page in eligible) {
      final path = page.sectionPath;
      if (path.isEmpty) continue;
      final segments = path.split('/');
      final depth = parentPath.isEmpty ? 0 : parentPath.split('/').length;
      // The immediate child lineage under parentPath is the first `depth + 1`
      // segments; the page must actually descend from parentPath.
      if (segments.length <= depth) continue;
      final prefix = segments.sublist(0, depth).join('/');
      if (prefix != parentPath) continue;
      result.add(segments.sublist(0, depth + 1).join('/'));
    }
    return result.toList();
  }

  /// The integer `weight` of the section page at [path] (its `_index.md`), or
  /// `null` when the section has no page or no valid `weight` — used to order
  /// sibling section nodes.
  int? _sectionWeight(String path, Map<String, Page> sectionPageByPath) {
    final sectionPage = sectionPageByPath[path];
    return sectionPage == null ? null : pageWeight(sectionPage);
  }

  /// Resolves a node's title via the shared 3-tier precedence (see [nodeTitleFor]):
  /// `menu_title` → front-matter `title` → humanized [fallbackSegment].
  String _titleFor(Page page, String fallbackSegment) => nodeTitleFor(page, fallbackSegment);

  bool _isMenuExcluded(Page page) => page.frontMatter[menuExcludeKey] == true;

  /// Extracts the last path segment of a root-absolute [url] (e.g.
  /// `/docs/guides/a/` → `a`). Returns an empty string for the root URL.
  String _lastSegment(String url) {
    final trimmed = url.replaceAll(RegExp(r'^/|/$'), '');
    if (trimmed.isEmpty) return '';
    return trimmed.split('/').last;
  }
}

/// Resolves a display title for [page] via the canonical 3-tier precedence:
/// `menu_title` front matter → front-matter `title` → humanized [fallbackSegment].
///
/// This is the single title-fallback seam shared by the menu ([NavigationBuilder]),
/// breadcrumbs, and prev/next neighbor references — so every derived title matches
/// exactly. [fallbackSegment] is the URL/folder segment to humanize when no
/// front-matter title is present (e.g. `guides` → `Guides`).
String nodeTitleFor(Page page, String fallbackSegment) {
  final menuTitle = page.frontMatter[NavigationBuilder.menuTitleKey];
  if (menuTitle is String && menuTitle.isNotEmpty) return menuTitle;
  final title = page.frontMatter['title'];
  if (title is String && title.isNotEmpty) return title;
  return humanizeSegment(fallbackSegment);
}

/// Humanizes a URL/folder [segment] into a display title.
///
/// Replaces `-` and `_` with spaces and title-cases each word:
/// `getting-started` → `Getting Started`, `api_reference` → `Api Reference`.
/// An empty segment yields an empty string.
String humanizeSegment(String segment) {
  if (segment.isEmpty) return '';
  final words = segment.replaceAll(RegExp('[-_]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
  return words.map((w) => w[0].toUpperCase() + w.substring(1)).join(' ');
}
