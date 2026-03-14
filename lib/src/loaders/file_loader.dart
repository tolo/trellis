import 'dart:async';
import 'dart:io';

import '../exceptions.dart';
import 'template_loader.dart';

final _pathSepPattern = RegExp(r'[/\\]');

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
  StreamSubscription<FileSystemEvent>? _watchSubscription;

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
    _watchSubscription = Directory(_canonicalBase)
        .watch(recursive: true)
        .where((event) => event.path.endsWith(extension))
        .listen((_) => _changesController?.add(null));
  }

  /// Stops watching for file changes and releases resources.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  Future<void> close() async {
    await _watchSubscription?.cancel();
    _watchSubscription = null;
    await _changesController?.close();
    _changesController = null;
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
  List<String> listTemplates() {
    final templates =
        Directory(_canonicalBase)
            .listSync(recursive: true)
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
