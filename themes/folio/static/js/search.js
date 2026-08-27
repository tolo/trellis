/*
 * Arbor Docs Theme — client-side search (S09).
 *
 * A self-contained, dependency-free search client over the site's generated
 * `search-index.json`. No npm, no build step, no external host — this file is
 * vendored (committed) and served same-origin; see VENDORED.md.
 *
 * Design constraints:
 *   - Progressive enhancement. Docs are fully readable and navigable with this
 *     script absent or disabled. The `.search-shell` ships `hidden` and the
 *     <input> ships `disabled` in the static HTML; both are lifted only after
 *     the index has loaded successfully. A page where this script never ran, or
 *     where the index fetch failed, therefore shows no dead search control.
 *   - Same-origin only. The index URL is not hardcoded here (the static file
 *     cannot interpolate the site's pathPrefix). It is read from the shell's
 *     `data-search-index` attribute, which the layout computes with pathPrefix.
 *   - Result links use each entry's `url` verbatim (already pathPrefix-prefixed
 *     by the generator) — never re-prefixed here.
 *
 * Index schema (fixed; array of page objects): each entry always has `url`;
 * the configured fields include `title`, `summary`, `content`, `tags`. Absent
 * keys are tolerated.
 *
 * Shell hooks (from the S04 layout):
 *   [data-arbor-search]          the search <input> (ships disabled)
 *   [data-arbor-search-results]  the results <ul> (ships hidden)
 *   [data-search-index]          on the .search-shell container (ships hidden): index URL
 */
(function () {
  'use strict';

  var MAX_RESULTS = 20;
  var SNIPPET_LENGTH = 140;

  var input = document.querySelector('[data-arbor-search]');
  var results = document.querySelector('[data-arbor-search-results]');
  if (!input || !results) return;

  var shell = input.closest('.search-shell') || input.parentNode;
  var indexUrl = shell && shell.getAttribute('data-search-index');
  if (!indexUrl) {
    // No index URL wired — treat as unavailable and leave the control inert.
    disableSearch();
    return;
  }

  // Keep the control hidden and inert. Called on any failure so the search box is
  // never revealed as a broken, interactive-but-nonfunctional input.
  function disableSearch() {
    input.disabled = true;
    input.setAttribute('aria-disabled', 'true');
    if (shell) shell.hidden = true;
    clearResults();
  }

  function clearResults() {
    results.textContent = '';
    results.hidden = true;
  }

  // Fetch the index. Any failure (missing file, network error, non-OK status,
  // malformed JSON, non-array payload) degrades to a hidden/disabled control
  // with no uncaught error surfaced to the user.
  fetch(indexUrl, { credentials: 'same-origin' })
    .then(function (response) {
      if (!response.ok) throw new Error('search index fetch failed: ' + response.status);
      return response.json();
    })
    .then(function (data) {
      if (!Array.isArray(data)) throw new Error('search index is not an array');
      activate(data);
    })
    .catch(function () {
      // Swallow — search is a progressive enhancement; the page stays usable.
      disableSearch();
    });

  function activate(entries) {
    if (shell) shell.hidden = false;
    input.disabled = false;
    input.removeAttribute('aria-disabled');
    input.addEventListener('input', function () {
      render(query(entries, input.value));
    });
  }

  // Case-insensitive substring match over title, summary, content, and tags.
  // Empty/whitespace query returns null (idle — render() shows no list).
  function query(entries, raw) {
    var q = (raw || '').trim().toLowerCase();
    if (q === '') return null;

    var terms = q.split(/\s+/);
    var matches = [];
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i];
      var hay = haystack(entry);
      if (allTermsPresent(hay, terms)) {
        matches.push(entry);
        if (matches.length >= MAX_RESULTS) break;
      }
    }
    return matches;
  }

  function haystack(entry) {
    var parts = [];
    if (entry.title) parts.push(String(entry.title));
    if (entry.summary) parts.push(String(entry.summary));
    if (entry.content) parts.push(String(entry.content));
    if (Array.isArray(entry.tags)) parts.push(entry.tags.join(' '));
    return parts.join(' ').toLowerCase();
  }

  function allTermsPresent(hay, terms) {
    for (var i = 0; i < terms.length; i++) {
      if (hay.indexOf(terms[i]) === -1) return false;
    }
    return true;
  }

  // Render state:
  //   null      -> idle (empty query): no list shown.
  //   []        -> friendly empty state (no matches).
  //   [entries] -> result list (title + snippet, linking to entry.url).
  function render(matches) {
    if (matches === null) {
      clearResults();
      return;
    }

    results.textContent = '';
    results.hidden = false;

    if (matches.length === 0) {
      var empty = document.createElement('li');
      empty.className = 'search-empty';
      empty.setAttribute('aria-live', 'polite');
      empty.textContent = 'No results found.';
      results.appendChild(empty);
      return;
    }

    for (var i = 0; i < matches.length; i++) {
      results.appendChild(resultItem(matches[i]));
    }
  }

  function resultItem(entry) {
    var li = document.createElement('li');
    li.className = 'search-result';

    var link = document.createElement('a');
    link.className = 'search-result-link';
    // entry.url is already pathPrefix-prefixed by the generator — use verbatim.
    link.setAttribute('href', String(entry.url || ''));

    var title = document.createElement('span');
    title.className = 'search-result-title';
    title.textContent = entry.title ? String(entry.title) : String(entry.url || '');
    link.appendChild(title);

    var snippetText = snippet(entry);
    if (snippetText) {
      var snip = document.createElement('span');
      snip.className = 'search-result-snippet';
      snip.textContent = snippetText;
      link.appendChild(snip);
    }

    li.appendChild(link);
    return li;
  }

  function snippet(entry) {
    var source = entry.summary || entry.content || '';
    source = String(source).trim();
    if (source.length <= SNIPPET_LENGTH) return source;
    return source.slice(0, SNIPPET_LENGTH).replace(/\s+\S*$/, '') + '…';
  }
})();
