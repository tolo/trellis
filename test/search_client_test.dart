import 'dart:io';

import 'package:test/test.dart';

/// Contract ("smoke") test for the vendored client-side search script (S09):
/// `themes/arbor/static/js/search.js`.
///
/// Behavioral coverage (fetch-failure, no-match, empty-query, and happy-path
/// scenarios, executed against a DOM-harness under system `node`) lives in
/// `search_client_behavior_test.dart`. This file remains a cheap lexical guard
/// on top of that: it fails if a defensive branch the S09 FIS requires is
/// deleted from the source, without needing to run the script.
void main() {
  final file = File('themes/arbor/static/js/search.js');
  final source = file.existsSync() ? file.readAsStringSync() : '';

  setUpAll(() {
    expect(file.existsSync(), isTrue, reason: 'vendored search client must exist');
  });

  group('search.js progressive-enhancement contract (S09)', () {
    test('index URL is read from data-search-index, not hardcoded (pathPrefix-safe)', () {
      expect(source, contains("getAttribute('data-search-index')"));
      // The fetch must use the attribute-derived variable, never a literal path.
      expect(source, contains('fetch(indexUrl'));
    });

    test('any index-fetch failure disables the control (never a broken affordance)', () {
      expect(source, contains('.catch('), reason: 'fetch rejection must be handled');
      expect(source, contains('function disableSearch'));
      expect(source, contains('input.disabled = true'), reason: 'failure must disable the input');
      expect(source, contains('response.ok'), reason: 'a non-OK response is a failure');
      expect(source, contains('Array.isArray'), reason: 'a non-array payload is a failure');
    });

    test('an empty/whitespace query is idle — it does not dump the whole index', () {
      // query() trims and returns null for an empty query; render(null) clears.
      expect(source, contains("q === ''"));
      expect(source, contains('return null'));
    });

    test('a no-match query renders a friendly empty state', () {
      expect(source, contains('search-empty'));
      expect(source, contains('No results found'));
    });

    test('the input is enabled only after a successful load', () {
      expect(source, contains('input.disabled = false'));
    });

    test('result links use each entry url verbatim (already pathPrefix-prefixed)', () {
      expect(source, contains('entry.url'));
      expect(source, contains("setAttribute('href'"));
    });

    test('no external host / CDN is referenced', () {
      expect(source.toLowerCase(), isNot(matches(RegExp(r'cdnjs|unpkg|jsdelivr|googleapis|https?://'))));
    });
  });
}
