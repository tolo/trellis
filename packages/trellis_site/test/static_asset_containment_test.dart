@TestOn('vm')
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_site/trellis_site.dart';

/// A theme installed with `trellis theme add <git-url>` is third-party code, and
/// the git checkout keeps whatever symlinks the repo committed. If the static
/// walk follows them, a `static/secrets -> ~/.ssh` link in an untrusted theme
/// publishes the target into the built site with no warning and exit 0.
///
/// Reproduced end to end before the fix: the file below landed at
/// `output/escaped/secret.txt`.
void main() {
  late Directory root;
  late Directory outside;

  setUp(() {
    root = Directory.systemTemp.createTempSync('containment_site');
    outside = Directory.systemTemp.createTempSync('containment_outside');
    File(p.join(outside.path, 'secret.txt')).writeAsStringSync('PRIVATE');

    Directory(p.join(root.path, 'content')).createSync(recursive: true);
    File(p.join(root.path, 'content', '_index.md')).writeAsStringSync('---\ntitle: Home\n---\n\nHi.\n');
    Directory(p.join(root.path, 'layouts', '_default')).createSync(recursive: true);
    for (final name in ['list.html', 'single.html']) {
      File(
        p.join(root.path, 'layouts', '_default', name),
      ).writeAsStringSync('<html><body><h1 tl:text="\${page.title}">T</h1></body></html>');
    }
    Directory(p.join(root.path, 'static')).createSync(recursive: true);
    File(p.join(root.path, 'static', 'keep.txt')).writeAsStringSync('kept');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
    if (outside.existsSync()) outside.deleteSync(recursive: true);
  });

  Future<BuildResult> buildSite() =>
      TrellisSite(SiteConfig(siteDir: root.path, title: 'Containment', baseUrl: 'https://example.com')).build();

  test('a symlinked directory under static/ does not publish its target', () async {
    Link(p.join(root.path, 'static', 'escaped')).createSync(outside.path);

    final result = await buildSite();

    expect(
      File(p.join(root.path, 'output', 'escaped', 'secret.txt')).existsSync(),
      isFalse,
      reason: 'a static/ symlink must not publish content from outside the site',
    );
    // The rest of static/ still ships, so containment is not achieved by
    // skipping the walk altogether.
    expect(File(p.join(root.path, 'output', 'keep.txt')).existsSync(), isTrue);
    expect(result.staticFileCount, greaterThan(0));
    // Nothing anywhere in the output carries the outside file's contents.
    final published = Directory(
      p.join(root.path, 'output'),
    ).listSync(recursive: true, followLinks: false).whereType<File>().map((f) => f.readAsStringSync());
    expect(published, everyElement(isNot(contains('PRIVATE'))));
  });

  test('a symlinked file under static/ does not publish its target', () async {
    Link(p.join(root.path, 'static', 'leak.txt')).createSync(p.join(outside.path, 'secret.txt'));

    await buildSite();

    expect(File(p.join(root.path, 'output', 'leak.txt')).existsSync(), isFalse);
    expect(File(p.join(root.path, 'output', 'keep.txt')).existsSync(), isTrue);
  });
}
