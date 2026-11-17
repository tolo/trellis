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
    root = Directory('../../.agent_temp').absolute.createTempSync('sync-command-test-');
    addTearDown(() => root.deleteSync(recursive: true));
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
    for (final file in ['style-vega.css', 'tailwind.css', 'colors-neutral.json', 'LICENSE.md', 'ui/button.tsx']) {
      _write(root, 'vendor/shadcn/$_oldTag/$file', _input(file));
    }
    _write(root, 'generated/report.json', '{"hooks":["trellis-button"],"slots":[],"dataAttrs":[]}');
    for (final file in ['entry.css', 'trellis.css', 'trellis.min.css']) {
      _write(root, 'generated/$file', ':root { --primary: red; }\n.dark { --primary: blue; }\n.trellis-button {}');
    }
    _git(root, ['init', '-q']);
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
            expect(uri.path, endsWith('/$_newTag'));
            return utf8.encode(jsonEncode({'sha': _newCommit}));
          }
          expect(uri.path, endsWith('/registry/bases/base/ui'));
          final commit = uri.queryParameters['ref'];
          expect(commit, isIn([_oldCommit, _newCommit]));
          return utf8.encode(
            jsonEncode([
              {'name': 'button.tsx', 'type': 'file'},
              if (commit == _newCommit) {'name': 'slider.tsx', 'type': 'file'},
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
  for (final name in ['vendor', 'generated', 'sync-reports'])
    if (Directory('${root.path}/$name').existsSync())
      for (final file in Directory('${root.path}/$name').listSync(recursive: true).whereType<File>())
        file.path.substring(root.path.length + 1): file.readAsStringSync(),
};

void _git(Directory root, List<String> args) {
  final result = Process.runSync('git', args, workingDirectory: root.path);
  if (result.exitCode != 0) throw StateError('git ${args.join(' ')}: ${result.stderr}');
}
