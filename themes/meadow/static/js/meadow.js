(function () {
  'use strict';

  var root = document.documentElement;
  var skinButton = document.querySelector('[data-meadow-skin-toggle]');
  var media = window.matchMedia ? window.matchMedia('(prefers-color-scheme: dark)') : null;

  function savedSkin() {
    try {
      var saved = localStorage.getItem('meadow-skin');
      return saved === 'dark' || saved === 'light' ? saved : '';
    } catch (_) {
      return '';
    }
  }

  // The reader's own choice, kept in memory so a denied localStorage write does not strand the
  // toggle; '' means "follow the OS", the state the CSS prefers-color-scheme fallback needs.
  var explicitSkin = savedSkin();

  function effectiveSkin() {
    return explicitSkin || (media && media.matches ? 'dark' : 'light');
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
    // The pre-paint applier in <head> is an inline script, so a page served under a strict
    // script-src never runs it. Apply the saved skin here too: without it the page renders by
    // prefers-color-scheme while the button reports the saved value and toggles from it.
    root.dataset.skin = explicitSkin;
    syncSkinButton();
    skinButton.addEventListener('click', function () {
      explicitSkin = effectiveSkin() === 'dark' ? 'light' : 'dark';
      try {
        localStorage.setItem('meadow-skin', explicitSkin);
      } catch (_) {}
      root.dataset.skin = explicitSkin;
      syncSkinButton();
    });
    if (media && media.addEventListener) media.addEventListener('change', syncSkinButton);
  }

  // A bare <details> overlay stays open on Escape and on a click elsewhere on the page, and its
  // summary keeps announcing "Open navigation menu" while it is open.
  var mobileMenu = document.querySelector('.mobile-menu');
  var mobileSummary = mobileMenu && mobileMenu.querySelector('summary');
  if (mobileMenu && mobileSummary) {
    mobileMenu.addEventListener('toggle', function () {
      mobileSummary.setAttribute('aria-label', mobileMenu.open ? 'Close navigation menu' : 'Open navigation menu');
    });
    document.addEventListener('keydown', function (event) {
      if (event.key !== 'Escape' || !mobileMenu.open) return;
      mobileMenu.open = false;
      mobileSummary.focus();
    });
    document.addEventListener('pointerdown', function (event) {
      if (mobileMenu.open && !mobileMenu.contains(event.target)) mobileMenu.open = false;
    });
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
