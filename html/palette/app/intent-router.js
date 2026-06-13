(function (global) {
  "use strict";

  var ORDER = ["local", "ai", "action"];
  var LABELS = { local: "本地", ai: "问 AI", action: "动作" };
  var PLACEHOLDERS = {
    local: "搜索文件、路径或剪贴板…",
    ai: "选择模型，Enter 原地流式回答…",
    action: "描述任务 Enter 提交至上方所选引擎（龙虾/Hermes）…"
  };

  function nextIntent(cur) {
    var i = ORDER.indexOf(cur);
    return ORDER[(i < 0 ? 0 : i + 1) % ORDER.length];
  }

  function applyTag(el, intent) {
    if (!el) return;
    el.setAttribute("data-intent", intent);
    el.textContent = LABELS[intent] || intent;
    el.title = "Tab 切换意图";
  }

  global.PaletteIntentRouter = {
    ORDER: ORDER,
    LABELS: LABELS,
    PLACEHOLDERS: PLACEHOLDERS,
    nextIntent: nextIntent,
    applyTag: applyTag
  };
})(typeof window !== "undefined" ? window : globalThis);
