/**
 * palette-steps — Lit Web Component (Light DOM)
 * 只负责展示 canonical Steps props。
 */
(function () {
  var Lit = globalThis.Lit;
  if (!Lit || !Lit.LitElement || !Lit.html) return;

  var LitElement = Lit.LitElement;
  var html = Lit.html;

  class PaletteSteps extends LitElement {
    static get properties() {
      return {
        cardId: { type: String, attribute: "card-id" },
        blockId: { type: String, attribute: "block-id" },
        items: { type: Array }
      };
    }

    constructor() {
      super();
      this.cardId = "";
      this.blockId = "";
      this.items = [];
    }

    createRenderRoot() {
      return this;
    }

    render() {
      var items = Array.isArray(this.items) ? this.items : [];
      if (!items.length) return html``;
      return html`
        <div class="a2ui-steps">
          <ol class="a2ui-steps-list">
            ${items.map(function (item) {
              return html`<li>${String(item == null ? "" : item)}</li>`;
            })}
          </ol>
        </div>
      `;
    }
  }

  if (!customElements.get("palette-steps")) {
    customElements.define("palette-steps", PaletteSteps);
  }
})();
