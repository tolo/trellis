import 'page.dart';

/// A normalized taxonomy term with its associated pages.
///
/// A term is a single value (e.g. `"dart"`) that appears in a page's front
/// matter under a taxonomy field (e.g. `tags`). Terms are normalized to
/// lowercase and trimmed; the [slug] is URL-safe.
class TaxonomyTerm {
  /// Normalized term name (lowercase, trimmed). E.g. `"dart"`.
  final String name;

  /// URL-safe slug derived from [name]. E.g. `"hello-world"`.
  final String slug;

  /// Canonical URL for this term's listing page. E.g. `"/tags/dart/"`.
  final String url;

  /// Number of pages tagged with this term.
  final int count;

  /// Page maps for all pages tagged with this term (same shape as `${pages}`).
  final List<Map<String, dynamic>> pages;

  const TaxonomyTerm({
    required this.name,
    required this.slug,
    required this.url,
    required this.count,
    required this.pages,
  });

  /// Converts this term to a map suitable for Trellis template context.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'name': name,
    'slug': slug,
    'url': url,
    'count': count,
    'pages': pages,
  };
}

/// The complete taxonomy index for a single taxonomy (e.g., `"tags"`).
class TaxonomyIndex {
  /// The taxonomy name (e.g. `"tags"`).
  final String name;

  /// All terms for this taxonomy, sorted alphabetically by [TaxonomyTerm.name].
  final List<TaxonomyTerm> terms;

  const TaxonomyIndex({required this.name, required this.terms});

  /// Returns the terms as a list of maps for template context.
  List<Map<String, dynamic>> toTermMapList() => terms.map((t) => t.toMap()).toList();
}

/// Collects taxonomy terms from pages and generates virtual taxonomy pages.
///
/// Taxonomies are declared in `trellis_site.yaml` under `taxonomies: [tags, ...]`.
/// For each declared taxonomy, [collect] scans all page front matter, extracts
/// term values, normalises them, and builds a [TaxonomyIndex].
///
/// [buildVirtualPages] then creates synthetic [Page] objects — one listing page
/// per taxonomy (`/{taxonomy}/`) and one term page per term (`/{taxonomy}/{slug}/`)
/// — ready to be inserted into the build pipeline before `generateAll()`.
///
/// Example:
/// ```dart
/// final collector = const TaxonomyCollector();
/// final index = collector.collect(['tags'], nonDraftPages);
/// final virtualPages = collector.buildVirtualPages(index, nonDraftPages);
/// pages.addAll(virtualPages);
/// ```
class TaxonomyCollector {
  const TaxonomyCollector();

  /// Builds [TaxonomyIndex] objects for all declared taxonomy names.
  ///
  /// [taxonomyNames] — list from [SiteConfig.taxonomies]
  /// [pages] — non-draft pages (typically already rendered)
  ///
  /// Returns a map from taxonomy name to [TaxonomyIndex].
  Map<String, TaxonomyIndex> collect(List<String> taxonomyNames, List<Page> pages) {
    final result = <String, TaxonomyIndex>{};

    for (final taxName in taxonomyNames) {
      // Map from normalised term → list of page maps
      final termPages = <String, List<Map<String, dynamic>>>{};

      for (final page in pages) {
        final raw = page.frontMatter[taxName];
        if (raw == null) continue;

        final terms = _extractTerms(raw);
        final pageMap = pageToMap(page);

        for (final term in terms) {
          termPages.putIfAbsent(term, () => []).add(pageMap);
        }
      }

      // Build sorted TaxonomyTerm list
      final termList = termPages.entries.map((entry) {
        final name = entry.key;
        final slug = slugify(name);
        return TaxonomyTerm(
          name: name,
          slug: slug,
          url: '/$taxName/$slug/',
          count: entry.value.length,
          pages: entry.value,
        );
      }).toList()..sort((a, b) => a.name.compareTo(b.name));

      result[taxName] = TaxonomyIndex(name: taxName, terms: termList);
    }

    return result;
  }

  /// Builds synthetic [Page] objects for all taxonomies in [index].
  ///
  /// For each [TaxonomyIndex]:
  /// - One listing page (`/{taxonomy}/`) with `kind = section` and
  ///   `frontMatter['terms']` set to the term map list.
  /// - One term page (`/{taxonomy}/{slug}/`) per term with `kind = single`
  ///   and `frontMatter['pages']` set to the term's page map list.
  List<Page> buildVirtualPages(Map<String, TaxonomyIndex> index, List<Page> nonDraftPages) {
    final virtual = <Page>[];

    for (final entry in index.entries) {
      final taxName = entry.key;
      final taxIndex = entry.value;
      final termMaps = taxIndex.toTermMapList();

      // Taxonomy listing page: /{taxonomy}/
      virtual.add(
        Page(
          sourcePath: '_taxonomy/$taxName/_index.md',
          url: '/$taxName/',
          section: taxName,
          kind: PageKind.section,
          isDraft: false,
          isBundle: false,
          bundleAssets: const [],
          frontMatter: <String, dynamic>{'title': _capitalise(taxName), 'taxonomyName': taxName, 'terms': termMaps},
        ),
      );

      // One term page per term: /{taxonomy}/{slug}/
      for (final term in taxIndex.terms) {
        virtual.add(
          Page(
            sourcePath: '_taxonomy/$taxName/${term.slug}.md',
            url: term.url,
            section: taxName,
            kind: PageKind.single,
            isDraft: false,
            isBundle: false,
            bundleAssets: const [],
            frontMatter: <String, dynamic>{
              'title': term.name,
              'taxonomyName': taxName,
              'termName': term.name,
              'termSlug': term.slug,
              'termCount': term.count,
              'pages': term.pages,
              'term': term.toMap(),
            },
          ),
        );
      }
    }

    return virtual;
  }

  /// Normalises a raw term value to lowercase and trims whitespace.
  ///
  /// ```dart
  /// TaxonomyCollector.normalizeTerm('  DART  ') // → 'dart'
  /// ```
  static String normalizeTerm(String raw) => raw.trim().toLowerCase();

  /// Converts a normalised term to a URL-safe slug.
  ///
  /// Algorithm:
  /// 1. Apply [normalizeTerm] (lowercase + trim)
  /// 2. Replace sequences of non-alphanumeric characters with a single `-`
  /// 3. Strip any leading or trailing `-`
  ///
  /// ```dart
  /// TaxonomyCollector.slugify('Hello World') // → 'hello-world'
  /// TaxonomyCollector.slugify('C++ programming') // → 'c-programming'
  /// ```
  static String slugify(String term) {
    final normalized = normalizeTerm(term);
    return normalized.replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
  }

  /// Extracts normalised terms from a front matter value (String or List).
  List<String> _extractTerms(dynamic raw) {
    final terms = <String>[];
    if (raw is String) {
      final n = normalizeTerm(raw);
      if (n.isNotEmpty) terms.add(n);
    } else if (raw is List) {
      for (final item in raw) {
        if (item is String) {
          final n = normalizeTerm(item);
          if (n.isNotEmpty) terms.add(n);
        }
      }
    }
    // Deduplicate while preserving first-occurrence order
    final seen = <String>{};
    return terms.where(seen.add).toList();
  }

  /// Capitalises the first letter of [s].
  static String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
