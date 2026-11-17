@Tags(['ui-gate', 'visual'])
library;

import 'dart:io';

import 'package:test/test.dart';

import '../../../tool/ui_gate/manifest.dart';

void main() {
  test('automated qualification remains green in Chrome and Firefox', () async {
    final root = Directory.current.parent.parent;
    final files =
        Directory(
            '${root.path}/dev/ui-gate/manifests',
          ).listSync(followLinks: false).whereType<File>().where((file) => file.path.endsWith('.yaml')).toList()
          ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty);
    final names = files.map(GateManifest.load).map((manifest) => manifest.name).toList();
    expect(names.toSet(), hasLength(names.length), reason: 'Each manifest must own a distinct record: $names');
    final paths = files.map((file) => file.absolute.path).toList();
    final chunks = List.generate(paths.length < 3 ? paths.length : 3, (_) => <String>[]);
    for (var i = 0; i < paths.length; i++) {
      chunks[i % chunks.length].add(paths[i]);
    }
    expect(chunks.expand((chunk) => chunk), unorderedEquals(paths));

    Future<ProcessResult> run(int index, List<String> chunk) async {
      final label =
          'UI gate chunk ${index + 1}/${chunks.length}: ${chunk.map((p) => File(p).uri.pathSegments.last).join(', ')}';
      print(label);
      final result = await Process.run(Platform.resolvedExecutable, [
        'run',
        'tool/ui_gate.dart',
        '--serve',
        'dart run packages/trellis_ui/tool/gallery.dart --port 0',
        ...chunk,
      ], workingDirectory: root.path);
      print('$label\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}');
      return result;
    }

    // Every owned CLI must finish its browser/server cleanup before a failure escapes.
    final results = await Future.wait([
      for (final (index, chunk) in chunks.indexed) run(index, chunk),
    ], eagerError: false);
    for (var i = 0; i < results.length; i++) {
      expect(results[i].exitCode, 0, reason: 'UI gate chunk ${i + 1}: ${chunks[i]}');
    }
  }, timeout: const Timeout(Duration(minutes: 45)));
}
