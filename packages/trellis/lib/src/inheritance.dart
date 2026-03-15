import 'package:html/dom.dart';

import 'exceptions.dart';
import 'loaders/template_loader.dart';

/// Resolves template inheritance (`tl:extends` / `tl:define`) as a pre-pass
/// before fragment collection and DOM processing.
///
/// Each child template declares `tl:extends="parent-name"` on its root element.
/// Named blocks (`tl:define="name"`) in the child override matching blocks in
/// the parent. Resolution is recursive (parent can extend grandparent) with
/// cycle detection and a configurable max depth.
class InheritanceResolver {
  /// Combined prefix+separator (e.g. `'tl:'` or `'data-tl-'`).
  final String attrPrefix;

  /// Loader for resolving parent templates by name.
  final TemplateLoader loader;

  /// Parse function — uses the engine's cached parse path.
  final Document Function(String source) parse;

  /// Maximum inheritance chain depth.
  final int maxDepth;

  InheritanceResolver({required this.attrPrefix, required this.loader, required this.parse, this.maxDepth = 16});

  /// Resolve inheritance on [doc].
  ///
  /// If the root element has `tl:extends`, loads and merges parent templates
  /// recursively. If no `tl:extends`, strips any `tl:define` attributes and
  /// returns the document unchanged.
  Document resolve(Document doc) {
    final root = doc.documentElement;
    if (root == null) return doc;

    // Validate: tl:extends must only appear on the root element.
    _validateExtendsPlacement(doc);

    final extendsAttr = '${attrPrefix}extends';
    final parentName = root.attributes[extendsAttr];
    if (parentName == null) {
      // No inheritance — strip tl:define attrs but preserve content.
      _stripDefineAttrs(doc);
      return doc;
    }

    final result = _resolveChain(doc, <String>[]);
    // Strip all inheritance attributes after full chain resolution.
    _stripInheritanceAttrs(result);
    return result;
  }

  /// Recursively resolve the inheritance chain.
  ///
  /// Does NOT strip attributes — caller is responsible for final cleanup.
  Document _resolveChain(Document childDoc, List<String> ancestorStack) {
    final root = childDoc.documentElement!;
    final extendsAttr = '${attrPrefix}extends';
    final parentName = root.attributes[extendsAttr];

    if (parentName == null) {
      // Base template — no further resolution.
      return childDoc;
    }

    if (parentName.trim().isEmpty) {
      throw TemplateException('tl:extends value cannot be empty');
    }

    // Cycle detection.
    if (ancestorStack.contains(parentName)) {
      final cyclePath = [...ancestorStack, parentName].join(' → ');
      throw TemplateException('Template inheritance cycle detected: $cyclePath');
    }

    // Depth check.
    if (ancestorStack.length >= maxDepth) {
      throw TemplateException(
        'Template inheritance depth exceeded (max: $maxDepth). '
        'Chain: ${ancestorStack.join(' → ')}',
      );
    }

    // Load parent template.
    final parentSource = loader.loadSync(parentName);
    if (parentSource == null) {
      throw TemplateNotFoundException(parentName);
    }

    final parentDoc = parse(parentSource);

    // Collect child blocks.
    final childBlocks = _collectBlocks(root);

    // Recurse into parent (it may also extend another template).
    ancestorStack.add(parentName);
    final resolvedParent = _resolveChain(parentDoc, ancestorStack);

    // Merge child blocks into resolved parent.
    _mergeBlocks(resolvedParent, childBlocks);

    return resolvedParent;
  }

  /// Collect `tl:define` blocks from [root], depth-first.
  /// Returns a map of block name → element. Last wins for duplicate names.
  Map<String, Element> _collectBlocks(Element root) {
    final defineAttr = '${attrPrefix}define';
    final blocks = <String, Element>{};

    void walk(Element element) {
      final name = element.attributes[defineAttr];
      if (name != null) {
        blocks[name] = element;
        // Don't recurse into tl:define — nested tl:define inside is part
        // of the outer block's content, replaced as a whole.
        return;
      }
      for (final child in element.children) {
        walk(child);
      }
    }

    for (final child in root.children) {
      walk(child);
    }
    return blocks;
  }

  /// Replace parent block children with child override children.
  void _mergeBlocks(Document parentDoc, Map<String, Element> childBlocks) {
    if (childBlocks.isEmpty) return;

    final defineAttr = '${attrPrefix}define';

    void walk(Element element) {
      final name = element.attributes[defineAttr];
      if (name != null) {
        final override = childBlocks[name];
        if (override != null) {
          // Replace parent element's children with child block's children.
          // Parent element (tag, class, etc.) is preserved.
          element.nodes.clear();
          for (final child in override.nodes.toList()) {
            element.append(child.clone(true));
          }
        }
        // Don't recurse into tl:define — children are already replaced or kept.
        return;
      }
      for (final child in element.children) {
        walk(child);
      }
    }

    final root = parentDoc.documentElement;
    if (root != null) walk(root);
  }

  /// Strip all `tl:extends` and `tl:define` attributes from the document.
  void _stripInheritanceAttrs(Document doc) {
    final extendsAttr = '${attrPrefix}extends';
    final defineAttr = '${attrPrefix}define';

    void walk(Element element) {
      element.attributes.remove(extendsAttr);
      element.attributes.remove(defineAttr);
      for (final child in element.children) {
        walk(child);
      }
    }

    final root = doc.documentElement;
    if (root != null) walk(root);
  }

  /// Strip `tl:define` attributes only (for non-extends templates).
  void _stripDefineAttrs(Document doc) {
    final defineAttr = '${attrPrefix}define';

    void walk(Element element) {
      element.attributes.remove(defineAttr);
      for (final child in element.children) {
        walk(child);
      }
    }

    final root = doc.documentElement;
    if (root != null) walk(root);
  }

  /// Validate that `tl:extends` only appears on the root element.
  void _validateExtendsPlacement(Document doc) {
    final extendsAttr = '${attrPrefix}extends';
    final root = doc.documentElement;
    if (root == null) return;

    void walk(Element element) {
      for (final child in element.children) {
        if (child.attributes.containsKey(extendsAttr)) {
          throw TemplateException(
            'tl:extends must only appear on the root element, '
            'found on <${child.localName}>',
          );
        }
        walk(child);
      }
    }

    walk(root);
  }
}
