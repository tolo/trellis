class TlTabs extends TlElement {
  onConnect() {
    this.listen(this, 'click', (event) => {
      const tab = event.target.closest('[role="tab"]');
      if (!tab || tab.disabled || !this.tabs.includes(tab)) return;
      for (const trigger of this.tabs) {
        const active = trigger === tab;
        trigger.setAttribute('aria-selected', String(active));
        trigger.toggleAttribute('data-active', active);
        const panel = document.getElementById(trigger.getAttribute('aria-controls'));
        panel.hidden = !active;
        panel.toggleAttribute('data-hidden', !active);
      }
      this.rove(tab);
    });
    this.listen(this, 'keydown', (event) => {
      const tabs = this.tabs.filter((tab) => !tab.disabled);
      const index = tabs.indexOf(event.target);
      if (index < 0) return;
      const vertical = this.firstElementChild.hasAttribute('data-vertical');
      const [previous, next] = vertical ? ['ArrowUp', 'ArrowDown'] : ['ArrowLeft', 'ArrowRight'];
      const target = {
        [previous]: tabs[(index - 1 + tabs.length) % tabs.length],
        [next]: tabs[(index + 1) % tabs.length],
        Home: tabs[0],
        End: tabs.at(-1),
      }[event.key];
      if (!target) return;
      event.preventDefault();
      this.rove(target);
      target.focus();
    });
    this.listen(this, 'focusout', (event) => {
      if (!this.tabs.includes(event.target) || this.tabs.includes(event.relatedTarget)) return;
      this.rove(this.tabs.find((tab) => tab.getAttribute('aria-selected') === 'true'));
    });
  }

  get tabs() {
    return [...this.querySelectorAll('[role="tab"]')].filter((tab) => tab.closest('tl-tabs') === this);
  }

  rove(target) {
    for (const tab of this.tabs) tab.tabIndex = tab === target ? 0 : -1;
  }
}
customElements.define('tl-tabs', TlTabs);
