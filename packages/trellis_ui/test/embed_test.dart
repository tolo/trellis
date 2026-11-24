import 'dart:io';

import 'package:test/test.dart';

import '../../../test/browser_reflow_probe.dart';

import '../tool/embed.dart' as embed;
import '../tool/src/bundle.dart';

void main() {
  test('embedded assets regenerate byte for byte from the sources and generated CSS', () {
    expect(embed.embeddedSource(Directory.current), File('lib/src/embedded_assets.g.dart').readAsStringSync());
  });

  test('compressed hand CSS preserves the upstream sheet, cascade order and embedded Unicode strings', () {
    final fixture = Directory.systemTemp.createTempSync('suite_css_');
    addTearDown(() => fixture.deleteSync(recursive: true));
    final generated = Directory('${fixture.path}/generated')..createSync();
    final hand = Directory('${fixture.path}/assets/css/hand')..createSync(recursive: true);
    const upstream = '/*! upstream notice */\n@layer base, trellis-hand;';
    File('${generated.path}/trellis.min.css').writeAsStringSync(upstream);
    File('${hand.path}/zz-label.css').writeAsStringSync('.label::before { content: "✓  →"; }');
    File('${hand.path}/label.css').writeAsStringSync('.label::before { content: "first"; }');

    final css = bundleCss(fixture);
    expect(css, startsWith('$upstream\n@layer trellis-hand'));
    expect(css, contains('first'));
    expect(css.indexOf('✓  →'), greaterThan(css.indexOf('first')));
  });

  test('the bundle orders scripts by name and rejects module syntax', () {
    final fixture = Directory.systemTemp.createTempSync('suite_bundle_');
    addTearDown(() => fixture.deleteSync(recursive: true));
    final scripts = Directory('${fixture.path}/assets/js')..createSync(recursive: true);
    final a = File('${scripts.path}/00-a.js')..writeAsStringSync('const first = 1;');
    File('${scripts.path}/10-b.js').writeAsStringSync('const second = first + 1;');
    final bundle = bundleScript(fixture);
    expect(bundle.indexOf('const first'), lessThan(bundle.indexOf('const second')));
    expect(bundle, startsWith('(function () {\n"use strict";'));
    expect(bundle, endsWith('})();\n'));
    for (final source in [
      'import x from "./a.js";',
      'export const x = 1;',
      'import("./a.js");',
      r'const text = `${import("./a.js")}`;',
      r'const text = `${({ run: () => import("./a.js") }).run()}`;',
      r'const text = `${`nested ${import("./a.js")}`}`;',
    ]) {
      a.writeAsStringSync(source);
      expect(() => bundleScript(fixture), throwsFormatException);
    }
    a.writeAsStringSync('const text = "import export"; /* export */ // import\nconst valid = true;');
    expect(bundleScript(fixture), contains('const valid'));
    a.writeAsStringSync(r'const text = `import export ${"import export"}`;');
    expect(bundleScript(fixture), contains('const text'));
  });
  test('bundled files keep their statement boundaries in a classic script', () async {
    if (BrowserProbe.locateChrome() == null) {
      requireChromeInCi('classic bundle statement boundaries');
      return;
    }
    final fixture = Directory.systemTemp.createTempSync('suite_script_boundaries_');
    final scripts = Directory('${fixture.path}/assets/js')..createSync(recursive: true);
    File('${scripts.path}/00-first.js').writeAsStringSync("globalThis.bundleOrder = ['first']");
    File(
      '${scripts.path}/10-second.js',
    ).writeAsStringSync("(function () { globalThis.bundleOrder.push('second'); })();");
    File('${fixture.path}/bundle.js').writeAsStringSync(bundleScript(fixture));
    File('${fixture.path}/index.html').writeAsStringSync('<!doctype html><script src="bundle.js"></script>');
    final server = await StaticSiteServer.serve(fixture);
    final probe = await BrowserProbe.launch();
    try {
      final result = await probe.evaluate(server.baseUrl, 'globalThis.bundleOrder', width: 390, height: 844);
      expect(result, ['first', 'second']);
    } finally {
      await probe.close();
      await server.close();
      fixture.deleteSync(recursive: true);
    }
  });
}
