import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:test/test.dart';

import '../tool/port.dart';
import '../tool/src/pipeline.dart';

const _oldTag = 'shadcn@1.0.1';
const _newTag = 'shadcn@1.0.2';
const _oldCommit = '1111111111111111111111111111111111111111';
const _newCommit = '2222222222222222222222222222222222222222';

void main() {
  late Directory root;
  late File compiler;
  late Map<String, String> original;

  setUp(() {
    final repo = Directory.systemTemp.createTempSync('sync-command-test-');
    addTearDown(() => repo.deleteSync(recursive: true));
    root = Directory('${repo.path}/packages/trellis_ui')..createSync(recursive: true);
    compiler = _write(root, 'fixture-compiler', r'''#!/bin/sh
while [ "$#" -gt 0 ]; do
  case "$1" in
    -i) input=$2; shift ;;
    -o) output=$2; shift ;;
  esac
  shift
done
cp "$input" "$output"
''');
    _write(root, '.gitignore', '.agent_temp/\n.tools/\n');
    _write(
      root,
      'tool/pins.json',
      jsonEncode({
        'repo': 'example/ui',
        'base': 'base',
        'style': 'vega',
        'baseColor': 'neutral',
        'components': ['button'],
        'shadcn': {'tag': _oldTag, 'commit': _oldCommit},
        'compiler': {
          'platforms': {'fixture': sha256.convert(compiler.readAsBytesSync()).toString()},
        },
      }),
    );
    _write(root, 'tool/parity-ignore.json', '[]');
    _write(
      root,
      'tool/sync-inventory.json',
      jsonEncode({
        'previous': {'tag': 'shadcn@1.0.0', 'commit': '0000000000000000000000000000000000000000'},
        'current': {'tag': _oldTag, 'commit': _oldCommit},
        'entries': <Object>[],
      }),
    );
    for (final file in ['style-vega.css', 'tailwind.css', 'colors-neutral.json', 'LICENSE.md', 'ui/button.tsx']) {
      _write(root, 'vendor/shadcn/$_oldTag/$file', _input(file));
    }
    _write(root, 'generated/report.json', '{"hooks":["trellis-button"],"slots":[],"dataAttrs":[]}');
    for (final file in ['entry.css', 'trellis.css', 'trellis.min.css']) {
      _write(root, 'generated/$file', ':root { --primary: red; }\n.dark { --primary: blue; }\n.trellis-button {}');
    }
    _git(repo, ['init', '-q']);
    _git(root, ['add', '.']);
    _git(root, ['-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.test', 'commit', '-qm', 'Previous pin']);
    original = _syncFiles(root);
  });

  Future<int> sync(String tag, {String? missingInput}) => runPortCommand(
    ['sync', tag],
    Pipeline(
      root,
      download: (uri) async {
        if (uri.host == 'api.github.com') {
          if (uri.path.contains('/commits/')) {
            expect(uri.path, '/repos/example/ui/commits/refs/tags/$_newTag');
            return utf8.encode(jsonEncode({'sha': _newCommit}));
          }
          expect(uri.path, endsWith('/registry/bases/base/ui'));
          final commit = uri.queryParameters['ref'];
          expect(commit, isIn([_oldCommit, _newCommit]));
          return utf8.encode(
            jsonEncode([
              {'name': 'button.tsx', 'type': 'file'},
              if (commit == _newCommit) {'name': 'slider.tsx', 'type': 'file'},
              if (commit == _newCommit) {'name': 'trace.tsx', 'type': 'file'},
              if (commit == _oldCommit) {'name': 'legacy.tsx', 'type': 'file'},
              {'name': 'README.md', 'type': 'file'},
              {'name': 'fixture.tsx', 'type': 'dir'},
            ]),
          );
        }
        expect(uri.host, 'raw.githubusercontent.com');
        expect(uri.path, startsWith('/example/ui/$_newCommit/'));
        final name = uri.pathSegments.last;
        if (name == missingInput) throw HttpException('GET $uri -> 404', uri: uri);
        return utf8.encode(_input(name));
      },
    ),
    compilerPath: compiler.path,
    platform: 'fixture',
  );

  test('sync bumps the pin, regenerates and writes the report', () async {
    expect(await sync(_newTag), 0);
    final pins = jsonDecode(File('${root.path}/tool/pins.json').readAsStringSync()) as Map;
    expect(pins['shadcn'], {'tag': _newTag, 'commit': _newCommit});
    final newVendor = Directory('${root.path}/vendor/shadcn');
    expect(newVendor.listSync().map((entity) => entity.uri.pathSegments.where((part) => part.isNotEmpty).last), [
      _newTag,
    ]);
    expect(File('${newVendor.path}/$_newTag/ui/button.tsx').readAsStringSync(), contains('cn-button'));
    final entry = File('${root.path}/generated/entry.css').readAsStringSync();
    expect(entry, contains('from shadcn-ui/ui $_newTag (2222222)'));
    expect(entry, contains('--primary: blue'));
    expect(File('${root.path}/generated/trellis.min.css').readAsStringSync(), entry);
    final report = File('${root.path}/sync-reports/sync-$_oldTag-to-$_newTag.md');
    expect(report.readAsStringSync(), contains('Upstream component added: `slider`'));
    expect(await runPortCommand(['sync', '--check-report', report.path], Pipeline(root)), 1);
  });

  test('check-report binds editable triage to the inventory even when the count is adjusted', () async {
    expect(await sync(_newTag), 0);
    final report = File('${root.path}/sync-reports/sync-$_oldTag-to-$_newTag.md');
    final complete = report
        .readAsStringSync()
        .replaceAll('Kind: new component\nTriage: pending', 'Kind: new component\nTriage: defer')
        .replaceAll('Triage: pending', 'Triage: mechanical')
        .replaceAll('Disposition: pending\nReason:', 'Disposition: expected\nReason: Reviewed.')
        .replaceAll('Result: pending', 'Result: pass');
    report.writeAsStringSync(complete);
    final command = ['sync', '--check-report', report.path];
    expect(await runPortCommand(command, Pipeline(root)), 0);

    final triageStart = complete.indexOf('### U001 ');
    final triageEnd = complete.indexOf('## Gates', triageStart);
    final rows = complete.substring(triageStart, triageEnd);
    final mutations = {
      'all rows omitted': complete.replaceFirst(
        RegExp(r'Upstream entries: \d+[\s\S]*?(?=\n## Gates)'),
        'Upstream entries: 0\n',
      ),
      'middle row omitted and counts adjusted': complete
          .replaceFirst('Upstream entries: 3', 'Upstream entries: 2')
          .replaceFirst(RegExp(r'^### U002 [\s\S]*?(?=^### U003 )', multiLine: true), '')
          .replaceFirst('### U003 ', '### U002 '),
      'wrong component with the same count': complete.replaceFirst('added: `slider`', 'added: `unrelated`'),
      'changed kind and triage': complete.replaceFirst(
        'Kind: new component\nTriage: defer',
        'Kind: mechanical\nTriage: mechanical',
      ),
      'wrong upstream commit': complete.replaceFirst(_oldCommit, _newCommit),
      'rows moved outside Upstream triage': '${complete.replaceRange(triageStart, triageEnd, '')}\n$rows',
      'rows hidden by an HTML comment': complete.replaceRange(triageStart, triageEnd, '<!--\n$rows-->\n\n'),
      'rows in a code fence': complete.replaceRange(triageStart, triageEnd, '```text\n$rows```\n\n'),
    };
    for (final MapEntry(key: mutation, value: edited) in mutations.entries) {
      expect(edited, isNot(complete), reason: mutation);
      report.writeAsStringSync(edited);
      expect(await runPortCommand(command, Pipeline(root)), 1, reason: mutation);
    }

    report.writeAsStringSync(complete);
    final pins = File('${root.path}/tool/pins.json');
    final pinned = pins.readAsStringSync();
    pins.writeAsStringSync(pinned.replaceFirst(_newCommit, _oldCommit));
    expect(await runPortCommand(command, Pipeline(root)), 1, reason: 'wrong current pin');
    pins.writeAsStringSync(pinned);
    File('${root.path}/tool/sync-inventory.json').deleteSync();
    expect(await runPortCommand(command, Pipeline(root)), 1, reason: 'missing generated inventory');
  });

  test('a tag that cannot be fetched changes nothing', () async {
    await expectLater(
      sync(_newTag, missingInput: 'button.tsx'),
      throwsA(
        predicate<Object>(
          (error) =>
              error is HttpException &&
              error.message.contains(_newTag) &&
              error.message.contains('button.tsx') &&
              error.message.contains('404'),
        ),
      ),
    );
    expect(_syncFiles(root), original);
    for (final malformed in ['branch', 'shadcn@1.0.2-beta', '../shadcn@1.0.2']) {
      await expectLater(
        sync(malformed),
        throwsA(isA<FormatException>().having((error) => error.message, 'tag', contains(malformed))),
      );
      expect(_syncFiles(root), original);
    }
  });

  test('interrupting a fetch releases the sync lock and leaves the inputs unchanged', () async {
    final suite = Directory.current.uri;
    final blocker = _write(root, '.agent_temp/interrupted-sync.dart', '''
import 'dart:io';

import '${suite.resolve('tool/port.dart')}';
import '${suite.resolve('tool/src/pipeline.dart')}';

Future<void> main(List<String> args) async {
  exitCode = await runPortCommand(['sync', '$_newTag'], Pipeline(Directory(args.single), download: (_) async {
    stdout.writeln('fetch started');
    await stdout.flush();
    await stdin.first;
    throw StateError('The fixture should be interrupted while fetching');
  }));
}
''');
    final process = await Process.start(Platform.resolvedExecutable, [
      '--packages=${suite.resolve('../../.dart_tool/package_config.json').toFilePath()}',
      blocker.path,
      root.path,
    ]);
    final ready = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).first;
    final errors = utf8.decodeStream(process.stderr);
    try {
      // Parallel CI can delay the cold Dart child before it reaches the fetch callback.
      expect(await ready.timeout(const Duration(seconds: 45)), 'fetch started');
      await expectLater(sync(_newTag), throwsA(isA<FileSystemException>()));
      expect(_syncFiles(root), original);
    } finally {
      process.kill(ProcessSignal.sigint);
      expect(
        await process.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            process.kill(ProcessSignal.sigkill);
            return process.exitCode;
          },
        ),
        isNot(0),
      );
      expect(await errors, isEmpty);
    }
    expect(_syncFiles(root), original);
    expect(await sync(_newTag), 0);
  }, timeout: const Timeout(Duration(minutes: 1)));

  test('dirty committed sources are rejected before fetching', () async {
    final css = File('${root.path}/generated/entry.css');
    css.writeAsStringSync('.unexpected {}\n', mode: FileMode.append);
    final dirty = _syncFiles(root);
    await expectLater(
      runPortCommand([
        'sync',
        _newTag,
      ], Pipeline(root, download: (uri) async => throw StateError('Unexpected fetch $uri'))),
      throwsA(isA<StateError>().having((error) => error.message, 'input', contains('generated/entry.css'))),
    );
    expect(_syncFiles(root), dirty);
  });
}

