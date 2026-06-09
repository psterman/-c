/**
 * palette-alert — Lit Web Component (Light DOM)
 * 只负责展示 canonical Alert props。
 */
(function () {
  var Lit = globalThis.Lit;
  if (!Lit || !Lit.LitElement || !Lit.html) return;

  var LitElement = Lit.LitElement;
  var html = Lit.html;

  class PaletteAlert extends LitElement {
    static get properties() {
      return {
        cardId: { type: String, attribute: "card-id" },
        blockId: { type: String, attribute: "block-id" },
        variant: { type: String },
        text: { type: String }
      };
    }

    constructor() {
      super();
      this.cardId = "";
      this.blockId = "";
      this.variant = "info";
      this.text = "";
    }

    createRenderRoot() {
      return this;
    }

    render() {
      var text = String(this.text || "").trim();
      if (!text) return html``;
      var variant = String(this.variant || "info").trim() || "info";
      return html`
        <div class="a2ui-alert a2ui-alert-${variant}">
          ${text}
        </div>
      `;
    }
  }

  if (!customElements.get("palette-alert")) {
    customElements.define("palette-alert", PaletteAlert);
  }
})();
