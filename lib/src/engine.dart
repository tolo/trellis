import 'dart:async';

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import 'cache_stats.dart';
import 'dialect.dart';
import 'exceptions.dart';
import 'expression/ast.dart';
import 'loaders/template_loader.dart';
import 'loaders/file_loader.dart';
import 'loaders/map_loader.dart';
import 'message_source.dart';
import 'processor.dart';
import 'processor_api.dart';
import 'processors/fragment_processor.dart' show escapeAttrSelector;
import 'utils/html_normalizer.dart';
import 'warm_up_result.dart';

/// Core template engine. Parses HTML, processes `tl:*` attributes,
/// renders output.
final class Trellis {
  final TemplateLoader loader;
  final bool cache;
  final String prefix;
  final int maxCacheSize;
  final Map<String, Function> filters;
  final bool strict;
  final List<Processor>? processors;
  final List<Dialect>? dialects;
  final bool includeStandard;
  final MessageSource? messageSource;
  final String? locale;
  final bool devMode;
  final Map<String, Document> _cache = {};
  final Map<String, Expr>? _expressionCache;

  /// Separator between prefix and attribute name.
  /// Derived from prefix: `-` if prefix contains a hyphen, `:` otherwise.
  late final String separator = prefix.contains('-') ? '-' : ':';

  int _cacheHits = 0;
  int _cacheMisses = 0;
  StreamSubscription<void>? _watchSubscription;

  Trellis({
    TemplateLoader? loader,
    this.cache = true,
    this.prefix = 'tl',
    this.maxCacheSize = 256,
    this.strict = false,
    Map<String, Function>? filters,
    this.processors,
    this.dialects,
    this.includeStandard = true,
    this.messageSource,
    this.locale,
    this.devMode = false,
  }) : loader = loader ?? FileSystemLoader('templates/', devMode: devMode),
       filters = filters ?? const {},
       _expressionCache = cache ? <String, Expr>{} : null {
    if (devMode && this.loader is FileSystemLoader) {
      _watchSubscription = (this.loader as FileSystemLoader).changes?.listen((_) => clearCache());
    }
  }

  /// Current cache statistics snapshot.
  CacheStats get cacheStats => CacheStats(
    size: _cache.length,
    hits: _cacheHits,
    misses: _cacheMisses,
    expressionCacheSize: _expressionCache?.length ?? 0,
  );

  /// Clear the template cache and reset statistics.
  void clearCache() {
    _cache.clear();
    _expressionCache?.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
  }

  /// Release resources held by this engine instance.
  ///
  /// Cancels the file-watch subscription (if any) and closes the underlying
  /// loader when it is a [FileSystemLoader]. Safe to call multiple times.
  Future<void> close() async {
    await _watchSubscription?.cancel();
    _watchSubscription = null;
    if (loader is FileSystemLoader) {
      await (loader as FileSystemLoader).close();
    }
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

  /// Pre-load specific templates into the DOM cache.
  ///
  /// Throws [StateError] when caching is disabled.
  Future<WarmUpResult> warmUp(List<String> names) async {
    if (!cache) {
      throw StateError('Cannot warm up with cache disabled');
    }

    final preSize = _cache.length;
    var loaded = 0;
    final failures = <(String name, Object error)>[];

    for (final name in names) {
      try {
        final source = await loader.load(name);
        final normalizedSource = fixSelfClosingBlocks(source, prefix: prefix, separator: separator);
        final wasCached = _cache.containsKey(normalizedSource);
        _parse(source);
        if (!wasCached && _cache.containsKey(normalizedSource)) {
          loaded++;
        }
      } catch (error) {
        failures.add((name, error));
      }
    }

    final projectedSize = preSize + loaded;
    final evicted = projectedSize > _cache.length ? projectedSize - _cache.length : 0;
    return WarmUpResult(loaded: loaded, failed: failures, evicted: evicted);
  }

  /// Discover templates from the configured loader and warm them into the DOM cache.
  Future<WarmUpResult> warmUpAll() {
    if (loader is FileSystemLoader) {
      return warmUp((loader as FileSystemLoader).listTemplates());
    }
    if (loader is MapLoader) {
      return warmUp((loader as MapLoader).listTemplates());
    }
    throw UnsupportedError('warmUpAll() is only supported for FileSystemLoader and MapLoader');
  }

  /// Render a specific named fragment from a template string.
  String renderFragment(String source, {required String fragment, required Map<String, dynamic> context}) {
    final doc = _parse(source);
    final attrPrefix = '$prefix$separator';
    final fragEl = doc.querySelector('[${escapeAttrSelector(attrPrefix)}fragment="$fragment"]');
    if (fragEl == null) {
      throw FragmentNotFoundException(fragment);
    }
    final clone = fragEl.clone(true);
    final processor = _createProcessor()..collectFragments(doc);
    processor.process(clone, context);
    clone.attributes.remove('${attrPrefix}fragment');
    return _elementHtml(clone, attrPrefix);
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
  String renderFragments(String source, {required List<String> fragments, required Map<String, dynamic> context}) {
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
      buffer.write(_elementHtml(clone, attrPrefix));
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
    return DomProcessor(
      prefix: prefix,
      separator: separator,
      loader: loader,
      filters: filters,
      strict: strict,
      processors: processors,
      dialects: dialects,
      includeStandard: includeStandard,
      messageSource: messageSource,
      locale: locale,
      expressionCache: _expressionCache,
    );
  }

  /// Return outerHtml for regular elements, innerHtml for block elements
  /// (virtual wrappers that should not appear in output).
  String _elementHtml(Element element, String attrPrefix) {
    if (element.localName == '${attrPrefix}block') return element.innerHtml;
    return element.outerHtml;
  }

  Document _parse(String source) {
    final normalizedSource = fixSelfClosingBlocks(source, prefix: prefix, separator: separator);
    if (cache && _cache.containsKey(normalizedSource)) {
      _cacheHits++;
      final doc = _cache.remove(normalizedSource)!;
      _cache[normalizedSource] = doc;
      return doc.clone(true);
    }
    if (cache) _cacheMisses++;
    final doc = html_parser.parse(normalizedSource);
    if (cache) {
      _cache[normalizedSource] = doc;
      if (_cache.length > maxCacheSize) {
        _cache.remove(_cache.keys.first);
      }
    }
    return cache ? doc.clone(true) : doc;
  }
}
