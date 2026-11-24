import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '_csp_browser.dart';
import '_e2e_server.dart';
import '_workspace_root.dart';

enum UiScaffold {
  shelf('htmx', 'static', 'templates/pages/ui.html'),
  relic('relic', 'static', 'templates/ui.html'),
  dartFrog('dart_frog', 'public', 'templates/pages/ui.html');

  const UiScaffold(this.template, this.staticRoot, this.page);

  final String template;
  final String staticRoot;
  final String page;
}

const _assets = ['trellis-ui.css', 'trellis-ui.js', 'htmx-indicator.css'];

void testUiScaffold(UiScaffold scaffold) {
  test('ui scaffold boots under strict CSP and previews embedded assets', () async {
    if (BrowserProbe.locateChrome() == null) requireChromeInCi('UI scaffold browser proof');
    final temp = Directory.systemTemp.createTempSync('trellis-ui-${scaffold.name}-');
    addTearDown(() => temp.deleteSync(recursive: true));
    final root = await findWorkspaceRoot();
    final cli = '${root.path}/packages/trellis_cli/bin/trellis.dart';
    final created = await _dart(temp, ['run', cli, 'create', 'ui_demo', '--template', scaffold.template, '--ui']);
    expect(created.exitCode, 0, reason: '${created.stdout}\n${created.stderr}');
    expect(created.stdout, contains('  dart pub get\n'));
    final runCommand = scaffold == UiScaffold.dartFrog ? 'dart_frog dev' : 'dart run bin/server.dart';
    expect(created.stdout, contains('  $runCommand\n'));

    final project = Directory('${temp.path}/ui_demo');
    final preview = Directory('${project.path}/${scaffold.staticRoot}/trellis-ui');
    File assetFile(String name) => File('${preview.path}/$name');
    final pubspec = File('${project.path}/pubspec.yaml');
    await pubspec.writeAsString(workspaceDependencyOverrides(root), mode: FileMode.append);
    for (final args in [
      ['pub', 'get'],
      ['analyze', '--fatal-infos'],
    ]) {
      final result = await _dart(project, args);
      expect(result.exitCode, 0, reason: 'dart ${args.join(' ')}: ${result.stdout}\n${result.stderr}');
    }

    final client = HttpClient();
    addTearDown(() => client.close(force: true));
    final frog = scaffold == UiScaffold.dartFrog;
    final originalServer = frog ? null : File('${project.path}/bin/server.dart').readAsStringSync();
    if (frog) {
      preview.createSync(recursive: true);
      assetFile('trellis-ui.css').writeAsStringSync('stale on dev boot');
    }
    final server = await _boot(scaffold, project, client, dev: frog, originalServer: originalServer);
    Future<void> stop(BootedServer server) async {
      await stopServer(server.process);
      if (frog) await killListenersOnPort(server.port);
    }

    addTearDown(() => stop(server));
    final base = Uri.parse('http://${e2eLoopback.address}:${server.port}/');
    final digests = await _expectEmbeddedAssets(client, base);
    if (frog) {
      _expectPreview(preview, digests);
    } else {
      expect(preview.existsSync(), isFalse, reason: 'non-dev boot must leave preview files alone');
    }

    final page = await _get(client, base.resolve('/ui'));
    expect(page.status, 200, reason: page.text);
    _expectStrict(page.csp);
    _expectStrict((await _get(client, base)).csp);
    final fragment = await _get(client, base.resolve('/ui'), headers: {'HX-Request': 'true'});
    expect(fragment.status, 200, reason: fragment.text);
    expect(fragment.text, contains('components-dialog'));
    expect(fragment.text, isNot(contains('<head>')));
    _expectStrict(fragment.csp);
    expect('href="/styles.css"'.allMatches(page.text), hasLength(1));
    for (final name in ['trellis-ui.css', 'trellis-ui.js']) {
      expect('/trellis-ui/$name'.allMatches(page.text), hasLength(1));
      expect(page.text, isNot(contains('${scaffold.staticRoot}/trellis-ui/$name')));
    }

    final browser = await BrowserProbe.launch();
    addTearDown(browser.close);
    await browser.captureSecurityPolicyViolations();
    await browser.evaluate(
      base.resolve('/ui'),
      'document.readyState',
      width: 1024,
      height: 800,
      reducedMotion: 'reduce',
    );
    _expectPrimaryButton(await browser.evaluateHere(_buttonStyle));
    expect(
      await browser.evaluateHere('''Boolean(
        document.querySelector('.trellis-badge') &&
        document.querySelector('label[for="example-name"]')?.control?.matches('.trellis-input') &&
        customElements.get('tl-dialog')
      )'''),
      isTrue,
    );
    await _click(browser, 'tl-dialog [data-slot=dialog-trigger] button');
    await waitForBrowser(browser, 'document.querySelector("#components-dialog").matches(":modal")');
    expect(
      await browser.evaluateHere('''(() => {
        const dialog = document.querySelector('#components-dialog');
        const box = dialog.getBoundingClientRect();
        return Math.abs(box.left - (innerWidth - box.right)) < 2 &&
               Math.abs(box.top - (innerHeight - box.bottom)) < 2 &&
               parseFloat(getComputedStyle(dialog).paddingInlineStart) > 0 &&
               parseFloat(getComputedStyle(document.querySelector('.trellis-button-variant-default')).paddingInlineStart) > 0;
      })()'''),
      isTrue,
      reason: 'scaffold styles preserve suite dialog centering and component padding',
    );
    expect(await browser.securityPolicyViolations(), isEmpty, reason: '/ui and its opened dialog');
    await browser.evaluate(base, 'document.readyState', width: 1024, height: 800);
    expect(
      await browser.evaluateHere('''typeof htmx === 'object' &&
        new URL(document.querySelector('script[src*=htmx]').src).origin === location.origin'''),
      isTrue,
    );
    expect(await browser.evaluateHere('document.querySelector(".counter-value").textContent.trim()'), '0');
    await browser.evaluateHere('''document.addEventListener('htmx:afterRequest', ({detail}) => {
      window.__counterPolicy = detail.xhr.getResponseHeader('Content-Security-Policy');
    }, {once: true})''');
    await _click(browser, '#counter-increment');
    await waitForBrowser(browser, 'document.querySelector(".counter-value").textContent.trim() === "1"');
    _expectStrict(await browser.evaluateHere('window.__counterPolicy') as String?);
    expect(await browser.securityPolicyViolations(), isEmpty);

    // Divergent disk copies must never shadow the embedded HTTP responses.
    preview.createSync(recursive: true);
    assetFile('trellis-ui.js').writeAsStringSync('stale on disk');
    expect(await _expectEmbeddedAssets(client, base), digests);
    final unknown = assetFile('preview-only.txt')..writeAsStringSync('preview data');
    final missing = await _get(client, base.resolve('/trellis-ui/preview-only.txt'));
    expect(missing.status, 404, reason: 'The suite prefix does not fall back to preview files');
    unknown.deleteSync();
    final materialize = await _dart(project, [
      'run',
      'trellis_ui:materialize',
      if (scaffold != UiScaffold.shelf) '${scaffold.staticRoot}/trellis-ui',
    ]);
    expect(materialize.exitCode, 0, reason: '${materialize.stdout}\n${materialize.stderr}');
    _expectPreview(preview, digests);

    _expectPrimaryButton(
      await browser.evaluate(File('${project.path}/${scaffold.page}').uri, _buttonStyle, width: 390, height: 844),
    );
    expect(await browser.evaluateHere('Boolean(customElements.get("tl-dialog"))'), isTrue);
    expect(
      await browser.evaluateHere('''(() => {
        const field = document.querySelector('input#example-name').getBoundingClientRect();
        const gap = (selector, property) => getComputedStyle(document.querySelector(selector))[property];
        return {
          pageFits: document.documentElement.scrollWidth === document.documentElement.clientWidth,
          fieldFits: field.left >= 0 && field.right <= innerWidth,
          stackGap: gap('.trellis-stack', 'rowGap'),
          clusterGap: gap('.trellis-cluster', 'columnGap'),
        };
      })()'''),
      {'pageFits': true, 'fieldFits': true, 'stackGap': '24px', 'clusterGap': '8px'},
      reason: 'natural preview preserves the layout and input at 390px',
    );

    if (scaffold == UiScaffold.relic) {
      await stop(server);
      final devServer = await _boot(scaffold, project, client, dev: true, originalServer: originalServer);
      addTearDown(() => stop(devServer));
      final devBase = Uri.parse('http://${e2eLoopback.address}:${devServer.port}/');
      final devPage = await _get(client, devBase.resolve('/ui'));
      expect(devPage.status, 200, reason: devPage.text);
      expect(devPage.text, contains('src="/_dev/reload.js"'));
      _expectStrict(devPage.csp);
      expect(await _expectEmbeddedAssets(client, devBase), digests);
      await expectStaticReload(devBase, project, 'static');
    }

    if (scaffold == UiScaffold.shelf) {
      await stop(server);
      assetFile('trellis-ui.css').writeAsStringSync('stale on dev boot');
      final devServer = await _boot(scaffold, project, client, dev: true, originalServer: originalServer);
      addTearDown(() => stop(devServer));
      _expectPreview(preview, digests);
      await expectStaticReload(Uri.parse('http://${e2eLoopback.address}:${devServer.port}/'), project, 'static');
      final blocked = File('${project.path}/not-a-directory')..createSync();
      final failure = await _dart(project, ['run', 'trellis_ui:materialize', blocked.path]);
      expect(failure.exitCode, isNonZero);
      expect(failure.stderr, contains(blocked.path));
    }
  }, timeout: const Timeout(Duration(minutes: 4)));
}

