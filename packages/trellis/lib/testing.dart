/// Testing utilities for Trellis templates.
///
/// Provides a test engine factory, CSS-selector-based HTML matchers,
/// snapshot golden file testing, and fragment isolation helpers.
///
/// ```dart
/// import 'package:test/test.dart';
/// import 'package:trellis/testing.dart';
/// import 'package:trellis/trellis.dart';
///
/// void main() {
///   final engine = testEngine(templates: {
///     'page': '<h1 tl:text="${title}">x</h1>',
///   });
///
///   test('renders title', () {
///     final html = engine.render(
///       engine.loader.loadSync('page')!,
///       {'title': 'Hello'},
///     );
///     expect(html, hasElement('h1', withText: 'Hello'));
///   });
/// }
/// ```
library;

export 'src/testing/fragment_helpers.dart' show testFragment, testFragmentFile;
export 'src/testing/matchers/element_count_matcher.dart' show elementCount;
export 'src/testing/matchers/has_attribute_matcher.dart' show hasAttribute;
export 'src/testing/matchers/has_element_matcher.dart' show hasElement;
export 'src/testing/matchers/has_no_element_matcher.dart' show hasNoElement;
export 'src/testing/matchers/has_text_content_matcher.dart' show hasTextContent;
export 'src/testing/snapshot/html_normalizer.dart' show normalizeHtml;
export 'src/testing/snapshot/snapshot_testing.dart'
    show compareOrCreateGolden, expectSnapshot, expectSnapshotFromSource, updateGoldens;
export 'src/testing/test_engine.dart' show testEngine;
export 'src/testing/valid_template_matcher.dart' show isValidTemplate;
