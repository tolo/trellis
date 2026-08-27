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
    themeToggle.hidden = false;
    setTheme(root.dataset.theme === 'dark' ? 'dark' : 'light', false);
    themeToggle.addEventListener('click', function () {
      setTheme(root.dataset.theme === 'dark' ? 'light' : 'dark', true);
    });
  }

  var docsSidebar = document.querySelector('[data-docs-sidebar]');
  if (docsSidebar) {
    var sidebarBreakpoint = window.matchMedia('(max-width: 700px)');
    function syncSidebar(event) {
      docsSidebar.open = !event.matches;
    }
    syncSidebar(sidebarBreakpoint);
    if (typeof sidebarBreakpoint.addEventListener === 'function')
      sidebarBreakpoint.addEventListener('change', syncSidebar);
  }

  var headline = document.querySelector('[data-headline]');
  if (headline) {
    var headlineText = document.querySelector('[data-headline-text]');
    var entries = headline.querySelectorAll('.headline-entry');
    var headlineSlot = document.querySelector('[data-headline-slot]');
    var headlineIndex = 0;
    var paused = false;
    function headlineOverflows() {
      return headlineText.scrollHeight > headlineSlot.clientHeight;
    }
    function fitHeadline() {
      if (!headlineSlot || !headlineText) return;
      // Lock the slot to its fixed two-line box first: the server-rendered slot grows with
      // its content, so nothing would ever measure as overflowing.
      headlineSlot.classList.add('is-fitted');
      if (headlineSlot.clientHeight === 0) return;
      headline.style.removeProperty('--headline-fit-scale');
      headline.classList.remove('fit-1', 'fit-2', 'fit-3');
      if (headlineOverflows()) headline.classList.add('fit-1');
      if (headlineOverflows()) headline.classList.add('fit-2');
      if (headlineOverflows()) headline.classList.add('fit-3');
      var scale = 0.64;
      for (var step = 0; step < 4 && headlineOverflows(); step++) {
        scale *= (headlineSlot.clientHeight / headlineText.scrollHeight) * 0.98;
        headline.style.setProperty('--headline-fit-scale', String(scale));
      }
    }
    function renderHeadline(index) {
      if (!headlineText) return;
      headlineText.textContent = '';
      var entry = entries[index];
      if (!entry) return;
      headlineText.appendChild(document.createTextNode(entry.dataset.prefix || ''));
      var emphasis = document.createElement('em');
      emphasis.textContent = entry.dataset.emphasis || '';
      headlineText.appendChild(emphasis);
      headlineText.appendChild(document.createTextNode(entry.dataset.suffix || ''));
      fitHeadline();
    }
    fitHeadline();
    window.addEventListener('resize', fitHeadline);
    if (document.fonts) {
      if (document.fonts.ready && typeof document.fonts.ready.then === 'function') {
        document.fonts.ready.then(fitHeadline);
      }
      if (typeof document.fonts.addEventListener === 'function') {
        document.fonts.addEventListener('loadingdone', fitHeadline);
      }
    }
    if (entries.length > 1) {
      headline.addEventListener('mouseenter', function () {
        paused = true;
      });
      headline.addEventListener('mouseleave', function () {
        paused = false;
      });
      var cycleTimer = null;
      // The preference can be turned on after load, so it is tracked like the sidebar
      // breakpoint above rather than read once: cycling stops and restarts with it.
      function syncMotion(event) {
        if (event.matches) {
          if (cycleTimer === null) return;
          window.clearInterval(cycleTimer);
          cycleTimer = null;
          headline.classList.remove('is-fading');
          return;
        }
        if (cycleTimer !== null) return;
        cycleTimer = window.setInterval(function () {
          if (paused || document.hidden) return;
          headline.classList.add('is-fading');
          window.setTimeout(function () {
            headlineIndex = (headlineIndex + 1) % entries.length;
            renderHeadline(headlineIndex);
            headline.classList.remove('is-fading');
          }, 500);
        }, 6500);
      }
      syncMotion(reducedMotion);
      if (typeof reducedMotion.addEventListener === 'function')
        reducedMotion.addEventListener('change', syncMotion);
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

  // The Clipboard API is absent outside a secure context (plain-http staging or LAN), so the
  // buttons are server-rendered hidden and only revealed once the capability is confirmed —
  // an inert button that silently does nothing is worse than no button.
  if (navigator.clipboard && navigator.clipboard.writeText && window.isSecureContext) {
    var copyButtons = document.querySelectorAll('[data-copy-command]');
    for (var copyIndex = 0; copyIndex < copyButtons.length; copyIndex++) {
      copyButtons[copyIndex].hidden = false;
      copyButtons[copyIndex].addEventListener('click', function (event) {
        var button = event.currentTarget;
        var code = button.parentElement.querySelector('code');
        if (!code) return;
        navigator.clipboard.writeText(code.textContent).then(
          function () {
            button.textContent = 'Copied';
            window.setTimeout(function () {
              button.textContent = 'Copy';
            }, 1500);
          },
          function () {
            // Permission denied or the write failed: say so instead of rejecting unhandled.
            button.textContent = 'Copy failed';
            window.setTimeout(function () {
              button.textContent = 'Copy';
            }, 1500);
          },
        );
      });
    }
  }
})();
