(function (global) {
  "use strict";
  var api = null;
  var AGENT_PROVIDERS = [
    { id: "openclaw", label: "龙虾 OpenClaw", short: "龙虾" },
    { id: "hermes", label: "Hermes", short: "Hermes" }
  ];
  function install(ctx) {
    api = ctx || null;
  }
  function bindSubmit() {
    if (!api) return;
    var btn = document.getElementById("action-agent-submit");
    if (!btn || btn.dataset.bound) return;
    btn.dataset.bound = "1";
    btn.addEventListener("click", function (e) {
      e.preventDefault();
      e.stopPropagation();
      api.handleActionEnterKey(null);
      var inp = api.getInputEl();
      if (inp) inp.focus();
    });
  }
  function render() {
    if (!api) return;
    var bar = document.getElementById("action-agent-bar");
    var panel = document.getElementById("palette-panel");
    if (panel) panel.classList.toggle("intent-action", api.state.intent === "action");
    if (!bar) return;
    bar.hidden = api.state.intent !== "action";
    if (api.state.intent !== "action") return;
    var chips = bar.querySelector(".action-agent-chips");
    if (!chips) return;
    chips.innerHTML = AGENT_PROVIDERS.map(function (p) {
      var active = p.id === api.state.agentProvider ? " active" : "";
      return (
        '<button type="button" class="action-agent-chip' +
        active +
        '" data-prov="' +
        api.esc(p.id) +
        '" title="' +
        api.esc(p.label) +
        '">' +
        api.esc(p.short) +
        "</button>"
      );
    }).join("");
    var submitBtn = document.getElementById("action-agent-submit");
    if (!submitBtn) {
      submitBtn = document.createElement("button");
      submitBtn.type = "button";
      submitBtn.id = "action-agent-submit";
      submitBtn.className = "action-agent-submit-btn";
      submitBtn.title = "Enter 提交托管任务";
      submitBtn.textContent = "提交";
      bar.appendChild(submitBtn);
    }
    bindSubmit();
    chips.querySelectorAll(".action-agent-chip").forEach(function (btn) {
      btn.addEventListener("click", function () {
        api.state.agentProvider = btn.getAttribute("data-prov") || "openclaw";
        render();
        if (typeof PaletteAgentSummary !== "undefined" && PaletteAgentSummary.refreshActionHistoryHead) {
          PaletteAgentSummary.refreshActionHistoryHead();
        }
        if (
          api.state.intent === "action" &&
          !Object.keys(api.actionState.cards).length &&
          !api.state.input.trim()
        ) {
          api.maybeRequestAgentCardSync();
          if (!api.actionHasStoredCards()) api.showActionEmptyIfNeeded();
        }
        window.nmerPalette.setStatus(
          "已选引擎 · " + api.agentProviderLabel(api.state.agentProvider) + " · 输入后 Enter 提交",
          "idle"
        );
        api.syncWindowSize();
      });
    });
  }
  global.PaletteActionBar = {
    install: install,
    render: render,
    bindSubmit: bindSubmit
  };
})(typeof window !== "undefined" ? window : globalThis);
