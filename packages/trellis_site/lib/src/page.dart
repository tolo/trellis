/// Represents a single entry in a page's table of contents.
class TocEntry {
  /// The heading anchor id (e.g. `getting-started`).
  final String id;

  /// The heading text content.
  final String text;

  /// The heading level (2–6).
  final int level;

  const TocEntry({required this.id, required this.text, required this.level});

  @override
  String toString() => 'TocEntry(id: $id, text: $text, level: $level)';
}

/// The kind of content page.
enum PageKind {
  /// A regular content page (e.g. `posts/hello-world.md`).
  single,

  /// A section listing page (`_index.md` in a subdirectory).
  section,

  /// The home page (`_index.md` at the content root).
  home,
}

/// Represents a content page in the site.
///
/// Immutable fields are populated during content discovery (S01). Mutable
/// fields are populated by later pipeline stages: [frontMatter] and
/// [rawContent] by S02, [content]/[summary]/[toc] by S03.
class Page {
  /// Relative path to the source file from the content directory (e.g. `posts/hello-world.md`).
  final String sourcePath;

  /// URL path derived from directory structure (e.g. `/posts/hello-world/`).
  final String url;

  /// The top-level section name (e.g. `posts`). Empty string for root pages.
  final String section;

  /// The full nested section lineage (e.g. `docs/guides`). Empty string for
  /// root pages. Unlike [section] (top-level only), this captures every
  /// directory level so nested sub-sections are distinguishable.
  ///
  /// Additive to [section]: [section] keeps its top-level value; templates read
  /// this via `${page.sectionPath}` (string) and `${page.ancestors}` (list).
  final String sectionPath;

  /// The kind of page: single content page, section listing, or home page.
  final PageKind kind;

  /// Whether this page is a draft. Initially `false`; S02 sets from front matter.
  bool isDraft;

  /// Whether this page is part of a page bundle (a directory with `index.md`).
  final bool isBundle;

  /// Paths to bundle assets (non-`.md` sibling files), relative to content dir.
  /// Empty list for non-bundle pages.
  final List<String> bundleAssets;

  /// Front matter from the content file. Populated by S02; empty map initially.
  Map<String, dynamic> frontMatter;

  /// Raw Markdown content (everything after front matter). Populated by S02.
  String rawContent;

  /// Rendered HTML content. Populated by S03.
  String content;

  /// Page summary. Populated by S03.
  String summary;

  /// Table of contents entries. Populated by S03.
  List<TocEntry> toc;

  /// Creates a [Page] with required discovery-phase fields.
  ///
  /// Mutable pipeline fields default to empty values and are populated by
  /// subsequent pipeline stages (S02, S03).
  Page({
    required this.sourcePath,
    required this.url,
    required this.section,
    required this.kind,
    required this.isDraft,
    required this.isBundle,
    required this.bundleAssets,
    String? sectionPath,
    Map<String, dynamic>? frontMatter,
    String? rawContent,
    String? content,
    String? summary,
    List<TocEntry>? toc,
  }) : sectionPath = sectionPath ?? section,
       frontMatter = frontMatter ?? {},
       rawContent = rawContent ?? '',
       content = content ?? '',
       summary = summary ?? '',
       toc = toc ?? [];

  @override
  String toString() =>
      'Page(sourcePath: $sourcePath, url: $url, section: $section, kind: $kind, isDraft: $isDraft, isBundle: $isBundle)';
}

/// Converts a [Page] to a plain [Map] suitable for use as a Trellis context value.
///
/// The resulting map spreads [Page.frontMatter] and overrides it with the SSG
/// structural fields (`url`, `content`, `summary`, `toc`, `section`,
/// `sectionPath`, `ancestors`, `kind`, `isDraft`). Any extra keys injected into
/// `frontMatter` (e.g. taxonomy data) are preserved and accessible as
/// `${page.key}` in templates.
///
/// `section` stays the top-level folder (unchanged). `sectionPath` is the full
/// nested lineage (e.g. `docs/guides`), and `ancestors` is its list form
/// (e.g. `['docs', 'docs/guides']`) — the additive nested-section fields.
Map<String, dynamic> pageToMap(Page page) => <String, dynamic>{
  ...page.frontMatter,
  'url': page.url,
  'content': page.content,
  'summary': page.summary,
  'toc': page.toc.map((e) => {'id': e.id, 'text': e.text, 'level': e.level}).toList(),
  'section': page.section,
  'sectionPath': page.sectionPath,
  'ancestors': _sectionAncestors(page.sectionPath),
  'kind': page.kind.name,
  'isDraft': page.isDraft,
};

/// Builds the cumulative ancestor lineage list from a `sectionPath`.
///
/// Each entry is a progressively deeper section path, e.g. `docs/guides` yields
/// `['docs', 'docs/guides']`. An empty `sectionPath` (root page) yields `[]`.
List<String> _sectionAncestors(String sectionPath) {
  if (sectionPath.isEmpty) return const [];
  final parts = sectionPath.split('/');
  final result = <String>[];
  for (var i = 0; i < parts.length; i++) {
    result.add(parts.sublist(0, i + 1).join('/'));
  }
  return result;
}
