const MENU_ITEM = ':is([role="menuitem"], [role="menuitemcheckbox"]):not(:disabled,[aria-disabled="true"],[data-disabled])';

class TlDropdownMenu extends TlElement {
  onConnect() {
    this.sync(false);
    this.trackPopup(this.trigger, this.popup);
    this.listen(this.popup, 'toggle', () => {
      const open = this.popup.matches(':popover-open');
      this.sync(open);
      if (open) {
        place(this.trigger, this.popup);
        (this.focusLast ? this.items.at(-1) : this.items[0])?.focus();
      }
      this.focusLast = false;
    });
    this.listen(this, 'keydown', (event) => this.keydown(event));
    this.listen(this.popup, 'click', (event) => this.select(event));
    this.listen(this.popup, 'pointermove', (event) => event.target.closest(MENU_ITEM)?.focus({ preventScroll: true }));
    this.listen(this.popup, 'focusin', (event) => event.target.closest(MENU_ITEM)?.setAttribute('data-highlighted', ''));
    this.listen(this.popup, 'focusout', (event) => event.target.closest('[data-highlighted]')?.removeAttribute('data-highlighted'));
  }

  get trigger() { return this.querySelector('[data-slot="dropdown-menu-trigger"]'); }
  get popup() { return this.querySelector('[data-slot="dropdown-menu-content"]'); }
  get items() { return [...this.popup.querySelectorAll(MENU_ITEM)]; }

  onHistorySave() {
    this.sync(false);
    this.popup.querySelector('[data-highlighted]')?.removeAttribute('data-highlighted');
  }

  sync(open) {
    setOpenState(this.popup, open);
    this.trigger.setAttribute('aria-expanded', String(open));
    this.trigger.toggleAttribute('data-popup-open', open);
  }

  close() {
    this.popup.hidePopover();
    this.sync(false);
    this.trigger.focus();
  }

  keydown(event) {
    const { key } = event;
    if (event.target === this.trigger) {
      if (key !== 'ArrowDown' && key !== 'ArrowUp') return;
      event.preventDefault();
      this.focusLast = key === 'ArrowUp';
      this.popup.showPopover();
      return;
    }
    if (!this.popup.contains(event.target) || !this.popup.matches(':popover-open')) return;
    if (key === 'Escape' || key === 'Tab') {
      if (key === 'Escape') event.preventDefault();
      this.close();
      return;
    }
    const items = this.items, index = items.indexOf(document.activeElement);
    const target = {
      ArrowDown: items[(index + 1) % items.length],
      ArrowUp: items[(index - 1 + items.length) % items.length],
      Home: items[0],
      End: items.at(-1),
    }[key];
    if (target) {
      event.preventDefault();
      target.focus();
    } else if (key.length === 1 && key !== ' ' && !event.ctrlKey && !event.metaKey && !event.altKey) {
      const ordered = [...items.slice(index + 1), ...items.slice(0, index + 1)];
      ordered.find((item) => item.textContent.trim().toLowerCase().startsWith(key.toLowerCase()))?.focus();
    }
  }

  select(event) {
    const item = event.target.closest(MENU_ITEM);
    if (!item) return;
    if (item.getAttribute('role') === 'menuitemcheckbox') {
      const checked = item.getAttribute('aria-checked') !== 'true';
      item.setAttribute('aria-checked', String(checked));
      item.toggleAttribute('data-checked', checked);
    } else {
      this.close();
    }
    item.dispatchEvent(new CustomEvent('tl-select', { bubbles: true, detail: { item } }));
  }
}
customElements.define('tl-dropdown-menu', TlDropdownMenu);
