import 'dart:io';

import '../exceptions.dart';
import 'template_loader.dart';

/// Loads templates from the filesystem relative to a base directory.
///
/// Enforces security boundaries: rejects absolute paths, `..` traversal,
/// and symlink escapes outside the base path.
class FileSystemLoader implements TemplateLoader {
  final String basePath;
  final String extension;
  late final String _canonicalBase;

  FileSystemLoader(this.basePath, {this.extension = '.html'}) {
    try {
      _canonicalBase = Directory(basePath).resolveSymbolicLinksSync();
    } on FileSystemException catch (e) {
      throw TemplateException(
        'Template base path does not exist or is inaccessible: "$basePath" (${e.osError?.message})',
      );
    }
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

  String _resolve(String name) {
    // Reject absolute paths.
    if (File(name).isAbsolute) {
      throw TemplateSecurityException('Absolute path not allowed: "$name"');
    }

    // Reject path traversal segments.
    final segments = name.split(RegExp(r'[/\\]'));
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
    final baseWithSep =
        _canonicalBase.endsWith(Platform.pathSeparator) ? _canonicalBase : '$_canonicalBase${Platform.pathSeparator}';
    return canonicalPath.startsWith(baseWithSep);
  }
}
