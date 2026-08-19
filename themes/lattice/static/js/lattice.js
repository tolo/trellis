(function () {
  'use strict';

  var reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  var root = document.documentElement;
  var themeToggle = document.querySelector('[data-lattice-theme-toggle]');

  function setTheme(theme, persist) {
    root.dataset.theme = theme;
    if (themeToggle)
      themeToggle.setAttribute('aria-label', theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode');
    var screenshots = document.querySelectorAll('.theme-card img[data-light][data-dark]');
    for (var i = 0; i < screenshots.length; i++) screenshots[i].src = screenshots[i].dataset[theme];
    if (persist) {
      try {
        window.localStorage.setItem('trellis-theme', theme);
      } catch (_) {}
    }
  }

  if (themeToggle) {
    setTheme(root.dataset.theme === 'dark' ? 'dark' : 'light', false);
    themeToggle.addEventListener('click', function () {
      setTheme(root.dataset.theme === 'dark' ? 'light' : 'dark', true);
    });
  }

  var headline = document.querySelector('[data-headline]');
  if (headline) {
    var entries = headline.querySelectorAll('.headline-entry');
    var headlineIndex = 0;
    var paused = false;
    function showHeadline(index) {
      headline.textContent = '';
      var entry = entries[index];
      if (!entry) return;
      headline.appendChild(document.createTextNode(entry.dataset.prefix || ''));
      var emphasis = document.createElement('em');
      emphasis.textContent = entry.dataset.emphasis || '';
      headline.appendChild(emphasis);
      headline.appendChild(document.createTextNode(entry.dataset.suffix || ''));
    }
    if (entries.length > 1 && !reducedMotion.matches) {
      headline.addEventListener('mouseenter', function () {
        paused = true;
      });
      headline.addEventListener('mouseleave', function () {
        paused = false;
      });
      window.setInterval(function () {
        if (paused || document.hidden) return;
        headlineIndex = (headlineIndex + 1) % entries.length;
        showHeadline(headlineIndex);
      }, 6500);
    }
  }

  var demo = document.querySelector('[data-demo-view]');
  if (demo) {
    var demoButtons = demo.querySelectorAll('[data-demo-button]');
    var demoPanels = demo.querySelectorAll('[data-demo-panel]');
    for (var buttonIndex = 0; buttonIndex < demoButtons.length; buttonIndex++) {
      demoButtons[buttonIndex].addEventListener('click', function (event) {
        var view = event.currentTarget.dataset.demoButton;
        demo.dataset.demoView = view;
        for (var i = 0; i < demoButtons.length; i++)
          demoButtons[i].setAttribute('aria-pressed', String(demoButtons[i].dataset.demoButton === view));
        for (var j = 0; j < demoPanels.length; j++) demoPanels[j].hidden = demoPanels[j].dataset.demoPanel !== view;
      });
    }
  }

  var copyButtons = document.querySelectorAll('[data-copy-command]');
  for (var copyIndex = 0; copyIndex < copyButtons.length; copyIndex++) {
    copyButtons[copyIndex].addEventListener('click', function (event) {
      var button = event.currentTarget;
      var code = button.parentElement.querySelector('code');
      if (!code || !navigator.clipboard || !navigator.clipboard.writeText) return;
      navigator.clipboard.writeText(code.textContent).then(function () {
        button.textContent = 'Copied';
        window.setTimeout(function () {
          button.textContent = 'Copy';
        }, 1500);
      });
    });
  }
})();
