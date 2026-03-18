import 'package:matcher/matcher.dart';

import '_html_utils.dart';

/// Matches if the rendered HTML's full text content (tags stripped) contains [text].
///
/// ```dart
/// expect(html, hasTextContent('Hello World'));
/// ```
Matcher hasTextContent(String text) => _HasTextContentMatcher(text);

final class _HasTextContentMatcher extends Matcher {
  final String _text;

  const _HasTextContentMatcher(this._text);

  @override
  bool matches(Object? item, Map<Object?, Object?> matchState) {
    if (item is! String) {
      matchState[#mismatch] = 'was not a String';
      return false;
    }
    final actualText = parseHtml(item).text ?? '';
    matchState[#actualText] = actualText;
    return actualText.contains(_text);
  }

  @override
  Description describe(Description description) => description.add('HTML with text content containing "$_text"');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map<Object?, Object?> matchState,
    bool verbose,
  ) {
    final actualText = matchState[#actualText] as String? ?? '';
    const maxLength = 200;
    final truncated = actualText.length > maxLength ? '${actualText.substring(0, maxLength)}...' : actualText;
    return mismatchDescription.add('text content was: "$truncated"');
  }
}
