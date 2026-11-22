const focusedSearch = new WeakMap();

document.addEventListener('htmx:beforeSwap', ({ detail }) => {
  const field = document.activeElement;
  if (detail.xhr && detail.target.id === 'contact-list' && field?.id === 'contact-query') {
    focusedSearch.set(detail.xhr, field);
  }
});

document.addEventListener('htmx:afterSwap', ({ detail }) => {
  if (detail.elt.id !== 'contact-list') return;
  const search = detail.elt.querySelector('#contact-query');
  // HTMX serializes the value attribute rather than the value being typed.
  if (search) search.defaultValue = new URL(location.href).searchParams.get('q') ?? '';
  const field = focusedSearch.get(detail.xhr);
  focusedSearch.delete(detail.xhr);
  // Safari can drop focus while HTMX moves an hx-preserve input through its temporary container.
  if (field?.isConnected && document.hasFocus() && document.activeElement === document.body) {
    field.focus({ preventScroll: true });
  }
});
