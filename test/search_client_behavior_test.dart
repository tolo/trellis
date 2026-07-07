// Behavioral test for the vendored client-side search script (S09):
// `themes/arbor/static/js/search.js`.
//
// search_client_test.dart is a lexical/structural guard (substring checks over
// the source). This test exercises the script's actual runtime behavior via a
// minimal DOM-harness (test/search_client_harness.js) run under system `node`
// — no npm, no package.json, no JS build step; node is only a test-time
// interpreter for a committed .js fixture, not part of the site build
// pipeline. Per the S09 FIS Testing Strategy, the fetch-failure and no-match
// paths are load-bearing negative cases and need an explicit assertion, not
// just a happy-path check.
//
// If system `node` is unavailable, the test is skipped with a clear reason
// rather than failing the suite — CI runners (GitHub Actions ubuntu-latest)
// ship node, so in practice this runs, not skips.

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('search.js behavioral DOM-harness (S09)', () {
    late bool nodeAvailable;

    setUpAll(() async {
      try {
        final result = await Process.run('node', ['--version']);
        nodeAvailable = result.exitCode == 0;
      } on ProcessException {
        nodeAvailable = false;
      }
    });

    test('fetch-failure, no-match, empty-query, and happy-path scenarios all hold', () async {
      if (!nodeAvailable) {
        markTestSkipped('system node not found — behavioral DOM-harness skipped');
        return;
      }

      final harnessPath = p.join(Directory.current.path, 'test', 'search_client_harness.js');
      final scriptPath = p.join(Directory.current.path, 'themes', 'arbor', 'static', 'js', 'search.js');
      expect(File(harnessPath).existsSync(), isTrue, reason: 'harness must exist');
      expect(File(scriptPath).existsSync(), isTrue, reason: 'vendored search client must exist');

      final result = await Process.run('node', [harnessPath, scriptPath]);
      expect(result.exitCode, 0, reason: 'harness must run cleanly; stderr: ${result.stderr}');

      final scenarios = jsonDecode(result.stdout as String) as Map<String, dynamic>;

      // S04: index-fetch rejection (network error) degrades to disabled/unavailable.
      final fetchRejects = scenarios['fetchRejects'] as Map<String, dynamic>;
      expect(fetchRejects['inputDisabled'], isTrue, reason: 'input must be disabled on fetch rejection');
      expect(fetchRejects['inputAriaDisabled'], isTrue, reason: 'aria-disabled must be set on fetch rejection');
      expect(fetchRejects['shellUnavailable'], isTrue, reason: 'shell must get search-unavailable on fetch rejection');

      // S04: non-OK response (e.g. 404) is treated the same as a hard failure.
      final fetchNonOk = scenarios['fetchNonOk'] as Map<String, dynamic>;
      expect(fetchNonOk['inputDisabled'], isTrue, reason: 'input must be disabled on non-OK response');
      expect(fetchNonOk['inputAriaDisabled'], isTrue, reason: 'aria-disabled must be set on non-OK response');
      expect(fetchNonOk['shellUnavailable'], isTrue, reason: 'shell must get search-unavailable on non-OK response');

      // S02: a query with no matches renders the friendly empty-state element.
      final noMatch = scenarios['noMatch'] as Map<String, dynamic>;
      expect(noMatch['inputEnabled'], isTrue, reason: 'input must be enabled after a successful load');
      expect(noMatch['resultsHidden'], isFalse, reason: 'results container must be shown for a no-match query');
      expect(noMatch['hasEmptyState'], isTrue, reason: 'a search-empty element must be rendered');
      expect(noMatch['emptyStateText'], equals('No results found.'));

      // S03: empty/whitespace query resets to idle — cleared, not hidden-with-stale-content.
      final emptyQuery = scenarios['emptyQuery'] as Map<String, dynamic>;
      expect(emptyQuery['resultsHidden'], isTrue, reason: 'idle state must hide the results container');
      expect(emptyQuery['resultsChildCount'], equals(0), reason: 'idle state must not retain stale result nodes');

      // S01: a matching query renders a result link using the entry url + title via textContent.
      final happyPath = scenarios['happyPath'] as Map<String, dynamic>;
      expect(happyPath['resultsHidden'], isFalse);
      expect(happyPath['resultCount'], equals(1));
      expect(happyPath['href'], equals('/guide/intro/'));
      expect(happyPath['titleText'], equals('Getting Started'));
    });
  });
}
