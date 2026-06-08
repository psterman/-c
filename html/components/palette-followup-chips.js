/**
 * palette-followup-chips — Lit Web Component (Light DOM, v3 suggest zone)
 * 渲染 + dispatch palette-action；input/toast 不写；反馈由 palette-action-result / onPrefillFeedback 驱动
 */
(function () {
  var Lit = globalThis.Lit;
  if (!Lit || !Lit.LitElement || !Lit.html) return;

  var LitElement = Lit.LitElement;
  var html = Lit.html;
  var CONFIRMED_MS = 1600;

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
        activeChipId: { type: String },
        selectedChipId: { type: String },
        confirmedChipId: { type: String },
        focusedIndex: { type: Number }
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
      this.selectedChipId = "";
      this.confirmedChipId = "";
      this.focusedIndex = -1;
      this._boundActionResult = null;
      this._confirmTimer = null;
      this.onPrefillFeedback = null;
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
        self._onPrefillFeedback(d.chipId, d);
      };
      document.addEventListener("palette-action-result", this._boundActionResult);
    }

    disconnectedCallback() {
      if (this._boundActionResult) {
        document.removeEventListener("palette-action-result", this._boundActionResult);
        this._boundActionResult = null;
      }
      if (this._confirmTimer) {
        clearTimeout(this._confirmTimer);
        this._confirmTimer = null;
      }
      super.disconnectedCallback();
    }

    updated(changed) {
      if (changed.has("visible")) {
        if (this.visible) {
          this.removeAttribute("hidden");
          if (this.displayChips.length && this.focusedIndex < 0) this.focusedIndex = 0;
        } else {
          this.setAttribute("hidden", "");
        }
      }
      if (changed.has("focusedIndex") && this.focusedIndex >= 0) {
        this._focusChipAt(this.focusedIndex);
      }
    }

    _focusChipAt(index) {
      var track = this.querySelector(".followup-chips-track");
      if (!track) return;
      var buttons = track.querySelectorAll(".card-followup-chip");
      if (!buttons.length || index < 0 || index >= buttons.length) return;
      try {
        buttons[index].focus();
      } catch (_) {}
    }

    _onPrefillFeedback(chipId, detail) {
      if (typeof this.onPrefillFeedback === "function") {
        try {
          this.onPrefillFeedback({ chipId: chipId, cardId: this.cardId, detail: detail || {} });
        } catch (_) {}
      }
      this.selectedChipId = chipId;
      this.activeChipId = chipId;
      this.confirmedChipId = chipId;
      var list = this.displayChips;
      for (var i = 0; i < list.length; i++) {
        if (list[i] && list[i].id === chipId) {
          this.focusedIndex = i;
          break;
        }
      }
      var self = this;
      if (this._confirmTimer) clearTimeout(this._confirmTimer);
      this._confirmTimer = setTimeout(function () {
        if (self.confirmedChipId === chipId) self.confirmedChipId = "";
        self._confirmTimer = null;
      }, CONFIRMED_MS);
    }

    _onChipActivate(chip, index) {
      if (!chip || !chip.id) return;
      this.selectedChipId = chip.id;
      this.focusedIndex = index;
      this.dispatchEvent(
        new CustomEvent("palette-action", {
          bubbles: true,
          composed: true,
          detail: buildActionDetail(this, chip)
        })
      );
    }

    _onChipClick(chip, index) {
      this._onChipActivate(chip, index);
    }

    _onTrackKeydown(e) {
      var list = this.displayChips;
      if (!list.length) return;
      var key = e.key;
      if (key === "ArrowRight" || key === "ArrowLeft") {
        e.preventDefault();
        var next = this.focusedIndex < 0 ? 0 : this.focusedIndex;
        if (key === "ArrowRight") next = Math.min(list.length - 1, next + 1);
        else next = Math.max(0, next - 1);
        this.focusedIndex = next;
        return;
      }
      if (key === "Enter" || key === " ") {
        var idx = this.focusedIndex < 0 ? 0 : this.focusedIndex;
        var chip = list[idx];
        if (!chip) return;
        e.preventDefault();
        this._onChipActivate(chip, idx);
      }
    }

    _chipClasses(chip, index) {
      var cls = "card-followup-chip";
      if (index === 0) cls += " is-primary";
      if (this.selectedChipId && chip.id === this.selectedChipId) cls += " is-selected";
      if (this.confirmedChipId && chip.id === this.confirmedChipId) cls += " is-confirmed";
      if (this.focusedIndex === index) cls += " is-focused";
      if (this.activeChipId && chip.id === this.activeChipId) cls += " is-active";
      return cls;
    }

    _chipDisplayLabel(chip) {
      if (this.confirmedChipId && chip.id === this.confirmedChipId) return "已填入 ✓";
      return chipLabel(chip);
    }

    render() {
      var list = this.displayChips;
      if (!this.visible || !list.length) return html``;
      var self = this;
      return html`
        <div class="followup-suggest-zone">
          <div class="followup-suggest-label">建议继续</div>
          <div
            class="followup-chips-track"
            role="toolbar"
            aria-label="建议继续"
            @keydown=${function (e) {
              self._onTrackKeydown(e);
            }}
          >
            ${list.map(function (chip, index) {
              var act = chipAction(chip);
              return html`
                <button
                  type="button"
                  class=${self._chipClasses(chip, index)}
                  data-chip-id=${chip.id || ""}
                  data-prefill=${act.value || ""}
                  tabindex=${(self.focusedIndex < 0 && index === 0) || self.focusedIndex === index ? "0" : "-1"}
                  @click=${function () {
                    self._onChipClick(chip, index);
                  }}
                >
                  ${escText(self._chipDisplayLabel(chip))}
                </button>
              `;
            })}
          </div>
        </div>
      `;
    }
  }

  if (!customElements.get("palette-followup-chips")) {
    customElements.define("palette-followup-chips", PaletteFollowupChips);
  }
})();
