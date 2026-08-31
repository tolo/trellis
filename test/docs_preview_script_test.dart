import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  final root = Directory.current.path;
  final script = p.join(root, 'tool', 'serve_docs.sh');

  test('docs preview builds root-served output and uses port 8765 by default', () async {
    expect(File(script).existsSync(), isTrue);

    final temp = Directory.systemTemp.createTempSync('trellis_docs_preview_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final binDir = Directory(p.join(temp.path, 'bin'))..createSync();
    final log = File(p.join(temp.path, 'dart.log'));
    final fakeDart = File(p.join(binDir.path, 'dart'))
      ..writeAsStringSync(r'''#!/usr/bin/env bash
{
  printf 'cwd=<%s>' "$PWD"
  printf ' arg=<%s>' "$@"
  printf '\n'
} >> "$DOCS_PREVIEW_TEST_LOG"
if [[ "${DOCS_PREVIEW_FAIL_BUILD:-0}" == 1 && " $* " == *" build "* ]]; then
  exit 37
fi
''');
    expect((await Process.run('chmod', ['+x', fakeDart.path])).exitCode, 0);

    Future<ProcessResult> run(List<String> arguments, {Map<String, String> environment = const {}}) async {
      log.writeAsStringSync('');
      return Process.run(
        'bash',
        [script, ...arguments],
        workingDirectory: temp.path,
        environment: {
          ...Platform.environment,
          'PATH': '${binDir.path}:${Platform.environment['PATH']}',
          'DOCS_PREVIEW_TEST_LOG': log.path,
          ...environment,
        },
      );
    }

    // The gallery regeneration runs from the repo root, before the build cds
    // into site/ - a theme change is otherwise invisible to the preview.
    final expectedGallery = 'cwd=<$root> arg=<run> arg=<tool/generate_theme_gallery.dart>';
    final expectedDefault = [
      expectedGallery,
      'cwd=<${p.join(root, 'site')}> arg=<run> arg=<../packages/trellis_cli/bin/trellis.dart> '
          'arg=<build> arg=<--path-prefix> arg=<> arg=<--output> arg=<output-root>',
      'cwd=<${p.join(root, 'site')}> arg=<run> arg=<../packages/trellis_cli/bin/trellis.dart> '
          'arg=<serve> arg=<--output> arg=<output-root> arg=<--port> arg=<8765>',
    ];
    final defaultRun = await run([]);
    expect(defaultRun.exitCode, 0, reason: '${defaultRun.stdout}\n${defaultRun.stderr}');
    expect(log.readAsLinesSync(), expectedDefault);

    final customRun = await run(['9000']);
    expect(customRun.exitCode, 0, reason: '${customRun.stdout}\n${customRun.stderr}');
    expect(log.readAsLinesSync(), [
      expectedDefault[0],
      expectedDefault[1],
      expectedDefault.last.replaceFirst('arg=<8765>', 'arg=<9000>'),
    ]);

    for (final port in ['1', '65535']) {
      final boundaryRun = await run([port]);
      expect(boundaryRun.exitCode, 0, reason: '${boundaryRun.stdout}\n${boundaryRun.stderr}');
      expect(log.readAsLinesSync(), [
        expectedDefault[0],
        expectedDefault[1],
        expectedDefault.last.replaceFirst('arg=<8765>', 'arg=<$port>'),
      ]);
    }

    final failedBuild = await run([], environment: {'DOCS_PREVIEW_FAIL_BUILD': '1'});
    expect(failedBuild.exitCode, 37);
    expect(log.readAsLinesSync(), [expectedDefault[0], expectedDefault[1]]);

    for (final arguments in [
      [''],
      ['abc'],
      ['0'],
      ['65536'],
      ['8765', 'extra'],
    ]) {
      final invalidRun = await run(arguments);
      expect(invalidRun.exitCode, 2, reason: 'arguments: $arguments');
      expect(log.readAsStringSync(), isEmpty, reason: 'arguments: $arguments');
    }

    if (!Platform.isWindows) {
      expect((await Process.run('test', ['-x', script])).exitCode, 0);
    }
    final rootReadme = File(p.join(root, 'README.md')).readAsStringSync();
    expect(rootReadme, contains('tool/serve_docs.sh       # builds and serves http://localhost:8765'));
    expect(rootReadme, contains('tool/serve_docs.sh 9000  # optional custom port'));
    expect(rootReadme, contains('root-served snapshot'));
    expect(rootReadme, contains('Ctrl-C'));
    expect(rootReadme, contains('site/README.md'));

    final siteReadme = File(p.join(root, 'site', 'README.md')).readAsStringSync();
    expect(siteReadme, contains('[`tool/serve_docs.sh`](../tool/serve_docs.sh)'));
    expect(siteReadme, contains('root-served variant'));
    expect(siteReadme, contains('http://localhost:8765'));
    expect(siteReadme, contains('`tool/serve_docs.sh 9000`'));
    expect(siteReadme, contains('Stop the server with Ctrl-C'));
    expect(siteReadme, contains('Rerun the script after'));
    expect(siteReadme, contains('changing site content, layouts, or theme assets'));
  });
}
