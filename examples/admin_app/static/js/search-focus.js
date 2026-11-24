const focusedFilterControls = new WeakMap();

document.addEventListener('htmx:beforeSwap', ({ detail }) => {
  const field = document.activeElement;
  if (detail.xhr && detail.target.id === 'contact-list' && field?.form?.id === 'contact-filter') {
    focusedFilterControls.set(detail.xhr, field);
  }
});

document.addEventListener('htmx:afterSwap', ({ detail }) => {
  if (detail.elt.id !== 'contact-list') return;
  const { q: search, page, status } = detail.elt.querySelector('#contact-filter').elements;
  const params = new URL(location.href).searchParams;
  // History snapshots need the applied filters even if the live form already has newer edits.
  search.defaultValue = params.get('q') ?? '';
  page.value = params.get('page') ?? '1';
  const appliedStatus = params.get('status') ?? '';
  const liveStatus = status.value;
  for (const option of status.options) option.defaultSelected = option.value === appliedStatus;
  if (status.value !== liveStatus) status.value = liveStatus;

  const field = focusedFilterControls.get(detail.xhr);
  focusedFilterControls.delete(detail.xhr);
  // Safari can drop focus while HTMX moves the preserved form through its temporary container.
  if (field?.isConnected && document.hasFocus() && document.activeElement === document.body) {
    field.focus({ preventScroll: true });
  }
});
