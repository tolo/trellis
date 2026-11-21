class TlToast extends TlElement {
  onConnect() {
    const duration = Number(this.dataset.duration);
    this.remaining = duration > 0 ? duration : null;
    this.listen(this, 'click', (event) => {
      if (event.target.closest('[data-slot="toast-close"]')) this.remove();
    });
    this.listen(this, 'pointerdown', (event) => {
      if (event.pointerType === 'touch' && event.isPrimary) {
        this.swipe = { id: event.pointerId, x: event.clientX, y: event.clientY };
        this.updateTimer();
      }
    });
    const finishSwipe = (event) => {
      const start = this.swipe;
      if (start?.id !== event.pointerId) return;
      this.swipe = null;
      const dx = event.clientX - start.x;
      const dy = Math.abs(event.clientY - start.y);
      if (event.type === 'pointerup' && dx >= 56 && dx >= 1.5 * dy) this.remove();
      else this.updateTimer();
    };
    this.listen(this, 'pointerup', finishSwipe);
    this.listen(this, 'pointercancel', finishSwipe);
    this.listen(this, 'lostpointercapture', finishSwipe);
    if (this.remaining === null) return;
    this.listen(this, 'pointerover', () => this.updateTimer());
    this.listen(this, 'pointerout', (event) => {
      if (!this.contains(event.relatedTarget)) this.updateTimer(false);
    });
    this.listen(this, 'focusin', () => this.updateTimer());
    this.listen(this, 'focusout', () => queueMicrotask(() => this.updateTimer()));
    this.updateTimer();
  }

  onDisconnect() {
    clearTimeout(this.timer);
    this.started = null;
    this.swipe = null;
  }

  onHistorySave() { this.remove(); }

  updateTimer(hovered = this.matches(':hover')) {
    if (this.remaining === null) return;
    clearTimeout(this.timer);
    if (this.started != null) this.remaining -= performance.now() - this.started;
    this.started = null;
    if (!this.isConnected || this.swipe || hovered || this.contains(document.activeElement)) return;
    this.started = performance.now();
    this.timer = setTimeout(() => this.remove(), this.remaining);
  }
}
customElements.define('tl-toast', TlToast);
