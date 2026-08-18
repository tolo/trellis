import 'dart:async';
import 'dart:io';

import '../exceptions.dart';
import 'template_loader.dart';

final _pathSepPattern = RegExp(r'[/\\]');

/// Whether `Directory.watch(recursive: true)` actually recurses on this platform.
///
/// dart:io implements watching with inotify on Linux and Android, which reports events for the
/// watched directory only — the `recursive` flag is silently ignored there. macOS (FSEvents) and
/// Windows (`ReadDirectoryChangesW`) honour it.
final bool _hasNativeRecursiveWatch = !(Platform.isLinux || Platform.isAndroid);

/// Loads templates from the filesystem relative to a base directory.
///
/// Enforces security boundaries: rejects absolute paths, `..` traversal,
/// and symlink escapes outside the base path.
final class FileSystemLoader implements TemplateLoader {
  final String basePath;
  final String extension;
  final bool devMode;
  late final String _canonicalBase;

  StreamController<void>? _changesController;

  /// Active watch subscriptions, keyed by the directory each one watches.
  ///
  /// One entry (the base directory) where recursive watching is native; one per directory in the
  /// tree on Linux — see [_hasNativeRecursiveWatch].
  final Map<String, StreamSubscription<FileSystemEvent>> _watchSubscriptions = {};

  /// Guards [_onWatchError] so an exhausted watch budget warns once, not once per directory.
  bool _watchErrorWarned = false;

  /// A broadcast stream that emits an event whenever a template file changes.
  ///
  /// Returns `null` when [devMode] is `false`.
  Stream<void>? get changes => _changesController?.stream;

  FileSystemLoader(this.basePath, {this.extension = '.html', this.devMode = false}) {
    try {
      _canonicalBase = Directory(basePath).resolveSymbolicLinksSync();
    } on FileSystemException catch (e) {
      throw TemplateException(
        'Template base path does not exist or is inaccessible: "$basePath" (${e.osError?.message})',
      );
    }
    if (devMode) {
      _startWatching();
    }
  }

  void _startWatching() {
    _changesController = StreamController<void>.broadcast();
    if (_hasNativeRecursiveWatch) {
      _watchDirectory(_canonicalBase, recursive: true);
    } else {
      _watchSubtree(_canonicalBase, emitIfTemplatesFound: false);
    }
  }

  /// Watches [path] and — where recursive watching is not native — every directory below it.
  ///
  /// [emitIfTemplatesFound] reports the subtree as a change when it already holds templates. A
  /// directory can be created with content (`mkdir -p a/b` plus files, a checkout, a directory moved
  /// in) before its watch is installed, so those files would otherwise go unseen.
  void _watchSubtree(String path, {required bool emitIfTemplatesFound}) {
    if (!Directory(path).existsSync()) return;
    var templatesFound = false;
    final pending = [path];
    while (pending.isNotEmpty) {
      final directory = pending.removeLast();
      // Watch before listing, so a directory created during the walk still arrives as a create event
      // instead of falling into the gap between the two.
      _watchDirectory(directory, recursive: false);
      final List<FileSystemEntity> entries;
      try {
        entries = Directory(directory).listSync(followLinks: false);
      } on FileSystemException {
        // Removed mid-walk, or unreadable. One directory refusing to be read must not abandon the
        // rest of the tree, which a single `listSync(recursive: true)` would do.
        continue;
      }
      for (final entity in entries) {
        if (entity is Directory) {
          pending.add(entity.path);
        } else if (entity.path.endsWith(extension)) {
          templatesFound = true;
        }
      }
    }
    if (templatesFound && emitIfTemplatesFound) _changesController?.add(null);
  }

  void _watchDirectory(String path, {required bool recursive}) {
    if (_changesController == null || _watchSubscriptions.containsKey(path)) return;
    late final StreamSubscription<FileSystemEvent> subscription;
    subscription = Directory(path)
        .watch(recursive: recursive)
        .listen(
          _onFileSystemEvent,
          // Per-directory watches are bookkeeping: drop a dead one rather than surfacing an error the
          // dev server can't act on. The native recursive watch keeps its unhandled-error behaviour.
          onError: recursive ? null : (Object error) => _onWatchError(path, error, subscription),
          onDone: () => _dropWatch(path, subscription),
        );
    _watchSubscriptions[path] = subscription;
  }

  /// Handles a per-directory watch failing to start or dying.
  ///
  /// A directory that vanished between being listed and being watched is routine and silent. One that
  /// is still there means the OS refused the watch — on Linux almost always the per-user inotify limit
  /// (`fs.inotify.max_user_watches`), which a large template tree can exhaust. That caps hot reload
  /// silently, so it is worth one warning; further failures are almost certainly the same cause.
  void _onWatchError(String path, Object error, StreamSubscription<FileSystemEvent> subscription) {
    _dropWatch(path, subscription);
    // The controller-null check keeps a watch dying mid-close() from warning after shutdown.
    if (_changesController == null || _watchErrorWarned || !Directory(path).existsSync()) return;
    _watchErrorWarned = true;
    stderr.writeln(
      'Warning: Trellis dev-mode could not watch template directory "$path" ($error). Template changes '
      'below it will not trigger a reload. On Linux this is usually the inotify watch limit — raise '
      '"fs.inotify.max_user_watches" or point the loader at a smaller template tree.',
    );
  }

  void _dropWatch(String path, StreamSubscription<FileSystemEvent> subscription) {
    if (identical(_watchSubscriptions[path], subscription)) _watchSubscriptions.remove(path);
  }

