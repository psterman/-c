/**
 * palette-action-chips — Lit Web Component (Light DOM)
 * 仅渲染 + dispatch a2ui-action；不读写 input、不 submit。
 */
(function () {
  var Lit = globalThis.Lit;
  if (!Lit || !Lit.LitElement || !Lit.html) return;

  var LitElement = Lit.LitElement;
  var html = Lit.html;
  var eventSequence = 0;
  var ACTIVATION_DEBOUNCE_MS = 350;

  function escText(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

  function cloneAction(action) {
    action = action || {};
    var payload =
      action.payload && typeof action.payload === "object" && !Array.isArray(action.payload)
        ? Object.assign({}, action.payload)
        : {};
    return {
      id: String(action.id || ""),
      label: String(action.label || ""),
      intent: String(action.intent || "prefill"),
      payload: payload,
      tone: action.tone ? String(action.tone) : "",
      disabled: !!action.disabled
    };
  }

  function createActionEventDetail(component, action) {
    eventSequence += 1;
    return {
      version: 1,
      eventId: "a2ui-" + Date.now() + "-" + eventSequence,
      timestamp: Date.now(),
      cardId: String(component.cardId || ""),
      blockId: String(component.blockId || ""),
      action: cloneAction(action),
      state: {
        selectedActionId: String(component.selectedActionId || ""),
        pendingActionId: String(component.pendingActionId || "")
      }
    };
  }

  class PaletteActionChips extends LitElement {
    static get properties() {
      return {
        cardId: { type: String, attribute: "card-id" },
        blockId: { type: String, attribute: "block-id" },
        actions: { type: Array },
        disabled: { type: Boolean },
        pendingActionId: { type: String, attribute: "pending-action-id" },
        selectedActionId: { type: String, attribute: "selected-action-id" },
        focusedIndex: { type: Number }
      };
    }

    constructor() {
      super();
      this.cardId = "";
      this.blockId = "";
      this.actions = [];
      this.disabled = false;
      this.pendingActionId = "";
      this.selectedActionId = "";
      this.focusedIndex = -1;
      this._activationLocks = {};
    }

    createRenderRoot() {
      return this;
    }

    get displayActions() {
      return Array.isArray(this.actions) ? this.actions : [];
    }

    _chipClasses(action, index) {
      var cls = "card-followup-chip";
      if (index === 0) cls += " is-primary";
      if (action.tone === "danger") cls += " is-danger";
      if (this.selectedActionId && action.id === this.selectedActionId) cls += " is-selected";
      if (this.pendingActionId && action.id === this.pendingActionId) cls += " is-pending";
      if (this.focusedIndex === index) cls += " is-focused";
      return cls;
    }

    _isChipDisabled(action) {
      return !!this.disabled || !!action.disabled || !!(this.pendingActionId && action.id === this.pendingActionId);
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

    _onChipActivate(action, index) {
      if (!action || !action.id) return;
      if (this._isChipDisabled(action)) return;
      if (this._activationLocks[action.id]) return;
      this._activationLocks[action.id] = true;
      var self = this;
      setTimeout(function () {
        delete self._activationLocks[action.id];
      }, ACTIVATION_DEBOUNCE_MS);
      this.selectedActionId = action.id;
      this.focusedIndex = index;
      this.dispatchEvent(
        new CustomEvent("a2ui-action", {
          bubbles: true,
          composed: true,
          detail: createActionEventDetail(this, action)
        })
      );
    }

    _onTrackKeydown(e) {
      var list = this.displayActions;
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
        var action = list[idx];
        if (!action || this._isChipDisabled(action)) return;
        e.preventDefault();
        this._onChipActivate(action, idx);
      }
    }

    updated(changed) {
      if (changed.has("focusedIndex") && this.focusedIndex >= 0) {
        this._focusChipAt(this.focusedIndex);
      }
    }

    render() {
      var list = this.displayActions;
      if (!list.length) return html``;
      var self = this;
      return html`
        <div class="followup-suggest-zone action-chips-zone">
          <div class="followup-suggest-label">建议继续</div>
          <div
            class="followup-chips-track"
            role="toolbar"
            aria-label="操作选项"
            @keydown=${function (e) {
              self._onTrackKeydown(e);
            }}
          >
            ${list.map(function (action, index) {
              var chipDisabled = self._isChipDisabled(action);
              return html`
                <button
                  type="button"
                  class=${self._chipClasses(action, index)}
                  data-action-id=${action.id || ""}
                  aria-disabled=${chipDisabled ? "true" : "false"}
                  ?disabled=${chipDisabled}
                  tabindex=${(self.focusedIndex < 0 && index === 0) || self.focusedIndex === index ? "0" : "-1"}
                  @click=${function () {
                    self._onChipActivate(action, index);
                  }}
                >
                  ${escText(action.label || action.id || "")}
                </button>
              `;
            })}
          </div>
        </div>
      `;
    }
  }

  if (!customElements.get("palette-action-chips")) {
    customElements.define("palette-action-chips", PaletteActionChips);
  }

  globalThis.PaletteActionChipsEventContract = {
    VERSION: 1,
    ACTIVATION_DEBOUNCE_MS: ACTIVATION_DEBOUNCE_MS,
    cloneAction: cloneAction,
    createActionEventDetail: createActionEventDetail
  };
})();
