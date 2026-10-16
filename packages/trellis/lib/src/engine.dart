import 'dart:async';

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import 'cache_stats.dart';
import 'dialect.dart';
import 'exceptions.dart';
import 'expression/ast.dart';
import 'inheritance.dart';
import 'loaders/template_loader.dart';
import 'loaders/file_loader.dart';
import 'loaders/map_loader.dart';
import 'message_source.dart';
import 'processor.dart';
import 'processor_api.dart';
import 'processors/fragment_processor.dart' show escapeAttrSelector, parseFragmentDef, restParameterName;
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
    var doc = _parse(source);
    doc = _resolveInheritance(doc);
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
  ///
  /// [fragment] is the fragment's bare name (`toast`, not `toast(type, title)`); the first definition in document
  /// order wins. A parameterised fragment renders fully processed: its declared parameters resolve from the
  /// same-named [context] keys (absent: `null`, or an error in strict mode) and a `...rest` parameter is an empty
  /// map. This differs from in-template `tl:replace="toast"`, which binds unpassed parameters to `null` and never
  /// reads the context.
  ///
  /// Throws [FragmentNotFoundException] for an unknown name, and [TemplateException] when [fragment] carries
  /// arguments in parentheses (an empty `()` is read as the bare name).
  String renderFragment(String source, {required String fragment, required Map<String, dynamic> context}) {
    var doc = _parse(source);
    doc = _resolveInheritance(doc);
    final attrPrefix = '$prefix$separator';
    final fragEl = _findFragment(doc, fragment, attrPrefix);
    final clone = fragEl.clone(true);
    final processor = _createProcessor()..collectFragments(doc);
    return _renderFragmentRoot(processor, clone, context, attrPrefix);
  }

  /// Render a specific named fragment from a template file.
  ///
  /// Addresses [fragment] by bare name exactly as [renderFragment] does.
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
  /// fragment is missing or named with arguments — no partial output is returned.
  /// Names are bare names with the semantics of [renderFragment]; all fragments read the one shared [context].
  String renderFragments(String source, {required List<String> fragments, required Map<String, dynamic> context}) {
    if (fragments.isEmpty) return '';

    var doc = _parse(source);
    doc = _resolveInheritance(doc);
    final attrPrefix = '$prefix$separator';

    // Fail-fast: find and clone all fragment elements before processing any
    final clones = [for (final name in fragments) _findFragment(doc, name, attrPrefix).clone(true)];

    // Process each clone independently
    final processor = _createProcessor()..collectFragments(doc);
    final buffer = StringBuffer();
    for (final clone in clones) {
      buffer.write(_renderFragmentRoot(processor, clone, context, attrPrefix));
    }

    return buffer.toString();
  }

  /// Render multiple named fragments from a template file, concatenated in order.
  ///
  /// Addresses [fragments] by bare name exactly as [renderFragments] does.
  Future<String> renderFileFragments(
    String name, {
    required List<String> fragments,
    required Map<String, dynamic> context,
  }) async {
    final source = await loader.load(name);
    return renderFragments(source, fragments: fragments, context: context);
  }

  /// The first element in document order whose `tl:fragment` declares the bare name [requested].
  Element _findFragment(Document doc, String requested, String attrPrefix) {
    final name = requested.trim();
    final parenIdx = name.indexOf('(');
    if (parenIdx >= 0) {
      final bare = name.substring(0, parenIdx).trim();
      if (name.substring(parenIdx).replaceAll(RegExp(r'\s'), '') != '()') {
        throw TemplateException(
          'Fragment "$requested" is addressed with arguments; pass the bare name "$bare" instead. '
          'Parameters resolve from the render context.',
        );
      }
      return _findFragment(doc, bare, attrPrefix);
    }
    final attr = '${attrPrefix}fragment';
    for (final el in doc.querySelectorAll('[${escapeAttrSelector(attrPrefix)}fragment]')) {
      if (parseFragmentDef(el.attributes[attr]!).$1 == name) return el;
    }
    throw FragmentNotFoundException(requested);
  }

  /// Process a looked-up fragment [root] as a top-level render root and return its markup.
  ///
  /// The root gets a temporary parent so its own directives act as they would in place: `tl:replace` swaps it,
  /// `tl:each` copies it, and `tl:if`, `tl:unless`, `tl:remove` and `tl:block` remove or unwrap it. What the parent
  /// holds afterwards is the result. A parameterised root is rendered rather than removed as a definition. A `...rest`
  /// parameter is an empty map, since no invoking host exists.
  String _renderFragmentRoot(DomProcessor processor, Element root, Map<String, dynamic> context, String attrPrefix) {
    final fragAttr = '${attrPrefix}fragment';
    final restName = restParameterName(parseFragmentDef(root.attributes[fragAttr]!).$2);
    final holder = Element.tag('div')..append(root);
    processor.processRenderRoot(root, restName == null ? context : {...context, restName: <String, dynamic>{}});
    return holder.innerHtml;
  }

  Document _resolveInheritance(Document doc) {
    return InheritanceResolver(attrPrefix: '$prefix$separator', loader: loader, parse: _parse).resolve(doc);
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
