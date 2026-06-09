/**
 * palette-comparison-table — Lit Web Component (Light DOM)
 * 只负责展示 canonical ComparisonTable props。
 */
(function () {
  var Lit = globalThis.Lit;
  if (!Lit || !Lit.LitElement || !Lit.html) return;

  var LitElement = Lit.LitElement;
  var html = Lit.html;

  class PaletteComparisonTable extends LitElement {
    static get properties() {
      return {
        cardId: { type: String, attribute: "card-id" },
        blockId: { type: String, attribute: "block-id" },
        columns: { type: Array },
        rows: { type: Array }
      };
    }

    constructor() {
      super();
      this.cardId = "";
      this.blockId = "";
      this.columns = [];
      this.rows = [];
    }

    createRenderRoot() {
      return this;
    }

    render() {
      var columns = Array.isArray(this.columns) ? this.columns : [];
      var rows = Array.isArray(this.rows) ? this.rows : [];
      if (!columns.length) return html``;
      return html`
        <div class="a2ui-comparison">
          <table class="a2ui-table">
            <thead>
              <tr>
                ${columns.map(function (column) {
                  return html`<th>${String(column == null ? "" : column)}</th>`;
                })}
              </tr>
            </thead>
            <tbody>
              ${rows.map(function (row) {
                var cells = Array.isArray(row) ? row : [];
                return html`
                  <tr>
                    ${columns.map(function (_, index) {
                      return html`<td>${String(cells[index] == null ? "" : cells[index])}</td>`;
                    })}
                  </tr>
                `;
              })}
            </tbody>
          </table>
        </div>
      `;
    }
  }

  if (!customElements.get("palette-comparison-table")) {
    customElements.define("palette-comparison-table", PaletteComparisonTable);
  }
})();
