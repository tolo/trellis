const optionSelector = '[role="option"]';

class TlCombobox extends TlElement {
  onConnect() {
    this.setOpen(false);
    this.listen(this.input, 'input', () => {
      this.querySelector('[data-slot="combobox-value"]').value = '';
      const hasText = Boolean(this.input.value.trim());
      if (!this.input.matches('[hx-get], [data-hx-get]')) return this.setOpen(hasText);
      // An editing action must not select from a previous search or its in-flight response.
      this.input.dispatchEvent(new CustomEvent('htmx:abort', { bubbles: true, detail: { elt: this.input } }));
      this.listbox.replaceChildren();
      this.setOpen(false);
      this.searching = hasText;
    });
    this.listen(this.input, 'keydown', (event) => this.keydown(event));
    this.listen(this.input, 'focusout', () => this.setOpen(false));
    this.listen(this, 'pointerdown', (event) => {
      if (event.target.closest(`${optionSelector}, [data-slot="combobox-trigger"]`)) event.preventDefault();
    });
    this.listen(this, 'click', (event) => {
      if (this.input.disabled || this.searching) return;
      const option = event.target.closest(optionSelector);
      if (option) this.select(option);
      if (event.target.closest('[data-slot="combobox-trigger"]')) {
        this.input.focus({ preventScroll: true });
        this.setOpen(!this.open);
      }
    });
    const applyResults = () => {
      if (this.searching) this.setOpen(true);
      else this.syncResults();
    };
    for (const type of ['htmx:responseError', 'htmx:sendError', 'htmx:timeout']) {
      this.listen(this.input, type, () => {
        this.listbox.replaceChildren();
        applyResults();
      });
    }
    // HTMX replaces the results node, so observe its stable parent.
    this.observer = new MutationObserver(applyResults);
    this.observer.observe(this.popup, { childList: true });
    this.trackPopup(this.input.parentElement, this.popup);
  }

  onDisconnect() { this.observer.disconnect(); }
  onHistorySave() {
    this.input.defaultValue = this.input.value;
    this.setOpen(false);
  }

  get input() { return this.querySelector('[role="combobox"]'); }
  get popup() { return this.querySelector(popupSelector); }
  get listbox() { return this.querySelector('[role="listbox"]'); }
  get options() { return [...this.listbox.querySelectorAll(optionSelector)]; }
  get open() { return this.popup.matches(':popover-open'); }

  setOpen(open) {
    this.searching = false;
    if (open && !this.open) this.popup.showPopover();
    if (!open && this.open) this.popup.hidePopover();
    this.input.setAttribute('aria-expanded', String(open));
    setOpenState(this.popup, open);
    if (open) this.syncResults();
    else this.highlight(null);
  }

  syncResults() {
    const count = this.options.length;
    this.listbox.hidden = count === 0;
    this.querySelector('[data-slot="combobox-empty"]').hidden = count > 0;
    this.popup.toggleAttribute('data-empty', count === 0);
    this.highlight(null);
    this.querySelector('[role="status"]').textContent =
      count ? `${count} result${count === 1 ? '' : 's'} available` : 'No results';
    if (this.open) place(this.input.parentElement, this.popup);
  }

  keydown(event) {
    if (event.isComposing) return;
    const { key } = event;
    if (key === 'Escape' && (this.open || this.searching)) {
      event.preventDefault();
      event.stopPropagation();
      this.setOpen(false);
      return;
    }
    // Firefox on macOS can otherwise scroll the page on unmodified Home/End.
    if ((key === 'Home' || key === 'End') && !event.shiftKey && !event.ctrlKey && !event.altKey && !event.metaKey) {
      event.preventDefault();
      const cursor = key === 'Home' ? 0 : this.input.value.length;
      this.input.setSelectionRange(cursor, cursor);
      return;
    }
    if (this.searching) return;
    const options = this.options;
    const index = options.findIndex((option) => option.id === this.input.getAttribute('aria-activedescendant'));
    if (key === 'Enter' && this.open && index >= 0) {
      event.preventDefault();
      this.select(options[index]);
    }
    if (key !== 'ArrowDown' && key !== 'ArrowUp') return;
    if (!this.open) this.setOpen(true);
    if (!options.length) return;
    event.preventDefault();
    const next = key === 'ArrowDown' ? Math.min(index + 1, options.length - 1) :
      index < 0 ? options.length - 1 : Math.max(index - 1, 0);
    this.highlight(options[next]);
    options[next].scrollIntoView({ block: 'nearest' });
  }

  highlight(active) {
    for (const option of this.options) {
      option.setAttribute('aria-selected', String(option === active));
      option.toggleAttribute('data-highlighted', option === active);
    }
    if (active) this.input.setAttribute('aria-activedescendant', active.id);
    else this.input.removeAttribute('aria-activedescendant');
  }

  select(option) {
    this.input.value = option.textContent.trim();
    this.querySelector('[data-slot="combobox-value"]').value = option.dataset.value;
    this.setOpen(false);
  }
}
customElements.define('tl-combobox', TlCombobox);
