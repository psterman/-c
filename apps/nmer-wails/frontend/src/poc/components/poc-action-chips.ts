import { LitElement, html } from 'lit';
import { customElement, property } from 'lit/decorators.js';

export interface ChipAction {
  id: string;
  label: string;
  intent?: string;
  payload?: Record<string, unknown>;
  tone?: string;
  disabled?: boolean;
}

@customElement('poc-action-chips')
export class PocActionChips extends LitElement {
  @property({ type: String, attribute: 'card-id' }) cardId = '';
  @property({ type: String, attribute: 'block-id' }) blockId = '';
  @property({ type: Array }) actions: ChipAction[] = [];

  createRenderRoot() {
    return this;
  }

  private onChipClick(action: ChipAction) {
    this.dispatchEvent(
      new CustomEvent('poc-chip-click', {
        bubbles: true,
        composed: true,
        detail: { action, cardId: this.cardId, blockId: this.blockId },
      })
    );
  }

  render() {
    const list = Array.isArray(this.actions) ? this.actions : [];
    return html`
      <div class="poc-chips-label">建议继续</div>
      <div class="poc-chips-track">
        ${list.map(
          (a) => html`
            <button
              type="button"
              class="poc-chip ${a.tone === 'danger' ? 'is-danger' : ''}"
              ?disabled=${!!a.disabled}
              @click=${() => this.onChipClick(a)}
            >
              ${a.label}
            </button>
          `
        )}
      </div>
    `;
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'poc-action-chips': PocActionChips;
  }
}
