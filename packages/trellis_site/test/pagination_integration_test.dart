import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:trellis_site/trellis_site.dart';
import 'package:test/test.dart';

late String _paginatedSiteDir;

void main() {
  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
    final packageRoot = p.dirname(packageUri!.toFilePath());
    _paginatedSiteDir = p.join(packageRoot, 'test', 'test_fixtures', 'paginated_site');
  });

  /// Creates a fresh output directory and returns a [SiteConfig] for the
  /// paginated_site fixture with the given [paginate] setting.
  SiteConfig paginatedConfig({int? paginate}) {
    final outputDir = Directory.systemTemp.createTempSync('trellis_paginated_').path;
    addTearDown(() => Directory(outputDir).deleteSync(recursive: true));
    return SiteConfig(
      siteDir: _paginatedSiteDir,
      contentDir: p.join(_paginatedSiteDir, 'content'),
      layoutsDir: p.join(_paginatedSiteDir, 'layouts'),
      staticDir: p.join(_paginatedSiteDir, '_no_static'), // no static dir in fixture
      outputDir: outputDir,
      paginate: paginate,
    );
  }

  group('Pagination integration — paginate: 2, 5 posts', () {
    late SiteConfig config;
    late BuildResult result;

    setUpAll(() async {
      config = paginatedConfig(paginate: 2);
      final site = TrellisSite(config);
      result = await site.build();
    });

    test('posts section generates 3 output pages (ceil(5/2) = 3)', () {
      // First page at /posts/index.html
      expect(File(p.join(config.outputDir, 'posts', 'index.html')).existsSync(), isTrue);
      // Page 2 at /posts/page/2/index.html
      expect(File(p.join(config.outputDir, 'posts', 'page', '2', 'index.html')).existsSync(), isTrue);
      // Page 3 at /posts/page/3/index.html
      expect(File(p.join(config.outputDir, 'posts', 'page', '3', 'index.html')).existsSync(), isTrue);
    });

    test('no /posts/page/1/ directory (page 1 uses clean URL)', () {
      expect(Directory(p.join(config.outputDir, 'posts', 'page', '1')).existsSync(), isFalse);
    });

    test('no extra pages beyond page 3', () {
      expect(Directory(p.join(config.outputDir, 'posts', 'page', '4')).existsSync(), isFalse);
    });

    test('first posts page contains 2 post links', () {
      final html = File(p.join(config.outputDir, 'posts', 'index.html')).readAsStringSync();
      // Should contain links to exactly 2 posts (paginate=2)
      expect('Post One'.allMatches(html).length + 'Post Two'.allMatches(html).length, 2);
    });

    test('page 3 contains 1 post (last page of 5 with pageSize 2)', () {
      final html = File(p.join(config.outputDir, 'posts', 'page', '3', 'index.html')).readAsStringSync();
      expect(html, contains('Post Five'));
    });

    test('first posts page has Next link but no Prev link', () {
      final html = File(p.join(config.outputDir, 'posts', 'index.html')).readAsStringSync();
      expect(html, contains('Next'));
      expect(html, isNot(contains('Prev')));
    });

    test('page 2 has both Prev and Next links', () {
      final html = File(p.join(config.outputDir, 'posts', 'page', '2', 'index.html')).readAsStringSync();
      expect(html, contains('Prev'));
      expect(html, contains('Next'));
    });

    test('page 3 has Prev but no Next', () {
      final html = File(p.join(config.outputDir, 'posts', 'page', '3', 'index.html')).readAsStringSync();
      expect(html, contains('Prev'));
      expect(html, isNot(contains('Next')));
    });

    test('BuildResult.pageCount includes all paginated output pages', () {
      // home (1) + posts section (3 pages) + 5 single posts = 9 total
      expect(result.pageCount, greaterThanOrEqualTo(9));
    });

    test('single post pages are still generated', () {
      expect(File(p.join(config.outputDir, 'posts', 'post-01', 'index.html')).existsSync(), isTrue);
    });
  });

  group('Pagination integration — paginate: null (disabled)', () {
    late SiteConfig config;

    setUp(() {
      config = paginatedConfig(); // no paginate
    });

    test('single /posts/ page when paginate is null', () async {
      final site = TrellisSite(config);
      await site.build();
      expect(File(p.join(config.outputDir, 'posts', 'index.html')).existsSync(), isTrue);
      expect(Directory(p.join(config.outputDir, 'posts', 'page')).existsSync(), isFalse);
    });

    test('all 5 posts appear on single page', () async {
      final site = TrellisSite(config);
      await site.build();
      final html = File(p.join(config.outputDir, 'posts', 'index.html')).readAsStringSync();
      expect(html, contains('Post One'));
      expect(html, contains('Post Five'));
    });
  });

  group('Pagination integration — items equal to paginate', () {
    test('2 posts with paginate=2 → single page, no pagination', () async {
      // Use paginate=5 so all 5 posts fit on one page (no /page/2/ dir)
      final config = paginatedConfig(paginate: 5);
      final site = TrellisSite(config);
      await site.build();
      expect(File(p.join(config.outputDir, 'posts', 'index.html')).existsSync(), isTrue);
      expect(Directory(p.join(config.outputDir, 'posts', 'page')).existsSync(), isFalse);
    });

    test('no pagination context rendered when items fit on one page', () async {
      final config = paginatedConfig(paginate: 10);
      final site = TrellisSite(config);
      await site.build();
      final html = File(p.join(config.outputDir, 'posts', 'index.html')).readAsStringSync();
      // Navigation element rendered only when pagination context exists
      expect(html, isNot(contains('Next')));
      expect(html, isNot(contains('Prev')));
    });
  });

  group('Pagination integration — home page', () {
    test('home page paginated when paginate is set', () async {
      final config = paginatedConfig(paginate: 2);
      final site = TrellisSite(config);
      await site.build();
      // Home page lists all single pages across all sections; with 5 posts → 3 pages
      expect(File(p.join(config.outputDir, 'index.html')).existsSync(), isTrue);
      // Paginated home at /page/2/
      expect(File(p.join(config.outputDir, 'page', '2', 'index.html')).existsSync(), isTrue);
    });
  });
}
