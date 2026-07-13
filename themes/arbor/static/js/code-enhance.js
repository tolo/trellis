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

  function copyText(text, button) {
    var done = function () {
      button.textContent = 'Copied';
      button.classList.add('is-copied');
      window.setTimeout(function () {
        button.textContent = 'Copy';
        button.classList.remove('is-copied');
      }, 1600);
    };
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, function () {
        button.textContent = 'Error';
        window.setTimeout(function () { button.textContent = 'Copy'; }, 1600);
      });
    } else {
      button.textContent = 'Error';
      window.setTimeout(function () { button.textContent = 'Copy'; }, 1600);
    }
  }

  function enhance(code) {
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

    var button = document.createElement('button');
    button.type = 'button';
    button.className = 'code-copy';
    button.textContent = 'Copy';
    button.setAttribute('aria-label', 'Copy code to clipboard');
    button.addEventListener('click', function () {
      copyText(code.textContent, button);
    });

    bar.appendChild(lang);
    bar.appendChild(button);
    wrap.appendChild(bar);
    wrap.appendChild(pre);
  }

  function run() {
    var blocks = document.querySelectorAll('pre > code[class*="language-"]');
    Array.prototype.forEach.call(blocks, enhance);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', run);
  } else {
    run();
  }
})();
