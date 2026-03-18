/// Pagination utilities for list-type pages.
///
/// The [Paginator] class splits item lists into pages and generates
/// [PaginationContext] objects suitable for template injection.
library;

/// Pagination metadata available in templates as `${pagination.*}`.
class PaginationContext {
  /// Current page number (1-based).
  final int page;

  /// Total number of paginated output pages.
  final int totalPages;

  /// Total number of items across all pages.
  final int totalItems;

  /// Whether there is a next page.
  final bool hasNext;

  /// Whether there is a previous page.
  final bool hasPrev;

  /// URL of the next page, or `null` if this is the last page.
  final String? nextUrl;

  /// URL of the previous page, or `null` if this is the first page.
  final String? prevUrl;

  /// URLs of all paginated pages (for page-number links).
  ///
  /// Index 0 = page 1 URL, index 1 = page 2 URL, etc.
  final List<String> pages;

  const PaginationContext({
    required this.page,
    required this.totalPages,
    required this.totalItems,
    required this.hasNext,
    required this.hasPrev,
    this.nextUrl,
    this.prevUrl,
    required this.pages,
  });

  /// Converts to a map for injection into the Trellis template context.
  Map<String, dynamic> toMap() => <String, dynamic>{
    'page': page,
    'totalPages': totalPages,
    'totalItems': totalItems,
    'hasNext': hasNext,
    'hasPrev': hasPrev,
    'nextUrl': nextUrl,
    'prevUrl': prevUrl,
    'pages': pages,
  };
}

/// A single output page of paginated results.
class PaginatedPage<T> {
  /// The items for this page (a subset of the full list).
  final List<T> items;

  /// The canonical output URL for this page.
  final String url;

  /// Pagination context, or `null` when no pagination is needed
  /// (i.e. all items fit on one page or pagination is disabled).
  final PaginationContext? pagination;

  const PaginatedPage({required this.items, required this.url, this.pagination});
}

/// Splits a list of items into paginated output pages.
///
/// Example:
/// ```dart
/// const paginator = Paginator();
/// final pages = paginator.paginate(
///   items: myItems,
///   baseUrl: '/posts/',
///   pageSize: 5,
/// );
/// ```
class Paginator {
  const Paginator();

  /// Paginates [items] into chunks of [pageSize].
  ///
  /// [baseUrl] is the clean URL of the list page (e.g. `/posts/`).
  ///
  /// Returns a list of [PaginatedPage] objects — one per output page.
  /// If [pageSize] is `null`, `<= 0`, or the number of items fits on a single
  /// page, returns a single [PaginatedPage] with all items and `pagination: null`.
  List<PaginatedPage<T>> paginate<T>({required List<T> items, required String baseUrl, required int? pageSize}) {
    // No pagination when pageSize is disabled or items fit on one page
    if (pageSize == null || pageSize <= 0 || items.length <= pageSize) {
      return [PaginatedPage(items: items, url: baseUrl)];
    }

    final chunks = _chunk(items, pageSize);
    final totalPages = chunks.length;
    final allUrls = [for (var i = 1; i <= totalPages; i++) _pageUrl(baseUrl, i)];

    return [
      for (var i = 0; i < totalPages; i++)
        PaginatedPage(
          items: chunks[i],
          url: allUrls[i],
          pagination: PaginationContext(
            page: i + 1,
            totalPages: totalPages,
            totalItems: items.length,
            hasNext: i < totalPages - 1,
            hasPrev: i > 0,
            nextUrl: i < totalPages - 1 ? allUrls[i + 1] : null,
            prevUrl: i > 0 ? allUrls[i - 1] : null,
            pages: allUrls,
          ),
        ),
    ];
  }

  /// Returns the canonical URL for page [pageNumber].
  ///
  /// Page 1 uses [baseUrl] directly (clean URL).
  /// Pages > 1 use `${baseUrl}page/${pageNumber}/`.
  /// Handles root URL (`/`) correctly to avoid double slashes.
  String _pageUrl(String baseUrl, int pageNumber) {
    if (pageNumber == 1) return baseUrl;
    // Strip trailing slash before appending path segment
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return '${base}page/$pageNumber/';
  }

  /// Splits [items] into chunks of at most [size] elements.
  List<List<T>> _chunk<T>(List<T> items, int size) {
    final chunks = <List<T>>[];
    for (var i = 0; i < items.length; i += size) {
      chunks.add(items.sublist(i, i + size < items.length ? i + size : items.length));
    }
    return chunks;
  }
}
