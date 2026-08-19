(() => {
  'use strict';

  const button = document.querySelector('[data-folio-skin-toggle]');
  if (!button) return;

  const media = window.matchMedia('(prefers-color-scheme: dark)');
  const stored = () => {
    try { return localStorage.getItem('folio-skin') || ''; } catch (_) { return ''; }
  };
  let explicit = stored();
  const apply = (skin) => {
    document.documentElement.dataset.skin = skin;
    button.setAttribute('aria-pressed', String(skin === 'dark'));
  };
  const sync = () => {
    document.documentElement.dataset.skin = explicit;
    button.setAttribute('aria-pressed', String((explicit || (media.matches ? 'dark' : 'light')) === 'dark'));
  };

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
