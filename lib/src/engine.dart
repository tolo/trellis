import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import 'cache_stats.dart';
import 'exceptions.dart';
import 'loaders/template_loader.dart';
import 'loaders/file_loader.dart';
import 'processor.dart';
import 'processors/fragment_processor.dart' show escapeAttrSelector;

/// Core template engine. Parses HTML, processes `tl:*` attributes,
/// renders output.
class Trellis {
  final TemplateLoader loader;
  final bool cache;
  final String prefix;
  final int maxCacheSize;
  final Map<String, dynamic Function(dynamic)> filters;
  final bool strict;
  final Map<String, Document> _cache = {};

  /// Separator between prefix and attribute name.
  /// Derived from prefix: `-` if prefix contains a hyphen, `:` otherwise.
  late final String separator = prefix.contains('-') ? '-' : ':';

  int _cacheHits = 0;
  int _cacheMisses = 0;

  Trellis({
    TemplateLoader? loader,
    this.cache = true,
    this.prefix = 'tl',
    this.maxCacheSize = 256,
    this.strict = false,
    Map<String, dynamic Function(dynamic)>? filters,
  }) : loader = loader ?? FileSystemLoader('templates/'),
       filters = filters ?? const {};

  /// Current cache statistics snapshot.
  CacheStats get cacheStats => CacheStats(size: _cache.length, hits: _cacheHits, misses: _cacheMisses);

  /// Clear the template cache and reset statistics.
  void clearCache() {
    _cache.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
  }

  /// Render a template string with the given context.
  String render(String source, Map<String, dynamic> context) {
    final doc = _parse(source);
    final processor = _createProcessor()..collectFragments(doc);
    processor.process(doc.documentElement!, context);
    return doc.outerHtml;
  }

  /// Render a template file by name.
  Future<String> renderFile(String name, Map<String, dynamic> context) async {
    final source = await loader.load(name);
    return render(source, context);
  }

  /// Render a specific named fragment from a template string.
  String renderFragment(String source, {required String fragment, required Map<String, dynamic> context}) {
    final doc = _parse(source);
    final attrPrefix = '$prefix$separator';
    final fragEl = doc.querySelector('[${escapeAttrSelector(attrPrefix)}fragment="$fragment"]');
    if (fragEl == null) {
      throw FragmentNotFoundException(fragment);
    }
    final processor = _createProcessor()..collectFragments(doc);
    processor.process(fragEl, context);
    fragEl.attributes.remove('${attrPrefix}fragment');
    return fragEl.outerHtml;
  }

  /// Render a specific named fragment from a template file.
  Future<String> renderFileFragment(
    String name, {
    required String fragment,
    required Map<String, dynamic> context,
  }) async {
    final source = await loader.load(name);
    return renderFragment(source, fragment: fragment, context: context);
  }

  /// Render multiple named fragments from a template string, concatenated in order.
  ///
  /// Designed for HTMX OOB (out-of-band) swap responses. Each fragment is
  /// processed independently with the same context. Fails fast if any
  /// fragment is missing — no partial output is returned.
  String renderFragments(
    String source, {
    required List<String> fragments,
    required Map<String, dynamic> context,
  }) {
    if (fragments.isEmpty) return '';

    final doc = _parse(source);
    final attrPrefix = '$prefix$separator';
    final escapedPrefix = escapeAttrSelector(attrPrefix);

    // Fail-fast: find and clone all fragment elements before processing any
    final clones = <Element>[];
    for (final name in fragments) {
      final el = doc.querySelector('[${escapedPrefix}fragment="$name"]');
      if (el == null) throw FragmentNotFoundException(name);
      clones.add(el.clone(true));
    }

    // Process each clone independently
    final processor = _createProcessor()..collectFragments(doc);
    final buffer = StringBuffer();
    for (final clone in clones) {
      clone.attributes.remove('${attrPrefix}fragment');
      processor.process(clone, context);
      buffer.write(clone.outerHtml);
    }

    return buffer.toString();
  }

  /// Render multiple named fragments from a template file, concatenated in order.
  Future<String> renderFileFragments(
    String name, {
    required List<String> fragments,
    required Map<String, dynamic> context,
  }) async {
    final source = await loader.load(name);
    return renderFragments(source, fragments: fragments, context: context);
  }

  DomProcessor _createProcessor() {
    return DomProcessor(prefix: prefix, separator: separator, loader: loader, filters: filters, strict: strict);
  }

  Document _parse(String source) {
    if (cache && _cache.containsKey(source)) {
      _cacheHits++;
      final doc = _cache.remove(source)!;
      _cache[source] = doc;
      return _cloneDocument(doc);
    }
    if (cache) _cacheMisses++;
    final doc = html_parser.parse(source);
    if (cache) {
      _cache[source] = doc;
      if (_cache.length > maxCacheSize) {
        _cache.remove(_cache.keys.first);
      }
    }
    return cache ? _cloneDocument(doc) : doc;
  }

  Document _cloneDocument(Document doc) {
    return doc.clone(true);
  }

}
