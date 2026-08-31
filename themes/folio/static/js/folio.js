(() => {
  'use strict';

  const button = document.querySelector('[data-folio-skin-toggle]');
  if (!button) return;

  const media = window.matchMedia('(prefers-color-scheme: dark)');
  const stored = () => {
    try {
      const saved = localStorage.getItem('folio-skin');
      return saved === 'dark' || saved === 'light' ? saved : '';
    } catch (_) { return ''; }
  };
  let explicit = stored();
  // The control names the edition currently in force, as the masthead badge does in
  // the design; the accessible name stays the action (aria-label on the element).
  const mark = (dark) => {
    button.setAttribute('aria-pressed', String(dark));
    button.textContent = dark ? 'Night edition' : 'Light folio';
  };
  const apply = (skin) => {
    document.documentElement.dataset.skin = skin;
    mark(skin === 'dark');
  };
  const sync = () => {
    document.documentElement.dataset.skin = explicit;
    mark((explicit || (media.matches ? 'dark' : 'light')) === 'dark');
  };

  // Ships hidden: with no JavaScript the button could not change anything.
  button.hidden = false;
  sync();
  button.addEventListener('click', () => {
    const current = explicit || (media.matches ? 'dark' : 'light');
    const next = current === 'dark' ? 'light' : 'dark';
    explicit = next;
    apply(next);
    try { localStorage.setItem('folio-skin', next); } catch (_) {}
  });
  media.addEventListener('change', () => {
    if (!explicit) sync();
  });
})();
