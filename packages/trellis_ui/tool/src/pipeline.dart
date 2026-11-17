import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'generate.dart';

/// Pinned inputs and compiler operations, with network injection for offline fixtures.
class Pipeline {
  Pipeline(this.root, {Future<List<int>> Function(Uri)? download}) : download = download ?? downloadBytes;
  final Directory root;
  final Future<List<int>> Function(Uri) download;
  Map<String, dynamic> get pins =>
      jsonDecode(File('${root.path}/tool/pins.json').readAsStringSync()) as Map<String, dynamic>;
  Generator get generator => Generator(root, pins);

  static Future<List<int>> downloadBytes(Uri uri) async {
    final client = HttpClient();
    try {
      final response = await (await client.getUrl(uri)).close();
      if (response.statusCode != 200) {
        await response.drain<void>();
        throw HttpException('GET $uri -> ${response.statusCode}', uri: uri);
      }
      return await response.fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
    } finally {
      client.close();
    }
  }

  Future<void> fetch() async {
    final p = pins;
    final source = p['shadcn'] as Map<String, dynamic>;
    final tag = source['tag'] as String;
    final base = 'https://raw.githubusercontent.com/${p['repo']}/${source['commit']}';
    final files = <String, String>{
      'style-${p['style']}.css': 'apps/v4/registry/styles/style-${p['style']}.css',
      'tailwind.css': 'packages/shadcn/src/tailwind.css',
      'colors-${p['baseColor']}.json': 'apps/v4/public/r/colors/${p['baseColor']}.json',
      'LICENSE.md': 'LICENSE.md',
      for (final c in (p['components'] as List).cast<String>())
        'ui/$c.tsx': 'apps/v4/registry/bases/${p['base']}/ui/$c.tsx',
    };
    final vendor = '${root.path}/vendor/shadcn/$tag';
    await _fetchFiles(vendor, base, files);
    await _write(
      '$vendor/SOURCE.md',
      utf8.encode(
        '# shadcn/ui $tag\n\nCommit `${source['commit']}`. Base `${p['base']}`, style `${p['style']}`.\nUnmodified MIT inputs from $base/. See LICENSE.md.\n\n${[for (final e in files.entries) '- `${e.key}`: `${e.value}`'].join('\n')}\n',
      ),
    );
    final animate = p['twAnimate'] as Map<String, dynamic>;
    for (final entry in {'tw-animate.css': 'dist/tw-animate.css', 'LICENSE': 'LICENSE'}.entries) {
      await _write(
        '${root.path}/vendor/tw-animate/${entry.key}',
        await download(Uri.parse('${animate['cdn']}/${entry.value}')),
      );
    }
    await _write(
      '${root.path}/vendor/tw-animate/SOURCE.md',
      utf8.encode('tw-animate-css ${animate['version']} (MIT). ${animate['cdn']}/dist/tw-animate.css\n'),
    );
    final compiler = p['compiler'] as Map<String, dynamic>;
    await _write(
      '${root.path}/vendor/tailwind/LICENSE',
      await download(
        Uri.parse('https://raw.githubusercontent.com/tailwindlabs/tailwindcss/v${compiler['version']}/LICENSE'),
      ),
    );
    await _write(
      '${root.path}/vendor/tailwind/SOURCE.md',
      utf8.encode('Tailwind CSS v${compiler['version']} (MIT). Compiler digests: tool/pins.json.\n'),
    );
    final lucide = p['lucide'] as Map<String, dynamic>;
    final icons = (lucide['icons'] as List?)?.cast<String>() ?? const [];
    if (icons.isNotEmpty) {
      final base = 'https://raw.githubusercontent.com/lucide-icons/lucide/${lucide['commit']}';
      final vendor = '${root.path}/vendor/lucide';
      final files = {'LICENSE': 'LICENSE', for (final icon in icons) '$icon.svg': 'icons/$icon.svg'};
      await _fetchFiles(vendor, base, files);
      await _write(
        '$vendor/SOURCE.md',
        utf8.encode('Lucide ${lucide['tag']} at commit ${lucide['commit']}. ISC and Feather MIT notices in LICENSE.\n'),
      );
    }
    stdout.writeln('Fetched ${files.length} shadcn inputs at $tag and dependency licences');
  }

