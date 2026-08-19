(() => {
  'use strict';

  const button = document.querySelector('[data-folio-skin-toggle]');
  if (!button) return;

  const media = window.matchMedia('(prefers-color-scheme: dark)');
  const stored = () => {
    try { return localStorage.getItem('folio-skin') || ''; } catch (_) { return ''; }
  };
  const apply = (skin) => {
    document.documentElement.dataset.skin = skin;
    button.setAttribute('aria-pressed', String(skin === 'dark'));
  };

  apply(stored());
  button.addEventListener('click', () => {
    const current = document.documentElement.dataset.skin || (media.matches ? 'dark' : 'light');
    const next = current === 'dark' ? 'light' : 'dark';
    apply(next);
    try { localStorage.setItem('folio-skin', next); } catch (_) {}
  });
})();
