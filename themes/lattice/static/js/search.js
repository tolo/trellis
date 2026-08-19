(function () {
  'use strict';
  var input = document.querySelector('[data-lattice-search]');
  var results = document.querySelector('[data-lattice-search-results]');
  if (!input || !results) return;
  var shell = input.closest('.search-shell');
  var indexUrl = shell && shell.dataset.searchIndex;
  function unavailable() {
    input.disabled = true;
    shell.classList.add('search-unavailable');
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
      .slice(0, 20);
    if (matches.length === 0) {
      var empty = document.createElement('li');
      empty.textContent = 'No results found.';
      results.appendChild(empty);
      return;
    }
    matches.forEach(function (entry) {
      var item = document.createElement('li');
      var link = document.createElement('a');
      link.href = entry.url;
      link.textContent = entry.title || entry.url;
      item.appendChild(link);
      results.appendChild(item);
    });
  }
  fetch(indexUrl, { credentials: 'same-origin' })
    .then(function (response) {
      if (!response.ok) throw new Error('search unavailable');
      return response.json();
    })
    .then(function (entries) {
      if (!Array.isArray(entries)) throw new Error('invalid search index');
      input.disabled = false;
      input.addEventListener('input', function () {
        render(entries, input.value);
      });
    })
    .catch(unavailable);
})();
