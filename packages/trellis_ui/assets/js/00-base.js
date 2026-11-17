const popupSelector = '[popover][data-trellis-popup]';

class TlElement extends HTMLElement {
  connectedCallback() {
    this.listeners = new AbortController();
    this.onConnect();
    this.listen(document.body, 'htmx:beforeSwap', (event) => this.preparePopups(event.detail?.target));
    this.listen(document.body, 'htmx:beforeHistorySave', () => {
      this.onHistorySave?.();
      this.preparePopups(this);
    });
  }

  disconnectedCallback() {
    this.listeners.abort();
    this.onDisconnect?.();
  }

  listen(target, type, callback, options = {}) {
    target.addEventListener(type, callback, { ...options, signal: this.listeners.signal });
  }

  preparePopups(region) {
    // htmx settles matching IDs by copying attributes. CSSOM positioning is safe
    // under CSP until htmx copies it or serializes it into a history snapshot.
    for (const popup of this.querySelectorAll(popupSelector)) {
      if (region?.contains(popup) && popup.matches(':popover-open')) popup.hidePopover();
      // Blink can leave an empty attribute if it hasn't materialized the CSSOM
      // writes yet. Drop the presence read when removeAttribute alone clears it.
      if (!popup.matches(':popover-open') && popup.hasAttribute('style')) popup.removeAttribute('style');
    }
  }

  trackPopup(anchor, popup, options = {}) {
    const reposition = () => {
      if (popup.matches(':popover-open')) place(anchor, popup, options);
    };
    this.listen(window, 'resize', reposition);
    this.listen(document, 'scroll', reposition, { capture: true });
  }
}

function setOpenState(element, open) {
  element.toggleAttribute('data-open', open);
  element.toggleAttribute('data-closed', !open);
}

function place(anchor, popup, { align = 'start', offset = 4 } = {}) {
  const edge = 4;
  const rect = anchor.getBoundingClientRect();
  const style = popup.style;
  style.setProperty('--anchor-width', `${rect.width}px`);
  // Measure against the full viewport so a previous height cap cannot bias the flip.
  style.setProperty('--available-height', `${innerHeight - 2 * edge}px`);
  const below = innerHeight - rect.bottom - offset - edge;
  const above = rect.top - offset - edge;
  const top = below < popup.offsetHeight && above > below;
  style.setProperty('--available-height', `${Math.max(0, top ? above : below)}px`);
  const width = popup.offsetWidth;
  const height = popup.offsetHeight;
  const x = align === 'end' ? rect.right - width : rect.left;
  const y = top ? rect.top - height - offset : rect.bottom + offset;
  style.left = `${Math.max(edge, Math.min(x, innerWidth - width - edge))}px`;
  style.top = `${Math.max(edge, Math.min(y, innerHeight - height - edge))}px`;
  style.setProperty('--transform-origin', `${top ? 'bottom' : 'top'} ${align === 'end' ? 'right' : 'left'}`);
  popup.dataset.side = top ? 'top' : 'bottom';
  popup.dataset.align = align;
}
