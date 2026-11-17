class TlDialog extends TlElement {
  get dialog() { return this.querySelector(':scope > dialog'); }

  onConnect() {
    const dialog = this.dialog;
    this.listen(this, 'click', (event) => this.clickDialog(event));
    this.listen(dialog, 'keydown', (event) => this.cycleTab(event));
    this.listen(dialog, 'close', () => {
      if (!dialog.open) this.reflectClosed();
    });
    if (dialog.getAttribute('role') !== 'alertdialog') {
      this.listen(dialog, 'pointerdown', (event) => { this.backdropDown = this.onBackdrop(event); });
    }
    if (dialog.open) {
      // The parsed open attribute makes the dialog non-modal until we re-open it.
      dialog.removeAttribute('open');
      this.openDialog(document.activeElement);
    }
  }

  onBackdrop(event) {
    if (event.target !== this.dialog) return false;
    const {left, right, top, bottom} = this.dialog.getBoundingClientRect();
    return event.clientX < left || event.clientX >= right || event.clientY < top || event.clientY >= bottom;
  }

  cycleTab(event) {
    if (event.key !== 'Tab' || event.defaultPrevented || event.target.closest('dialog') !== this.dialog) return;
    // Native modality keeps the page inert, but Tab can still leave for browser chrome.
    const candidates = this.dialog.querySelectorAll('a[href], button, input, select, textarea, summary, [tabindex], [contenteditable]');
    const tabs = Array.from(candidates).filter((element) => element.tabIndex >= 0 &&
      !element.matches(':disabled') && !element.closest('[inert]') && element.getClientRects().length &&
      getComputedStyle(element).visibility === 'visible');
    const [from, to] = event.shiftKey ? [tabs[0], tabs.at(-1)] : [tabs.at(-1), tabs[0]];
    if (event.target !== from) return;
    event.preventDefault();
    to.focus();
  }

  clickDialog(event) {
    const target = event.target;
    if (target.closest('tl-dialog') !== this) return;
    if (target.closest('[data-slot=dialog-trigger]')) {
      this.openDialog(target.closest('button, a[href]') || document.activeElement);
    } else if (target.closest('[data-dialog-close], [data-slot=alert-dialog-action] button') ||
        (this.backdropDown && this.onBackdrop(event))) {
      this.closeDialog();
    }
  }

  openDialog(opener) {
    if (this.dialog.open) return;
    this.opener = document.getElementById(this.dialog.dataset.returnFocus) || opener;
    this.dialog.showModal();
    setOpenState(this.dialog, true);
  }

  closeDialog() {
    this.dialog.close();
    this.reflectClosed();
  }

  reflectClosed() {
    if (!this.dialog.hasAttribute('data-open')) return;
    setOpenState(this.dialog, false);
    this.returnFocus();
  }

  returnFocus() {
    if (this.opener?.isConnected) this.opener.focus({preventScroll: true});
  }

  onHistorySave() {
    if (this.dialog.open) this.closeDialog();
  }

  onDisconnect() {
    // A replacement modal may already have taken focus as htmx inserts it first.
    if (this.dialog?.open) queueMicrotask(() => this.returnFocus());
  }
}

customElements.define('tl-dialog', TlDialog);