File _write(Directory root, String path, String text) {
  final file = File('${root.path}/$path')..parent.createSync(recursive: true);
  return file..writeAsStringSync(text);
}

String _input(String name) => switch (name) {
  'style-vega.css' => '.style-vega { .cn-button { color: var(--primary); }}',
  'tailwind.css' => '/* utilities */',
  'colors-neutral.json' || 'neutral.json' => '{"cssVarsV4":{"light":{"primary":"red"},"dark":{"primary":"blue"}}}',
  'LICENSE.md' => 'MIT',
  'button.tsx' || 'ui/button.tsx' => '<button className="cn-button"/>',
  _ => throw StateError('Unexpected source $name'),
};

Map<String, String> _syncFiles(Directory root) => {
  'tool/pins.json': File('${root.path}/tool/pins.json').readAsStringSync(),
  if (File('${root.path}/tool/sync-inventory.json').existsSync())
    'tool/sync-inventory.json': File('${root.path}/tool/sync-inventory.json').readAsStringSync(),
  for (final name in ['vendor', 'generated', 'sync-reports'])
    if (Directory('${root.path}/$name').existsSync())
      for (final file in Directory('${root.path}/$name').listSync(recursive: true).whereType<File>())
        file.path.substring(root.path.length + 1): file.readAsStringSync(),
};

void _git(Directory root, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: root.path);
  if (result.exitCode != 0) throw StateError('git ${args.join(' ')}: ${result.stderr}');
}
