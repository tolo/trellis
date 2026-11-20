import './cally-0.9.2.js';

const mounted = new Map();

function mount(root) {
  const pristine = root.cloneNode(true);
  const controls = [...root.querySelectorAll('input[type=date]')];
  const enhanced = root.querySelector('[data-calendar]');
  const range = root.hasAttribute('data-range');
  const calendar = document.createElement(range ? 'calendar-range' : 'calendar-date');
  calendar.locale = root.dataset.locale;
  calendar.lang = root.dataset.locale;
  calendar.firstDayOfWeek = Number(root.dataset.firstDayOfWeek);
  for (const [direction, label] of [['previous', root.dataset.previousLabel], ['next', root.dataset.nextLabel]]) {
    if (!label) continue;
    const text = document.createElement('span');
    text.slot = direction;
    text.textContent = label;
    calendar.append(text);
  }
  calendar.append(document.createElement('calendar-month'));

  const listeners = new AbortController();
  const signal = listeners.signal;
  const read = () => {
    const dates = controls.map(input => input.value);
    calendar.value = dates.every(Boolean) && (!range || dates[0] <= dates[1]) ? dates.join('/') : '';
    calendar.focusedDate = dates.find(Boolean);
  };
  read();
  for (const input of controls) input.addEventListener('input', read, { signal });
  calendar.addEventListener('change', () => {
    const dates = calendar.value.split('/');
    if (dates.length !== controls.length) return;
    for (const [index, input] of controls.entries()) {
      if (input.value === dates[index]) continue;
      input.value = dates[index];
      input.dispatchEvent(new Event('change', { bubbles: true }));
    }
  }, { signal });
  enhanced.querySelector('[popover]').append(calendar);
  enhanced.hidden = false;
  mounted.set(root, { pristine, listeners });
}

function unmount(root) {
  mounted.get(root).listeners.abort();
  mounted.delete(root);
}

function reconcile() {
  for (const root of mounted.keys()) {
    if (!root.isConnected) unmount(root);
  }
  for (const root of document.querySelectorAll('[data-date-picker]')) {
    if (!mounted.has(root)) mount(root);
  }
}

document.addEventListener('htmx:beforeCleanupElement', ({ detail: { elt } }) => {
  for (const root of mounted.keys()) {
    if (elt.contains(root)) unmount(root);
  }
});
document.addEventListener('htmx:beforeHistorySave', () => {
  for (const [root, { pristine }] of mounted) {
    unmount(root);
    root.replaceChildren(...pristine.childNodes);
  }
  // HTMX serializes in this turn. Regions left in place still need to remount.
  queueMicrotask(reconcile);
});

document.addEventListener('htmx:afterSwap', reconcile);
document.addEventListener('htmx:historyRestore', reconcile);
reconcile();
