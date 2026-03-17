import 'package:test/test.dart';
import 'package:trellis_site/trellis_site.dart';

void main() {
  const paginator = Paginator();

  group('Paginator — no pagination', () {
    test('pageSize null → single page with all items, no pagination context', () {
      final pages = paginator.paginate(items: [1, 2, 3], baseUrl: '/posts/', pageSize: null);
      expect(pages, hasLength(1));
      expect(pages[0].items, [1, 2, 3]);
      expect(pages[0].pagination, isNull);
      expect(pages[0].url, '/posts/');
    });

    test('pageSize 0 → treated as no pagination', () {
      final pages = paginator.paginate(items: [1, 2, 3], baseUrl: '/posts/', pageSize: 0);
      expect(pages, hasLength(1));
      expect(pages[0].pagination, isNull);
    });

    test('pageSize negative → treated as no pagination', () {
      final pages = paginator.paginate(items: [1, 2, 3], baseUrl: '/posts/', pageSize: -5);
      expect(pages, hasLength(1));
      expect(pages[0].pagination, isNull);
    });

    test('items exactly equal to pageSize → single page, no pagination', () {
      final pages = paginator.paginate(items: [1, 2], baseUrl: '/posts/', pageSize: 2);
      expect(pages, hasLength(1));
      expect(pages[0].pagination, isNull);
    });

    test('items fewer than pageSize → single page, no pagination', () {
      final pages = paginator.paginate(items: [1], baseUrl: '/posts/', pageSize: 5);
      expect(pages, hasLength(1));
      expect(pages[0].pagination, isNull);
    });

    test('empty items → single page with empty list, no pagination', () {
      final pages = paginator.paginate<int>(items: [], baseUrl: '/posts/', pageSize: 5);
      expect(pages, hasLength(1));
      expect(pages[0].items, isEmpty);
      expect(pages[0].pagination, isNull);
    });
  });

  group('Paginator — pagination enabled', () {
    test('5 items, pageSize 2 → 3 pages', () {
      final pages = paginator.paginate(items: [1, 2, 3, 4, 5], baseUrl: '/posts/', pageSize: 2);
      expect(pages, hasLength(3));
    });

    test('items correctly distributed across pages', () {
      final pages = paginator.paginate(items: [1, 2, 3, 4, 5], baseUrl: '/posts/', pageSize: 2);
      expect(pages[0].items, [1, 2]);
      expect(pages[1].items, [3, 4]);
      expect(pages[2].items, [5]);
    });

    test('large count: 100 items, pageSize 10 → 10 pages', () {
      final items = List.generate(100, (i) => i);
      final pages = paginator.paginate(items: items, baseUrl: '/list/', pageSize: 10);
      expect(pages, hasLength(10));
      expect(pages.last.items, hasLength(10));
    });

    test('works with Map items (realistic use case)', () {
      final items = [
        {'title': 'Post 1'},
        {'title': 'Post 2'},
        {'title': 'Post 3'},
      ];
      final pages = paginator.paginate(items: items, baseUrl: '/posts/', pageSize: 2);
      expect(pages, hasLength(2));
      expect(pages[0].items, hasLength(2));
      expect(pages[1].items, hasLength(1));
    });
  });

  group('Paginator — URL generation', () {
    test('page 1 uses baseUrl directly', () {
      final pages = paginator.paginate(items: [1, 2, 3], baseUrl: '/posts/', pageSize: 1);
      expect(pages[0].url, '/posts/');
    });

    test('page 2 uses baseUrl + page/2/', () {
      final pages = paginator.paginate(items: [1, 2, 3], baseUrl: '/posts/', pageSize: 1);
      expect(pages[1].url, '/posts/page/2/');
    });

    test('page 3 uses baseUrl + page/3/', () {
      final pages = paginator.paginate(items: [1, 2, 3], baseUrl: '/posts/', pageSize: 1);
      expect(pages[2].url, '/posts/page/3/');
    });

    test('root URL / → page 2 is /page/2/', () {
      final pages = paginator.paginate(items: [1, 2, 3], baseUrl: '/', pageSize: 2);
      expect(pages[0].url, '/');
      expect(pages[1].url, '/page/2/');
    });

    test('no double slashes in paginated URLs', () {
      final pages = paginator.paginate(items: [1, 2, 3], baseUrl: '/posts/', pageSize: 1);
      for (final page in pages) {
        expect(page.url, isNot(contains('//')));
      }
    });
  });

  group('Paginator — PaginationContext values', () {
    late List<PaginatedPage<int>> pages;

    setUp(() {
      pages = paginator.paginate(items: [1, 2, 3, 4, 5], baseUrl: '/posts/', pageSize: 2);
    });

    test('page numbers are 1-based', () {
      expect(pages[0].pagination!.page, 1);
      expect(pages[1].pagination!.page, 2);
      expect(pages[2].pagination!.page, 3);
    });

    test('totalPages is correct', () {
      for (final page in pages) {
        expect(page.pagination!.totalPages, 3);
      }
    });

    test('totalItems is correct', () {
      for (final page in pages) {
        expect(page.pagination!.totalItems, 5);
      }
    });

    test('first page: hasNext=true, hasPrev=false', () {
      final first = pages[0].pagination!;
      expect(first.hasNext, isTrue);
      expect(first.hasPrev, isFalse);
    });

    test('middle page: hasNext=true, hasPrev=true', () {
      final middle = pages[1].pagination!;
      expect(middle.hasNext, isTrue);
      expect(middle.hasPrev, isTrue);
    });

    test('last page: hasNext=false, hasPrev=true', () {
      final last = pages[2].pagination!;
      expect(last.hasNext, isFalse);
      expect(last.hasPrev, isTrue);
    });

    test('nextUrl is null on last page', () {
      expect(pages[2].pagination!.nextUrl, isNull);
    });

    test('prevUrl is null on first page', () {
      expect(pages[0].pagination!.prevUrl, isNull);
    });

    test('nextUrl points to next page URL', () {
      expect(pages[0].pagination!.nextUrl, '/posts/page/2/');
      expect(pages[1].pagination!.nextUrl, '/posts/page/3/');
    });

    test('prevUrl points to previous page URL', () {
      expect(pages[1].pagination!.prevUrl, '/posts/');
      expect(pages[2].pagination!.prevUrl, '/posts/page/2/');
    });

    test('pages list contains all page URLs in order', () {
      final allUrls = pages[0].pagination!.pages;
      expect(allUrls, hasLength(3));
      expect(allUrls[0], '/posts/');
      expect(allUrls[1], '/posts/page/2/');
      expect(allUrls[2], '/posts/page/3/');
    });

    test('pages list is same across all paginated pages', () {
      final urlsPage1 = pages[0].pagination!.pages;
      final urlsPage2 = pages[1].pagination!.pages;
      expect(urlsPage1, urlsPage2);
    });
  });

  group('PaginationContext.toMap()', () {
    test('toMap returns all expected keys', () {
      final ctx = PaginationContext(
        page: 2,
        totalPages: 3,
        totalItems: 5,
        hasNext: true,
        hasPrev: true,
        nextUrl: '/posts/page/3/',
        prevUrl: '/posts/',
        pages: ['/posts/', '/posts/page/2/', '/posts/page/3/'],
      );
      final map = ctx.toMap();
      expect(map['page'], 2);
      expect(map['totalPages'], 3);
      expect(map['totalItems'], 5);
      expect(map['hasNext'], isTrue);
      expect(map['hasPrev'], isTrue);
      expect(map['nextUrl'], '/posts/page/3/');
      expect(map['prevUrl'], '/posts/');
      expect(map['pages'], hasLength(3));
    });
  });
}