  Future<void> _fetchFiles(String destination, String base, Map<String, String> files) async {
    // Resolve required inputs before writing so a 404 cannot mix source revisions.
    final content = <String, List<int>>{
      for (final entry in files.entries) entry.key: await download(Uri.parse('$base/${entry.value}')),
    };
    for (final entry in content.entries) {
      await _write('$destination/${entry.key}', entry.value);
    }
  }

  static String currentPlatform() {
    final arch = Abi.current().toString().split('_').last;
    return '${Platform.isMacOS ? 'macos' : Platform.operatingSystem}-$arch';
  }

  Future<File> verifiedCompiler({String? path, String? platform}) async {
    final target = platform ?? currentPlatform();
    final compiler = pins['compiler'] as Map<String, dynamic>;
    final expected = (compiler['platforms'] as Map<String, dynamic>)[target] as String?;
    if (expected == null) throw StateError('Unpinned compiler platform: $target');
    final file = File(path ?? '${root.path}/.tools/tailwindcss-$target');
    if (!file.existsSync()) {
      if (path != null) throw FileSystemException('Compiler does not exist', path);
      final bytes = await download(
        Uri.parse(
          'https://github.com/tailwindlabs/tailwindcss/releases/download/v${compiler['version']}/tailwindcss-$target',
        ),
      );
      final actual = sha256.convert(bytes).toString();
      if (actual != expected) throw StateError('Compiler digest mismatch: expected $expected, actual $actual');
      await _write(file.path, bytes);
    }
    final actual = sha256.convert(file.readAsBytesSync()).toString();
    if (actual != expected) throw StateError('Compiler digest mismatch: expected $expected, actual $actual');
    final mode = await Process.run('chmod', ['+x', file.path]);
    if (mode.exitCode != 0) throw ProcessException('chmod', ['+x', file.path], '${mode.stderr}', mode.exitCode);
    return file;
  }

  Future<void> build({Directory? output, String? compilerPath, String? platform}) async {
    final compiler = await verifiedCompiler(path: compilerPath, platform: platform);
    await _compile(compiler, output ?? Directory('${root.path}/generated'));
  }

  Future<void> _compile(File compiler, Directory output) async {
    await generator.generate(output: output);
    for (final min in [false, true]) {
      final args = [
        '-i',
        '${output.path}/entry.css',
        '-o',
        '${output.path}/${min ? 'trellis.min.css' : 'trellis.css'}',
        if (min) '--minify',
      ];
      final result = await Process.run(compiler.absolute.path, args, workingDirectory: root.path);
      if (result.exitCode != 0) {
        throw ProcessException(compiler.path, args, '${result.stdout}${result.stderr}', result.exitCode);
      }
    }
  }

  Future<void> check() async {
    final compiler = await verifiedCompiler();
    final scratchRoot = Directory('${root.parent.parent.path}/.agent_temp')..createSync(recursive: true);
    final scratch = scratchRoot.createTempSync('trellis-ui-regeneration-');
    final output = Directory('${scratch.path}/generated');
    try {
      // Generated imports need a sibling vendor directory in the scratch build.
      Link('${scratch.path}/vendor').createSync('${root.absolute.path}/vendor');
      await _compile(compiler, output);
      for (final name in ['entry.css', 'trellis.css', 'trellis.min.css', 'report.json']) {
        final expected = File('${root.path}/generated/$name').readAsBytesSync();
        final actual = File('${output.path}/$name').readAsBytesSync();
        if (!_equal(expected, actual)) throw StateError('Regeneration drift: generated/$name');
      }
      stdout.writeln('Regeneration check: 4 files byte-identical');
    } finally {
      scratch.deleteSync(recursive: true);
    }
  }
}

Future<void> _write(String path, List<int> bytes) async {
  final f = File(path);
  await f.parent.create(recursive: true);
  await f.writeAsBytes(bytes);
}

bool _equal(List<int> a, List<int> b) =>
    a.length == b.length && Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);
