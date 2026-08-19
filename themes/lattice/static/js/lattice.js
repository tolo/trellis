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
    var headlineText = document.querySelector('[data-headline-text]');
    var entries = headline.querySelectorAll('.headline-entry');
    var headlineSlot = document.querySelector('[data-headline-slot]');
    var headlineIndex = 0;
    var paused = false;
    function headlineOverflows() {
      return headlineText.scrollHeight > headlineSlot.clientHeight;
    }
    function fitHeadline() {
      if (!headlineSlot || !headlineText || headlineSlot.clientHeight === 0) return;
      headline.style.removeProperty('--headline-fit-scale');
      headline.classList.remove('fit-initial', 'fit-1', 'fit-2', 'fit-3');
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
    if (entries.length > 1 && !reducedMotion.matches) {
      headline.addEventListener('mouseenter', function () {
        paused = true;
      });
      headline.addEventListener('mouseleave', function () {
        paused = false;
      });
      window.setInterval(function () {
        if (paused || document.hidden) return;
        headline.classList.add('is-fading');
        window.setTimeout(function () {
          headlineIndex = (headlineIndex + 1) % entries.length;
          renderHeadline(headlineIndex);
          headline.classList.remove('is-fading');
        }, 500);
      }, 6500);
    }
  }

  function appendCodeToken(parent, text, className) {
    var token = document.createElement('span');
    token.className = className;
    token.textContent = text;
    parent.appendChild(token);
  }

  function appendCodeString(parent, text) {
    var cursor = 0;
    var expression = /\$\{[^}]+\}/g;
    var match;
    while ((match = expression.exec(text)) !== null) {
      if (match.index > cursor) appendCodeToken(parent, text.slice(cursor, match.index), 't-str');
      appendCodeToken(parent, match[0], 't-expr');
      cursor = match.index + match[0].length;
    }
    if (cursor < text.length) appendCodeToken(parent, text.slice(cursor), 't-str');
  }

  var codeBlocks = document.querySelectorAll('[data-lattice-code]');
  var codePattern = /(<\/?)([A-Za-z][\w-]*)|(\s)(tl:[\w-]+|[A-Za-z][\w-]*)(?==)|("[^"]*")|(\/?>)/g;
  for (var codeIndex = 0; codeIndex < codeBlocks.length; codeIndex++) {
    var block = codeBlocks[codeIndex];
    var source = block.textContent;
    var fragment = document.createDocumentFragment();
    var sourceCursor = 0;
    var codeMatch;
    while ((codeMatch = codePattern.exec(source)) !== null) {
      if (codeMatch.index > sourceCursor)
        fragment.appendChild(document.createTextNode(source.slice(sourceCursor, codeMatch.index)));
      if (codeMatch[1]) {
        appendCodeToken(fragment, codeMatch[1], 't-dim');
        appendCodeToken(fragment, codeMatch[2], 't-tag');
      } else if (codeMatch[4]) {
        fragment.appendChild(document.createTextNode(codeMatch[3]));
        appendCodeToken(fragment, codeMatch[4], codeMatch[4].indexOf('tl:') === 0 ? 't-tl' : 't-attr');
      } else if (codeMatch[5]) {
        appendCodeString(fragment, codeMatch[5]);
      } else {
        appendCodeToken(fragment, codeMatch[6], 't-dim');
      }
      sourceCursor = codePattern.lastIndex;
    }
    if (sourceCursor < source.length)
      fragment.appendChild(document.createTextNode(source.slice(sourceCursor)));
    block.textContent = '';
    block.appendChild(fragment);
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
