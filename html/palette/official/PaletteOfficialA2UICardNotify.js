/**
 * PaletteOfficialA2UICardNotify — 将 A2UI 回执/拒收写入卡片 status log
 */
(function (root) {
  var installed = false;

  function appendStatusLine(dom, title, body, seqKey) {
    if (!dom || !dom.querySelector) return false;
    var logBox = dom.querySelector(".card-status-log");
    if (!logBox) return false;
    var seq = String(seqKey || "a2ui-" + Date.now());
    var tail = logBox.querySelector('.b-status[data-seq="' + seq + '"]');
    if (!tail) {
      tail = document.createElement("div");
      tail.className = "b-status b-status-a2ui";
      tail.setAttribute("data-seq", seq);
      tail.innerHTML = '<div class="b-status-title"></div><div class="b-status-log"></div>';
      logBox.appendChild(tail);
    }
    tail.querySelector(".b-status-title").textContent = String(title || "[A2UI]");
    var logEl = tail.querySelector(".b-status-log");
    if (logEl) logEl.textContent = String(body || "");
    logBox.scrollTop = logBox.scrollHeight;
    if (
      root.PaletteCardRenderer &&
      typeof PaletteCardRenderer.syncActionCardStatusLogVisibility === "function"
    ) {
      PaletteCardRenderer.syncActionCardStatusLogVisibility(dom);
    }
    return true;
  }

  function resolveCardDom(cardId, options) {
    options = options || {};
    if (typeof options.getCardDom === "function") {
      return options.getCardDom(cardId);
    }
    if (root.document && document.getElementById) {
      return document.getElementById("card-" + String(cardId || ""));
    }
    return null;
  }

  function install(options) {
    options = options || {};
    if (installed || !root.document || !document.addEventListener) return;
    installed = true;
    var Labels = root.PaletteOfficialA2UIActionLabels;

    document.addEventListener("palette-official-a2ui-action-result", function (event) {
      var result = (event && event.detail) || {};
      if (!Labels || !Labels.formatActionResult) return;
      var line = Labels.formatActionResult(result);
      var cardId = String(result.cardId || "");
      if (!cardId) return;
      var dom = resolveCardDom(cardId, options);
      if (!dom) return;
      appendStatusLine(
        dom,
        line.title,
        line.body,
        "a2ui-action-" + String(result.requestId || result.eventId || Date.now())
      );
      if (typeof options.onActionResultLine === "function") {
        options.onActionResultLine(cardId, line, result);
      }
    });

    document.addEventListener("palette-official-a2ui-rejected", function (event) {
      var frame = (event && event.detail) || {};
      if (!Labels || !Labels.formatRejected) return;
      var line = Labels.formatRejected(frame);
      var ctx = (frame.error && frame.error.context) || {};
      var cardId = String(ctx.cardId || frame.cardId || "");
      if (!cardId) return;
      var dom = resolveCardDom(cardId, options);
      if (!dom) return;
      appendStatusLine(
        dom,
        line.title,
        line.body,
        "a2ui-reject-" + String(ctx.seq || line.code || Date.now())
      );
      if (typeof options.onRejectedLine === "function") {
        options.onRejectedLine(cardId, line, frame);
      }
    });
  }

  function _resetForTest() {
    installed = false;
  }

  root.PaletteOfficialA2UICardNotify = {
    install: install,
    appendStatusLine: appendStatusLine,
    _resetForTest: _resetForTest
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
