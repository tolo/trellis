/// The client is emitted next to the configured JSON index at build time.
const searchClientFilename = 'trellis-search.js';

/// Same-origin, progressively enhanced search over the generated JSON index.
const searchClient = r'''
(() => {
  'use strict';

  for (const shell of document.querySelectorAll('[data-trellis-search]')) {
    const input = shell.querySelector('[role="combobox"]');
    const value = shell.querySelector('input[type="hidden"]');
    const template = shell.querySelector('template[data-trellis-search-results]');
    if (!input || !value || !template) continue;

    const indexUrl = shell.getAttribute('data-search-index');
    const disableSearch = () => {
      shell.hidden = true;
      input.disabled = true;
      input.setAttribute('aria-disabled', 'true');
    };
    if (!indexUrl) {
      disableSearch();
      continue;
    }

    fetch(indexUrl, { mode: 'same-origin' })
      .then(response => {
        if (!response.ok) throw new Error('Search index unavailable');
        return response.json();
      })
      .then(async data => {
        if (!Array.isArray(data)) throw new Error('Invalid search index');

        // Either deferred script can execute first. An undefined control
        // must stay hidden until it can handle a reader's first input.
        const pending = input.closest(':not(:defined)');
        if (pending) await customElements.whenDefined(pending.localName);

        const entries = data.filter(entry => typeof entry?.url === 'string' && entry.url).map(entry => ({
          url: entry.url,
          title: entry.title || entry.url,
          text: [entry.title, entry.summary, entry.content, Array.isArray(entry.tags) ? entry.tags.join(' ') : '']
            .join(' ').toLowerCase(),
        }));
        const listId = input.getAttribute('aria-controls');
        input.addEventListener('input', () => {
          const query = input.value.trim().toLowerCase();
          const terms = query.split(/\s+/);
          const results = template.content.firstElementChild.cloneNode(true);
          const list = results.querySelector('[role="listbox"]');
          const sample = list.querySelector('[role="option"]');
          sample.remove();
          if (query) {
            for (const entry of entries) {
              if (!terms.every(term => entry.text.includes(term))) continue;
              const option = sample.cloneNode(true);
              option.id = listId + '-option-' + list.children.length;
              option.dataset.value = entry.url;
              option.textContent = entry.title;
              list.append(option);
              if (list.children.length === 20) break;
            }
          }
          // The combobox observes replacement of the results wrapper. That
          // makes its own input-listener order irrelevant to the final state.
          document.getElementById(listId).parentElement.replaceWith(results);
        });

        // Bubble to the shell after the control has stored its selected value.
        const navigate = () => { if (value.value) location.assign(value.value); };
        shell.addEventListener('keydown', event => {
          if (event.target === input && event.key === 'Enter' && event.defaultPrevented) navigate();
        });
        shell.addEventListener('click', event => {
          if (event.target.closest('[role="option"]')) navigate();
        });

        input.disabled = false;
        input.removeAttribute('aria-disabled');
        shell.hidden = false;
      })
      .catch(disableSearch);
  }
})();
''';
