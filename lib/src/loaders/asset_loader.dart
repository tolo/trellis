import 'dart:io';
import 'dart:isolate';

import '../exceptions.dart';
import 'template_loader.dart';

/// Loads templates from Dart package assets using [Isolate.resolvePackageUri].
///
/// Resolves `package:` URIs to filesystem paths at runtime, then reads the
/// template file. Applies the same path traversal and symlink protections as
/// [FileSystemLoader].
///
/// **JIT only**: This loader works reliably with `dart run` (JIT VM) where
/// the package config and source tree are available. It does **not** work
/// for AOT-compiled binaries deployed to a different machine, because
/// `Isolate.resolvePackageUri` resolves to build-machine paths that won't
/// exist on the deployment target.
///
/// | Deployment | AssetLoader works? | Recommendation |
/// |---|---|---|
/// | `dart run` (JIT) | Yes | `AssetLoader` directly |
/// | `dart compile exe` same machine | Yes (source tree present) | `AssetLoader` or `FileSystemLoader` |
/// | AOT deployed to different machine | No | `FileSystemLoader` + co-deployed templates |
/// | Docker (binary only) | No | Bake templates at known path + `FileSystemLoader` |
///
/// Use [CompositeLoader] for fallback:
/// ```dart
/// final loader = CompositeLoader([
///   AssetLoader('package:my_app/templates/'),
///   FileSystemLoader('templates/'),
/// ]);
/// ```
final class AssetLoader implements TemplateLoader {
  /// The base `package:` URI (e.g. `'package:my_app/templates/'`).
  final String basePath;
  final String extension;

  /// Cached resolved base directory path (lazily initialized).
  String? _resolvedBasePath;

  /// Cached canonical base path for symlink checks.
  String? _canonicalBase;

  AssetLoader(this.basePath, {this.extension = '.html'}) {
    if (!basePath.startsWith('package:')) {
      throw ArgumentError('AssetLoader basePath must start with "package:" — got "$basePath"');
    }
    if (!basePath.endsWith('/')) {
      throw ArgumentError('AssetLoader basePath must end with "/" — got "$basePath"');
    }
  }

  @override
  Future<String> load(String name) async {
    final path = await _resolve(name);
    final file = File(path);
    if (!file.existsSync()) {
      throw TemplateNotFoundException(name);
    }
    return file.readAsString();
  }

  @override
  String? loadSync(String name) {
    final path = _resolveSync(name);
    if (path == null) return null; // sync resolution not available
    final file = File(path);
    if (!file.existsSync()) {
      throw TemplateNotFoundException(name);
    }
    return file.readAsStringSync();
  }

  /// Resolve a template name to a filesystem path (async).
  Future<String> _resolve(String name) async {
    _validateName(name);
    final base = await _resolveBase();
    final fileName = name.endsWith(extension) ? name : '$name$extension';
    final resolved = '$base${Platform.pathSeparator}$fileName';
    _ensureWithinBase(resolved, name, await _getCanonicalBase(base));
    return resolved;
  }

  /// Resolve a template name to a filesystem path (sync).
  /// Returns null if the base path cannot be resolved synchronously.
  String? _resolveSync(String name) {
    _validateName(name);
    final base = _resolveBaseSync();
    if (base == null) return null;
    final fileName = name.endsWith(extension) ? name : '$name$extension';
    final resolved = '$base${Platform.pathSeparator}$fileName';
    _ensureWithinBase(resolved, name, _getCanonicalBaseSync(base));
    return resolved;
  }

  /// Validate the template name for security.
  void _validateName(String name) {
    // Reject absolute paths.
    if (File(name).isAbsolute) {
      throw TemplateSecurityException('Absolute path not allowed: "$name"');
    }

    // Reject path traversal segments.
    final segments = name.split(RegExp(r'[/\\]'));
    if (segments.contains('..')) {
      throw TemplateSecurityException('Path traversal not allowed: "$name"');
    }
  }

  /// Resolve the base package URI to a filesystem directory (async).
  Future<String> _resolveBase() async {
    if (_resolvedBasePath != null) return _resolvedBasePath!;
    final uri = Uri.parse(basePath);
    final resolved = await Isolate.resolvePackageUri(uri);
    if (resolved == null) {
      throw TemplateException(
        'Could not resolve package URI: "$basePath". '
        'AssetLoader requires JIT VM (dart run). '
        'For AOT deployments, use FileSystemLoader.',
      );
    }
    _resolvedBasePath = resolved.toFilePath();
    // Remove trailing separator if present for consistent base path
    if (_resolvedBasePath!.endsWith(Platform.pathSeparator)) {
      _resolvedBasePath = _resolvedBasePath!.substring(0, _resolvedBasePath!.length - 1);
    }
    return _resolvedBasePath!;
  }

  /// Resolve the base package URI synchronously.
  /// Returns null if resolution is not possible synchronously.
  String? _resolveBaseSync() {
    if (_resolvedBasePath != null) return _resolvedBasePath!;
    // Isolate.resolvePackageUriSync is available in Dart 3.x
    final uri = Uri.parse(basePath);
    final resolved = Isolate.resolvePackageUriSync(uri);
    if (resolved == null) return null;
    _resolvedBasePath = resolved.toFilePath();
    if (_resolvedBasePath!.endsWith(Platform.pathSeparator)) {
      _resolvedBasePath = _resolvedBasePath!.substring(0, _resolvedBasePath!.length - 1);
    }
    return _resolvedBasePath!;
  }

  /// Get canonical base path for symlink detection (async, cached).
  Future<String> _getCanonicalBase(String base) async {
    if (_canonicalBase != null) return _canonicalBase!;
    try {
      _canonicalBase = Directory(base).resolveSymbolicLinksSync();
    } on FileSystemException catch (e) {
      throw TemplateException(
        'Asset base path does not exist or is inaccessible: '
        '"$basePath" resolved to "$base" (${e.osError?.message})',
      );
    }
    return _canonicalBase!;
  }

  /// Get canonical base path synchronously (cached).
  String _getCanonicalBaseSync(String base) {
    if (_canonicalBase != null) return _canonicalBase!;
    try {
      _canonicalBase = Directory(base).resolveSymbolicLinksSync();
    } on FileSystemException catch (e) {
      throw TemplateException(
        'Asset base path does not exist or is inaccessible: '
        '"$basePath" resolved to "$base" (${e.osError?.message})',
      );
    }
    return _canonicalBase!;
  }

  /// Verify resolved path is within the base directory.
  void _ensureWithinBase(String resolved, String name, String canonicalBase) {
    final file = File(resolved);
    if (file.existsSync()) {
      final canonicalPath = file.resolveSymbolicLinksSync();
      if (!_isWithinBase(canonicalPath, canonicalBase)) {
        throw TemplateSecurityException('Template path escapes base directory: "$name"');
      }
    } else {
      final parent = file.parent;
      if (parent.existsSync()) {
        final canonicalParent = parent.resolveSymbolicLinksSync();
        if (!_isWithinBase(canonicalParent, canonicalBase)) {
          throw TemplateSecurityException('Template path escapes base directory: "$name"');
        }
      }
    }
  }

  bool _isWithinBase(String canonicalPath, String canonicalBase) {
    if (canonicalPath == canonicalBase) return true;
    final baseWithSep = canonicalBase.endsWith(Platform.pathSeparator)
        ? canonicalBase
        : '$canonicalBase${Platform.pathSeparator}';
    return canonicalPath.startsWith(baseWithSep);
  }
}
