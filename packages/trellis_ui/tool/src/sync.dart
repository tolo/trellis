import 'dart:convert';
import 'dart:io';

import 'pipeline.dart';
import 'sync_report.dart';

const _protectedPaths = [
  'vendor',
  'generated',
  'tool/pins.json',
  'tool/parity-ignore.json',
  SyncReportInventory.path,
  'assets',
  'sync-reports',
];
final _activeSyncs = <String>{};

/// Builds a candidate from the committed pin and installs it only after all inputs compile.
Future<File> syncPin(Pipeline pipeline, String tag, {String? compilerPath, String? platform}) async {
  if (!RegExp(r'^shadcn@\d+\.\d+\.\d+$').hasMatch(tag)) {
    throw FormatException('Invalid shadcn tag $tag (expected shadcn@X.Y.Z)');
  }
  final root = pipeline.root.absolute;
  final lockFile = File('${root.resolveSymbolicLinksSync()}/.tools/sync.lock');
  // The OS releases advisory locks when the command exits, even after an interrupt.
  // Keep the inode and refuse reentry before opening it, since POSIX locks are per process.
  if (!_activeSyncs.add(lockFile.path)) throw StateError('A sync is already running in ${root.path}');
  RandomAccessFile? lock;
  try {
    lockFile.parent.createSync(recursive: true);
    lock = lockFile.openSync(mode: FileMode.append);
    lock.lockSync();
    await _requireClean(root);
    final head = (await _git(root, ['rev-parse', 'HEAD'])).trim();
    final prefix = (await _git(root, ['rev-parse', '--show-prefix'])).trim();
    final repoRoot = (await _git(root, ['rev-parse', '--show-toplevel'])).trim();
    final scratchRoot = Directory('$repoRoot/.agent_temp')..createSync(recursive: true);
    final scratch = scratchRoot.createTempSync('upstream-sync-');
    try {
      final previous = Directory('${scratch.path}/previous')..createSync();
      final candidate = Directory('${scratch.path}/candidate')..createSync();
      final archive = '${scratch.path}/committed.tar';
      // Git applies the working-directory prefix even to a named subtree.
      await _git(Directory(repoRoot), [
        'archive',
        '--format=tar',
        '--output=$archive',
        if (prefix.isEmpty) head else '$head:${prefix.substring(0, prefix.length - 1)}',
      ]);
      for (final tree in [previous, candidate]) {
        await _run(root, 'tar', ['-xf', archive, '-C', tree.path]);
      }

      final stage = Pipeline(candidate, download: pipeline.download);
      final pins = stage.pins;
      final old = (pins['shadcn'] as Map).cast<String, String>();
      if (old['tag'] == tag) throw StateError('$tag is already pinned');
      final api = '/repos/${pins['repo']}';
      final base = pins['base'] as String;
      Future<Object?> get(String path, {Map<String, String>? query}) async =>
          jsonDecode(utf8.decode(await pipeline.download(Uri.https('api.github.com', '$api/$path', query))));
      Future<Set<String>> listing(String commit) async {
        final rows = (await get('contents/apps/v4/registry/bases/$base/ui', query: {'ref': commit})) as List;
        return {
          for (final row in rows.cast<Map<String, Object?>>())
            if (row['type'] == 'file' && (row['name']! as String).endsWith('.tsx'))
              (row['name']! as String).replaceFirst(RegExp(r'\.tsx$'), ''),
        };
      }

      // Resolving a tag through the commits endpoint peels annotated tags.
      final resolved = (await get('commits/refs/tags/$tag')) as Map;
      final commit = resolved['sha'] as String?;
      if (commit == null || !RegExp(r'^[a-f0-9]{40}$').hasMatch(commit)) {
        throw FormatException('$tag did not resolve to a commit');
      }
      pins['shadcn'] = {'tag': tag, 'commit': commit};
      _writeJson(File('${candidate.path}/tool/pins.json'), pins);
      final oldTree = SyncTree(previous, await listing(old['commit']!));
      final newTree = SyncTree(candidate, await listing(commit));
      try {
        await stage.fetchShadcn();
      } on HttpException catch (error) {
        throw HttpException('Sync $tag: ${error.message}', uri: error.uri);
      }
      final compiler = await pipeline.verifiedCompiler(path: compilerPath, platform: platform);
      await stage.build(compilerPath: compiler.absolute.path, platform: platform);
      final reportPath = 'sync-reports/sync-${oldTree.tag}-to-$tag.md';
      final report = newTree.file(reportPath);
      report.parent.createSync(recursive: true);
      final (:markdown, :inventory) = buildSyncReport(oldTree, newTree);
      report.writeAsStringSync(markdown);
      newTree.file(SyncReportInventory.path).writeAsStringSync(inventory.encode());

      Directory('${candidate.path}/${oldTree.vendor}').deleteSync(recursive: true);
      if ((await _git(root, ['rev-parse', 'HEAD'])).trim() != head) {
        throw StateError('HEAD changed while preparing the sync to $tag');
      }
      await _requireClean(root);
      final target = File('${root.path}/$reportPath');
      if (target.existsSync()) throw StateError('Sync report already exists: $reportPath');
      _install(
        root,
        candidate,
        scratch,
        ['vendor/shadcn', 'generated'],
        ['tool/pins.json', reportPath, SyncReportInventory.path],
      );
      return target;
    } finally {
      scratch.deleteSync(recursive: true);
    }
  } finally {
    _activeSyncs.remove(lockFile.path);
    lock?.closeSync();
  }
}

Future<void> _requireClean(Directory root) async {
  final dirty = await _git(root, ['status', '--porcelain', '--untracked-files=all', '--', ..._protectedPaths]);
  if (dirty.isNotEmpty) throw StateError('Commit or set aside changed sync inputs and outputs before syncing:\n$dirty');
}

Future<String> _git(Directory root, List<String> arguments) => _run(root, 'git', arguments);

Future<String> _run(Directory root, String executable, List<String> arguments) async {
  final result = await Process.run(executable, arguments, workingDirectory: root.path);
  if (result.exitCode != 0) {
    throw ProcessException(executable, arguments, '${result.stderr}', result.exitCode);
  }
  return result.stdout as String;
}

void _writeJson(File file, Object value) =>
    file.writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(value)}\n');

void _install(Directory root, Directory candidate, Directory scratch, List<String> directories, List<String> files) {
  final swaps = <(FileSystemEntity, FileSystemEntity?)>[];
  final moves = <(FileSystemEntity, FileSystemEntity)>[
    for (final path in directories) (Directory('${root.path}/$path'), Directory('${candidate.path}/$path')),
    for (final path in files) (File('${root.path}/$path'), File('${candidate.path}/$path')),
  ];
  try {
    for (final (index, (live, staged)) in moves.indexed) {
      live.parent.createSync(recursive: true);
      final backup = live.existsSync() ? live.renameSync('${scratch.path}/backup-$index') : null;
      swaps.add((live, backup));
      staged.renameSync(live.path);
    }
  } on FileSystemException {
    for (final (live, backup) in swaps.reversed) {
      if (live.existsSync()) live.deleteSync(recursive: true);
      backup?.renameSync(live.path);
    }
    rethrow;
  }
}
