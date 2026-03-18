import 'package:matcher/matcher.dart';

import '_html_utils.dart';

/// Matches if an element matching [selector] has [attribute] with [value].
///
/// [value] can be a String for exact match, or a Matcher for flexible matching.
///
/// ```dart
/// expect(html, hasAttribute('a', 'href', '/home'));
/// expect(html, hasAttribute('img', 'alt', contains('photo')));
/// ```
Matcher hasAttribute(String selector, String attribute, dynamic value) =>
    _HasAttributeMatcher(selector, attribute, value);

final class _HasAttributeMatcher extends Matcher {
  final String _selector;
  final String _attribute;
  final dynamic _value;

  const _HasAttributeMatcher(this._selector, this._attribute, this._value);

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is! String) {
      matchState[#mismatch] = 'was not a String';
      return false;
    }

    final doc = parseHtml(item);
    final element = doc.querySelector(_selector);

    if (element == null) {
      matchState[#mismatch] = 'no element matching \'$_selector\' found';
      return false;
    }

    if (!element.attributes.containsKey(_attribute)) {
      matchState[#mismatch] = 'element has no attribute "$_attribute"';
      return false;
    }

    final actualValue = element.attributes[_attribute];
    matchState[#actualValue] = actualValue;

    if (_value is Matcher) {
      return _value.matches(actualValue, matchState);
    }
    return actualValue == _value;
  }

  @override
  Description describe(Description description) =>
      description.add('HTML element "$_selector" with attribute "$_attribute" = $_value');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) {
    final mismatch = matchState[#mismatch] as String?;
    if (mismatch != null) {
      return mismatchDescription.add(mismatch);
    }
    final actualValue = matchState[#actualValue];
    return mismatchDescription.add('attribute "$_attribute" was "$actualValue"');
  }
}
