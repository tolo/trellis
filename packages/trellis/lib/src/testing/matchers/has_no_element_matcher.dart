import 'package:matcher/matcher.dart';

import '_html_utils.dart';

/// Matches if rendered HTML does NOT contain any element matching [selector].
///
/// ```dart
/// expect(html, hasNoElement('.error'));
/// expect(html, hasNoElement('div.warning'));
/// ```
Matcher hasNoElement(String selector) => _HasNoElementMatcher(selector);

final class _HasNoElementMatcher extends Matcher {
  final String _selector;

  const _HasNoElementMatcher(this._selector);

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is! String) {
      matchState[#mismatch] = 'was not a String';
      return false;
    }
    final elements = parseHtml(item).querySelectorAll(_selector);
    matchState[#foundCount] = elements.length;
    return elements.isEmpty;
  }

  @override
  Description describe(Description description) => description.add('HTML not containing <$_selector>');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) {
    final foundCount = matchState[#foundCount] as int? ?? 0;
    return mismatchDescription.add('found $foundCount element(s) matching \'$_selector\'');
  }
}
