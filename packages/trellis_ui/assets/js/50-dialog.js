class TlDialog extends TlElement {
  get dialog() { return this.querySelector(':scope > dialog'); }
  get sheet() { return this.dataset.slot === 'sheet'; }
  get sheetTrigger() { return this.querySelector(':scope > [data-slot=sheet-trigger] button'); }

  onConnect() {
    if (this.sheet && this.sheetTrigger) this.connectSheet();
    const dialog = this.dialog;
    if (!dialog) return;
    this.observeExit(dialog);
    this.listen(this, 'click', (event) => this.clickDialog(event));
    this.listen(dialog, 'keydown', (event) => this.cycleTab(event));
    if (dialog.hasAttribute('data-command-palette')) this.connectPalette(dialog);
    this.listen(dialog, 'close', () => {
      if (!dialog.open) this.reflectClosed();
    });
    if (dialog.getAttribute('role') !== 'alertdialog') {
      this.listen(dialog, 'pointerdown', (event) => { this.backdropDown = this.onBackdrop(event); });
    }
    if (!this.sheet && dialog.open) {
      dialog.removeAttribute('open');
      this.openDialog(document.activeElement);
    }
  }

  connectPalette(dialog) {
    this.listen(dialog, 'tl-select', event => {
      if (event.target.matches('[role="option"]') && event.target.closest('dialog') === dialog) this.closeDialog();
    });

    const shortcut = dialog.dataset.shortcut?.toLowerCase();
    if (!shortcut || !/^[a-z]$/.test(shortcut)) return;
    this.listen(document, 'keydown', event => {
      if (event.defaultPrevented || event.repeat || event.isComposing || event.altKey || event.shiftKey ||
          event.ctrlKey === event.metaKey || event.key.toLowerCase() !== shortcut ||
          dialog.closest('[data-palette-inactive]') || document.querySelector('dialog:modal')) return;
      if (event.target.isContentEditable || event.target.matches?.('input:not(:read-only), textarea:not(:read-only), select')) return;
      event.preventDefault();
      this.openDialog(document.activeElement);
    });
  }

  connectSheet() {
    let dialog = this.dialog;
    if (!dialog) {
      const fallback = this.querySelector(':scope > [data-slot=sheet-content]');
      dialog = document.createElement('dialog');
      for (const { name, value } of fallback.attributes) dialog.setAttribute(name, value);
      dialog.append(...fallback.childNodes);
      fallback.replaceWith(dialog);
    }
    if (!['top', 'right', 'bottom', 'left'].includes(dialog.dataset.side)) dialog.dataset.side = 'right';
    const trigger = this.sheetTrigger;
    trigger.setAttribute('aria-controls', dialog.id);
    trigger.setAttribute('aria-haspopup', 'dialog');
    trigger.setAttribute('aria-expanded', 'false');
    const close = dialog.querySelector('[data-slot=sheet-close]');
    const setInline = ({ matches }) => {
      const focused = document.activeElement;
      this.clearExit();
      if (dialog.matches(':modal')) withoutOverlayExit(() => this.closeDialog(false));
      dialog.toggleAttribute('open', matches);
      trigger.closest('[data-slot=sheet-trigger]').hidden = matches;
      close.hidden = matches;
      if (dialog.contains(focused) || focused === trigger) {
        const next = matches ? (dialog.contains(focused) && focused.checkVisibility() ? focused : this.tabStops()[0]) : trigger;
        next?.focus({ preventScroll: true });
      }
    };
    const width = Number(this.dataset.inlineAbove);
    const media = Number.isFinite(width) && width >= 0 ? matchMedia(`(width > ${width}px)`) : null;
    if (media) this.listen(media, 'change', setInline);
    setInline(media ?? { matches: false });
    // Text-only swaps have no afterSettle target.
    const recoverFocus = new MutationObserver((changes) => {
      if (dialog.matches(':modal') && !dialog.contains(document.activeElement) &&
          changes.some(change => change.removedNodes.length)) {
        this.tabStops()[0]?.focus({ preventScroll: true });
      }
    });
    recoverFocus.observe(dialog, { childList: true, subtree: true });
    this.listeners.signal.addEventListener('abort', () => recoverFocus.disconnect(), { once: true });
  }

  onBackdrop(event) {
    if (event.target !== this.dialog) return false;
    const {left, right, top, bottom} = this.dialog.getBoundingClientRect();
    return event.clientX < left || event.clientX >= right || event.clientY < top || event.clientY >= bottom;
  }

  tabStops() {
    const candidates = this.dialog.querySelectorAll('a[href], button, input, select, textarea, summary, [tabindex], [contenteditable]');
    const stops = [...candidates].filter(element => {
      // Editing hosts may report tabIndex -1.
      const editable = element.isContentEditable && !element.hasAttribute('tabindex') && !element.parentElement.isContentEditable;
      if ((element.tabIndex < 0 && !editable) || element.matches(':disabled') || element.closest('[inert]')) return false;
      const { visibility, interactivity } = getComputedStyle(element);
      return visibility === 'visible' && interactivity !== 'inert' && element.checkVisibility();
    });
    const active = document.activeElement;
    return stops.filter(radio => radio.type !== 'radio' || !radio.name || radio === active || !stops.some(other =>
      other.type === radio.type && other.name === radio.name && other.form === radio.form &&
      (other === active || other.checked && !radio.checked)
    )).sort((a, b) => (Math.max(a.tabIndex, 0) || Infinity) - (Math.max(b.tabIndex, 0) || Infinity));
  }

  cycleTab(event) {
    const dialog = this.dialog;
    if (event.key !== 'Tab' || event.defaultPrevented || event.target.closest('dialog') !== dialog ||
        !dialog.matches(':modal')) return;
    // Tab can reach browser chrome.
    const tabs = this.tabStops();
    const [from, to] = event.shiftKey ? [tabs[0], tabs.at(-1)] : [tabs.at(-1), tabs[0]];
    if (event.target !== from) return;
    event.preventDefault();
    to.focus();
  }

  clickDialog(event) {
    const target = event.target;
    if (target.closest('tl-dialog') !== this) return;
    if (target.closest('[data-slot=dialog-trigger], [data-slot=sheet-trigger]')) {
      this.openDialog(target.closest('button, a[href]') || document.activeElement);
    } else if (target.closest('[data-dialog-close], [data-slot=alert-dialog-action] button') ||
        (this.backdropDown && this.onBackdrop(event))) {
      this.closeDialog();
    } else if (this.sheet && this.dialog.matches(':modal') && target.closest('a[href]') && !(
        event.metaKey || event.ctrlKey || event.altKey || event.shiftKey)) {
      this.closeDialog(false);
    }
  }

  openDialog(opener) {
    const dialog = this.dialog;
    if (dialog.open) return;
    this.opener = document.getElementById(dialog.dataset.returnFocus) || opener;
    if (dialog.hasAttribute('data-command-palette')) dialog.querySelector('tl-combobox').resetQuery();
    if (this.sheet) {
      // Avoid restoring focus on link dismissal.
      document.activeElement?.blur();
    }
    dialog.showModal();
    if (this.sheet && !dialog.open) return this.returnFocus();
    setOpenState(dialog, true);
    if (this.sheet) {
      dialog.setAttribute('aria-modal', 'true');
      this.sheetTrigger.setAttribute('aria-expanded', 'true');
    }
  }

  closeDialog(restore = true) {
    this.dialog.close();
    this.reflectClosed(restore);
  }

  reflectClosed(restore = true) {
    if (!this.dialog.hasAttribute('data-open')) return;
    setOpenState(this.dialog, false);
    if (this.sheet) {
      this.preparePopups(this.dialog);
      this.dialog.removeAttribute('aria-modal');
      this.sheetTrigger.setAttribute('aria-expanded', 'false');
    }
    if (restore) this.returnFocus();
  }

  returnFocus() {
    if (this.opener?.isConnected) this.opener.focus({preventScroll: true});
  }

  onHistorySave() {
    if (this.dialog?.open && (!this.sheet || this.dialog.matches(':modal'))) this.closeDialog();
  }

  onDisconnect() {
    if (this.dialog?.open && (!this.sheet || this.dialog.hasAttribute('data-open'))) queueMicrotask(() => this.returnFocus());
  }
}

customElements.define('tl-dialog', TlDialog);
