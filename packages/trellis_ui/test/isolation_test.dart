import 'dart:io';

import 'package:test/test.dart';

import '../../../test/browser_reflow_probe.dart';
import '../tool/src/bundle.dart';

void main() {
  late Directory fixture;
  late StaticSiteServer server;
  BrowserProbe? probe;

  setUpAll(() async {
    fixture = Directory.systemTemp.createTempSync('suite_isolation_');
    server = await StaticSiteServer.serve(fixture);
    if (BrowserProbe.locateChrome() == null) {
      requireChromeInCi('suite CSS isolation');
    } else {
      probe = await BrowserProbe.launch();
    }
  });
  tearDownAll(() async {
    await probe?.close();
    await server.close();
    fixture.deleteSync(recursive: true);
  });

  test('non-suite elements keep their computed styles with the suite stylesheet loaded', () async {
    if (probe == null) return;
    const elements =
        '<h1>Heading</h1><h2>Heading</h2><h3>Heading</h3><h4>Heading</h4>'
        '<h5>Heading</h5><h6>Heading</h6><p>Paragraph <a href="#">link</a></p>'
        '<ul><li>List</li></ul><ol><li>List</li></ol><button>Plain</button><input value="Value">'
        '<select><option>Option</option></select><textarea>Value</textarea><table><tbody><tr><td>Cell</td></tr></tbody></table>'
        '<img alt="Blank" src="data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7">'
        '<pre><code>Code</code></pre><hr><fieldset><legend>Legend</legend></fieldset>'
        '<dialog open>Plain dialog</dialog><div popover>Plain popover</div><tl-unregistered>Plain element</tl-unregistered>';
    const expression = r'''[...document.querySelectorAll('html,body,body *:not([data-slot])')].map(e => {
      const s = getComputedStyle(e); return Object.fromEntries([...s].filter(p => !p.startsWith('--')).map(p => [p,s.getPropertyValue(p)]));
    })''';
    // A nonzero host margin makes an unscoped input reset observable; the UA default is already zero.
    File('${fixture.path}/fixture.css').writeAsStringSync(
      '@layer base { input { margin: 3px; } } [data-slot=button] { position: absolute; top: 0; right: 0; }',
    );
    File('${fixture.path}/suite.css').writeAsStringSync(bundleCss(Directory.current));
    for (final mode in ['', 'dark']) {
      String html(bool styled) =>
          '<!doctype html><html class="$mode"><head><link rel="stylesheet" href="fixture.css">${styled ? '<link rel="stylesheet" href="suite.css">' : ''}</head>'
          '<body>$elements<button data-slot="button" class="trellis-button trellis-button-size-default trellis-button-variant-default">Suite</button></body></html>';
      File('${fixture.path}/index.html').writeAsStringSync(html(false));
      final before = await probe!.evaluate(server.baseUrl, expression, width: 1024, height: 800);
      File('${fixture.path}/index.html').writeAsStringSync(html(true));
      final after = await probe!.evaluate(server.baseUrl, expression, width: 1024, height: 800);
      final expected = (before as List).cast<Map<String, dynamic>>();
      final actual = (after as List).cast<Map<String, dynamic>>();
      expect(actual.length, expected.length);
      for (var i = 0; i < expected.length; i++) {
        for (final p in expected[i].keys) {
          expect(actual[i][p], expected[i][p], reason: 'element $i property $p mode=$mode');
        }
      }
    }
  });

  test('a theme block wins in either link order', () async {
    if (probe == null) return;
    File('${fixture.path}/suite.css').writeAsStringSync(bundleCss(Directory.current));
    File(
      '${fixture.path}/app.css',
    ).writeAsStringSync(':root { --primary: rgb(10, 20, 30); } .dark { --primary: rgb(40, 50, 60); }');
    for (final dark in [false, true]) {
      for (final first in [true, false]) {
        final links = first ? ['app.css', 'suite.css'] : ['suite.css', 'app.css'];
        File('${fixture.path}/index.html').writeAsStringSync(
          '<!doctype html><html class="${dark ? 'dark' : ''}"><head>${links.map((l) => '<link rel="stylesheet" href="$l">').join()}</head>'
          '<body><button data-slot="button" class="trellis-button trellis-button-variant-default trellis-button-size-default">Suite</button></body></html>',
        );
        final actual = await probe!.evaluate(
          server.baseUrl,
          'getComputedStyle(document.querySelector("button")).backgroundColor',
          width: 1024,
          height: 800,
        );
        expect(actual, dark ? 'rgb(40, 50, 60)' : 'rgb(10, 20, 30)', reason: 'dark=$dark appFirst=$first');
      }
    }
  });
}
