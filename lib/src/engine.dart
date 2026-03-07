import 'dart:async';

import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';

import 'cache_stats.dart';
import 'dialect.dart';
import 'exceptions.dart';
import 'loaders/template_loader.dart';
import 'loaders/file_loader.dart';
import 'message_source.dart';
import 'processor.dart';
import 'processor_api.dart';
import 'processors/fragment_processor.dart' show escapeAttrSelector;

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
       filters = filters ?? const {} {
    if (devMode && this.loader is FileSystemLoader) {
      _watchSubscription = (this.loader as FileSystemLoader).changes?.listen((_) => clearCache());
    }
  }

  /// Current cache statistics snapshot.
  CacheStats get cacheStats => CacheStats(size: _cache.length, hits: _cacheHits, misses: _cacheMisses);

  /// Clear the template cache and reset statistics.
  void clearCache() {
    _cache.clear();
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
    );
  }

  /// Return outerHtml for regular elements, innerHtml for block elements
  /// (virtual wrappers that should not appear in output).
  String _elementHtml(Element element, String attrPrefix) {
    if (element.localName == '${attrPrefix}block') return element.innerHtml;
    return element.outerHtml;
  }

  /// Rewrite self-closing `<tl:block .../>` to `<tl:block ...></tl:block>`.
  /// HTML5 treats unknown elements as non-void, so `/>` is silently ignored
  /// by the parser — causing all subsequent siblings to become children.
  ///
  /// Uses a quote-aware scan instead of a simple regex so that `>` inside
  /// quoted attribute values (e.g. `tl:if="${count > 0}"`) is not mistaken
  /// for the end of the tag.
  String _fixSelfClosingBlocks(String source) {
    final tag = '$prefix${separator}block';
    final tagLower = tag.toLowerCase();
    final tagLen = tag.length;
    final buf = StringBuffer();
    var i = 0;
    while (i < source.length) {
      // Look for '<'
      if (source.codeUnitAt(i) != 0x3C) {
        buf.writeCharCode(source.codeUnitAt(i));
        i++;
        continue;
      }
      // Check if tag name matches (case-insensitive)
      final remaining = source.length - i;
      if (remaining < tagLen + 2 || source.substring(i + 1, i + 1 + tagLen).toLowerCase() != tagLower) {
        buf.writeCharCode(source.codeUnitAt(i));
        i++;
        continue;
      }
      // Char after tag name must be whitespace, '/' or '>'
      final afterTag = source.codeUnitAt(i + 1 + tagLen);
      if (afterTag != 0x20 &&
          afterTag != 0x09 &&
          afterTag != 0x0A &&
          afterTag != 0x0D &&
          afterTag != 0x2F &&
          afterTag != 0x3E) {
        buf.writeCharCode(source.codeUnitAt(i));
        i++;
        continue;
      }
      // Found a block tag — scan to end of tag, respecting quotes
      final tagStart = i;
      i += 1 + tagLen; // skip '<' + tag name
      int? quoteChar;
      while (i < source.length) {
        final c = source.codeUnitAt(i);
        if (quoteChar != null) {
          if (c == quoteChar) quoteChar = null;
          i++;
        } else if (c == 0x22 || c == 0x27) {
          // " or '
          quoteChar = c;
          i++;
        } else if (c == 0x2F && i + 1 < source.length && source.codeUnitAt(i + 1) == 0x3E) {
          // '/>' — rewrite to ></tag>
          final attrs = source.substring(tagStart + 1 + tagLen, i);
          final tagName = source.substring(tagStart + 1, tagStart + 1 + tagLen);
          buf.write('<$tagName$attrs></$tagName>');
          i += 2; // skip '/>'
          break;
        } else if (c == 0x3E) {
          // '>' — not self-closing, copy as-is
          buf.write(source.substring(tagStart, i + 1));
          i++;
          break;
        } else {
          i++;
        }
      }
      // If we ran out of input inside the tag, copy remainder as-is
      if (i >= source.length && (quoteChar != null || tagStart + 1 + tagLen >= source.length)) {
        buf.write(source.substring(tagStart));
      }
    }
    return buf.toString();
  }

  Document _parse(String source) {
    final normalizedSource = _fixSelfClosingBlocks(source);
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
