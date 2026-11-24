const MENU_ITEM = ':is([role="menuitem"], [role="menuitemcheckbox"]):not(:disabled,[aria-disabled="true"],[data-disabled])';

class TlDropdownMenu extends TlElement {
  onConnect() {
    this.sync(false);
    this.observeExit(this.popup);
    const placement = this.submenu ? { side: 'right' } : undefined;
    this.trackPopup(this.trigger, this.popup, placement);
    this.listen(this.popup, 'beforetoggle', (event) => {
      if (event.newState === 'closed') this.clearMenu();
    });
    this.listen(this.popup, 'toggle', () => {
      const open = this.popup.matches(':popover-open');
      this.sync(open);
      if (open) {
        place(this.trigger, this.popup, placement);
        (this.focusLast ? this.items.at(-1) : this.items[0])?.focus();
      }
      this.focusLast = false;
    });
    if (this.submenu) {
      this.listen(this.trigger, 'click', (event) => {
        if (!this.trigger.matches(MENU_ITEM)) event.preventDefault();
      });
    }
    this.listen(this, 'keydown', (event) => this.keydown(event));
    this.listen(this.popup, 'click', (event) => this.select(event));
    this.listen(this.popup, 'pointermove', (event) => {
      if (!this.popup.querySelector('[role=menu]:popover-open')) this.item(event.target)?.focus({ preventScroll: true });
    });
    this.listen(this.popup, 'focusin', (event) => this.item(event.target)?.setAttribute('data-highlighted', ''));
    this.listen(this.popup, 'focusout', (event) => this.item(event.target, '[data-highlighted]')?.removeAttribute('data-highlighted'));
  }

  get trigger() { return this.querySelector(':scope > button[popovertarget]'); }
  get popup() { return this.querySelector(':scope > [role=menu]'); }
  get parentMenu() { return this.parentElement?.closest('tl-dropdown-menu'); }
  get submenu() { return this.dataset.slot === 'dropdown-menu-sub'; }
  get items() { return [...this.popup.querySelectorAll(MENU_ITEM)].filter(item => this.item(item)); }

  item(target, selector = MENU_ITEM) {
    const item = target.closest(selector);
    return item?.closest('[role=menu]') === this.popup ? item : null;
  }

  onHistorySave() { this.clearMenu(); }

  clearMenu() {
    this.sync(false);
    for (const item of this.popup.querySelectorAll('[data-highlighted]')) {
      this.item(item, '[data-highlighted]')?.removeAttribute('data-highlighted');
    }
  }

  sync(open) {
    setOpenState(this.popup, open);
    this.trigger.setAttribute('aria-expanded', String(open));
    this.trigger.toggleAttribute('data-popup-open', open);
  }

  close() {
    this.popup.hidePopover();
    this.trigger.focus({ preventScroll: true });
  }

  keydown(event) {
    if (event.defaultPrevented) return;
    const { key } = event;
    if (event.target === this.trigger) {
      if (this.submenu ? key !== 'ArrowRight' : key !== 'ArrowDown' && key !== 'ArrowUp') return;
      if (this.submenu && !this.trigger.matches(MENU_ITEM)) return;
      event.preventDefault();
      this.focusLast = key === 'ArrowUp';
      this.popup.showPopover({ source: this.trigger });
      return;
    }
    if (event.target.closest('[role=menu]') !== this.popup || !this.popup.matches(':popover-open')) return;
    if (key === 'Escape' || key === 'Tab' || (this.submenu && key === 'ArrowLeft')) {
      if (key !== 'Tab') event.preventDefault();
      if (key === 'Tab') this.closeBranch();
      else this.close();
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

  closeBranch() {
    this.close();
    this.parentMenu?.closeBranch();
  }

  select(event) {
    const item = this.item(event.target);
    if (!item) return;
    if (item.dataset.slot === 'dropdown-menu-sub-trigger') return;
    if (item.getAttribute('role') === 'menuitemcheckbox') {
      const checked = item.getAttribute('aria-checked') !== 'true';
      item.setAttribute('aria-checked', String(checked));
      item.toggleAttribute('data-checked', checked);
    } else {
      this.closeBranch();
    }
    item.dispatchEvent(new CustomEvent('tl-select', { bubbles: true, detail: { item } }));
  }
}
customElements.define('tl-dropdown-menu', TlDropdownMenu);
