import { LitElement, html } from 'lit';
import { customElement, property } from 'lit/decorators.js';

@customElement('poc-comparison-table')
export class PocComparisonTable extends LitElement {
  @property({ type: Array }) columns: string[] = [];
  @property({ type: Array }) rows: string[][] = [];

  createRenderRoot() {
    return this;
  }

  render() {
    const cols = Array.isArray(this.columns) ? this.columns : [];
    const rows = Array.isArray(this.rows) ? this.rows : [];
    return html`
      <div class="poc-a2ui-head">对比表格</div>
      <table class="poc-table">
        <thead>
          <tr>
            ${cols.map((c) => html`<th>${c}</th>`)}
          </tr>
        </thead>
        <tbody>
          ${rows.map(
            (row) => html`
              <tr>
                ${(row || []).map((cell) => html`<td>${cell}</td>`)}
              </tr>
            `
          )}
        </tbody>
      </table>
    `;
  }
}

declare global {
  interface HTMLElementTagNameMap {
    'poc-comparison-table': PocComparisonTable;
  }
}
