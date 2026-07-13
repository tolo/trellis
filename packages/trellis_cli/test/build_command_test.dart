import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_cli/trellis_cli.dart';

import '_workspace_root.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('trellis_build_cmd_');
  });

  tearDown(() {
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

  /// Creates a site with a `dart` fenced code block in its home page and a home
  /// layout that renders `${page.content}`. [highlightEnabled] null omits the
  /// `highlight:` block (defaults on); true/false writes it explicitly.
  void highlightSite(Directory dir, {bool? highlightEnabled}) {
    final highlightBlock = highlightEnabled == null ? '' : 'highlight:\n  enabled: $highlightEnabled\n';
    File(p.join(dir.path, 'trellis_site.yaml')).writeAsStringSync('''
title: Highlight Site
baseUrl: https://example.com
$highlightBlock''');
    Directory(p.join(dir.path, 'content')).createSync();
    File(p.join(dir.path, 'content', '_index.md')).writeAsStringSync('''
---
title: Home
---

```dart
void main() {}
```
''');
    Directory(p.join(dir.path, 'layouts')).createSync(recursive: true);
    File(p.join(dir.path, 'layouts', 'home.html')).writeAsStringSync('''
<!DOCTYPE html>
<html>
<head><title tl:text="\${page.title}">Title</title></head>
<body><div tl:utext="\${page.content}">body</div></body>
</html>
''');
  }

  group('BuildCommand', () {
    // T01: valid site → exits 0, prints summary
    test('T01: builds valid site successfully', () async {
      minimalSite(tempDir);
      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['build']);
      expect(result, 0);
    });

    // T02: no trellis_site.yaml → exits 1, error mentions trellis_site.yaml
    test('T02: no trellis_site.yaml exits 1', () async {
      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['build']);
      expect(result, 1);
    });

    // T03: --output dist → output written to dist/
    test('T03: --output writes to custom directory', () async {
      minimalSite(tempDir, outputDir: 'output');
      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['build', '--output', 'dist']);
      expect(result, 0);
      expect(Directory(p.join(tempDir.path, 'dist')).existsSync(), isTrue);
      expect(Directory(p.join(tempDir.path, 'output')).existsSync(), isFalse);
    });

    /// Creates a site whose home page carries a root-absolute content link and a
    /// theme literal link, for asserting path-prefix rewriting reaches the output.
    void linkSite(Directory dir, {String? pathPrefix}) {
      File(p.join(dir.path, 'trellis_site.yaml')).writeAsStringSync('''
title: Link Site
baseUrl: https://example.com
${pathPrefix != null ? 'pathPrefix: $pathPrefix\n' : ''}''');
      Directory(p.join(dir.path, 'content')).createSync();
      File(p.join(dir.path, 'content', '_index.md')).writeAsStringSync('''
---
title: Home
---
See the [about page](/about/).
''');
      Directory(p.join(dir.path, 'layouts')).createSync();
      File(p.join(dir.path, 'layouts', 'home.html')).writeAsStringSync('''
<!DOCTYPE html>
<html><body>
<a class="lit" href="/docs/">docs</a>
<div tl:utext="\${page.content}">body</div>
</body></html>
''');
    }

    // pathPrefix from config rewrites root-absolute content + literal links.
    test('T03b: pathPrefix from config prefixes root-absolute links', () async {
      linkSite(tempDir, pathPrefix: '/myprefix/');
      final result = await TrellisCli(workingDirectory: tempDir.path).run(['build']);
      expect(result, 0);
      final html = File(p.join(tempDir.path, 'output', 'index.html')).readAsStringSync();
      expect(html, contains('href="/myprefix/about/"'), reason: 'content link prefixed');
      expect(html, contains('href="/myprefix/docs/"'), reason: 'theme literal prefixed');
      expect(html, isNot(contains('href="/about/"')));
      // Output file stays at the unprefixed on-disk path.
      expect(Directory(p.join(tempDir.path, 'output', 'myprefix')).existsSync(), isFalse);
    });

    // --path-prefix flag overrides (and normalizes) when config has none.
    test('T03c: --path-prefix override prefixes links', () async {
      linkSite(tempDir); // no pathPrefix in config
      final result = await TrellisCli(workingDirectory: tempDir.path).run(['build', '--path-prefix', 'myprefix']);
      expect(result, 0);
      final html = File(p.join(tempDir.path, 'output', 'index.html')).readAsStringSync();
      expect(html, contains('href="/myprefix/about/"'));
      expect(html, contains('href="/myprefix/docs/"'));
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
      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['build', '--drafts']);
      expect(result, 0);
      // Draft page should appear in output when --drafts is set
      final outputPath = p.join(tempDir.path, 'output', 'draft-page', 'index.html');
      expect(File(outputPath).existsSync(), isTrue);
    });

    // T05: --verbose → exits 0
    test('T05: --verbose exits 0', () async {
      minimalSite(tempDir);
      final cli = TrellisCli(workingDirectory: tempDir.path);
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
      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['build']);
      expect(result, 1);
    });

    // T07: --help → exits 0
    test('T07: --help exits 0', () async {
      final cli = TrellisCli(workingDirectory: tempDir.path);
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
      final cli = TrellisCli(workingDirectory: tempDir.path);
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
      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['build']);
      expect(result, 0);
      // Partial should not produce output file
      expect(File(p.join(tempDir.path, 'output', '_variables.css')).existsSync(), isFalse);
    });

    // --output shorthand -o
    test('short flag -o sets output directory', () async {
      minimalSite(tempDir);
      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['build', '-o', 'public']);
      expect(result, 0);
      expect(Directory(p.join(tempDir.path, 'public')).existsSync(), isTrue);
    });

    // outputDir from config is honoured when --output is not passed
    test('honors outputDir from trellis_site.yaml when --output not specified', () async {
      minimalSite(tempDir, outputDir: 'dist');
      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['build']);
      expect(result, 0);
      expect(Directory(p.join(tempDir.path, 'dist')).existsSync(), isTrue);
      // Default 'output' dir should not be created
      expect(Directory(p.join(tempDir.path, 'output')).existsSync(), isFalse);
    });

    // Themed site build: theme config preserved, theme layouts used, SASS bridge wired
    test('builds themed site with theme config, layouts, and SASS bridge', () async {
      minimalSite(tempDir);

      // Create a minimal theme
      final themeDir = Directory(p.join(tempDir.path, 'themes', 'test-theme'));
      themeDir.createSync(recursive: true);
      File(p.join(themeDir.path, 'theme.yaml')).writeAsStringSync('''
name: test-theme
version: 1.0.0
author: Test
description: A test theme.
params:
  primary_color:
    type: color
    default: "#ff0000"
    description: Primary color
  site_name:
    type: string
    default: "Default Name"
    description: Site name
''');

      // Theme layouts that use ${theme.*} params
      Directory(p.join(themeDir.path, 'layouts', '_default')).createSync(recursive: true);
      File(p.join(themeDir.path, 'layouts', '_default', 'list.html')).writeAsStringSync(r'''
<!DOCTYPE html>
<html>
<head><title tl:text="${page.title}">Title</title></head>
<body><h1 tl:text="${page.title}">Title</h1></body>
</html>
''');
      File(p.join(themeDir.path, 'layouts', 'home.html')).writeAsStringSync(r'''
<!DOCTYPE html>
<html>
<head><title tl:text="${page.title}">Title</title></head>
<body>
  <h1 tl:text="${page.title}">Title</h1>
  <span class="theme-color" tl:text="${theme.primary_color}">color</span>
  <span class="theme-name" tl:text="${theme.site_name}">name</span>
</body>
</html>
''');

      // Theme SASS
      Directory(p.join(themeDir.path, 'sass')).createSync();
      File(p.join(themeDir.path, 'sass', 'main.scss')).writeAsStringSync(r'''
@import 'variables';
.themed { color: $trellis-primary-color; }
''');
      File(p.join(themeDir.path, 'sass', '_variables.scss')).writeAsStringSync(r'''
$trellis-primary-color: #ff0000 !default;
''');

      // Update site config to use the theme with an override.
      // Delete site-level layouts so theme layouts are used (site-first resolution).
      File(p.join(tempDir.path, 'layouts', 'home.html')).deleteSync();
      File(p.join(tempDir.path, 'layouts', '_default', 'list.html')).deleteSync();
      File(p.join(tempDir.path, 'trellis_site.yaml')).writeAsStringSync('''
title: Test Site
baseUrl: https://example.com
outputDir: output
theme: test-theme
theme_params:
  primary_color: "#00ff00"
  site_name: "Overridden Name"
''');

      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['build']);
      expect(result, 0);

      // Theme layout should be used — output should contain the overridden param
      final homeHtml = File(p.join(tempDir.path, 'output', 'index.html'));
      expect(homeHtml.existsSync(), isTrue);
      final homeContent = homeHtml.readAsStringSync();
      expect(homeContent, contains('#00ff00'));
      expect(homeContent, contains('Overridden Name'));

      // SASS bridge should produce compiled CSS
      final cssFile = File(p.join(tempDir.path, 'output', 'css', 'main.css'));
      expect(cssFile.existsSync(), isTrue);
      final cssContent = cssFile.readAsStringSync();
      expect(cssContent, contains('.themed'));
      // The bridge should have injected the overridden color.
      // SASS compresses #00ff00 to the CSS keyword 'lime'.
      expect(cssContent, contains('lime'));

      // CSS custom properties file should be generated
      final propsFile = File(p.join(tempDir.path, 'output', 'css', 'theme-props.css'));
      expect(propsFile.existsSync(), isTrue);
      expect(propsFile.readAsStringSync(), contains('--trellis-primary-color'));
    });

    // Skin selection (H3): skin: light | dark must force the theme's _skins/
    // palette; skin: auto (and unset) must emit no skin import so output stays
    // byte-for-byte identical to the pre-skin behavior. Precedence: the skin file
    // is imported BEFORE _theme_params.scss, and since both use !default (and SASS
    // honors the first !default), the skin palette wins over theme.yaml's baked-in
    // light color defaults.
    group('skin selection', () {
      /// Creates a theme with light/dark skin palettes and returns its dir.
      Directory skinTheme(Directory dir) {
        final themeDir = Directory(p.join(dir.path, 'themes', 'skin-theme'))..createSync(recursive: true);
        File(p.join(themeDir.path, 'theme.yaml')).writeAsStringSync('''
name: skin-theme
version: 1.0.0
author: Test
description: A skin test theme.
params:
  skin:
    type: enum
    values: [light, dark, auto]
    default: auto
    description: Color scheme
  bg_color:
    type: color
    default: "#ffffff"
    description: Page background
''');
        Directory(p.join(themeDir.path, 'layouts', '_default')).createSync(recursive: true);
        File(p.join(themeDir.path, 'layouts', '_default', 'list.html')).writeAsStringSync(r'''
<!DOCTYPE html><html><head><title tl:text="${page.title}">t</title></head>
<body><h1 tl:text="${page.title}">t</h1></body></html>
''');
        File(p.join(themeDir.path, 'layouts', 'home.html')).writeAsStringSync(r'''
<!DOCTYPE html><html><head><title tl:text="${page.title}">t</title></head>
<body><h1 tl:text="${page.title}">t</h1></body></html>
''');
        final sassDir = Directory(p.join(themeDir.path, 'sass', '_skins'))..createSync(recursive: true);
        File(p.join(themeDir.path, 'sass', 'main.scss')).writeAsStringSync(r'''
@import 'variables';
.bg { background: $trellis-bg-color; }
''');
        File(p.join(themeDir.path, 'sass', '_variables.scss')).writeAsStringSync(r'''
$trellis-bg-color: #ffffff !default;
''');
        File(p.join(sassDir.path, '_light.scss')).writeAsStringSync(r'''
$trellis-bg-color: #ffffff !default;
''');
        // Dark uses a value that survives compression verbatim (#010203 has no
        // shorter form), so the end-to-end assertion is unambiguous.
        File(p.join(sassDir.path, '_dark.scss')).writeAsStringSync(r'''
$trellis-bg-color: #010203 !default;
''');
        return themeDir;
      }

      /// Points the site at [themeName] with the given [skin] value, deleting
      /// site-level layouts so the theme layouts are used.
      void useSkinTheme(Directory dir, String themeName, String skin) {
        // Tolerant of repeat calls in one test (layouts already removed).
        final home = File(p.join(dir.path, 'layouts', 'home.html'));
        if (home.existsSync()) home.deleteSync();
        final list = File(p.join(dir.path, 'layouts', '_default', 'list.html'));
        if (list.existsSync()) list.deleteSync();
        File(p.join(dir.path, 'trellis_site.yaml')).writeAsStringSync('''
title: Test Site
baseUrl: https://example.com
outputDir: output
theme: $themeName
theme_params:
  skin: $skin
''');
      }

      test('skin: dark injects the dark skin import before theme_params', () async {
        minimalSite(tempDir);
        skinTheme(tempDir);
        useSkinTheme(tempDir, 'skin-theme', 'dark');

        expect(await TrellisCli(workingDirectory: tempDir.path).run(['build']), 0);

        final wrapper = File(p.join(tempDir.path, '.trellis', 'build', 'bridge_main.scss')).readAsStringSync();
        expect(wrapper, contains('_skins/_dark.scss'));
        // Skin import must precede theme_params so its !default palette wins.
        expect(wrapper.indexOf('_dark.scss'), lessThan(wrapper.indexOf('theme_params')));

        // End-to-end: the dark-only color must reach the compiled CSS.
        final css = File(p.join(tempDir.path, 'output', 'css', 'main.css')).readAsStringSync();
        expect(css, contains('#010203'));
      });

      test('skin: light injects the light skin import', () async {
        minimalSite(tempDir);
        skinTheme(tempDir);
        useSkinTheme(tempDir, 'skin-theme', 'light');

        expect(await TrellisCli(workingDirectory: tempDir.path).run(['build']), 0);

        final wrapper = File(p.join(tempDir.path, '.trellis', 'build', 'bridge_main.scss')).readAsStringSync();
        expect(wrapper, contains('_skins/_light.scss'));
        expect(wrapper, isNot(contains('_dark.scss')));
      });

      test('skin: auto injects no skin import', () async {
        minimalSite(tempDir);
        skinTheme(tempDir);
        useSkinTheme(tempDir, 'skin-theme', 'auto');

        expect(await TrellisCli(workingDirectory: tempDir.path).run(['build']), 0);

        final wrapper = File(p.join(tempDir.path, '.trellis', 'build', 'bridge_main.scss')).readAsStringSync();
        expect(wrapper, isNot(contains('_skins')));
        expect(wrapper, isNot(contains('_dark.scss')));
        expect(wrapper, isNot(contains('_light.scss')));
      });

      test('skin: dark and skin: light compile to different CSS', () async {
        minimalSite(tempDir);
        skinTheme(tempDir);

        useSkinTheme(tempDir, 'skin-theme', 'dark');
        expect(await TrellisCli(workingDirectory: tempDir.path).run(['build']), 0);
        final darkCss = File(p.join(tempDir.path, 'output', 'css', 'main.css')).readAsStringSync();

        useSkinTheme(tempDir, 'skin-theme', 'light');
        expect(await TrellisCli(workingDirectory: tempDir.path).run(['build']), 0);
        final lightCss = File(p.join(tempDir.path, 'output', 'css', 'main.css')).readAsStringSync();

        expect(darkCss, isNot(equals(lightCss)));
        expect(darkCss, contains('#010203'));
        expect(lightCss, isNot(contains('#010203')));
      });

      test('official themes compile dark syntax tokens into the root palette', () async {
        final workspaceRoot = (await findWorkspaceRoot()).path;
        const expectedTokens = {
          'arbor': {
            'keyword': '#d2a8ff',
            'string': '#7ee787',
            'number': '#ffa657',
            'comment': '#8b949e',
            'function': '#79c0ff',
            'punctuation': '#8b949e',
          },
          'verdant': {
            'keyword': '#c4b5fd',
            'string': '#6ee7b7',
            'number': '#fcd34d',
            'comment': '#6b7280',
            'function': '#93c5fd',
            'punctuation': '#9ca3af',
          },
        };

        for (final entry in expectedTokens.entries) {
          final siteDir = Directory(p.join(tempDir.path, entry.key))..createSync(recursive: true);
          Directory(p.join(siteDir.path, 'content')).createSync();
          File(p.join(siteDir.path, 'content', '_index.md')).writeAsStringSync('''
---
title: Home
---
```dart
final value = 1;
```
''');
          final themeDir = p.join(workspaceRoot, 'themes', entry.key);
          final themeValue = p.relative(themeDir, from: p.join(siteDir.path, 'themes'));
          File(p.join(siteDir.path, 'trellis_site.yaml')).writeAsStringSync('''
title: Dark Theme Test
baseUrl: https://example.com
theme: $themeValue
theme_params:
  skin: dark
''');

          expect(await TrellisCli(workingDirectory: siteDir.path).run(['build']), 0);
          final css = File(p.join(siteDir.path, 'output', 'css', 'main.css')).readAsStringSync();
          final rootPalette = css.split('@media').first;
          for (final token in entry.value.entries) {
            expect(rootPalette, contains('--trellis-code-${token.key}: ${token.value}'), reason: entry.key);
          }
        }
      });

      test('theme without _skins/ files skips the skin import (no crash)', () async {
        minimalSite(tempDir);
        // Theme has a sass/main.scss but no _skins/ directory.
        final themeDir = Directory(p.join(tempDir.path, 'themes', 'no-skins'))..createSync(recursive: true);
        File(p.join(themeDir.path, 'theme.yaml')).writeAsStringSync('''
name: no-skins
version: 1.0.0
author: Test
description: A theme without skins.
params:
  skin:
    type: enum
    values: [light, dark, auto]
    default: auto
    description: Color scheme
''');
        Directory(p.join(themeDir.path, 'layouts', '_default')).createSync(recursive: true);
        File(p.join(themeDir.path, 'layouts', '_default', 'list.html')).writeAsStringSync(r'''
<!DOCTYPE html><html><head><title tl:text="${page.title}">t</title></head><body><h1 tl:text="${page.title}">t</h1></body></html>
''');
        File(p.join(themeDir.path, 'layouts', 'home.html')).writeAsStringSync(r'''
<!DOCTYPE html><html><head><title tl:text="${page.title}">t</title></head><body><h1 tl:text="${page.title}">t</h1></body></html>
''');
        Directory(p.join(themeDir.path, 'sass')).createSync();
        File(p.join(themeDir.path, 'sass', 'main.scss')).writeAsStringSync('.no-skins { color: red; }\n');

        useSkinTheme(tempDir, 'no-skins', 'dark');

        expect(await TrellisCli(workingDirectory: tempDir.path).run(['build']), 0);
        final wrapper = File(p.join(tempDir.path, '.trellis', 'build', 'bridge_main.scss')).readAsStringSync();
        expect(wrapper, isNot(contains('_skins')));
        expect(File(p.join(tempDir.path, 'output', 'css', 'main.css')).existsSync(), isTrue);
      });
    });

    // A theme referenced by a RELATIVE escaping path (theme lives outside the
    // site dir) must still have its SASS compiled — guards the build_command
    // themeDir normalization. Without it, the site builds but ships unstyled.
    test('relative theme path compiles theme SASS (not silently unstyled)', () async {
      // Theme is a sibling of the (nested) site, referenced via ../../.
      final themeDir = Directory(p.join(tempDir.path, 'shared-theme'))..createSync(recursive: true);
      File(p.join(themeDir.path, 'theme.yaml')).writeAsStringSync('name: shared\nversion: 1.0.0\n');
      Directory(p.join(themeDir.path, 'layouts', '_default')).createSync(recursive: true);
      File(p.join(themeDir.path, 'layouts', 'home.html')).writeAsStringSync(
        '<!DOCTYPE html><html><body><link href="/css/main.css"><h1 tl:text="\${page.title}">t</h1></body></html>\n',
      );
      File(
        p.join(themeDir.path, 'layouts', '_default', 'list.html'),
      ).writeAsStringSync('<!DOCTYPE html><html><body><h1 tl:text="\${page.title}">t</h1></body></html>\n');
      Directory(p.join(themeDir.path, 'sass')).createSync();
      File(p.join(themeDir.path, 'sass', 'main.scss')).writeAsStringSync('.themed-rel { color: red; }\n');

      final siteDir = Directory(p.join(tempDir.path, 'mysite'))..createSync(recursive: true);
      File(
        p.join(siteDir.path, 'trellis_site.yaml'),
      ).writeAsStringSync('title: Rel\nbaseUrl: https://example.com\ntheme: ../../shared-theme\n');
      Directory(p.join(siteDir.path, 'content')).createSync();
      File(p.join(siteDir.path, 'content', '_index.md')).writeAsStringSync('---\ntitle: Home\n---\nHi\n');

      final result = await TrellisCli(workingDirectory: siteDir.path).run(['build']);
      expect(result, 0);
      final css = File(p.join(siteDir.path, 'output', 'css', 'main.css'));
      expect(css.existsSync(), isTrue, reason: 'theme SASS must compile for a relative theme path');
      expect(css.readAsStringSync(), contains('themed-rel'));
    });

    // --base-url overrides config baseUrl
    test('--base-url overrides baseUrl from config', () async {
      minimalSite(tempDir);
      // baseUrl in config is https://example.com (set by minimalSite)
      final cli = TrellisCli(workingDirectory: tempDir.path);
      final result = await cli.run(['build', '--base-url', 'https://staging.example.com', '--verbose']);
      expect(result, 0);
      // Sitemap should contain the overridden base URL
      final sitemapFile = File(p.join(tempDir.path, 'output', 'sitemap.xml'));
      expect(sitemapFile.existsSync(), isTrue);
      expect(sitemapFile.readAsStringSync(), contains('https://staging.example.com'));
    });

    // Build-time syntax highlighting (ADR-010): default on, honors an explicit
    // `highlight: enabled: false` through the CLI (regression guard — the CLI
    // reconstructs SiteConfig field-by-field and must thread highlightConfig).
    test('highlights fenced code by default; ships no /prism/ assets', () async {
      highlightSite(tempDir); // no highlight: block → defaults on
      final result = await TrellisCli(workingDirectory: tempDir.path).run(['build']);
      expect(result, 0);
      final html = File(p.join(tempDir.path, 'output', 'index.html')).readAsStringSync();
      expect(html, contains('class="hljs-'));
      expect(html, contains('<code class="language-dart">'));
      expect(html, isNot(contains('/prism/')));
    });

    test('highlight.enabled: false leaves code plain through the CLI (S08)', () async {
      highlightSite(tempDir, highlightEnabled: false);
      final result = await TrellisCli(workingDirectory: tempDir.path).run(['build']);
      expect(result, 0);
      final html = File(p.join(tempDir.path, 'output', 'index.html')).readAsStringSync();
      expect(html, contains('<code class="language-dart">'));
      expect(html, isNot(contains('hljs-')));
    });
  });
}
