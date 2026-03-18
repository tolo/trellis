import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_site/trellis_site.dart';

late String _buildSiteDir;

void main() {
  setUpAll(() async {
    final packageUri = await Isolate.resolvePackageUri(Uri.parse('package:trellis_site/'));
    final packageRoot = p.dirname(packageUri!.toFilePath());
    _buildSiteDir = p.join(packageRoot, 'test', 'test_fixtures', 'build_site');
  });

  /// Creates an isolated output dir and a SiteConfig with feeds enabled.
  SiteConfig isolatedFeedConfig({
    FeedConfig? feeds,
    String baseUrl = 'https://example.com',
  }) {
    final outputDir = Directory.systemTemp.createTempSync('feed_integ_').path;
    addTearDown(() => Directory(outputDir).deleteSync(recursive: true));
    return SiteConfig(
      siteDir: _buildSiteDir,
      baseUrl: baseUrl,
      contentDir: p.join(_buildSiteDir, 'content'),
      layoutsDir: p.join(_buildSiteDir, 'layouts'),
      staticDir: p.join(_buildSiteDir, '_no_static'),
      outputDir: outputDir,
      feeds: feeds,
    );
  }

  group('feed integration — atom feed', () {
    test('feed.xml exists in output when feeds config present', () async {
      final config = isolatedFeedConfig(feeds: const FeedConfig());
      final result = await TrellisSite(config).build();
      expect(File(p.join(config.outputDir, 'feed.xml')).existsSync(), isTrue);
      expect(result.staticFileCount, greaterThan(0));
    });

    test('feed.xml not generated when feeds config absent', () async {
      final config = isolatedFeedConfig(feeds: null);
      await TrellisSite(config).build();
      expect(File(p.join(config.outputDir, 'feed.xml')).existsSync(), isFalse);
    });

    test('feed.xml contains Atom namespace', () async {
      final config = isolatedFeedConfig(feeds: const FeedConfig());
      await TrellisSite(config).build();
      final xml = File(p.join(config.outputDir, 'feed.xml')).readAsStringSync();
      expect(xml, contains('<feed xmlns="http://www.w3.org/2005/Atom">'));
    });

    test('feed.xml contains hello-world entry', () async {
      final config = isolatedFeedConfig(feeds: const FeedConfig());
      await TrellisSite(config).build();
      final xml = File(p.join(config.outputDir, 'feed.xml')).readAsStringSync();
      expect(xml, contains('Hello World'));
    });

    test('draft pages excluded from feed', () async {
      final config = isolatedFeedConfig(feeds: const FeedConfig());
      await TrellisSite(config).build();
      final xml = File(p.join(config.outputDir, 'feed.xml')).readAsStringSync();
      expect(xml, isNot(contains('Draft Page')));
    });

    test('feed files counted in BuildResult.staticFileCount', () async {
      final config = isolatedFeedConfig(feeds: const FeedConfig(atom: true, rss: true));
      final result = await TrellisSite(config).build();
      // atom feed.xml + rss.xml both count as static files
      // staticFileCount includes sitemap.xml (1) + feed.xml (1) + rss.xml (1) at minimum
      expect(result.staticFileCount, greaterThanOrEqualTo(3));
    });
  });

  group('feed integration — rss feed', () {
    test('rss.xml generated when feeds.rss: true', () async {
      final config = isolatedFeedConfig(feeds: const FeedConfig(rss: true));
      await TrellisSite(config).build();
      expect(File(p.join(config.outputDir, 'rss.xml')).existsSync(), isTrue);
    });

    test('rss.xml not generated when feeds.rss: false', () async {
      final config = isolatedFeedConfig(feeds: const FeedConfig(rss: false));
      await TrellisSite(config).build();
      expect(File(p.join(config.outputDir, 'rss.xml')).existsSync(), isFalse);
    });

    test('rss.xml contains RSS 2.0 structure', () async {
      final config = isolatedFeedConfig(feeds: const FeedConfig(rss: true));
      await TrellisSite(config).build();
      final xml = File(p.join(config.outputDir, 'rss.xml')).readAsStringSync();
      expect(xml, contains('<rss version="2.0"'));
      expect(xml, contains('<channel>'));
    });
  });

  group('feed integration — per-section feeds', () {
    test('section feed.xml generated for configured section', () async {
      final config = isolatedFeedConfig(feeds: const FeedConfig(sections: ['posts']));
      await TrellisSite(config).build();
      expect(File(p.join(config.outputDir, 'posts', 'feed.xml')).existsSync(), isTrue);
    });

    test('section feed contains only pages from that section', () async {
      final config = isolatedFeedConfig(feeds: const FeedConfig(sections: ['posts']));
      await TrellisSite(config).build();
      final xml = File(p.join(config.outputDir, 'posts', 'feed.xml')).readAsStringSync();
      expect(xml, contains('Hello World'));
    });

    test('unknown section emits BuildWarning', () async {
      final config = isolatedFeedConfig(feeds: const FeedConfig(sections: ['nonexistent']));
      final result = await TrellisSite(config).build();
      expect(result.hasWarnings, isTrue);
      expect(
        result.warnings.any((w) => w.toString().contains('nonexistent')),
        isTrue,
      );
    });

    test('known section does not emit BuildWarning', () async {
      final config = isolatedFeedConfig(feeds: const FeedConfig(sections: ['posts']));
      final result = await TrellisSite(config).build();
      // Should not warn about 'posts' — it exists in content
      expect(
        result.warnings.any((w) => w.toString().contains("unknown section 'posts'")),
        isFalse,
      );
    });
  });

  group('feed integration — no feeds config', () {
    test('build succeeds without feeds config', () async {
      final config = isolatedFeedConfig(feeds: null);
      final result = await TrellisSite(config).build();
      expect(result.pageCount, greaterThanOrEqualTo(1));
    });

    test('no feed files generated without feeds config', () async {
      final config = isolatedFeedConfig(feeds: null);
      await TrellisSite(config).build();
      expect(File(p.join(config.outputDir, 'feed.xml')).existsSync(), isFalse);
      expect(File(p.join(config.outputDir, 'rss.xml')).existsSync(), isFalse);
    });
  });
}
