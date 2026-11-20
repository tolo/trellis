class TlNavigationMenu extends TlElement {
  onConnect() {
    if (!HTMLElement.prototype.showPopover) return;
    const panels = ':scope > ul > [data-slot=navigation-menu-item] > details';
    const openPanel = () => this.querySelector(`${panels} > :popover-open`);
    const pending = [];
    this.onPopupCleanup = () => pending.forEach(cancel => cancel());
    for (const details of this.querySelectorAll(panels)) {
      const [trigger, panel] = details.children;
      panel.popover = 'auto';
      const show = () => {
        pending.forEach(cancel => cancel());
        if (panel.matches(':popover-open')) return;
        details.open = true;
        panel.showPopover({ source: trigger });
        if (panel.matches(':popover-open')) place(trigger, panel, details.dataset);
        else details.open = false;
      };
      const hover = hoverIntent({
        open: show,
        close: () => { if (!details.contains(document.activeElement)) panel.hidePopover(); },
        openDelay: 180,
        closeDelay: 140,
      });
      pending.push(hover.cancel);
      this.listen(panel, 'beforetoggle', ({ newState }) => {
        if (newState !== 'closed') return;
        details.open = false;
        delete panel.dataset.side;
        delete panel.dataset.align;
      });
      this.listen(details, 'pointerenter', ({ pointerType }) => {
        if (pointerType !== 'touch') hover.enter();
      });
      this.listen(details, 'pointerleave', hover.leave);
      // Opening on focus and click is idempotent when a click first moves focus.
      this.listen(trigger, 'click', event => { event.preventDefault(); show(); });
      this.listen(trigger, 'focus', () => { if (openPanel()) show(); });
      this.listen(trigger, 'keydown', event => {
        if (event.key !== 'ArrowDown') return;
        event.preventDefault();
        show();
        panel.querySelector('a[href]')?.focus();
      });
      this.trackPopup(trigger, panel, details.dataset);
      if (details.open) show();
    }
    this.listen(this, 'focusout', ({ relatedTarget }) => {
      if (relatedTarget && !this.contains(relatedTarget)) this.preparePopups(this);
    });
    this.listen(document, 'keydown', event => {
      if (event.key !== 'Escape' || event.defaultPrevented) return;
      const panel = openPanel();
      if (!panel) return;
      event.preventDefault();
      this.preparePopups(this);
      panel.previousElementSibling.focus({ preventScroll: true });
    });
  }
}
customElements.define('tl-navigation-menu', TlNavigationMenu);
