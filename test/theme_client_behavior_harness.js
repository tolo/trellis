'use strict';

const fs = require('fs');
const vm = require('vm');

const mode = process.argv[2];
const scriptPath = process.argv[3];
if (!['lattice', 'folio'].includes(mode) || !scriptPath) {
  console.error('usage: node theme_client_behavior_harness.js <lattice|folio> <script-path>');
  process.exit(2);
}

const source = fs.readFileSync(scriptPath, 'utf8');

function runScript(context) {
  vm.createContext(context);
  vm.runInContext(source, context, { filename: scriptPath });
}

function makeElement(dataset = {}) {
  return {
    dataset: { ...dataset },
    children: [],
    listeners: {},
    attributes: {},
    _text: '',
    get textContent() {
      return this.children.length ? this.children.map((child) => child.textContent).join('') : this._text;
    },
    set textContent(value) {
      this._text = String(value);
      this.children = [];
    },
    appendChild(child) {
      this.children.push(child);
      return child;
    },
    addEventListener(type, handler) {
      (this.listeners[type] = this.listeners[type] || []).push(handler);
    },
    dispatch(type) {
      (this.listeners[type] || []).forEach((handler) => handler({ currentTarget: this }));
    },
    setAttribute(name, value) {
      this.attributes[name] = String(value);
    },
    getAttribute(name) {
      return this.attributes[name] ?? null;
    },
    querySelector() {
      return null;
    },
    querySelectorAll() {
      return [];
    },
  };
}

function runLattice(reducedMotion) {
  const headline = makeElement();
  headline.textContent = 'Server first';
  const entries = [
    makeElement({ prefix: 'Server ', emphasis: 'first', suffix: '' }),
    makeElement({ prefix: 'Client ', emphasis: 'second', suffix: '' }),
  ];
  headline.querySelectorAll = (selector) => selector === '.headline-entry' ? entries : [];

  const intervals = [];
  const document = {
    hidden: false,
    documentElement: makeElement(),
    querySelector(selector) {
      return selector === '[data-headline]' ? headline : null;
    },
    querySelectorAll() {
      return [];
    },
    createTextNode(text) {
      return { textContent: String(text) };
    },
    createElement() {
      return makeElement();
    },
  };
  const window = {
    matchMedia: () => ({ matches: reducedMotion }),
    setInterval(handler, delay) {
      intervals.push({ handler, delay });
    },
  };
  runScript({ document, window, navigator: {} });
  const immediate = headline.textContent;
  if (intervals[0]) intervals[0].handler();
  return {
    immediate,
    afterFirstInterval: headline.textContent,
    intervalDelay: intervals[0] ? intervals[0].delay : null,
    intervalCount: intervals.length,
  };
}

function runFolio(initialStored, initialOsDark, { throwRead = false, throwWrite = false } = {}) {
  const button = makeElement();
  const root = makeElement();
  let stored = initialStored;
  const persisted = [];
  const media = {
    matches: initialOsDark,
    listeners: [],
    addEventListener(type, handler) {
      if (type === 'change') this.listeners.push(handler);
    },
    change(matches) {
      this.matches = matches;
      this.listeners.forEach((handler) => handler({ matches }));
    },
  };
  const localStorage = {
    getItem() {
      if (throwRead) throw new Error('read denied');
      return stored;
    },
    setItem(key, value) {
      if (throwWrite) throw new Error('write denied');
      stored = value;
      persisted.push({ key, value });
    },
  };
  const document = {
    documentElement: root,
    querySelector: () => button,
  };
  runScript({ document, window: { matchMedia: () => media }, localStorage });

  const initial = { skin: root.dataset.skin, pressed: button.getAttribute('aria-pressed') };
  return {
    initial,
    persisted,
    changeMedia(matches) {
      media.change(matches);
      return { skin: root.dataset.skin, pressed: button.getAttribute('aria-pressed') };
    },
    click() {
      button.dispatch('click');
      return { skin: root.dataset.skin, pressed: button.getAttribute('aria-pressed'), persisted };
    },
  };
}

if (mode === 'lattice') {
  console.log(JSON.stringify({ motion: runLattice(false), reducedMotion: runLattice(true) }));
} else {
  const osDark = runFolio(null, true);
  const osDarkAfterMediaChange = osDark.changeMedia(false);
  const osDarkPersisted = [...osDark.persisted];
  const click = osDark.click();
  const storedLight = runFolio('light', true);
  const storedDark = runFolio('dark', false);
  const failedLight = runFolio(null, true, { throwRead: true, throwWrite: true });
  const failedLightClick = failedLight.click();
  const failedDark = runFolio(null, false, { throwRead: true, throwWrite: true });
  const failedDarkClick = failedDark.click();
  console.log(JSON.stringify({
    osDark: {
      initial: osDark.initial,
      afterMediaChange: osDarkAfterMediaChange,
      persisted: osDarkPersisted,
    },
    storedLight: {
      initial: storedLight.initial,
      afterMediaChange: storedLight.changeMedia(false),
      persisted: storedLight.persisted,
    },
    storedDark: {
      initial: storedDark.initial,
      afterMediaChange: storedDark.changeMedia(true),
      persisted: storedDark.persisted,
    },
    click,
    failedLight: {
      initial: failedLight.initial,
      click: failedLightClick,
      afterOsLight: failedLight.changeMedia(false),
      afterOsDark: failedLight.changeMedia(true),
      persisted: failedLight.persisted,
    },
    failedDark: {
      initial: failedDark.initial,
      click: failedDarkClick,
      afterOsDark: failedDark.changeMedia(true),
      afterOsLight: failedDark.changeMedia(false),
      persisted: failedDark.persisted,
    },
  }));
}
