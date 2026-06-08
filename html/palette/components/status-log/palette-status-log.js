/**
 * palette-status-log — Lit Web Component (Light DOM)
 * 渲染 status block 条目；不调用 host、不写 input/toast。
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

  function levelClass(level) {
    if (level === "error") return " is-error";
    if (level === "warning") return " is-warning";
    return "";
  }

  function titleText(entry) {
    entry = entry || {};
    return entry.time ? "[" + entry.time + "] " : "[执行中] ";
  }

  class PaletteStatusLog extends LitElement {
    static get properties() {
      return {
        cardId: { type: String, attribute: "card-id" },
        blockId: { type: String, attribute: "block-id" },
        entries: { type: Array },
        text: { type: String },
        streaming: { type: Boolean }
      };
    }

    constructor() {
      super();
      this.cardId = "";
      this.blockId = "";
      this.entries = [];
      this.text = "";
      this.streaming = false;
    }

    createRenderRoot() {
      return this;
    }

    get displayEntries() {
      if (Array.isArray(this.entries) && this.entries.length) return this.entries;
      if (String(this.text || "").trim()) {
        return [{ text: this.text, level: "info", time: "", bodyHtml: escText(this.text) }];
      }
      return [];
    }

    updated(changed) {
      if (changed.has("entries") || changed.has("text") || changed.has("blockId")) {
        this._syncEntryBodies();
      }
    }

    _syncEntryBodies() {
      var list = this.displayEntries;
      var bodies = this.querySelectorAll(".b-status-log[data-entry-idx]");
      for (var i = 0; i < bodies.length; i++) {
        var entry = list[i];
        if (!entry) continue;
        var bodyHtml =
          entry.bodyHtml != null ? String(entry.bodyHtml) : escText(entry.text || "");
        bodies[i].innerHTML = bodyHtml;
      }
    }

    render() {
      var list = this.displayEntries;
      if (!list.length) return html``;
      var blockId = this.blockId || "";
      return html`
        ${list.map(function (entry, idx) {
          var lv = levelClass(entry.level);
          return html`
            <div class="b-status${lv}" data-block-id=${blockId}>
              <div class="b-status-title">${escText(titleText(entry))}</div>
              <div class="b-status-log md-body" data-entry-idx=${String(idx)}></div>
            </div>
          `;
        })}
      `;
    }

    firstUpdated() {
      this._syncEntryBodies();
    }
  }

  if (!customElements.get("palette-status-log")) {
    customElements.define("palette-status-log", PaletteStatusLog);
  }
})();
