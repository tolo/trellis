(function () {
  'use strict';

  var root = document.documentElement;
  var skinButton = document.querySelector('[data-meadow-skin-toggle]');
  var media = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;

  function savedSkin() {
    try {
      return localStorage.getItem('meadow-skin') || '';
    } catch (_) {
      return '';
    }
  }

  function effectiveSkin() {
    return savedSkin() || (media && media.matches ? 'dark' : 'light');
  }

  function syncSkinButton() {
    if (!skinButton) return;
    var dark = effectiveSkin() === 'dark';
    skinButton.setAttribute('aria-pressed', String(dark));
    skinButton.setAttribute('aria-label', dark ? 'Switch to light theme' : 'Switch to dark theme');
    skinButton.textContent = dark ? '☀' : '☾';
  }

  if (skinButton) {
    skinButton.hidden = false;
    syncSkinButton();
    skinButton.addEventListener('click', function () {
      var next = effectiveSkin() === 'dark' ? 'light' : 'dark';
      try {
        localStorage.setItem('meadow-skin', next);
      } catch (_) {}
      root.dataset.skin = next;
      syncSkinButton();
    });
    if (media && media.addEventListener) media.addEventListener('change', syncSkinButton);
  }

  var copyButton = document.querySelector('[data-copy]');
  if (!copyButton || !navigator.clipboard || !window.isSecureContext) return;
  copyButton.hidden = false;
  copyButton.addEventListener('click', function () {
    var command = document.getElementById('install-command');
    if (!command) return;
    navigator.clipboard.writeText(command.textContent).then(function () {
      copyButton.textContent = 'Copied';
      window.setTimeout(function () { copyButton.textContent = 'Copy'; }, 1400);
    }).catch(function () {});
  });
})();
