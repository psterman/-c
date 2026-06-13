(function (global) {
  "use strict";

  function getInputEl() {
    return document.getElementById("command-input");
  }

  function ensureShell(ctx) {
    ctx = ctx || {};
    var root = ctx.root || document.getElementById("root");
    if (!root) return;
    if (!document.getElementById("palette-panel")) {
      root.innerHTML =
        '<main class="palette-root">' +
        '<section class="palette-panel" id="palette-panel" aria-label="命令面板">' +
        '<header class="palette-header">' +
        '<span id="intent-tag" data-intent="action" title="Tab 切换意图">动作</span>' +
        '<input id="command-input" class="palette-search" type="text" lang="zh-CN" autocomplete="off" spellcheck="false" placeholder="搜索文件、路径或剪贴板…" />' +
        '<button type="button" id="debug-btn" class="palette-debug-btn" title="命令面板诊断 (Ctrl+Shift+D 搜索 / Ctrl+Shift+A 动作托管)" aria-label="打开命令面板诊断">诊</button>' +
        "</header>" +
        '<p id="voice-hint" class="palette-status"></p>' +
        '<div id="action-agent-bar" class="action-agent-bar" hidden>' +
        '<span class="action-agent-label">托管引擎</span>' +
        '<div class="action-agent-chips"></div></div>' +
        '<div id="results" class="palette-results"><div class="action-history-loading" id="action-history-loading">加载历史任务…</div></div>' +
        "</section></main>";
    }
    root.dataset.ready = "1";
    if (root.dataset.shellBound) return;
    root.dataset.shellBound = "1";
    if (typeof ctx.syncIntentUI === "function") ctx.syncIntentUI();
    if (typeof ctx.bindUI === "function") ctx.bindUI();
    if (typeof ctx.bindLayoutObservers === "function") ctx.bindLayoutObservers();
    if (typeof ctx.bindActionSubmitButton === "function") ctx.bindActionSubmitButton();
    if (typeof global.PalettePerfMarks !== "undefined") {
      if (global.PalettePerfMarks.setSender && typeof ctx.post === "function") {
        global.PalettePerfMarks.setSender(function (payload) {
          ctx.post(payload);
        });
      }
      global.PalettePerfMarks.mark("palette_ready");
      global.PalettePerfMarks.flush();
    }
    if (typeof ctx.post === "function") ctx.post({ type: "palette_ready" });
    if (typeof ctx.probeAgentHostBridge === "function") setTimeout(ctx.probeAgentHostBridge, 400);
    if (typeof ctx.shouldDeferAgentCardPullOnReady === "function" && typeof ctx.requestAgentCardSync === "function") {
      if (!ctx.shouldDeferAgentCardPullOnReady()) setTimeout(ctx.requestAgentCardSync, 120);
    }
  }

  global.PaletteBootstrap = {
    getInputEl: getInputEl,
    ensureShell: ensureShell
  };
})(typeof window !== "undefined" ? window : globalThis);
