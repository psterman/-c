/**

 * palette-followup-chips — Lit Web Component (Light DOM, v2)

 * 渲染 + dispatch palette-action；input/toast 不写；active 由 palette-action-result 驱动

 */

(function () {

  var Lit = globalThis.Lit;

  if (!Lit || !Lit.LitElement || !Lit.html) return;



  var LitElement = Lit.LitElement;

  var html = Lit.html;



  function escText(s) {

    return String(s || "")

      .replace(/&/g, "&amp;")

      .replace(/</g, "&lt;")

      .replace(/>/g, "&gt;");

  }



  function chipLabel(chip) {

    return chip.label || chip.id || "";

  }



  function chipAction(chip) {

    if (chip && chip.action && chip.action.type) return chip.action;

    return {

      type: "prefill",

      value: (chip && chip.action && chip.action.value) || chip.prefill || chip.label || ""

    };

  }



  function buildActionDetail(self, chip) {

    if (globalThis.PaletteUIEventContract && PaletteUIEventContract.buildChipClickDetail) {

      return PaletteUIEventContract.buildChipClickDetail({

        cardId: self.cardId,

        chip: { id: chip.id, label: chipLabel(chip), intent: chip.intent },

        action: chipAction(chip),

        dataSource: self.dataSource || "merged",

        renderer: "lit",

        component: "follow-up-chips",

        slot: "actions"

      });

    }

    return {

      kind: "chip_click",

      component: "follow-up-chips",

      slot: "actions",

      cardId: self.cardId,

      chipId: chip.id,

      chip: { id: chip.id, label: chipLabel(chip) },

      action: chipAction(chip),

      dataSource: self.dataSource || "merged",

      renderer: "lit"

    };

  }



  class PaletteFollowupChips extends LitElement {

    static get properties() {

      return {

        cardId: { type: String, attribute: "card-id" },

        routeId: { type: String, attribute: "route-id" },

        dataSource: { type: String, attribute: "data-source" },

        chips: { type: Array },

        actions: { type: Array },

        visible: { type: Boolean },

        activeChipId: { type: String }

      };

    }



    constructor() {

      super();

      this.cardId = "";

      this.routeId = "";

      this.dataSource = "merged";

      this.chips = [];

      this.actions = [];

      this.visible = false;

      this.activeChipId = "";

      this._boundActionResult = null;

    }



    createRenderRoot() {

      return this;

    }



    get displayChips() {

      if (this.chips && this.chips.length) return this.chips;

      return this.actions || [];

    }



    connectedCallback() {

      super.connectedCallback();

      var self = this;

      this._boundActionResult = function (e) {

        var d = e && e.detail;

        if (!d || !d.ok || d.cardId !== self.cardId || !d.chipId) return;

        self._flashChip(d.chipId);

      };

      document.addEventListener("palette-action-result", this._boundActionResult);

    }



    disconnectedCallback() {

      if (this._boundActionResult) {

        document.removeEventListener("palette-action-result", this._boundActionResult);

        this._boundActionResult = null;

      }

      super.disconnectedCallback();

    }



    updated(changed) {

      if (changed.has("visible")) {

        if (this.visible) this.removeAttribute("hidden");

        else this.setAttribute("hidden", "");

      }

    }



    _flashChip(chipId) {

      this.activeChipId = chipId;

      var self = this;

      setTimeout(function () {

        if (self.activeChipId === chipId) self.activeChipId = "";

      }, 200);

    }



    _onChipClick(chip) {

      if (!chip || !chip.id) return;

      this.dispatchEvent(

        new CustomEvent("palette-action", {

          bubbles: true,

          composed: true,

          detail: buildActionDetail(this, chip)

        })

      );

    }



    render() {

      var list = this.displayChips;

      if (!this.visible || !list.length) {

        return html``;

      }

      var self = this;

      return html`

        ${list.map(function (chip) {

          var act = chipAction(chip);

          var isActive = self.activeChipId && chip.id === self.activeChipId;

          return html`

            <button

              type="button"

              class="card-followup-chip${isActive ? " is-active" : ""}"

              data-chip-id=${chip.id || ""}

              data-prefill=${act.value || ""}

              @click=${function () {

                self._onChipClick(chip);

              }}

            >

              ${escText(chipLabel(chip))}

            </button>

          `;

        })}

      `;

    }

  }



  if (!customElements.get("palette-followup-chips")) {

    customElements.define("palette-followup-chips", PaletteFollowupChips);

  }

})();


