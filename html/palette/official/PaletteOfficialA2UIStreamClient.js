/**
 * PaletteOfficialA2UIStreamClient — CommandPalette duplex client for Go A2UI bridge.
 */
(function (root) {
  var DEFAULT_URL = "ws://127.0.0.1:18791/agent/ws";
  var reconnectTimer = 0;
  var retries = 0;
  var socket = null;
  var manualStop = false;
  var state = "idle";

  function emitState(next, detail) {
    state = next;
    if (root.document && typeof root.CustomEvent === "function") {
      document.dispatchEvent(
        new CustomEvent("palette-official-a2ui-connection", {
          detail: { state: next, retries: retries, detail: detail || "" }
        })
      );
    }
  }

  function deliver(envelope, replay) {
    if (!envelope || typeof envelope !== "object") return false;
    if (!root.nmerPalette || typeof root.nmerPalette.applyOfficialA2uiEnvelope !== "function") {
      return false;
    }
    var result = root.nmerPalette.applyOfficialA2uiEnvelope(envelope);
    if (root.nmerPalette && typeof root.nmerPalette.setStatus === "function" && !replay) {
      root.nmerPalette.setStatus(
        result && result.ok ? "官方 A2UI 流已更新" : "官方 A2UI 已回退到旧回复",
        result && result.ok ? "success" : "idle"
      );
    }
    return !!(result && result.ok);
  }

  function deliverReplay(items) {
    if (!Array.isArray(items) || !items.length) return;
    var keepCards = Object.create(null);
    var keepCount = 0;
    for (var i = items.length - 1; i >= 0; i--) {
      var cardId = String(items[i] && items[i].cardId || "");
      if (!cardId || keepCards[cardId]) continue;
      if (keepCount >= 20) continue;
      keepCards[cardId] = true;
      keepCount += 1;
    }
    items.forEach(function (item) {
      if (keepCards[String(item && item.cardId || "")]) deliver(item, true);
    });
  }

  function normalizeAction(detail) {
    if (!detail || detail.source !== "go-jsonl") return null;
    var envelope = detail && detail.envelope;
    if (!envelope || typeof envelope !== "object") return null;
    var cardId = String(detail.cardId || envelope.cardId || "");
    var normalized = {
      schemaVersion: "nmer.a2ui.action.v1",
      eventId: String(envelope.eventId || ""),
      requestId: String(envelope.requestId || ""),
      correlationId: String(envelope.correlationId || ""),
      cardId: cardId,
      surfaceId: String(envelope.surfaceId || ""),
      componentId: String(envelope.componentId || ""),
      actionName: String(envelope.actionName || ""),
      depth: Number(envelope.depth || 0),
      timeoutMs: Number(envelope.timeoutMs || 30000),
      abortId: String(envelope.abortId || ""),
      data: envelope.data && typeof envelope.data === "object" ? envelope.data : {}
    };
    var required = [
      "eventId", "requestId", "correlationId", "cardId",
      "surfaceId", "componentId", "actionName", "abortId"
    ];
    for (var i = 0; i < required.length; i++) {
      if (!normalized[required[i]]) return null;
    }
    return normalized;
  }

  function buildActionFrame(detail) {
    var action = normalizeAction(detail);
    if (!action) return null;
    return { type: "official_a2ui_action", a2uiAction: action };
  }

  function sendAction(detail) {
    var frame = buildActionFrame(detail);
    if (!frame) return { ok: false, reason: "invalid_action" };
    if (
      root.PaletteOfficialA2UIActionPolicy &&
      typeof PaletteOfficialA2UIActionPolicy.validate === "function"
    ) {
      var policy = PaletteOfficialA2UIActionPolicy.validate(frame.a2uiAction);
      if (!policy.ok) {
        if (root.PaletteA2UIMetrics && PaletteA2UIMetrics.recordError) {
          PaletteA2UIMetrics.recordError({
            code: policy.code,
            message: policy.message,
            layer: "policy",
            cardId: frame.a2uiAction.cardId,
            source: "client_policy"
          });
        }
        return { ok: false, reason: policy.code, message: policy.message };
      }
    }
    if (!socket || socket.readyState !== WebSocket.OPEN) {
      return { ok: false, reason: "socket_not_open" };
    }
    try {
      socket.send(JSON.stringify(frame));
      return { ok: true, requestId: frame.a2uiAction.requestId };
    } catch (error) {
      return {
        ok: false,
        reason: String(error && error.message ? error.message : error)
      };
    }
  }

  function buildAbortFrame(requestId, abortId) {
    requestId = String(requestId || "");
    abortId = String(abortId || "");
    if (!requestId || !abortId) return null;
    return {
      type: "official_a2ui_abort",
      a2uiAbort: {
        schemaVersion: "nmer.a2ui.action.v1",
        requestId: requestId,
        abortId: abortId
      }
    };
  }

  function abortAction(requestId, abortId) {
    var frame = buildAbortFrame(requestId, abortId);
    if (!frame) return { ok: false, reason: "invalid_abort" };
    if (!socket || socket.readyState !== WebSocket.OPEN) {
      return { ok: false, reason: "socket_not_open" };
    }
    try {
      socket.send(JSON.stringify(frame));
      return { ok: true, requestId: frame.a2uiAbort.requestId };
    } catch (error) {
      return {
        ok: false,
        reason: String(error && error.message ? error.message : error)
      };
    }
  }

  function recordRejected(frame) {
    if (!frame || typeof frame !== "object") return;
    if (root.PaletteA2UIMetrics && PaletteA2UIMetrics.recordError) {
      var err = frame.error && typeof frame.error === "object" ? frame.error : {};
      PaletteA2UIMetrics.recordError({
        source: "ws_rejected",
        error: err,
        message: frame.reason || err.message || ""
      });
      if (err.fallback && err.fallback.hint && PaletteA2UIMetrics.recordFallback) {
        PaletteA2UIMetrics.recordFallback({
          hint: String(err.fallback.hint),
          source: "ws_rejected"
        });
      }
    }
    if (root.document && typeof root.CustomEvent === "function") {
      document.dispatchEvent(
        new CustomEvent("palette-official-a2ui-rejected", { detail: frame })
      );
    }
  }

  function deliverAgentEvent(ev) {
    if (!ev || typeof ev !== "object") return false;
    if (root.document && typeof root.CustomEvent === "function") {
      document.dispatchEvent(
        new CustomEvent("palette-hub-agent-event", { detail: ev })
      );
    }
    return true;
  }

  function handleWireFrame(frame) {
    if (!frame || typeof frame !== "object") return false;
    if (frame.type === "hello_ack" && Array.isArray(frame.a2uiReplay)) {
      deliverReplay(frame.a2uiReplay);
      return true;
    }
    if (frame.type === "agent_event" && frame.event) {
      deliverAgentEvent(frame.event);
      return true;
    }
    if (frame.type === "official_a2ui_event" && frame.a2ui) {
      deliver(frame.a2ui, false);
      return true;
    }
    if (frame.type === "official_a2ui_rejected") {
      recordRejected(frame);
      return true;
    }
    if (frame.type === "official_a2ui_action_result" && frame.a2uiActionResult) {
      deliverActionResult(frame.a2uiActionResult);
      return true;
    }
    return false;
  }

  function deliverActionResult(result) {
    if (!result || typeof result !== "object") return;
    if (root.PaletteA2UIMetrics && PaletteA2UIMetrics.recordActionResult) {
      PaletteA2UIMetrics.recordActionResult({
        status: result.status || "unknown",
        error: result.error || "",
        errorCode: result.errorCode || "",
        requestId: result.requestId || "",
        cardId: result.cardId || "",
        source: "ws"
      });
    }
    if (root.document && typeof root.CustomEvent === "function") {
      document.dispatchEvent(
        new CustomEvent("palette-official-a2ui-action-result", { detail: result })
      );
    }
    if (root.nmerPalette && typeof root.nmerPalette.setStatus === "function") {
      var line =
        root.PaletteOfficialA2UIActionLabels &&
        PaletteOfficialA2UIActionLabels.formatActionResult
          ? PaletteOfficialA2UIActionLabels.formatActionResult(result)
          : null;
      var ok = result.status === "accepted" || result.status === "completed";
      root.nmerPalette.setStatus(
        line ? line.title + (line.body ? " — " + line.body : "") : (ok ? "A2UI 操作：" + result.status : "A2UI 操作失败：" + String(result.error || result.status)),
        ok ? "success" : "idle"
      );
    }
  }

  function scheduleReconnect(reason) {
    if (manualStop) return;
    retries += 1;
    var delay = Math.min(8000, Math.round(400 * Math.pow(1.6, retries - 1)));
    emitState("reconnecting", reason || ("retry in " + delay + "ms"));
    clearTimeout(reconnectTimer);
    reconnectTimer = setTimeout(connect, delay);
  }

  function connect(url) {
    if (url) api.url = String(url);
    manualStop = false;
    clearTimeout(reconnectTimer);
    if (socket) {
      try { socket.close(); } catch (_) {}
      socket = null;
    }
    emitState(retries ? "reconnecting" : "connecting");
    try {
      var clientId = "command_palette_a2ui_" + Date.now().toString(36);
      socket = new WebSocket(api.url + "?clientId=" + encodeURIComponent(clientId));
    } catch (error) {
      scheduleReconnect(String(error && error.message ? error.message : error));
      return;
    }
    socket.onopen = function () {
      retries = 0;
      emitState("open");
      try { socket.send(JSON.stringify({ type: "hello", clientId: "command_palette_a2ui" })); } catch (_) {}
    };
    socket.onmessage = function (event) {
      var frame;
      try { frame = JSON.parse(String(event.data || "{}")); } catch (_) { return; }
      handleWireFrame(frame);
    };
    socket.onerror = function () {};
    socket.onclose = function (event) {
      socket = null;
      if (manualStop) {
        emitState("closed", "manual");
        return;
      }
      scheduleReconnect("close code=" + String(event && event.code || 0));
    };
  }

  function stop() {
    manualStop = true;
    clearTimeout(reconnectTimer);
    reconnectTimer = 0;
    if (socket) {
      try { socket.close(1000, "manual"); } catch (_) {}
      socket = null;
    }
    emitState("closed", "manual");
  }

  function shouldConnect(cfg) {
    cfg = cfg || root.nmerPaletteBridgeConfig || {};
    if (root.PaletteOfficialA2UIGray && PaletteOfficialA2UIGray.isOfficialGloballyEnabled) {
      return PaletteOfficialA2UIGray.isOfficialGloballyEnabled(cfg) && PaletteOfficialA2UIGray.isBridgeReady(cfg);
    }
    var rb = cfg.rollback || {};
    if (rb.forceNmerOnly === true || rb.forceNmerOnly === 1) return false;
    var wb = cfg.wailsBridge || {};
    if (wb.enabled === false || wb.healthy === false) return false;
    var oa = cfg.officialA2ui || {};
    return oa.enabled === true || oa.enabled === 1 || String(oa.enabled) === "1";
  }

  function applyBridgeConfig(cfg) {
    root.nmerPaletteBridgeConfig = cfg || {};
    if (!shouldConnect(cfg)) {
      stop();
      return;
    }
    var wb = (cfg && cfg.wailsBridge) || {};
    if (wb.wsUrl) api.url = String(wb.wsUrl);
    if (wb.healthy === false && root.nmerPalette && typeof root.nmerPalette.setStatus === "function") {
      root.nmerPalette.setStatus("A2UI sidecar 未就绪（:18791）", "idle");
    }
    if (state === "open" || state === "connecting") return;
    connect();
  }

  var api = {
    url: DEFAULT_URL,
    connect: connect,
    stop: stop,
    applyBridgeConfig: applyBridgeConfig,
    getState: function () { return state; },
    getRetryCount: function () { return retries; },
    deliver: deliver,
    deliverReplay: deliverReplay,
    normalizeAction: normalizeAction,
    buildActionFrame: buildActionFrame,
    sendAction: sendAction,
    buildAbortFrame: buildAbortFrame,
    abortAction: abortAction,
    deliverActionResult: deliverActionResult,
    handleWireFrame: handleWireFrame,
    recordRejected: recordRejected
  };

  root.PaletteOfficialA2UIStreamClient = api;
  if (root.document && document.addEventListener) {
    document.addEventListener("palette-official-a2ui-action", function (event) {
      var result = sendAction((event && event.detail) || {});
      if (!result.ok && root.nmerPalette && typeof root.nmerPalette.setStatus === "function") {
        root.nmerPalette.setStatus("A2UI 操作未发送：" + result.reason, "idle");
      }
    });
  }
  if (typeof root.WebSocket === "function" && shouldConnect()) {
    setTimeout(function () {
      if (!root.nmerPaletteBridgeConfig) connect();
    }, 250);
  }
})(typeof window !== "undefined" ? window : globalThis);
