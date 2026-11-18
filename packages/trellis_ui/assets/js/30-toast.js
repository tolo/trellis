class TlToast extends TlElement {
  onConnect() {
    this.remaining = Number(this.dataset.duration);
    this.listen(this, 'click', (event) => {
      if (event.target.closest('[data-slot="toast-close"]')) this.remove();
    });
    if (!(this.remaining > 0)) return;
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
  }

  onHistorySave() { this.remove(); }

  updateTimer(hovered = this.matches(':hover')) {
    clearTimeout(this.timer);
    if (this.started != null) this.remaining -= performance.now() - this.started;
    this.started = null;
    if (!this.isConnected || hovered || this.contains(document.activeElement)) return;
    this.started = performance.now();
    this.timer = setTimeout(() => this.remove(), this.remaining);
  }
}
customElements.define('tl-toast', TlToast);
