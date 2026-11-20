class TlTooltip extends TlElement {
  static active;

  onConnect() {
    const trigger = this.querySelector('[data-slot="tooltip-trigger"]').firstElementChild;
    const hint = this.querySelector('[role="tooltip"]');
    if (!trigger || !hint.id) return;
    const descriptions = new Set((trigger.getAttribute('aria-describedby') || '').split(/\s+/).filter(Boolean));
    descriptions.add(hint.id);
    trigger.setAttribute('aria-describedby', [...descriptions].join(' '));

    const { side, openDelay, closeDelay } = this.dataset;
    const options = { side: ['top', 'right', 'bottom', 'left'].includes(side) ? side : 'top', align: 'center' };
    const visible = () => hint.matches(':popover-open');
    const show = () => {
      hover.cancel();
      if (visible() || trigger.closest('dialog:not([open]), [inert]')) return;
      TlTooltip.active?.dismiss();
      hint.showPopover({ source: trigger });
      if (!visible()) return;
      TlTooltip.active = this;
      place(trigger, hint, options);
      setOpenState(hint, true);
    };
    const hover = hoverIntent({
      open: show, close: () => { if (!trigger.matches(':focus-visible')) this.dismiss(); },
      openDelay: Number(openDelay), closeDelay: Number(closeDelay),
    });
    this.dismiss = () => {
      hover.cancel();
      if (visible()) hint.hidePopover();
    };
    this.listen(hint, 'beforetoggle', ({ newState }) => {
      if (newState !== 'closed') return;
      if (TlTooltip.active === this) TlTooltip.active = null;
      setOpenState(hint, false);
      if (hint.hasAttribute('style')) hint.removeAttribute('style');
    });

    for (const element of [trigger, hint]) {
      this.listen(element, 'pointerenter', ({ pointerType }) => {
        if (pointerType !== 'touch') hover.enter();
      });
      this.listen(element, 'pointerleave', hover.leave);
    }
    this.listen(trigger, 'focus', () => { if (trigger.matches(':focus-visible')) show(); });
    this.listen(trigger, 'blur', this.dismiss);
    const dialog = trigger.closest('dialog');
    if (dialog) this.listen(dialog, 'close', this.dismiss);

    this.listen(document, 'keydown', (event) => {
      if (event.key !== 'Escape') return;
      const modal = document.activeElement?.closest(':modal');
      if (visible() && (!modal || modal.contains(trigger))) {
        // Let a covering modal receive Escape, while keeping an enclosing modal open.
        event.preventDefault();
        event.stopPropagation();
      }
      this.dismiss();
    }, { capture: true });
    this.trackPopup(trigger, hint, options);
  }

  onPopupCleanup() { this.dismiss?.(); }
  onDisconnect() { if (TlTooltip.active === this) TlTooltip.active = null; }
}
customElements.define('tl-tooltip', TlTooltip);
