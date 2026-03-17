import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

void main() {
  late Directory tempDir;
  late String originalDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('trellis_build_cmd_');
    originalDir = Directory.current.path;
    Directory.current = tempDir;
  });

  tearDown(() {
    Directory.current = originalDir;
    tempDir.deleteSync(recursive: true);
  });

  /// Creates a minimal valid Trellis site in [dir]:
  /// - `trellis_site.yaml`
  /// - `content/_index.md`
  /// - `layouts/_default/list.html`
  /// - `layouts/home.html`
  void minimalSite(Directory dir, {String outputDir = 'output'}) {
    File(p.join(dir.path, 'trellis_site.yaml')).writeAsStringSync('''
title: Test Site
baseUrl: https://example.com
outputDir: $outputDir
''');
    Directory(p.join(dir.path, 'content')).createSync();
    File(p.join(dir.path, 'content', '_index.md')).writeAsStringSync('''
---
title: Home
---
Hello world.
''');
    Directory(p.join(dir.path, 'layouts', '_default')).createSync(recursive: true);
    File(p.join(dir.path, 'layouts', '_default', 'list.html')).writeAsStringSync('''
<!DOCTYPE html>
<html>
<head><title tl:text="\${page.title}">Title</title></head>
<body><h1 tl:text="\${page.title}">Title</h1></body>
</html>
''');
    File(p.join(dir.path, 'layouts', 'home.html')).writeAsStringSync('''
<!DOCTYPE html>
<html>
<head><title tl:text="\${page.title}">Title</title></head>
<body><h1 tl:text="\${page.title}">Title</h1></body>
</html>
''');
  }

  group('BuildCommand', () {
    // T01: valid site → exits 0, prints summary
    test('T01: builds valid site successfully', () async {
      minimalSite(tempDir);
      final cli = TrellisCli();
      final result = await cli.run(['build']);
      expect(result, 0);
    });

    // T02: no trellis_site.yaml → exits 1, error mentions trellis_site.yaml
    test('T02: no trellis_site.yaml exits 1', () async {
      final cli = TrellisCli();
      final result = await cli.run(['build']);
      expect(result, 1);
    });

    // T03: --output dist → output written to dist/
    test('T03: --output writes to custom directory', () async {
      minimalSite(tempDir, outputDir: 'output');
      final cli = TrellisCli();
      final result = await cli.run(['build', '--output', 'dist']);
      expect(result, 0);
      expect(Directory(p.join(tempDir.path, 'dist')).existsSync(), isTrue);
      expect(Directory(p.join(tempDir.path, 'output')).existsSync(), isFalse);
    });

    // T04: --drafts → draft pages included
    test('T04: --drafts includes draft pages', () async {
      minimalSite(tempDir);
      // Add a draft page
      File(p.join(tempDir.path, 'content', 'draft-page.md')).writeAsStringSync('''
---
title: Draft Page
draft: true
---
Draft content.
''');
      File(p.join(tempDir.path, 'layouts', '_default', 'single.html')).writeAsStringSync('''
<!DOCTYPE html>
<html>
<head><title tl:text="\${page.title}">Title</title></head>
<body><div tl:utext="\${page.content}">content</div></body>
</html>
''');
      final cli = TrellisCli();
      final result = await cli.run(['build', '--drafts']);
      expect(result, 0);
      // Draft page should appear in output when --drafts is set
      final outputPath = p.join(tempDir.path, 'output', 'draft-page', 'index.html');
      expect(File(outputPath).existsSync(), isTrue);
    });

    // T05: --verbose → exits 0
    test('T05: --verbose exits 0', () async {
      minimalSite(tempDir);
      final cli = TrellisCli();
      final result = await cli.run(['build', '--verbose']);
      expect(result, 0);
    });

    // T06: missing layout → exits 1
    test('T06: missing layout exits 1', () async {
      // Create a site where the layout for single pages is missing
      File(p.join(tempDir.path, 'trellis_site.yaml')).writeAsStringSync('''
title: Broken Site
baseUrl: https://example.com
''');
      Directory(p.join(tempDir.path, 'content')).createSync();
      File(p.join(tempDir.path, 'content', 'page.md')).writeAsStringSync('''
---
title: A Page
---
Content.
''');
      // Provide home layout but NOT single/list — so page.md has no layout
      Directory(p.join(tempDir.path, 'layouts')).createSync(recursive: true);
      // No layout files at all → TemplateNotFoundException
      final cli = TrellisCli();
      final result = await cli.run(['build']);
      expect(result, 1);
    });

    // T07: --help → exits 0
    test('T07: --help exits 0', () async {
      final cli = TrellisCli();
      final result = await cli.run(['build', '--help']);
      expect(result, 0);
    });

    // SASS compilation test: .scss file in static/ → compiled .css in output/
    test('compiles SCSS files from static dir', () async {
      minimalSite(tempDir);
      Directory(p.join(tempDir.path, 'static')).createSync();
      File(p.join(tempDir.path, 'static', 'main.scss')).writeAsStringSync(r'''
$primary: #3498db;
.btn { color: $primary; }
''');
      final cli = TrellisCli();
      final result = await cli.run(['build']);
      expect(result, 0);
      final cssPath = p.join(tempDir.path, 'output', 'main.css');
      expect(File(cssPath).existsSync(), isTrue);
      expect(File(cssPath).readAsStringSync(), contains('.btn'));
    });

    // SASS partial _ files should be skipped
    test('skips SCSS partials starting with underscore', () async {
      minimalSite(tempDir);
      Directory(p.join(tempDir.path, 'static')).createSync();
      File(p.join(tempDir.path, 'static', '_variables.scss')).writeAsStringSync(r'''
$primary: #3498db;
''');
      final cli = TrellisCli();
      final result = await cli.run(['build']);
      expect(result, 0);
      // Partial should not produce output file
      expect(File(p.join(tempDir.path, 'output', '_variables.css')).existsSync(), isFalse);
    });

    // --output shorthand -o
    test('short flag -o sets output directory', () async {
      minimalSite(tempDir);
      final cli = TrellisCli();
      final result = await cli.run(['build', '-o', 'public']);
      expect(result, 0);
      expect(Directory(p.join(tempDir.path, 'public')).existsSync(), isTrue);
    });

    // outputDir from config is honoured when --output is not passed
    test('honors outputDir from trellis_site.yaml when --output not specified', () async {
      minimalSite(tempDir, outputDir: 'dist');
      final cli = TrellisCli();
      final result = await cli.run(['build']);
      expect(result, 0);
      expect(Directory(p.join(tempDir.path, 'dist')).existsSync(), isTrue);
      // Default 'output' dir should not be created
      expect(Directory(p.join(tempDir.path, 'output')).existsSync(), isFalse);
    });

    // --base-url overrides config baseUrl
    test('--base-url overrides baseUrl from config', () async {
      minimalSite(tempDir);
      // baseUrl in config is https://example.com (set by minimalSite)
      final cli = TrellisCli();
      final result = await cli.run(['build', '--base-url', 'https://staging.example.com', '--verbose']);
      expect(result, 0);
      // Sitemap should contain the overridden base URL
      final sitemapFile = File(p.join(tempDir.path, 'output', 'sitemap.xml'));
      expect(sitemapFile.existsSync(), isTrue);
      expect(sitemapFile.readAsStringSync(), contains('https://staging.example.com'));
    });
  });
}
