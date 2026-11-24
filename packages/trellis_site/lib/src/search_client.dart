/// The client is emitted next to the configured JSON index at build time.
const searchClientFilename = 'trellis-search.js';

/// Same-origin, progressively enhanced search over the generated JSON index.
const searchClient = r'''
(() => {
  'use strict';

  const initialized = new WeakSet();
  for (const shell of document.querySelectorAll('[data-trellis-search]')) connect(shell);
  document.addEventListener('htmx:load', ({ target }) => {
    if (target.matches?.('[data-trellis-search]')) connect(target);
    for (const shell of target.querySelectorAll?.('[data-trellis-search]') ?? []) connect(shell);
  });

  async function connect(shell) {
    if (initialized.has(shell)) return;
    const input = shell.querySelector('[role="combobox"]');
    const value = shell.querySelector('input[type="hidden"]');
    const template = shell.querySelector('template[data-trellis-search-results]');
    if (!input || !value || !template) return;
    initialized.add(shell);

    const palette = shell.querySelector('dialog[data-command-palette]');
    const status = palette?.querySelector('[data-command-status]');
    const describeSearch = (text) => {
      status.textContent = text;
      status.hidden = !text;
      if (text) input.setAttribute('aria-describedby', status.id);
      else input.removeAttribute('aria-describedby');
    };
    if (palette) {
      // Either deferred script can arrive first. An unupgraded trigger cannot open its modal.
      await Promise.all([customElements.whenDefined('tl-dialog'), customElements.whenDefined('tl-combobox')]);
      if (!shell.isConnected) return;
      input.removeAttribute('data-combobox-filter');
      input.readOnly = true;
      input.setAttribute('aria-busy', 'true');
      describeSearch('Loading search…');
      shell.removeAttribute('data-palette-inactive');
      palette.previousElementSibling.querySelector('button[hidden]')?.removeAttribute('hidden');
    }

    const disableSearch = () => {
      if (palette) {
        input.removeAttribute('aria-busy');
        describeSearch('Search unavailable');
      } else {
        shell.hidden = true;
        input.disabled = true;
        input.setAttribute('aria-disabled', 'true');
      }
    };
    const indexUrl = shell.getAttribute('data-search-index');
    if (!indexUrl) return disableSearch();

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

        const validUrl = entry => {
          if (typeof entry?.url !== 'string' || !entry.url) return false;
          if (!palette) return true;
          try { return new URL(entry.url, location.href).origin === location.origin; }
          catch { return false; }
        };
        const entries = data.filter(validUrl).map(entry => ({
          url: entry.url,
          title: entry.title || entry.url,
          text: [entry.title, entry.summary, entry.content, Array.isArray(entry.tags) ? entry.tags.join(' ') : '']
            .join(' ').toLowerCase(),
        }));
        if (!shell.isConnected) return;
        if (palette && !entries.length) throw new Error('Invalid search index');

        const listId = input.getAttribute('aria-controls');
        const updateResults = () => {
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
          shell.querySelector('[role="listbox"]').parentElement.replaceWith(results);
        };
        input.addEventListener('input', updateResults);
        if (input.value) updateResults();

        // Bubble to the shell after the control has stored its selected value.
        const navigate = () => { if (value.value) location.assign(value.value); };
        if (palette) {
          shell.addEventListener('tl-select', event => {
            if (palette.contains(event.target)) navigate();
          });
        } else {
          shell.addEventListener('keydown', event => {
            if (event.target === input && event.key === 'Enter' && event.defaultPrevented) navigate();
          });
          shell.addEventListener('click', event => {
            if (event.target.closest('[role="option"]')) navigate();
          });
        }

        if (palette) {
          input.readOnly = false;
          input.removeAttribute('aria-busy');
          describeSearch('');
        }
        input.disabled = false;
        input.removeAttribute('aria-disabled');
        shell.hidden = false;
      })
      .catch(disableSearch);
  }
})();
''';
