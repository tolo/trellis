class TlPopover extends TlElement {
  get trigger() { return this.querySelector(':scope > [data-slot="popover-trigger"]'); }
  get popup() { return this.querySelector(':scope > [data-slot="popover-content"]'); }

  onConnect() {
    const popup = this.popup;
    this.observeExit(popup);
    const options = { ...this.dataset };
    const reflect = (open) => {
      setOpenState(popup, open);
      this.trigger?.setAttribute('aria-expanded', String(open));
    };
    let retainFocus = false;
    const restoreFocus = () => {
      if (!document.activeElement?.closest(':popover-open')) this.trigger?.focus({ preventScroll: true });
    };
    reflect(popup.matches(':popover-open'));
    // Reflect close before an HTMX snapshot and open only after toggle.
    this.listen(popup, 'beforetoggle', ({ newState }) => {
      if (newState === 'closed') {
        retainFocus = false;
        reflect(false);
      }
    });
    this.listen(this, 'focusin', ({ target }) => {
      if (target === this.trigger && !popup.matches(':popover-open')) retainFocus = true;
    });
    this.listen(popup, 'toggle', () => {
      if (popup.matches(':popover-open')) {
        const trigger = this.trigger;
        if (!trigger) return popup.hidePopover();
        reflect(true);
        place(trigger, popup, options);
        if (!popup.contains(document.activeElement)) popup.focus({ preventScroll: true });
      } else if (!retainFocus) {
        restoreFocus();
      }
    });
    this.listen(popup, 'keydown', ({ key }) => {
      if (key !== 'Tab') return;
      // Let the browser choose the next control. Close before painting focus behind the panel.
      requestAnimationFrame(() => {
        if (popup.matches(':popover-open') && !popup.contains(document.activeElement)) {
          popup.hidePopover();
          retainFocus = true;
        }
      });
    });
    this.listen(this, 'click', (event) => {
      const trigger = this.trigger;
      if (!trigger?.contains(event.target)) return;
      if (popup.matches(':popover-open')) popup.hidePopover();
      else popup.showPopover({ source: trigger });
    });
    this.trackPopup(() => this.trigger, popup, options);
    this.trackHashDismissal(popup, restoreFocus);
  }

  trackHashDismissal(popup, restoreFocus) {
    let link, destination;
    this.listen(document, 'pointerdown', (event) => {
      destination = null;
      link = event.button === 0 && popup.matches(':popover-open') ? event.target.closest?.('a[href]') : null;
    }, { capture: true });
    this.listen(document, 'click', (event) => {
      const clicked = link;
      link = null;
      if (!clicked?.contains(event.target) || popup.contains(clicked) || popup.matches(':popover-open')) return;
      if (event.metaKey || event.ctrlKey || event.altKey || event.shiftKey || clicked.hasAttribute('download')) return;
      const { origin, pathname, search, hash, href } = new URL(clicked.href);
      if (hash && hash !== location.hash && origin === location.origin &&
          pathname === location.pathname && search === location.search) destination = href;
    }, { capture: true });
    // A same-page link can move focus after native light dismissal. Let the jump stand.
    this.listen(window, 'hashchange', ({ newURL }) => {
      if (newURL === destination && !popup.matches(':popover-open')) restoreFocus();
      destination = null;
    });
  }

  onBeforeSwap(region) {
    if (region?.contains(this.trigger)) this.preparePopups(this);
  }
}
customElements.define('tl-popover', TlPopover);
