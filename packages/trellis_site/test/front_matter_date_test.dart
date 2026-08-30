@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_site/trellis_site.dart';

/// Timezones either side of UTC, including one with a whole-day offset from the
/// other. If date-only values were read as local time, `2026-01-01` would land
/// on four different instants across them — which is the bug TD-014
/// fixes, and what makes them the right probes.
const _timezones = ['UTC', 'Europe/Stockholm', 'Etc/GMT+12', 'Pacific/Kiritimati'];

Page _page(Map<String, dynamic> frontMatter) => Page(
  sourcePath: 'posts/hello.md',
  url: '/posts/hello/',
  section: 'posts',
  kind: PageKind.single,
  isDraft: false,
  isBundle: false,
  bundleAssets: const [],
  frontMatter: frontMatter,
  content: '<p>Hello.</p>',
  summary: 'Hello.',
);

/// Runs [script] in a child VM under [tz] and returns its stdout.
///
/// `TZ` is read once per process by the platform, so an in-process `expect`
/// cannot exercise this. Only a fresh VM per timezone actually proves it.
String _runUnder(String tz, String script) {
  // The probe must live under the package root: Dart resolves `package:` URIs
  // by walking up from the *script* file to find .dart_tool/package_config.json,
  // so a systemTemp script cannot import trellis_site.
  final dir = Directory(p.join(Directory.current.path, '.dart_tool')).createTempSync('tz_probe');
  addTearDown(() => dir.deleteSync(recursive: true));
  final file = File(p.join(dir.path, 'probe.dart'))..writeAsStringSync(script);
  final result = Process.runSync(
    Platform.resolvedExecutable,
    ['run', file.path],
    environment: {'TZ': tz},
    workingDirectory: Directory.current.path,
    includeParentEnvironment: true,
  );
  expect(result.exitCode, 0, reason: 'TZ=$tz: ${result.stderr}');
  return (result.stdout as String).trim();
}

void main() {
  group('resolveFrontMatterDate', () {
    test('anchors a date-only value at UTC midnight', () {
      expect(resolveFrontMatterDate('2026-01-01'), DateTime.utc(2026, 1, 1));
    });

    test('honours an explicit offset on a value that carries a time', () {
      expect(resolveFrontMatterDate('2026-01-01T12:00:00+02:00'), DateTime.utc(2026, 1, 1, 10));
    });

    test('anchors a zone-less date-time at the same UTC calendar fields', () {
      for (final value in [
        '2026-03-15T23:30:00',
        '2026-03-15 23:30:00',
        '2026-03-15T23:30:00,123',
        '20260315T233000',
      ]) {
        expect(resolveFrontMatterDate(value), DateTime.utc(2026, 3, 15, 23, 30, 0, value.contains(',') ? 123 : 0));
      }
    });

    test('returns null for an unparseable value so callers fall back to mtime', () {
      expect(resolveFrontMatterDate('last tuesday'), isNull);
      expect(resolveFrontMatterDate(''), isNull);
      expect(resolveFrontMatterDate(null), isNull);
      expect(resolveFrontMatterDate(42), isNull);
    });

    test('keeps DateTime.parse out-of-range rollover, anchored in UTC', () {
      // Pre-existing semantics: this fix changes the zone, not the validation.
      expect(resolveFrontMatterDate('2026-13-45'), DateTime.utc(2027, 2, 14));
    });
  });

  group('TD-014: build output does not depend on the build machine timezone', () {
    test('a date-only value yields the same feed timestamp in every timezone', () {
      const script = '''
import 'package:trellis_site/trellis_site.dart';
void main() => print(resolveFrontMatterDate('2026-01-01')!.toIso8601String());
''';
      final results = {for (final tz in _timezones) tz: _runUnder(tz, script)};
      expect(results.values.toSet(), {
        '2026-01-01T00:00:00.000Z',
      }, reason: 'date-only values must anchor at UTC midnight, got $results');
    });

    test('rss pubDate and atom updated are identical across timezones', () {
      const script = r'''
import 'package:trellis_site/trellis_site.dart';
void main() {
  final page = Page(
    sourcePath: 'posts/hello.md',
    url: '/posts/hello/',
    section: 'posts',
    kind: PageKind.single,
    isDraft: false,
    isBundle: false,
    bundleAssets: const [],
    frontMatter: {'title': 'Hello', 'date': '2026-01-01'},
    content: '<p>Hello.</p>',
    summary: 'Hello.',
  );
  final gen = FeedGenerator(
    config: const FeedConfig(),
    baseUrl: 'https://example.com',
    siteTitle: 'My Blog',
    siteDescription: 'A blog',
    contentDir: '/does/not/exist',
  );
  print(gen.generateRss([page]));
  print(gen.generateAtom([page]));
}
''';
      final outputs = {for (final tz in _timezones) tz: _runUnder(tz, script)};
      final distinct = outputs.values.toSet();
      expect(distinct, hasLength(1), reason: 'feeds differ by timezone: $outputs');
      expect(distinct.single, contains('Thu, 01 Jan 2026 00:00:00 GMT'));
      expect(distinct.single, contains('2026-01-01T00:00:00Z'));
    });

    test('sitemap lastmod is identical across timezones', () {
      const values = [
        '2026-03-15',
        '2026-03-15T23:30:00',
        '2026-03-15 23:30:00',
        '2026-03-15T23:30:00,123',
        '20260315T233000',
        '2026-03-15T23:30:00-12:00',
      ];
      const scriptPrefix = r'''
import 'package:trellis_site/trellis_site.dart';
void main() {
  final page = Page(
    sourcePath: 'posts/hello.md',
    url: '/posts/hello/',
    section: 'posts',
    kind: PageKind.single,
    isDraft: false,
    isBundle: false,
    bundleAssets: const [],
    frontMatter: {'title': 'Hello', 'date': ''';
      const scriptSuffix = r'''},
    content: '<p>Hello.</p>',
    summary: 'Hello.',
  );
  final gen = SitemapGenerator(baseUrl: 'https://example.com', contentDir: '/does/not/exist');
  print(gen.generate([page]));
}
''';
      for (final value in values) {
        final script = "$scriptPrefix'$value'$scriptSuffix";
        final outputs = {for (final tz in _timezones) tz: _runUnder(tz, script)};
        expect(outputs.values.toSet(), hasLength(1), reason: '$value sitemap differs by timezone: $outputs');
      }
    });
  });

  group('feed and sitemap consume the shared resolver', () {
    test('a date-only front matter value reaches the feed as UTC midnight', () {
      final generator = FeedGenerator(
        config: const FeedConfig(),
        baseUrl: 'https://example.com',
        siteTitle: 'My Blog',
        siteDescription: 'A blog',
        contentDir: '/does/not/exist',
      );
      final atom = generator.generateAtom([
        _page({'title': 'Hello', 'date': '2026-01-01'}),
      ]);
      expect(atom, contains('2026-01-01T00:00:00Z'));
    });

    test('a date-only front matter value reaches the sitemap unshifted', () {
      final sitemap = SitemapGenerator(baseUrl: 'https://example.com', contentDir: '/does/not/exist').generate([
        _page({'title': 'Hello', 'date': '2026-01-01'}),
      ]);
      expect(sitemap, contains('<lastmod>2026-01-01</lastmod>'));
    });
  });
}
