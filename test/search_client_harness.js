// Behavioral DOM-harness for the vendored client-side search script (S09):
// themes/arbor/static/js/search.js.
//
// Runs under plain system `node` — no npm, no package.json, no build step. It
// stubs the minimal DOM/fetch surface search.js actually touches (learned by
// reading the source, not guessed), loads the real script via a source read +
// eval, drives it through named scenarios, and prints one JSON object of
// scenario results to stdout for the Dart test to assert against.
//
// Usage: node search_client_harness.js <path-to-search.js>
//
// Deliberately NOT reimplemented here: the search/query logic. Every scenario
// drives the actual `input` listener captured via addEventListener, and reads
// results back out of the stubbed results/shell nodes — this harness only
// fakes the DOM, never the behavior under test.

'use strict';

const fs = require('fs');

const scriptPath = process.argv[2];
if (!scriptPath) {
  console.error('usage: node search_client_harness.js <path-to-search.js>');
  process.exit(2);
}

// ---- Minimal fake DOM -------------------------------------------------

function makeClassList(el) {
  return {
    add(name) {
      if (!el._classes.includes(name)) el._classes.push(name);
    },
    remove(name) {
      el._classes = el._classes.filter((c) => c !== name);
    },
    contains(name) {
      return el._classes.includes(name);
    },
  };
}

function makeElement(tag) {
  const el = {
    tagName: tag.toUpperCase(),
    _classes: [],
    _attrs: {},
    _listeners: {},
    children: [],
    disabled: false,
    hidden: false,
    parentNode: null,
    get className() {
      return el._classes.join(' ');
    },
    set className(value) {
      el._classes = String(value).split(/\s+/).filter(Boolean);
    },
    get textContent() {
      if (el.children.length === 0) return el._text || '';
      return el.children.map((c) => c.textContent).join('');
    },
    set textContent(value) {
      el._text = value;
      el.children = [];
    },
    setAttribute(name, value) {
      el._attrs[name] = String(value);
    },
    getAttribute(name) {
      return Object.prototype.hasOwnProperty.call(el._attrs, name) ? el._attrs[name] : null;
    },
    removeAttribute(name) {
      delete el._attrs[name];
    },
    hasAttribute(name) {
      return Object.prototype.hasOwnProperty.call(el._attrs, name);
    },
    addEventListener(type, handler) {
      (el._listeners[type] = el._listeners[type] || []).push(handler);
    },
    dispatch(type) {
      (el._listeners[type] || []).forEach((h) => h.call(el));
    },
    appendChild(child) {
      child.parentNode = el;
      el.children.push(child);
      return child;
    },
    closest(selector) {
      // Only '.search-shell' is ever queried by search.js — support that case.
      const className = selector.replace(/^\./, '');
      let node = el;
      while (node) {
        if (node._classes && node._classes.includes(className)) return node;
        node = node.parentNode;
      }
      return null;
    },
    get classList() {
      return makeClassList(el);
    },
  };
  return el;
}

// Builds a fresh document graph mirroring the S04 shell contract:
//   .search-shell[data-search-index] > input[data-arbor-search] + ul[data-arbor-search-results]
function buildDom({ withIndexUrl = true, withShell = true } = {}) {
  const input = makeElement('input');
  input.setAttribute('data-arbor-search', '');
  input.disabled = true;

  const results = makeElement('ul');
  results.setAttribute('data-arbor-search-results', '');
  results.hidden = true;

  const shell = makeElement('div');
  // The layout ships the shell hidden; search.js is what reveals it, and the
  // script-never-ran case is exactly the one a class-toggle mechanism missed.
  shell.hidden = true;
  if (withShell) {
    shell.classList.add('search-shell');
    if (withIndexUrl) shell.setAttribute('data-search-index', '/search-index.json');
    shell.appendChild(input);
    shell.appendChild(results);
  }

  const registry = [input, results];
  if (withShell) registry.push(shell);

  const document = {
    querySelector(selector) {
      if (selector === '[data-arbor-search]') return input;
      if (selector === '[data-arbor-search-results]') return results;
      return null;
    },
    createElement(tag) {
      return makeElement(tag);
    },
  };

  return { document, input, results, shell };
}

// ---- Controllable fetch stub ------------------------------------------