const _buttonStyle = '''(() => {
  const button = document.querySelector('.trellis-button-variant-default');
  if (!button) return null;
  const style = getComputedStyle(button);
  const token = style.getPropertyValue('--primary').trim();
  const sample = document.createElement('span');
  sample.style.backgroundColor = token;
  button.append(sample);
  const expected = getComputedStyle(sample).backgroundColor;
  sample.remove();
  return [style.backgroundColor, token, expected];
})()''';

void _expectPrimaryButton(Object? result) {
  expect(result, isA<List<Object?>>(), reason: 'Primary button is rendered');
  final colors = result as List<Object?>;
  expect(colors[1], isNotEmpty, reason: '--primary resolves on the button');
  expect(colors.first, colors.last, reason: 'button background resolves to --primary');
}

Future<ProcessResult> _dart(Directory project, List<String> args) =>
    Process.run(Platform.resolvedExecutable, args, workingDirectory: project.path);

Future<BootedServer> _boot(
  UiScaffold scaffold,
  Directory project,
  HttpClient client, {
  required bool dev,
  required String? originalServer,
}) async {
  final frog = scaffold == UiScaffold.dartFrog;
  final dartFrogExecutable = frog ? await prepareDartFrogExecutable() : null;
  return bootServer(
    label: '${scaffold.name} UI scaffold',
    start: (port) async {
      if (dartFrogExecutable != null) {
        final vmServicePort = await allocateFreePort();
        return Process.start(
          dartFrogExecutable,
          ['dev', '--port', '$port', '--dart-vm-service-port', '$vmServicePort'],
          workingDirectory: project.path,
          environment: {'DEV': '$dev'},
        );
      }
      // Only isolate the port and the bind family in the generated test copy.
      final patched = switch (scaffold) {
        UiScaffold.shelf => originalServer!.replaceFirst(
          "await shelf_io.serve(handler, 'localhost', 8080)",
          "await shelf_io.serve(handler, InternetAddress('${e2eLoopback.address}'), $port)",
        ),
        UiScaffold.relic => originalServer!.replaceFirst('port: 8080', 'port: $port'),
        UiScaffold.dartFrog => throw StateError('Dart Frog is started by its CLI'),
      };
      expect(patched, isNot(originalServer), reason: 'bind-patch pattern');
      await File('${project.path}/bin/server.dart').writeAsString(patched);
      return Process.start(
        Platform.resolvedExecutable,
        ['run', 'bin/server.dart', if (dev) '--dev'],
        workingDirectory: project.path,
        environment: {'DEV': 'false'},
      );
    },
    isReady: (port) async {
      final url = Uri.parse('http://${e2eLoopback.address}:$port/');
      final deadline = DateTime.now().add(const Duration(seconds: 35));
      while (DateTime.now().isBefore(deadline)) {
        try {
          final response = await _get(client, url);
          if (response.status == 200 && response.text.contains('ui_demo')) return true;
        } on SocketException {
          // The listener may not be bound on the first poll.
        }
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      return false;
    },
  );
}

typedef _Response = ({int status, String? csp, String? etag, String? mediaType, List<int> bytes, String text});

Future<_Response> _get(HttpClient client, Uri uri, {Map<String, String> headers = const {}}) async {
  final request = await client.getUrl(uri);
  headers.forEach(request.headers.set);
  final response = await request.close();
  final bytes = await response.expand((chunk) => chunk).toList();
  return (
    status: response.statusCode,
    csp: response.headers.value('content-security-policy'),
    etag: response.headers.value(HttpHeaders.etagHeader),
    mediaType: response.headers.contentType?.mimeType,
    bytes: bytes,
    text: utf8.decode(bytes),
  );
}

void _expectStrict(String? policy) {
  expect(policy, isNotNull);
  final directives = {for (final part in policy!.split('; ')) part.split(' ').first: part.split(' ').skip(1).toList()};
  expect(directives['script-src'], ["'self'"]);
  expect(directives['style-src'], ["'self'"]);
  expect(policy, isNot(contains("'unsafe-inline'")));
}

Future<Map<String, String>> _expectEmbeddedAssets(HttpClient client, Uri base) async {
  final digests = <String, String>{};
  for (final asset in _assets) {
    final response = await _get(client, base.resolve('/trellis-ui/$asset'));
    expect(response.status, 200, reason: asset);
    expect(response.mediaType, asset.endsWith('.css') ? 'text/css' : 'text/javascript', reason: asset);
    _expectStrict(response.csp);
    final digest = sha256.convert(response.bytes).toString();
    expect(response.etag, '"$digest"', reason: asset);
    digests[asset] = digest;
  }
  return digests;
}

void _expectPreview(Directory preview, Map<String, String> digests) {
  expect(preview.existsSync(), isTrue);
  expect(preview.listSync().map((entry) => entry.uri.pathSegments.last), unorderedEquals(_assets));
  for (final MapEntry(key: name, value: digest) in digests.entries) {
    final bytes = File('${preview.path}/$name').readAsBytesSync();
    expect(sha256.convert(bytes).toString(), digest, reason: name);
  }
}

Future<void> _click(BrowserProbe browser, String selector) async {
  final position = await browser.evaluateHere('''(() => {
    const target = document.querySelector(${jsonEncode(selector)});
    if (!target) return null;
    const box = target.getBoundingClientRect();
    return {x: box.x + box.width / 2, y: box.y + box.height / 2};
  })()''');
  expect(position, isA<Map<String, dynamic>>(), reason: selector);
  final coordinates = position as Map<String, dynamic>;
  for (final type in ['mousePressed', 'mouseReleased']) {
    await browser.command('Input.dispatchMouseEvent', {
      ...coordinates,
      'type': type,
      'button': 'left',
      'clickCount': 1,
    });
  }
}
