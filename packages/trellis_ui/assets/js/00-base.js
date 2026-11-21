const popupSelector = '[popover][data-trellis-popup]';

class TlElement extends HTMLElement {
  connectedCallback() {
    this.listeners = new AbortController();
    this.onConnect();
    this.listen(document.body, 'htmx:beforeSwap', (event) => {
      const region = event.detail?.target;
      if (region?.contains(this) || this.contains(region)) this.clearExit();
      withoutOverlayExit(() => {
        this.preparePopups(region);
        this.onBeforeSwap?.(region);
      });
    });
    this.listen(document.body, 'htmx:beforeHistorySave', () => {
      this.clearExit();
      withoutOverlayExit(() => {
        this.onHistorySave?.();
        this.preparePopups(this);
      });
    });
  }

  disconnectedCallback() {
    this.listeners.abort();
    this.clearExit();
    withoutOverlayExit(() => {
      this.onDisconnect?.();
      this.preparePopups(this);
    });
  }

  listen(target, type, callback, options = {}) {
    target.addEventListener(type, callback, { ...options, signal: this.listeners.signal });
  }

  preparePopups(region) {
    if (region?.contains(this)) this.onPopupCleanup?.();
    // htmx settles matching IDs by copying attributes. CSSOM positioning is safe
    // under CSP until htmx copies it or serializes it into a history snapshot.
    for (const popup of this.querySelectorAll(popupSelector)) {
      if (region?.contains(popup)) {
        clearOverlayExit(popup);
        if (popup.matches(':popover-open')) withoutOverlayExit(() => popup.hidePopover());
      }
      // Blink can leave an empty attribute if it hasn't materialized the CSSOM
      // writes yet. Drop the presence read when removeAttribute alone clears it.
      if (!popup.matches(':popover-open, [data-trellis-overlay-exit="native"]') && popup.hasAttribute('style')) {
        popup.removeAttribute('style');
      }
    }
  }

  observeExit(surface) {
    this.exitSurface = surface;
    this.listen(surface, 'beforetoggle', ({ newState }) => {
      clearOverlayExit(surface);
      if (newState === 'closed') startOverlayExit(surface);
    });
  }

  clearExit() { clearOverlayExit(this.exitSurface); }

  trackPopup(anchor, popup, options = {}) {
    const findAnchor = typeof anchor === 'function' ? anchor : () => anchor;
    const reposition = (event) => {
      if (popup.contains(event.target instanceof Node ? event.target : null) || !popup.matches(':popover-open')) return;
      const currentAnchor = findAnchor();
      if (currentAnchor) place(currentAnchor, popup, options);
    };
    this.listen(window, 'resize', reposition);
    this.listen(document, 'scroll', reposition, { capture: true });
  }
}

function setOpenState(element, open) {
  element.toggleAttribute('data-open', open);
  element.toggleAttribute('data-closed', !open);
}

function place(anchor, popup, { side, align, offset } = {}) {
  if (!['top', 'right', 'bottom', 'left'].includes(side)) side = 'bottom';
  if (!['start', 'center', 'end'].includes(align)) align = 'start';
  offset = Number.isFinite(Number(offset)) ? Number(offset) : 4;
  const edge = 4;
  const rect = anchor.getBoundingClientRect();
  const style = popup.style;
  const maxWidth = Math.max(0, innerWidth - 2 * edge);
  const maxHeight = Math.max(0, innerHeight - 2 * edge);
  style.setProperty('--anchor-width', `${rect.width}px`);
  // Restore viewport caps before measuring so a previously clipped panel can grow.
  style.setProperty('--available-width', `${maxWidth}px`);
  style.setProperty('--available-height', `${maxHeight}px`);
  const opposite = { top: 'bottom', right: 'left', bottom: 'top', left: 'right' };
  const available = {
    top: rect.top - offset - edge,
    right: innerWidth - rect.right - offset - edge,
    bottom: innerHeight - rect.bottom - offset - edge,
    left: rect.left - offset - edge,
  };
  const horizontal = side === 'left' || side === 'right';
  const naturalSize = horizontal ? popup.offsetWidth : popup.offsetHeight;
  const otherSide = opposite[side];
  if (available[side] < naturalSize && available[otherSide] > available[side]) side = otherSide;
  // If the anchor itself fills the viewport, allow the panel to overlap it.
  const space = Math.min(available[side], horizontal ? maxWidth : maxHeight);
  if (space > 0) style.setProperty(horizontal ? '--available-width' : '--available-height', `${space}px`);

  const width = popup.offsetWidth, height = popup.offsetHeight;
  const aligned = (start, end, size) =>
    align === 'end' ? end - size : align === 'center' ? (start + end - size) / 2 : start;
  const x = horizontal
    ? side === 'left' ? rect.left - width - offset : rect.right + offset
    : aligned(rect.left, rect.right, width);
  const y = horizontal
    ? aligned(rect.top, rect.bottom, height)
    : side === 'top' ? rect.top - height - offset : rect.bottom + offset;
  style.left = `${Math.max(edge, Math.min(x, innerWidth - width - edge))}px`;
  style.top = `${Math.max(edge, Math.min(y, innerHeight - height - edge))}px`;
  const across = horizontal
    ? { start: 'top', center: 'center', end: 'bottom' }
    : { start: 'left', center: 'center', end: 'right' };
  style.setProperty('--transform-origin', `${opposite[side]} ${across[align]}`);
  popup.dataset.side = side;
  popup.dataset.align = align;
}

function hoverIntent({ open, close, openDelay, closeDelay }) {
  let timer;
  const cancel = () => clearTimeout(timer);
  const schedule = (action, delay) => {
    cancel();
    timer = setTimeout(action, delay);
  };
  return {
    enter: () => schedule(open, openDelay),
    leave: () => schedule(close, closeDelay),
    cancel,
  };
}
