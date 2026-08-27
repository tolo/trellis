/*
 * Lattice — client-side search over the site's generated `search-index.json`.
 *
 * Vendored (committed) and served same-origin; see VENDORED.md. No npm, no build step.
 *
 * Progressive enhancement: the `.search-shell` and the <input> ship `hidden`/`disabled` in the
 * layout and are lifted only once the index has loaded. A page where this script never ran —
 * JavaScript off, blocked, or a failed fetch — shows no search control at all, rather than a
 * permanently disabled input the visitor cannot use.
 *
 * The index URL is read from the shell's `data-search-index` attribute: a static file cannot
 * interpolate the site's pathPrefix. Each entry's `url` is already prefixed by the generator,
 * so it is used verbatim.
 *
 * Every element built here carries a class the stylesheet declares — result markup and CSS are
 * one contract, and `test/lattice_theme_contract_test.dart` derives the class set from this file.
 */
(function () {
  'use strict';

  var MAX_RESULTS = 20;
  var SNIPPET_LENGTH = 140;

  var input = document.querySelector('[data-lattice-search]');
  var results = document.querySelector('[data-lattice-search-results]');
  if (!input || !results) return;

  var shell = input.closest('.search-shell');
  var indexUrl = shell && shell.getAttribute('data-search-index');

  function unavailable() {
    input.disabled = true;
    input.setAttribute('aria-disabled', 'true');
    if (shell) shell.hidden = true;
    results.textContent = '';
    results.hidden = true;
  }

  if (!indexUrl) {
    unavailable();
    return;
  }

  function render(entries, query) {
    results.textContent = '';
    var needle = query.trim().toLowerCase();
    results.hidden = needle === '';
    if (needle === '') return;
    var matches = entries
      .filter(function (entry) {
        return [entry.title, entry.summary, entry.content].join(' ').toLowerCase().indexOf(needle) !== -1;
      })
      .slice(0, MAX_RESULTS);
    if (matches.length === 0) {
      var empty = document.createElement('li');
      empty.className = 'search-empty';
      empty.textContent = 'No results found.';
      results.appendChild(empty);
      return;
    }
    matches.forEach(function (entry) {
      results.appendChild(resultItem(entry));
    });
  }

  function resultItem(entry) {
    var item = document.createElement('li');
    item.className = 'search-result';

    var link = document.createElement('a');
    link.className = 'search-result-link';
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

    item.appendChild(link);
    return item;
  }

  function snippet(entry) {
    var source = String(entry.summary || entry.content || '').trim();
    if (source.length <= SNIPPET_LENGTH) return source;
    return source.slice(0, SNIPPET_LENGTH).replace(/\s+\S*$/, '') + '…';
  }

  fetch(indexUrl, { credentials: 'same-origin' })
    .then(function (response) {
      if (!response.ok) throw new Error('search unavailable');
      return response.json();
    })
    .then(function (entries) {
      if (!Array.isArray(entries)) throw new Error('invalid search index');
      shell.hidden = false;
      input.disabled = false;
      input.removeAttribute('aria-disabled');
      input.addEventListener('input', function () {
        render(entries, input.value);
      });
    })
    .catch(unavailable);
})();