  void _onFileSystemEvent(FileSystemEvent event) {
    if (!_hasNativeRecursiveWatch) _syncWatches(event);
    // A move event carries the source in `path`; a rename INTO a template name (atomic saves:
    // write `page.html.tmp`, rename over `page.html`) is only visible on the destination. macOS
    // never takes this branch — FSEvents reports renames as delete + create instead.
    final isTemplateEvent =
        event.path.endsWith(extension) ||
        (event is FileSystemMoveEvent && (event.destination?.endsWith(extension) ?? false));
    if (isTemplateEvent) _changesController?.add(null);
  }

  /// Keeps the per-directory watch set in step with directories appearing and disappearing while
  /// watching. Only meaningful without native recursive watching.
  void _syncWatches(FileSystemEvent event) {
    if (event is FileSystemCreateEvent) {
      // No `isDirectory` check — [_watchSubtree] ignores non-directories, and the flag is only as
      // reliable as a stat of an entity that may already be gone.
      _watchSubtree(event.path, emitIfTemplatesFound: true);
    } else if (event is FileSystemDeleteEvent) {
      _unwatchSubtree(event.path);
    } else if (event is FileSystemMoveEvent) {
      _unwatchSubtree(event.path);
      final destination = event.destination;
      if (destination != null && _isWithinBase(destination)) {
        _watchSubtree(destination, emitIfTemplatesFound: true);
      }
    }
  }

  /// Cancels the watch on [path] and on everything below it.
  ///
  /// A no-op for paths that were never watched, which is what a deleted file looks like — delete
  /// events cannot report `isDirectory` reliably, since the entity is already gone.
  void _unwatchSubtree(String path) {
    final prefix = '$path${Platform.pathSeparator}';
    final stale = _watchSubscriptions.keys.where((watched) => watched == path || watched.startsWith(prefix)).toList();
    for (final watched in stale) {
      unawaited(_watchSubscriptions.remove(watched)!.cancel());
    }
  }

  /// Stops watching for file changes and releases resources.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> close() async {
    // Drop the controller first: cancelling is asynchronous, and an event delivered by a not-yet-
    // cancelled watch while we await would otherwise add to a closing controller — or, for a directory
    // create, install a fresh watch that this snapshot no longer covers.
    final controller = _changesController;
    _changesController = null;
    final subscriptions = _watchSubscriptions.values.toList();
    _watchSubscriptions.clear();
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    await controller?.close();
  }

  @override
  Future<String> load(String name) async {
    final path = _resolve(name);
    final file = File(path);
    if (!file.existsSync()) {
      throw TemplateNotFoundException(name);
    }
    return file.readAsString();
  }

  @override
  String? loadSync(String name) {
    final path = _resolve(name);
    final file = File(path);
    if (!file.existsSync()) {
      throw TemplateNotFoundException(name);
    }
    return file.readAsStringSync();
  }

  /// Recursively list all templates under [basePath].
  ///
  /// Returned names match [load] input format: relative to [basePath] and
  /// without the configured [extension].
  ///
  /// Symlinks are not followed, so every name returned is one [load] will actually serve: a symlink
  /// out of the tree would be rejected by the same boundary check [load] applies. A symlink pointing
  /// back inside the tree is also omitted — its target stays listed under the real path, and [load]
  /// still serves the alias name, but the alias itself no longer appears here. This also matches
  /// what dev-mode watching covers.
  List<String> listTemplates() {
    final templates =
        Directory(_canonicalBase)
            .listSync(recursive: true, followLinks: false)
            .whereType<File>()
            .map((file) => file.path)
            .where((path) => path.endsWith(extension))
            .map((path) {
              final relative = path.substring(_canonicalBase.length + 1).replaceAll(Platform.pathSeparator, '/');
              return relative.substring(0, relative.length - extension.length);
            })
            .toList()
          ..sort();
    return templates;
  }

  String _resolve(String name) {
    // Reject absolute paths.
    if (File(name).isAbsolute) {
      throw TemplateSecurityException('Absolute path not allowed: "$name"');
    }

    // Reject path traversal segments.
    final segments = name.split(_pathSepPattern);
    if (segments.contains('..')) {
      throw TemplateSecurityException('Path traversal not allowed: "$name"');
    }

    final fileName = name.endsWith(extension) ? name : '$name$extension';
    final resolved = '$basePath${Platform.pathSeparator}$fileName';

    // Canonicalize and verify the resolved path is within the base directory.
    final file = File(resolved);
    if (file.existsSync()) {
      final canonicalPath = file.resolveSymbolicLinksSync();
      _ensureWithinBase(canonicalPath, name);
    } else {
      final parent = file.parent;
      if (parent.existsSync()) {
        final canonicalParent = parent.resolveSymbolicLinksSync();
        _ensureWithinBase(canonicalParent, name);
      }
    }

    return resolved;
  }

  void _ensureWithinBase(String canonicalPath, String name) {
    if (!_isWithinBase(canonicalPath)) {
      throw TemplateSecurityException('Template path escapes base directory: "$name"');
    }
  }

  bool _isWithinBase(String canonicalPath) {
    if (canonicalPath == _canonicalBase) return true;
    final baseWithSep = _canonicalBase.endsWith(Platform.pathSeparator)
        ? _canonicalBase
        : '$_canonicalBase${Platform.pathSeparator}';
    return canonicalPath.startsWith(baseWithSep);
  }
}
