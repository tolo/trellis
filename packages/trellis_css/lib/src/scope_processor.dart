import 'package:html/dom.dart';
import 'package:trellis/trellis.dart';

/// Processor for `tl:scope` — wraps `<style>` content in CSS `@scope` and
/// adds the scope class to the enclosing `tl:fragment` root element.
///
/// When `<style tl:scope>` appears inside a `tl:fragment`, this processor
/// fires on the fragment root element (the element carrying `tl:fragment`).
/// It scans for `<style tl:scope>` descendants, then:
/// 1. Wraps the CSS in `@scope (.tl-scope-{name}) { ... }`
/// 2. Adds `class="tl-scope-{name}"` to the fragment root element
/// 3. Removes `tl:scope` attributes from all matching `<style>` elements
///
/// Requires CSS `@scope` browser support (Baseline Dec 2025, 86%+). No
/// fallback is provided — apps targeting older browsers should not use
/// `tl:scope`.
///
/// ## Usage
///
/// ```html
/// <div tl:fragment="card">
///   <style tl:scope>
///     h2 { color: navy; }
///   </style>
///   <h2 tl:text="${title}">Title</h2>
/// </div>
/// ```
///
/// Produces at render time:
///
/// ```html
/// <div class="tl-scope-card">
///   <style>
///     @scope (.tl-scope-card) {
///       h2 { color: navy; }
///     }
///   </style>
///   <h2>My Title</h2>
/// </div>
/// ```
class ScopeProcessor extends Processor {
  @override
  String get attribute => 'fragment';

  /// Fires early (highest priority) so the fragment element's attributes
  /// are still intact when we extract the fragment name.
  @override
  ProcessorPriority get priority => ProcessorPriority.highest;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    final fragName = _extractFragmentName(value);
    final fragAttr = '${context.attrPrefix}fragment';
    final scopeAttr = '${context.attrPrefix}scope';

    // Find only <style tl:scope> elements that belong directly to this fragment
    // (not inside a nested tl:fragment, which owns its own scope boundary).
    final styleElements = element
        .querySelectorAll('style')
        .where((el) => el.attributes.containsKey(scopeAttr) && !_hasIntermediateFragment(el, element, fragAttr))
        .toList();

    if (styleElements.isEmpty) return true;

    final scopeClass = 'tl-scope-$fragName';

    // Add scope class to fragment root element
    _addScopeClass(element, scopeClass);

    // Wrap CSS in @scope and remove tl:scope attribute from each <style>
    for (final styleEl in styleElements) {
      final originalCss = styleEl.text.trim();
      final indented = originalCss.isEmpty ? '' : '  ${originalCss.replaceAll('\n', '\n  ')}';
      final scopedCss = '@scope (.$scopeClass) {\n$indented\n}';
      styleEl.nodes.clear();
      styleEl.append(Text(scopedCss));
      styleEl.attributes.remove(scopeAttr);
    }

    return true;
  }

  String _extractFragmentName(String attrValue) {
    final parenIdx = attrValue.indexOf('(');
    return (parenIdx >= 0 ? attrValue.substring(0, parenIdx) : attrValue).trim();
  }

  void _addScopeClass(Element element, String scopeClass) {
    final existing = element.attributes['class'];
    if (existing == null) {
      element.attributes['class'] = scopeClass;
    } else if (!existing.split(' ').contains(scopeClass)) {
      element.attributes['class'] = '$existing $scopeClass';
    }
    // Already present — idempotent, do nothing.
  }

  /// Returns `true` if [descendant] has an ancestor with [fragAttr] between
  /// it and [fragmentRoot] (exclusive on both ends).
  ///
  /// Used to skip `<style tl:scope>` elements that belong to a nested
  /// fragment rather than the current one.
  bool _hasIntermediateFragment(Element descendant, Element fragmentRoot, String fragAttr) {
    var current = descendant.parent;
    while (current != null && current != fragmentRoot) {
      if (current.attributes.containsKey(fragAttr)) return true;
      current = current.parent;
    }
    return false;
  }
}

/// Handles `<style tl:scope>` elements that appear without a `tl:fragment`
/// ancestor — emits a warning and removes the stray `tl:scope` attribute.
///
/// Provide [onWarning] to receive warning messages instead of discarding them.
/// If [onWarning] is `null`, warnings are silently dropped.
///
/// Example:
/// ```dart
/// final processor = OrphanScopeProcessor(
///   onWarning: (msg) => print('CSS warning: $msg'),
/// );
/// ```
class OrphanScopeProcessor extends Processor {
  /// Called when a misplaced `tl:scope` attribute is encountered.
  ///
  /// If `null`, warnings are silently dropped.
  final void Function(String message)? onWarning;

  OrphanScopeProcessor({this.onWarning});

  @override
  String get attribute => 'scope';

  @override
  ProcessorPriority get priority => ProcessorPriority.afterContent;

  @override
  bool process(Element element, String value, ProcessorContext context) {
    if (element.localName != 'style') {
      onWarning?.call(
        'tl:scope is only supported on <style> elements, '
        'found on <${element.localName}>. Ignoring.',
      );
    } else {
      onWarning?.call(
        'tl:scope found on <style> outside a tl:fragment element. '
        'CSS will not be scoped.',
      );
    }
    element.attributes.remove('${context.attrPrefix}scope');
    return true;
  }
}
