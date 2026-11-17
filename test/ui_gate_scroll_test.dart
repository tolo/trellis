import 'dart:async';
import 'dart:io';

import 'package:test/test.dart';

import '../tool/ui_gate/checks.dart';
import '../tool/ui_gate/manifest.dart';
import 'ui_gate_test_support.dart';

void main() {
  test('reflow accepts a labelled keyboard scroll region and rejects inaccessible or escaping content', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((request) {
      final mode = request.uri.queryParameters['mode'] ?? 'scroll';
      request.response.headers.contentType = ContentType.html;
      request.response.write('''<!doctype html><html lang="en"><head><title>Scrollable table</title><style>
        body { margin: 16px; } .scroll { overflow-x: ${mode == 'escape' ? 'visible' : 'auto'}; }
        table { min-width: 640px; } dialog { position: fixed; left: 500px; top: 0; }
        </style></head><body><main id="component"><h2 id="records-title">Records</h2><p id="records-detail">Recent entries</p><div class="scroll" role="region"
        ${mode == 'labelledby'
          ? 'aria-labelledby="records-title records-detail"'
          : mode == 'unlabelled'
          ? ''
          : 'aria-label="Records"'} ${mode == 'unfocusable' ? '' : 'tabindex="0"'}>
        <table><caption>Records</caption><tr><th scope="col">Name</th></tr><tr><td>Ada</td></tr></table></div>
        ${mode == 'popup' ? '<dialog open>Escaping popup</dialog>' : ''}
        </main><a id="after" href="#component">After</a></body></html>''');
      unawaited(request.response.close());
    });
    final scratch = Directory.systemTemp.createTempSync('gate_scroll_');
    addTearDown(() => scratch.deleteSync(recursive: true));
    await forBrowsers((driver) async {
      for (final mode in ['scroll', 'labelledby', 'unlabelled', 'unfocusable', 'escape', 'popup']) {
        final file = File('${scratch.path}/$mode.yaml')
          ..writeAsStringSync('''name: scroll
page: /?mode=$mode
root: '#component'
states: {default: []}
keyboard:
  - focus: '#after'
  - expect: {expression: document.activeElement.id, equals: after}
''');
        final result = await GateSession(
          GateManifest.load(file),
          driver,
          Uri.parse('http://127.0.0.1:${server.port}'),
        ).reflow([390, 768, 1440]);
        expect(
          result.status,
          ['scroll', 'labelledby'].contains(mode) ? 'pass' : 'fail',
          reason: '${driver.name}/$mode: ${result.evidence}',
        );
        if (mode == 'unlabelled' || mode == 'unfocusable') expect(result.evidence.join(), contains('scroll region'));
        if (mode == 'escape' || mode == 'popup') expect(result.evidence.join(), contains('viewport'));
      }
    });
  }, timeout: const Timeout(Duration(minutes: 2)));
}
