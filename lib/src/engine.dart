import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import 'exceptions.dart';
import 'loaders/template_loader.dart';
import 'loaders/file_loader.dart';
import 'processor.dart';

/// Core template engine. Parses HTML, processes `tl:*` attributes,
/// renders output.
class Trellis {
  final TemplateLoader loader;
  final bool cache;
  final String prefix;
  final int maxCacheSize;
  final Map<String, dynamic Function(dynamic)> filters;
  final Map<String, Document> _cache = {};

  Trellis({
    TemplateLoader? loader,
    this.cache = true,
    this.prefix = 'tl',
    this.maxCacheSize = 256,
    Map<String, dynamic Function(dynamic)>? filters,
  }) : loader = loader ?? FileSystemLoader('templates/'),
       filters = filters ?? const {};

  /// Render a template string with the given context.
  String render(String source, Map<String, dynamic> context) {
    final doc = _parse(source);
    final processor = DomProcessor(prefix: prefix, loader: loader, filters: filters)..collectFragments(doc);
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
    final fragEl = doc.querySelector('[$prefix\\:fragment="$fragment"]');
    if (fragEl == null) {
      throw FragmentNotFoundException(fragment);
    }
    final processor = DomProcessor(prefix: prefix, loader: loader, filters: filters)..collectFragments(doc);
    processor.process(fragEl, context);
    fragEl.attributes.remove('$prefix:fragment');
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

  Document _parse(String source) {
    if (cache && _cache.containsKey(source)) {
      final doc = _cache.remove(source)!;
      _cache[source] = doc;
      return _cloneDocument(doc);
    }
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
