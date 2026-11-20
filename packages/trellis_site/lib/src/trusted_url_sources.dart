import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:trellis/trellis.dart' show TrustedUrl;

import 'site_config.dart';

/// Matches a build's declarations only as the source loaders encounter their inputs.
final class TrustedUrlSources {
  final String _siteDir;
  late final String _resolvedSiteDir = Directory(_siteDir).resolveSymbolicLinksSync();
  final _pending = <String, Set<String>>{};

  TrustedUrlSources(SiteConfig config) : _siteDir = config.siteDir {
    for (final (:source, :field) in config.trustedUrls) {
      _pending.putIfAbsent(source, () => {}).add(field);
    }
  }

  Map<String, TrustedUrl> loadFields(String path, Object? mapping) {
    if (_pending.isEmpty) return const {};
    final source = _relativeSource(path);
    final fields = _pending[source];
    if (fields == null || !_isNamedFile(path, source)) return const {};
    _pending.remove(source);

    final result = <String, TrustedUrl>{};
    for (final field in fields) {
      if (mapping is! Map<Object?, Object?>) {
        _fail(source, field, 'the source must contain a mapping');
      }
      final value = mapping[field];
      if (value is! String) {
        _fail(source, field, 'the literal top-level field must exist and hold a string');
      }
      // YAML conversion stringifies keys and keeps the last one at a projected name.
      final renderedKey = mapping.keys.where((key) => key.toString() == field).last;
      if (renderedKey != field) {
        _fail(source, field, 'another YAML key shadows the declared field in the render context');
      }
      result[field] = TrustedUrl(value);
    }
    return result;
  }

  void rejectSourceFailure(String path, String message) {
    if (_pending.isEmpty) return;
    final source = _relativeSource(path);
    final field = _pending[source]?.firstOrNull;
    if (field != null) _fail(source, field, message);
  }

  void requireLoadedSources() {
    if (_pending.isEmpty) return;
    final entry = _pending.entries.first;
    _fail(entry.key, entry.value.first, 'source was not loaded from the configured content or site data directory');
  }

  String _relativeSource(String path) => p.split(p.relative(path, from: _siteDir)).join('/');

  bool _isNamedFile(String path, String source) {
    // A configured directory can lead through a link even when the file itself is regular.
    if (FileSystemEntity.typeSync(path, followLinks: false) != FileSystemEntityType.file) return false;
    final namedPath = p.joinAll([_resolvedSiteDir, ...source.split('/')]);
    try {
      return p.isWithin(_resolvedSiteDir, namedPath) && p.equals(File(path).resolveSymbolicLinksSync(), namedPath);
    } on FileSystemException {
      return false;
    }
  }

  Never _fail(String source, String field, String reason) => throw SiteConfigException(
    'trustedUrls source "$source", field "$field": $reason',
    configPath: p.join(_siteDir, 'trellis_site.yaml'),
  );
}
