import 'package:matcher/matcher.dart';

import '_html_utils.dart';

/// Matches if rendered HTML contains element(s) matching the CSS [selector].
///
/// Optional parameters refine the match:
/// - [withText]: element's text content must contain this string
/// - [withAttribute]: the element must have this attribute
/// - [attributeValue]: combined with [withAttribute], the attribute must equal this value
/// - [count]: exactly this many elements must match
///
/// ```dart
/// expect(html, hasElement('h1', withText: 'Hello'));
/// expect(html, hasElement('.item', count: 3));
/// expect(html, hasElement('a[href="/about"]'));
/// expect(html, hasElement('input', withAttribute: 'required'));
/// expect(html, hasElement('input', withAttribute: 'type', attributeValue: 'email'));
/// ```
Matcher hasElement(String selector, {String? withText, String? withAttribute, String? attributeValue, int? count}) =>
    _HasElementMatcher(
      selector,
      withText: withText,
      withAttribute: withAttribute,
      attributeValue: attributeValue,
      count: count,
    );

final class _HasElementMatcher extends Matcher {
  final String _selector;
  final String? _withText;
  final String? _withAttribute;
  final String? _attributeValue;
  final int? _count;

  const _HasElementMatcher(
    this._selector, {
    String? withText,
    String? withAttribute,
    String? attributeValue,
    int? count,
  }) : _withText = withText,
       _withAttribute = withAttribute,
       _attributeValue = attributeValue,
       _count = count;

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is! String) {
      matchState[#mismatch] = 'was not a String';
      return false;
    }

    final doc = parseHtml(item);
    final allElements = doc.querySelectorAll(_selector);
    matchState[#selectorCount] = allElements.length;
    matchState[#foundTexts] = allElements.map((e) => e.text.trim()).toList();

    var elements = allElements;

    if (_withText != null) {
      elements = elements.where((e) => e.text.contains(_withText)).toList();
    }

    if (_withAttribute != null) {
      if (_attributeValue != null) {
        elements = elements.where((e) => e.attributes[_withAttribute] == _attributeValue).toList();
      } else {
        elements = elements.where((e) => e.attributes.containsKey(_withAttribute)).toList();
      }
    }

    matchState[#foundCount] = elements.length;

    if (_count != null) {
      return elements.length == _count;
    }
    return elements.isNotEmpty;
  }

  @override
  Description describe(Description description) {
    description.add('HTML containing <$_selector>');
    if (_withText != null) description.add(' with text "$_withText"');
    if (_withAttribute != null) {
      description.add(' with attribute "$_withAttribute"');
      if (_attributeValue != null) description.add('="$_attributeValue"');
    }
    if (_count != null) description.add(' (count: $_count)');
    return description;
  }

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) {
    final foundCount = matchState[#foundCount] as int? ?? 0;
    final selectorCount = matchState[#selectorCount] as int? ?? 0;
    final foundTexts = matchState[#foundTexts] as List<String>? ?? const <String>[];

    if (selectorCount == 0) {
      return mismatchDescription.add('found 0 elements matching \'$_selector\'');
    }

    if (_count != null && foundCount != _count) {
      return mismatchDescription.add('found $selectorCount element(s) matching \'$_selector\', expected $_count');
    }

    if (_withText != null && foundCount == 0) {
      return mismatchDescription.add(
        'found elements but none with text "$_withText": ${foundTexts.map((t) => '"$t"').join(', ')}',
      );
    }

    if (_withAttribute != null && foundCount == 0) {
      return mismatchDescription.add('found $selectorCount element(s) but none with attribute "$_withAttribute"');
    }

    return mismatchDescription.add('found $selectorCount element(s) matching \'$_selector\'');
  }
}
