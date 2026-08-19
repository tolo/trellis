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
  const classes = new Set();
  const styleValues = {};
  return {
    dataset: { ...dataset },
    children: [],
    listeners: {},
    attributes: {},
    _text: '',
    clientHeight: 140,
    scrollHeight: 100,
    style: {
      getPropertyValue(name) {
        return styleValues[name] || '';
      },
      removeProperty(name) {
        delete styleValues[name];
      },
      setProperty(name, value) {
        styleValues[name] = String(value);
      },
    },
    classList: {
      add(...names) {
        names.forEach((name) => classes.add(name));
      },
      remove(...names) {
        names.forEach((name) => classes.delete(name));
      },
      contains(name) {
        return classes.has(name);
      },
    },
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

function runLattice(reducedMotion, { entryCount = 2, contentHeight = 100 } = {}) {
  const headline = makeElement();
  headline.classList.add('fit-initial');
  const headlineText = makeElement();
  headlineText.textContent = 'Server first';
  headline.appendChild(headlineText);
  const headlineSlot = makeElement();
  headlineSlot.clientHeight = 100;
  const entries = [
    makeElement({ prefix: 'Server ', emphasis: 'first', suffix: '' }),
    makeElement({ prefix: 'Client ', emphasis: 'second', suffix: '' }),
  ].slice(0, entryCount);
  headline.querySelectorAll = (selector) => selector === '.headline-entry' ? entries : [];

  let fontsSettled = false;
  function headlineScale() {
    const inlineScale = Number(headline.style.getPropertyValue('--headline-fit-scale'));
    if (inlineScale) return inlineScale;
    if (headline.classList.contains('fit-3') || headline.classList.contains('fit-initial')) return 0.64;
    if (headline.classList.contains('fit-2')) return 0.74;
    if (headline.classList.contains('fit-1')) return 0.86;
    return 1;
  }
  Object.defineProperty(headlineText, 'scrollHeight', {
    get() {
      const settledHeight = fontsSettled ? contentHeight : contentHeight * 0.8;
      return Math.ceil(settledHeight * headlineScale());
    },
  });

  const intervals = [];
  const timeouts = [];
  const fontReadyHandlers = [];
  const fontLoadingDoneHandlers = [];
  const document = {
    hidden: false,
    documentElement: makeElement(),
    fonts: {
      ready: {
        then(handler) {
          fontReadyHandlers.push(handler);
        },
      },
      addEventListener(type, handler) {
        if (type === 'loadingdone') fontLoadingDoneHandlers.push(handler);
      },
    },
    querySelector(selector) {
      if (selector === '[data-headline]') return headline;
      if (selector === '[data-headline-text]') return headlineText;
      if (selector === '[data-headline-slot]') return headlineSlot;
      return null;
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
    addEventListener() {},
    setInterval(handler, delay) {
      intervals.push({ handler, delay });
    },
    setTimeout(handler, delay) {
      timeouts.push({ handler, delay });
    },
  };
  runScript({ document, window, navigator: {} });
  const immediate = headline.textContent;
  const beforeFonts = {
    contentHeight: headlineText.scrollHeight,
    slotHeight: headlineSlot.clientHeight,
    scale: headline.style.getPropertyValue('--headline-fit-scale'),
  };
  fontsSettled = true;
  fontReadyHandlers.forEach((handler) => handler());
  fontLoadingDoneHandlers.forEach((handler) => handler());
  const afterFonts = {
    contentHeight: headlineText.scrollHeight,
    slotHeight: headlineSlot.clientHeight,
    scale: headline.style.getPropertyValue('--headline-fit-scale'),
  };
  if (intervals[0]) intervals[0].handler();
  const atFadeStart = {
    text: headline.textContent,
    fading: headline.classList.contains('is-fading'),
  };
  if (timeouts[0]) timeouts[0].handler();
  return {
    immediate,
    atFadeStart,
    afterFade: {
      text: headline.textContent,
      fading: headline.classList.contains('is-fading'),
    },
    intervalDelay: intervals[0] ? intervals[0].delay : null,
    intervalCount: intervals.length,
    fadeDelay: timeouts[0] ? timeouts[0].delay : null,
    timeoutCount: timeouts.length,
    beforeFonts,
    afterFonts,
    fontReadyHandlerCount: fontReadyHandlers.length,
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
  console.log(JSON.stringify({
    motion: runLattice(false),
    reducedMotion: runLattice(true),
    empty: runLattice(false, { entryCount: 0 }),
    single: runLattice(false, { entryCount: 1 }),
    long: runLattice(false, { entryCount: 1, contentHeight: 2000 }),
  }));
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
