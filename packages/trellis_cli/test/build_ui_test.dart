import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:trellis_ui/trellis_ui.dart';

import '_workspace_root.dart';

void main() {
  late Directory site;
  late String entryPoint;
  const assetRoot = 'trellis-ui';
  const layout = '''
<html><head><link rel="stylesheet" href="/trellis-ui/trellis-ui.css"></head>
<body><button tl:replace="~{trellis-ui/button :: button('destructive')}">Delete</button></body></html>
''';

  File write(String path, String contents) => File(p.join(site.path, path))
    ..createSync(recursive: true)
    ..writeAsStringSync(contents);

  Future<ProcessResult> build([List<String> flags = const []]) =>
      Process.run(Platform.resolvedExecutable, [entryPoint, 'build', ...flags], workingDirectory: site.path);

  String realPage() => File(p.join(site.path, 'output', 'index.html')).readAsStringSync();

  setUpAll(() async {
    final source = p.join((await findWorkspaceRoot()).path, 'packages', 'trellis_cli', 'bin', 'trellis.dart');
    final compiled = Directory.systemTemp.createTempSync('trellis_cli_ui_kernel_');
    addTearDown(() => compiled.deleteSync(recursive: true));
    entryPoint = p.join(compiled.path, 'trellis.dill');
    // Compiling on each launch can exhaust the test deadline before the build starts.
    final result = await Process.run(Platform.resolvedExecutable, ['compile', 'kernel', source, '-o', entryPoint]);
    expect(result.exitCode, 0, reason: '${result.stderr}\n${result.stdout}');
  });

  setUp(() {
    site = Directory.systemTemp.createTempSync('trellis_cli_ui_build_');
    addTearDown(() => site.deleteSync(recursive: true));
    write('content/_index.md', '# Home\n');
    write('trellis_site.yaml', 'uses: [trellis_ui]\n');
    write('layouts/home.html', layout);
  });

  test('build with uses: trellis_ui renders suite fragments and ships its assets', () async {
    final result = await build();
    expect(result.exitCode, 0, reason: '${result.stderr}\n${result.stdout}');
    final page = realPage();
    expect(page, contains('data-slot="button"'));
    expect(page, contains('trellis-button-variant-destructive'));
    expect(page, contains('href="/trellis-ui/trellis-ui.css"'));
    final outputAssets = Directory(p.join(site.path, 'output', assetRoot));
    final files = outputAssets.listSync().whereType<File>().toList();
    expect(
      files.map((file) => p.basename(file.path)),
      unorderedEquals(['trellis-ui.css', 'trellis-ui.js', 'htmx-indicator.css']),
    );
    for (final file in files) {
      final uriPath = '/$assetRoot/${p.basename(file.path)}';
      expect(file.readAsBytesSync(), trellisUiRespond(uriPath)!.body, reason: uriPath);
    }
  });

  test('a path prefix reaches suite links while files stay unprefixed', () async {
    final result = await build(['--path-prefix', '/trellis/']);
    expect(result.exitCode, 0, reason: '${result.stderr}\n${result.stdout}');
    expect(realPage(), contains('href="/trellis/trellis-ui/trellis-ui.css"'));
    expect(File(p.join(site.path, 'output', assetRoot, 'trellis-ui.css')).existsSync(), isTrue);
    expect(Directory(p.join(site.path, 'output', 'trellis')).existsSync(), isFalse);
  });

  test('without uses the output has no trellis-ui directory', () async {
    write('trellis_site.yaml', 'title: Plain Site\n');
    write('layouts/home.html', '<html><body>Home</body></html>');
    final plain = await build();
    expect(plain.exitCode, 0, reason: '${plain.stderr}\n${plain.stdout}');
    expect(Directory(p.join(site.path, 'output', assetRoot)).existsSync(), isFalse);

    write('layouts/home.html', layout);
    final missing = await build();
    expect(missing.exitCode, isNonZero);
    expect(missing.stderr, contains('TemplateException: Template "trellis-ui/button" not found'));
    expect(Directory(p.join(site.path, 'output')).existsSync(), isFalse);
  });

  test('an unknown name exits 1 naming the registered names', () async {
    write('trellis_site.yaml', 'uses: [nope]\n');
    final result = await build();
    expect(result.exitCode, 1);
    expect(result.stderr, allOf(contains('uses'), contains('nope'), contains('Registered sources: trellis_ui')));
    expect(Directory(p.join(site.path, 'output')).existsSync(), isFalse);
  });
}
