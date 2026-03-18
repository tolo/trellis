import 'package:matcher/matcher.dart';

import '_html_utils.dart';

/// Matches if exactly [count] elements match [selector] in the rendered HTML.
///
/// ```dart
/// expect(html, elementCount('li', 3));
/// expect(html, elementCount('.card', 0));
/// ```
Matcher elementCount(String selector, int count) => _ElementCountMatcher(selector, count);

final class _ElementCountMatcher extends Matcher {
  final String _selector;
  final int _count;

  const _ElementCountMatcher(this._selector, this._count);

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is! String) {
      matchState[#mismatch] = 'was not a String';
      return false;
    }
    final actual = parseHtml(item).querySelectorAll(_selector).length;
    matchState[#actual] = actual;
    return actual == _count;
  }

  @override
  Description describe(Description description) =>
      description.add('HTML containing exactly $_count <$_selector> element(s)');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) {
    final actual = matchState[#actual] as int? ?? 0;
    return mismatchDescription.add('found $actual element(s) matching \'$_selector\'');
  }
}
