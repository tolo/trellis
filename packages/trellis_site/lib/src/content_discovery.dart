import 'dart:io';

import 'package:path/path.dart' as p;

import 'page.dart';

/// Derives the URL path for a content file from its source path (relative to content dir).
///
/// Rules:
/// - `about.md` → `/about/`
/// - `posts/hello-world.md` → `/posts/hello-world/`
/// - `posts/_index.md` → `/posts/`
/// - `_index.md` → `/`
/// - `posts/my-trip/index.md` → `/posts/my-trip/` (page bundle)
///
/// When [pathPrefix] is a non-empty canonical sub-path (e.g. `/trellis/`, as
/// produced by `SiteConfig.normalizePathPrefix`), every derived root-absolute
/// URL resolves under it (e.g. `/docs/intro/` → `/trellis/docs/intro/`). The
/// default empty [pathPrefix] is a literal no-op that leaves output
/// byte-for-byte unchanged. This is the single engine URL-derivation seam, so
/// every downstream consumer (`${page.url}`, menu, prev/next, search-index
/// `url`) inherits the prefix with no per-consumer change.
String deriveUrl(String sourcePath, {String pathPrefix = ''}) {
  // Normalize to forward slashes regardless of platform.
  final normalized = sourcePath.replaceAll(r'\', '/');
  final parts = p.posix.split(normalized);
  final filename = parts.last;
  final base = p.posix.basenameWithoutExtension(filename);

  final String url;
  if (base == '_index' || base == 'index') {
    // _index.md section / index.md page bundle — URL is the containing directory
    if (parts.length == 1) {
      url = '/';
    } else {
      final dir = parts.sublist(0, parts.length - 1).join('/');
      url = '/$dir/';
    }
  } else {
    // Regular file — strip extension and use full path as URL slug
    final withoutExt = parts.sublist(0, parts.length - 1)..add(base);
    url = '/${withoutExt.join('/')}/';
  }

  return applyPathPrefix(url, pathPrefix);
}

/// Applies a normalized [pathPrefix] to an engine-derived [url].
///
/// Rewrites only internal root-absolute paths (a single leading `/`). External
/// and absolute URLs pass through verbatim: a protocol-relative `//host/...`,
/// or any scheme-bearing/absolute URL (`https://...`) is left untouched, so the
/// prefix is never prepended to links the site does not own.
///
/// An empty [pathPrefix] is a literal no-op — [url] is returned unchanged.
String applyPathPrefix(String url, String pathPrefix) {
  if (pathPrefix.isEmpty) return url;
  // Only internal root-absolute paths (leading '/', not '//') are rewritten.
  if (!url.startsWith('/') || url.startsWith('//')) return url;
  // pathPrefix is canonical `/x/`; strip its trailing slash and join with the
  // root-absolute url (which starts with '/') so the result is `/x/...`.
  final prefixBody = pathPrefix.substring(0, pathPrefix.length - 1);
  return '$prefixBody$url';
}

/// Removes a normalized [pathPrefix] from a prefixed [url], returning the
/// root-absolute path used to locate the output file on disk.
///
/// This is the inverse of [applyPathPrefix]. Emitted URLs carry the prefix (for
/// links, menu, prev/next, the search index, and the sitemap), but files are
/// written at their *unprefixed* paths so the whole output tree can be served
/// under the prefix by the host — GitHub Project Pages, for example, mounts the
/// published artifact root at `/<repo>/`, so a file at `output/docs/intro/`
/// served under `/trellis/` resolves the emitted `/trellis/docs/intro/` link.
/// Writing files under `output/trellis/` instead would double-apply the prefix.
///
/// An empty [pathPrefix], or a [url] that does not begin with the prefix (e.g.
/// an absolute external URL), is a literal no-op.
String stripPathPrefix(String url, String pathPrefix) {
  if (pathPrefix.isEmpty) return url;
  // pathPrefix is canonical `/x/`; the prefix body is `/x`.
  final prefixBody = pathPrefix.substring(0, pathPrefix.length - 1);
  if (url == prefixBody) return '/';
  // Match the prefix only on a path boundary so `/trellisish/` is not stripped.
  if (url.startsWith('$prefixBody/')) return url.substring(prefixBody.length);
  return url;
}

/// Matches either a `<pre>`/`<code>` region (group 1 — to be preserved verbatim)
/// or a root-absolute-internal `href`/`src` attribute (groups 2–4 — to be
/// rewritten).
///
/// The code-region alternative comes first so that a documentation *code
/// example* — e.g. a fenced block rendered by `package:markdown` to
/// `<code>&lt;link href="/css/main.css"&gt;</code>` — is skipped entirely.
/// This is load-bearing: markdown escapes `<`/`>`/`&` inside code but leaves the
/// attribute quote `"` literal, so without skipping code regions the link
/// pattern would rewrite the URL *shown in the example*, corrupting the docs.
/// The non-greedy `[\s\S]*?</pre>`/`</code>` consumes a whole (real, unescaped)
/// code region; escaped closers (`&lt;/code&gt;`) are not matched, so the region
/// bounds are correct. `<pre>` is listed first so a fenced `<pre><code>…` block
/// is consumed whole (including its inner `<code>`).
///
/// For the link alternative, the negative lookahead excludes protocol-relative
/// `//host` URLs.
final _rootAbsoluteLinkPattern = RegExp(
  r'(<pre\b[\s\S]*?</pre>|<code\b[\s\S]*?</code>)'
  r'|(\s(?:href|src)=")(/(?!/)[^"]*)(")',
);

/// Rewrites root-absolute **internal** `href`/`src` URLs in a rendered page's
/// [html] so they resolve when the site is served under a sub-path — the
/// expected SSG behavior (cf. Hugo's `baseURL` handling). This is what lets a
/// hand-written Markdown link (`/docs/guide/`), a theme literal (`/css/main.css`),
/// and a vendored-asset `src` (`/prism/core.js`) all work under `pathPrefix`
/// without the author threading the prefix through every link.
///
/// A URL is prefixed only when it is root-absolute internal (one leading `/`,
/// not `//`) and does **not** already begin with the prefix — so engine-derived
/// URLs (already prefixed at [deriveUrl]) are never double-prefixed. Relative
/// URLs (`../x`, `x/`), in-page anchors (`#x`), protocol-relative (`//host`),
/// and absolute/external URLs are left untouched, so **relative links keep
/// working as-is**. An empty [pathPrefix] is a literal no-op, so default (root-
/// served) output is byte-for-byte unchanged.
///
/// Links inside `<pre>`/`<code>` (documentation code examples) are never
/// rewritten — the URL a code sample *shows* is left exactly as authored.
///
/// Known limitation: only `href`/`src` attributes are rewritten; `srcset` and
/// CSS `url(...)` references are not (uncommon in prose docs — use relative or
/// prefix-aware paths there). Only *double-quoted* `href`/`src` values are
/// rewritten; single-quoted attributes (`href='/x'`) are left untouched.
/// Additionally, an unclosed `<pre>`/`<code>` tag over-consumes to the next
/// closing tag, so any real links in that swallowed span are skipped (not
/// rewritten); the resulting broken sub-path links are caught by the CI
/// link-integrity check rather than silently shipped.
String applyPathPrefixToLinks(String html, String pathPrefix) {
  if (pathPrefix.isEmpty) return html;
  final prefixBody = pathPrefix.substring(0, pathPrefix.length - 1); // e.g. '/trellis'
  return html.replaceAllMapped(_rootAbsoluteLinkPattern, (m) {
    // A <pre>/<code> region matched — preserve it verbatim (code examples are
    // never rewritten, even if they contain a literal `href="/…"`).
    if (m[1] != null) return m[1]!;
    final url = m[3]!;
    // Already under the prefix (engine-derived / already-prefixed) → leave as-is.
    if (url == prefixBody || url.startsWith('$prefixBody/')) return m[0]!;
    return '${m[2]}$prefixBody$url${m[4]}';
  });
}

/// Detects the [PageKind] for a content file.
///
/// - `_index.md` at content root → [PageKind.home]
/// - `_index.md` in any subdirectory → [PageKind.section]
/// - All other `.md` files (including `index.md` bundles) → [PageKind.single]
PageKind detectKind(String sourcePath) {
  final normalized = sourcePath.replaceAll(r'\', '/');
  final filename = p.posix.basename(normalized);
  final base = p.posix.basenameWithoutExtension(filename);

  if (base != '_index') return PageKind.single;

  final parts = p.posix.split(normalized);
  if (parts.length == 1) return PageKind.home;
  return PageKind.section;
}

/// Derives the top-level section name for a content file.
///
/// - Root-level files → `''` (empty string)
/// - `posts/hello.md` → `posts`
/// - `docs/advanced/config.md` → `docs` (top-level only)
String deriveSection(String sourcePath) {
  final normalized = sourcePath.replaceAll(r'\', '/');
  final parts = p.posix.split(normalized);
  if (parts.length <= 1) return '';
  return parts.first;
}

/// Derives the full nested section lineage for a content file.
///
/// Unlike [deriveSection] (top-level only), this joins every directory level so
/// nested sub-sections are distinguishable. The filename is never part of the
/// lineage.
///
/// - Root-level files (`about.md`, `_index.md`) → `''` (empty string)
/// - `posts/hello.md` → `posts`
/// - `docs/advanced/config.md` → `docs/advanced`
/// - `docs/guides/_index.md` → `docs/guides` (a nested section owns its level)
String deriveSectionPath(String sourcePath) {
  final normalized = sourcePath.replaceAll(r'\', '/');
  final parts = p.posix.split(normalized);
  if (parts.length <= 1) return '';
  return parts.sublist(0, parts.length - 1).join('/');
}

/// Scans a content directory and discovers all Markdown pages.
class ContentDiscovery {
  /// The root content directory path.
  final String contentDir;

  /// The normalized URL path-prefix applied to every derived [Page.url].
  ///
  /// Empty (the default) means no prefix — URLs stay root-absolute and output
  /// is byte-for-byte unchanged. A canonical `/x/` value (from
  /// `SiteConfig.normalizePathPrefix`) makes every internal URL resolve under
  /// it. See [deriveUrl].
  final String pathPrefix;

  /// Creates a [ContentDiscovery] for the given [contentDir].
  ///
  /// [pathPrefix] must already be normalized (see
  /// `SiteConfig.normalizePathPrefix`); it defaults to the empty no-prefix
  /// state.
  ContentDiscovery(this.contentDir, {this.pathPrefix = ''});

  /// Discovers all pages in the content directory.
  ///
  /// Returns a list of [Page] objects with [Page.sourcePath], [Page.url],
  /// [Page.section], [Page.kind], [Page.isBundle], and [Page.bundleAssets]
  /// populated. Front matter and content fields are left at their default
  /// empty values (populated by later pipeline stages).
  ///
  /// Pages are sorted by [Page.sourcePath] for deterministic output.
  ///
  /// Throws [ArgumentError] if [contentDir] does not exist.
  Future<List<Page>> discover() async {
    final dir = Directory(contentDir);
    if (!dir.existsSync()) {
      throw ArgumentError('Content directory does not exist: $contentDir');
    }

    // Collect all files recursively.
    final allFiles = dir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .map((f) => p.normalize(f.path))
        .toList();

    // Group all files by their parent directory (absolute path) for bundle detection.
    final filesByDir = <String, List<String>>{};
    for (final absPath in allFiles) {
      final parent = p.dirname(absPath);
      (filesByDir[parent] ??= []).add(absPath);
    }

    // Filter to .md files only and build pages.
    final contentDirNorm = p.normalize(contentDir);
    final mdFiles = allFiles.where((f) => f.endsWith('.md')).toList()..sort();

    final pages = <Page>[];
    for (final absPath in mdFiles) {
      // Compute path relative to content dir, using forward slashes.
      var relativePath = p.relative(absPath, from: contentDirNorm);
      relativePath = relativePath.replaceAll(r'\', '/');

      final filename = p.basename(relativePath);
      final base = p.basenameWithoutExtension(filename);

      final url = deriveUrl(relativePath, pathPrefix: pathPrefix);
      final kind = detectKind(relativePath);
      final section = deriveSection(relativePath);
      final sectionPath = deriveSectionPath(relativePath);

      // Bundle detection: index.md (not _index.md) in a directory.
      final isBundle = base == 'index';
      final bundleAssets = <String>[];

      if (isBundle) {
        final parentDir = p.dirname(absPath);
        final siblings = filesByDir[parentDir] ?? [];
        for (final sibling in siblings) {
          if (!sibling.endsWith('.md') && sibling != absPath) {
            var assetPath = p.relative(sibling, from: contentDirNorm);
            assetPath = assetPath.replaceAll(r'\', '/');
            bundleAssets.add(assetPath);
          }
        }
        bundleAssets.sort();
      }

      pages.add(
        Page(
          sourcePath: relativePath,
          url: url,
          section: section,
          sectionPath: sectionPath,
          kind: kind,
          isDraft: false,
          isBundle: isBundle,
          bundleAssets: bundleAssets,
        ),
      );
    }

    return pages;
  }
}
