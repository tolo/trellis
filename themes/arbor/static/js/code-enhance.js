// Arbor Docs Theme — static/js/code-enhance.js
// First-party, same-origin progressive enhancement for code blocks: wraps each
// `<pre><code class="language-*">` in a framed container with a language label
// and a copy-to-clipboard button.
//
// Progressive enhancement: with JS disabled the code blocks are fully readable
// (this only adds affordances). Independent of the tokenizer — it reads the
// language from the `language-*` class and the code from `textContent`, both
// present whether or not the SSG baked in build-time `.hljs-*` spans.
(function () {
  'use strict';

  // Friendly labels for common languages; anything else falls back to the
  // uppercased class suffix.
  var LABELS = {
    dart: 'Dart',
    markup: 'HTML',
    html: 'HTML',
    css: 'CSS',
    scss: 'SCSS',
    yaml: 'YAML',
    bash: 'Bash',
    shell: 'Shell',
    json: 'JSON',
    markdown: 'Markdown',
    clike: 'Code',
  };

  function labelFor(code) {
    var match = /(?:^|\s)language-([\w-]+)/.exec(code.className || '');
    if (!match) return null;
    var lang = match[1];
    return LABELS[lang] || lang.toUpperCase();
  }

  var latestCopy = 0;

  function enableCopy(code, button, status) {
    var buttonCopy, resetTimer;
    button.addEventListener('click', function () {
      var copy = ++latestCopy;
      buttonCopy = copy;
      function report(copied) {
        if (copy !== buttonCopy) return;
        button.textContent = copied ? 'Copied' : 'Error';
        // Every code block shares one live region, even though its button has its own feedback.
        if (status && copy === latestCopy) {
          status.textContent = copied ? 'Code copied to clipboard.' : 'Could not copy code to clipboard.';
        }
        window.clearTimeout(resetTimer);
        resetTimer = window.setTimeout(function () { button.textContent = 'Copy'; }, 1600);
      }
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(code.textContent).then(function () { report(true); }, function () { report(false); });
      } else {
        report(false);
      }
    });
  }

  function enhance(code, template, status) {
    var pre = code.parentElement;
    if (!pre || pre.tagName !== 'PRE') return;
    // Idempotent: skip if already wrapped (e.g. re-invoked).
    if (pre.parentElement && pre.parentElement.classList.contains('code-block')) return;

    var label = labelFor(code);

    var wrap = document.createElement('div');
    wrap.className = 'code-block';
    pre.parentNode.insertBefore(wrap, pre);

    var bar = document.createElement('div');
    bar.className = 'code-bar';

    var lang = document.createElement('span');
    lang.className = 'code-lang';
    lang.textContent = label || '';

    var button = template.content.firstElementChild.cloneNode(true);
    enableCopy(code, button, status);

    bar.appendChild(lang);
    bar.appendChild(button);
    wrap.appendChild(bar);
    wrap.appendChild(pre);
  }

  function run() {
    var template = document.querySelector('template[data-code-copy]');
    if (!template) return;
    var status = document.querySelector('[data-code-copy-status]');
    var blocks = document.querySelectorAll('pre > code[class*="language-"]');
    Array.prototype.forEach.call(blocks, function (code) { enhance(code, template, status); });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', run);
  } else {
    run();
  }
})();