function makeFetchStub(mode, fixture) {
  return function fetchStub() {
    if (mode === 'reject') {
      return Promise.reject(new Error('network error'));
    }
    if (mode === 'non-ok') {
      return Promise.resolve({ ok: false, status: 404, json: () => Promise.reject(new Error('should not be read')) });
    }
    if (mode === 'ok') {
      return Promise.resolve({ ok: true, status: 200, json: () => Promise.resolve(fixture) });
    }
    throw new Error('unknown fetch mode: ' + mode);
  };
}

// ---- Script loading ------------------------------------------------------

// search.js is an IIFE with no exports; it wires itself up purely off the
// global `document` and `fetch` at load time. Loading it fresh per scenario
// (via a new Function/vm context) means each scenario gets an isolated run.
const vm = require('vm');
const source = fs.readFileSync(scriptPath, 'utf8');

function runScript(context) {
  vm.createContext(context);
  vm.runInContext(source, context, { filename: scriptPath });
}

// Flushes the microtask queue enough times for the fetch().then().then().catch()
// chain in search.js to fully settle.
async function flushMicrotasks(times = 6) {
  for (let i = 0; i < times; i++) {
    await Promise.resolve();
  }
}

// ---- Scenarios -------------------------------------------------------

const FIXTURE_INDEX = [
  { url: '/guide/intro/', title: 'Getting Started', summary: 'How to install and configure Trellis.', tags: ['guide'] },
  { url: '/reference/attrs/', title: 'Attribute Reference', summary: 'All tl:* attributes explained.', tags: ['reference'] },
];

async function scenarioFetchRejects() {
  const { document, input, shell } = buildDom();
  runScript({ document, fetch: makeFetchStub('reject'), console });
  await flushMicrotasks();

  return {
    inputDisabled: input.disabled === true,
    inputAriaDisabled: input.getAttribute('aria-disabled') === 'true',
    shellHidden: shell.hidden === true,
  };
}

async function scenarioFetchNonOk() {
  const { document, input, shell } = buildDom();
  runScript({ document, fetch: makeFetchStub('non-ok'), console });
  await flushMicrotasks();

  return {
    inputDisabled: input.disabled === true,
    inputAriaDisabled: input.getAttribute('aria-disabled') === 'true',
    shellHidden: shell.hidden === true,
  };
}

async function scenarioNoMatch() {
  const { document, input, results, shell } = buildDom();
  runScript({ document, fetch: makeFetchStub('ok', FIXTURE_INDEX), console });
  await flushMicrotasks();

  input.value = 'zzz-no-such-term';
  input.dispatch('input');

  const emptyItem = results.children.find((c) => c.className === 'search-empty');
  return {
    inputEnabled: input.disabled === false,
    shellHidden: shell.hidden === true,
    resultsHidden: results.hidden === true,
    hasEmptyState: Boolean(emptyItem),
    emptyStateText: emptyItem ? emptyItem.textContent : null,
  };
}

async function scenarioEmptyQuery() {
  const { document, input, results } = buildDom();
  runScript({ document, fetch: makeFetchStub('ok', FIXTURE_INDEX), console });
  await flushMicrotasks();

  // First produce a non-idle state, then clear it, to prove idle really resets.
  input.value = 'trellis';
  input.dispatch('input');
  input.value = '   ';
  input.dispatch('input');

  return {
    resultsHidden: results.hidden === true,
    resultsChildCount: results.children.length,
  };
}

async function scenarioHappyPath() {
  const { document, input, results } = buildDom();
  runScript({ document, fetch: makeFetchStub('ok', FIXTURE_INDEX), console });
  await flushMicrotasks();

  input.value = 'install';
  input.dispatch('input');

  const item = results.children.find((c) => c.className === 'search-result');
  const link = item ? item.children.find((c) => c.tagName === 'A') : null;
  const title = link ? link.children.find((c) => c.className === 'search-result-title') : null;

  return {
    resultsHidden: results.hidden, // expect false (visible)
    resultCount: results.children.length,
    href: link ? link.getAttribute('href') : null,
    titleText: title ? title.textContent : null,
  };
}

async function main() {
  const out = {
    fetchRejects: await scenarioFetchRejects(),
    fetchNonOk: await scenarioFetchNonOk(),
    noMatch: await scenarioNoMatch(),
    emptyQuery: await scenarioEmptyQuery(),
    happyPath: await scenarioHappyPath(),
  };
  process.stdout.write(JSON.stringify(out));
}

main().catch((err) => {
  console.error('harness error:', err && err.stack ? err.stack : err);
  process.exit(1);
});
