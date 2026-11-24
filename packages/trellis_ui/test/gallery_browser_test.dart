import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import '../../../test/browser_reflow_probe.dart';
import '../tool/src/gallery.dart';

void main() {
  test('the button page loads under the strict policy with no violations', () async {
    if (BrowserProbe.locateChrome() == null) {
      requireChromeInCi('strict-policy button gallery');
      return;
    }
    final server = await shelf_io.serve(galleryHandler(Directory.current), InternetAddress.loopbackIPv4, 0);
    final probe = await BrowserProbe.launch();
    try {
      for (final width in [390, 1440]) {
        final result =
            await probe.evaluate(
                  Uri.parse('http://127.0.0.1:${server.port}/components/button'),
                  r'''(async () => {
          await new Promise(r => setTimeout(r, 60));
          const button = document.querySelector('.trellis-button-variant-default');
          const sample = document.createElement('span');
          sample.style.backgroundColor = 'var(--primary)';
          document.body.append(sample);
          const expected = getComputedStyle(sample).backgroundColor;
          sample.remove();
          return { violations: window.trellisCspViolations, background: getComputedStyle(button).backgroundColor,
            expected, boxSizing: getComputedStyle(button).boxSizing,
            count: document.querySelectorAll('[data-slot=button]').length,
            overflow: document.documentElement.scrollWidth > document.documentElement.clientWidth,
            htmxVersion: htmx.version, allowEval: htmx.config.allowEval, indicators: htmx.config.includeIndicatorStyles };
        })()''',
                  width: width,
                  height: 844,
                )
                as Map<String, dynamic>;
        expect(result['violations'], isEmpty);
        expect(result['background'], result['expected']);
        expect(result['background'], isNot('rgba(0, 0, 0, 0)'));
        expect(result['boxSizing'], 'border-box');
        expect(result['count'], 17);
        expect(result['overflow'], isFalse, reason: 'width $width');
        expect(result['htmxVersion'], '2.0.10');
        expect(result['allowEval'], isFalse);
        expect(result['indicators'], isFalse);
      }
    } finally {
      await probe.close();
      await server.close(force: true);
    }
  });
  test('refresh example replaces content without nesting gallery shells', () async {
    if (BrowserProbe.locateChrome() == null) {
      requireChromeInCi('gallery refresh example');
      return;
    }
    final server = await shelf_io.serve(galleryHandler(Directory.current), InternetAddress.loopbackIPv4, 0);
    final probe = await BrowserProbe.launch();
    try {
      await probe.evaluate(
        Uri.parse('http://127.0.0.1:${server.port}/components/button'),
        'true',
        width: 1440,
        height: 844,
      );
      for (var i = 0; i < 2; i++) {
        final result =
            await probe.evaluateHere(r'''(async () => {
          await new Promise((resolve, reject) => {
            document.body.addEventListener('htmx:afterSettle', resolve, {once: true});
            setTimeout(() => reject(new Error('refresh did not settle')), 3000);
            document.querySelector('button[hx-get]').click();
          });
          return {main: document.querySelectorAll('main').length, header: document.querySelectorAll('header').length,
            buttons: document.querySelectorAll('[data-slot=button]').length, violations: window.trellisCspViolations};
        })()''')
                as Map<String, dynamic>;
        expect(result['main'], 1);
        expect(result['header'], 1);
        expect(result['buttons'], 17);
        expect(result['violations'], isEmpty);
      }
    } finally {
      await probe.close();
      await server.close(force: true);
    }
  });
}
