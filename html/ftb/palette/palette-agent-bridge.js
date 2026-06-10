/**
 * FTB-1 — Palette Agent Bridge（M1）
 * 队列、prepare/cancel、结束通知、runPaletteAgentStream、runPaletteAgentStreamOnce。
 */
(function (root) {
  "use strict";
  var VERSION = "ftb-1.2.0";
  var DEFAULT_WAIT_MS = 600000;
  var DEFAULT_WAIT_POLL_MS = 3000;

  function requireFn(ctx, name) {
    if (!ctx || typeof ctx[name] !== "function") {
      throw new Error("NmerPaletteAgentBridge: missing ctx." + name);
    }
    return ctx[name];
  }

  function install(ctx) {
    if (!ctx || typeof ctx.post !== "function") {
      throw new Error("NmerPaletteAgentBridge: missing ctx.post");
    }
    if (!ctx.state) {
      throw new Error("NmerPaletteAgentBridge: missing ctx.state");
    }

    var post = ctx.post;
    var S = ctx.state;
    var chatState = ctx.chatState || ctx.appState || null;
    var waitMs = ctx.waitMs != null ? (ctx.waitMs + 0) : DEFAULT_WAIT_MS;
    var waitPollMs = ctx.waitPollMs != null ? (ctx.waitPollMs + 0) : DEFAULT_WAIT_POLL_MS;

    var paletteClearLateRecover = ctx.paletteClearLateRecover || function () {};
    var paletteSyncCardAnswerToNiumaSession = ctx.paletteSyncCardAnswerToNiumaSession || function () {
      return Promise.resolve();
    };
    var activeSession = ctx.activeSession || function () {
      return null;
    };
    var setSessionSending = ctx.setSessionSending || function () {};
    var declareChatBridgeReady = ctx.declareChatBridgeReady || function () {};
    var waitForChatBridgeReady = ctx.waitForChatBridgeReady || function () {
      return Promise.resolve();
    };
    var paletteEnsureAgentSessionForCard = requireFn(ctx, "paletteEnsureAgentSessionForCard");
    var createSessionWithProvider = ctx.createSessionWithProvider;
    var P = ctx.P || {};
    var paletteEnsureActiveSession = requireFn(ctx, "paletteEnsureActiveSession");
    var sessionById = requireFn(ctx, "sessionById");
    var isSessionSending = requireFn(ctx, "isSessionSending");
    var syncFormFromSession = ctx.syncFormFromSession || function () {};
    var saveCfg = ctx.saveCfg || function () {};
    var getNodeSendCfg = requireFn(ctx, "getNodeSendCfg");
    var nodeKeyForSession = requireFn(ctx, "nodeKeyForSession");
    var openClawEndpointFromCfg = requireFn(ctx, "openClawEndpointFromCfg");
    var resolvePaletteAgentGatewaySessionKey = requireFn(ctx, "resolvePaletteAgentGatewaySessionKey");
    var applyPaletteGatewaySessionKey = requireFn(ctx, "applyPaletteGatewaySessionKey");
    var paletteAgentExecuteViaGateway = requireFn(ctx, "paletteAgentExecuteViaGateway");
    var paletteAgentContentReady = requireFn(ctx, "paletteAgentContentReady");
    var palettePickAssistantAnswerForAgent = requireFn(ctx, "palettePickAssistantAnswerForAgent");
    var paletteHydrateAssistantFromGateway = requireFn(ctx, "paletteHydrateAssistantFromGateway");
    var paletteAgentAnswerCompleteEnough = requireFn(ctx, "paletteAgentAnswerCompleteEnough");
    var armPaletteAgentLateRecover = requireFn(ctx, "armPaletteAgentLateRecover");
    var paletteClearTransientOpenClawKey = ctx.paletteClearTransientOpenClawKey || function () {};

    function paletteAgentStreamWasCancelled(reqId) {
      var rid = String(reqId || S.activeReqId || "").trim();
      if (S.cancelled) return true;
      var job = rid && S.inflightByReqId[rid] ? S.inflightByReqId[rid] : null;
      return !!(job && job.cancelled);
    }

    function palettePrepareAgentStreamForCard(cardId, reqId) {
      var cid = String(cardId || "").trim();
      var rid = String(reqId || "").trim();
      var s = activeSession();
      if (s && s.id) setSessionSending(s.id, false);
      if (rid) {
        S.queue = S.queue.filter(function (j) {
          return String(j.reqId || "") === rid;
        });
      }
      Object.keys(S.inflightByReqId).forEach(function (orid) {
        if (orid === rid) return;
        var job = S.inflightByReqId[orid];
        if (!job) return;
        job.cancelled = true;
        paletteClearLateRecover(orid);
        delete S.inflightByReqId[orid];
        if (S.activeReqId === orid) {
          S.activeReqId = "";
          S.running = false;
        }
      });
      try {
        post({
          type: "niuma_palette_agent_trace",
          step: "agent_stream_prepare",
          detail: "card=" + cid + " req=" + rid
        });
      } catch (_) {}
    }

    function paletteNotifyPaletteAgentEnd(reqId, cardId, answer, sessionRef, queryOpt) {
      if (S.cancelled) return;
      var a = String(answer || "");
      var rid = String(reqId || "").trim();
      var cid = String(cardId || "").trim();
      var ref = sessionRef != null ? String(sessionRef) : "";
      var job = rid && S.inflightByReqId[rid] ? S.inflightByReqId[rid] : null;
      var q = String(queryOpt || (job && job.query) || "").trim();
      paletteClearLateRecover(rid);
      try {
        delete S.inflightByReqId[rid];
      } catch (_) {}
      if (a && q && cid) {
        paletteSyncCardAnswerToNiumaSession({
          reqId: rid,
          cardId: cid,
          query: q,
          sessionRef: ref || (job && job.sessionRef) || "",
          answer: a
        }).catch(function () {});
      }
      try {
        post({
          type: "niuma_palette_agent_end",
          reqId: rid,
          cardId: cid,
          answer: a,
          sessionRef: ref,
          query: q
        });
      } catch (_) {}
    }

    async function drainPaletteAgentStreamQueue() {
      if (S.draining) return;
      S.draining = true;
      try {
        while (S.queue.length) {
          var job = S.queue.shift();
          if (!job) continue;
          try {
            await runPaletteAgentStreamOnce(
              job.reqId,
              job.cardId,
              job.query,
              job.provider,
              job.systemPrompt,
              job.sessionRef
            );
          } catch (eJob) {
            try {
              post({
                type: "niuma_palette_agent_error",
                reqId: job.reqId,
                cardId: job.cardId,
                message: eJob && eJob.message ? eJob.message : String(eJob)
              });
            } catch (_) {}
          }
        }
      } finally {
        S.draining = false;
      }
    }

    async function runPaletteAgentStreamOnce(reqId, cardId, query, provider, systemPrompt, sessionRef) {
      var rid = String(reqId || "").trim();
      var q = String(query || "").trim();
      var cid = String(cardId || "");
      S.activeReqId = rid;
      S.running = true;
      S.inflightByReqId[rid] = {
        reqId: rid,
        cardId: cid,
        query: q,
        sessionRef: String(sessionRef || ""),
        startedAt: Date.now()
      };
      var paletteStreamContentDelivered = false;
      var sid = "";
      try {
        try {
          post({
            type: "niuma_palette_agent_trace",
            step: "agent_stream_start",
            detail: "req=" + rid + " q=" + q.slice(0, 48)
          });
        } catch (_) {}
        var provNode = String(provider || "openclaw").trim() || "openclaw";
        if (chatState && !chatState.chatBridgeReady) {
          try {
            declareChatBridgeReady();
          } catch (_) {}
          try {
            await waitForChatBridgeReady(8000);
          } catch (_) {}
        }
        post({ type: "niuma_palette_agent_chunk", reqId: reqId, cardId: cid, delta: "⏳ 正在准备代理引擎…\n" });
        var s = paletteEnsureAgentSessionForCard(cid, rid, q, provNode, sessionRef);
        if (!s || !s.id) {
          try {
            if (typeof createSessionWithProvider === "function" && P[provNode]) {
              createSessionWithProvider(provNode);
              s = paletteEnsureAgentSessionForCard(cid, rid, q, provNode, sessionRef);
            }
          } catch (_) {}
        }
        if (!s || !s.id) {
          post({
            type: "niuma_palette_agent_error",
            reqId: reqId,
            cardId: cid,
            message: "无活动会话：请先在 Niuma Chat 对「" + provNode + "」点一键连接"
          });
          return;
        }
        sid = s.id;
        paletteEnsureActiveSession(sid);
        s = sessionById(sid) || s;
        if (isSessionSending(sid)) {
          post({
            type: "niuma_palette_agent_chunk",
            reqId: reqId,
            cardId: cid,
            delta: "⏳ 等待当前会话完成上一次请求…\n"
          });
          var waitLeft = 360;
          while (isSessionSending(sid) && waitLeft-- > 0) {
            await new Promise(function (r) {
              setTimeout(r, 500);
            });
            if (paletteAgentStreamWasCancelled(rid)) return;
          }
          if (isSessionSending(sid)) {
            try {
              post({
                type: "niuma_palette_agent_trace",
                step: "palette_force_clear_sending",
                detail: "sid=" + sid + " req=" + rid
              });
            } catch (_) {}
            setSessionSending(sid, false);
          }
        }
        s._paletteAgentReqId = reqId;
        s._paletteAgentCardId = cid;
        s._paletteReqId = reqId;
        s._paletteAgentQuery = q;
        syncFormFromSession(s);
        saveCfg(false);
        var qLower = q.toLowerCase();
        if (qLower === "openclaw" || qLower === "hermes" || q === "龙虾") {
          post({
            type: "niuma_palette_agent_error",
            reqId: reqId,
            cardId: cid,
            message: "请勿只发送引擎名称，请在 Command Palette 输入具体任务内容"
          });
          return;
        }
        var cfg = getNodeSendCfg(nodeKeyForSession(s), s);
        if (!cfg) {
          post({ type: "niuma_palette_agent_error", reqId: reqId, cardId: cid, message: "无法构建模型配置" });
          return;
        }
        var p0 = P[cfg.provider] || P.openai;
        if (p0.transport === "cli") {
          post({ type: "niuma_palette_agent_error", reqId: reqId, cardId: cid, message: "CLI 模式请在大窗中使用" });
          return;
        }
        if (!cfg.baseUrl || (p0.transport !== "openclaw" && !cfg.model)) {
          post({ type: "niuma_palette_agent_error", reqId: reqId, cardId: cid, message: "请先配置 Base URL 与 Model" });
          return;
        }
        if (p0.transport === "openclaw" && !openClawEndpointFromCfg(cfg).ok) {
          post({
            type: "niuma_palette_agent_error",
            reqId: reqId,
            cardId: cid,
            message: "OpenClaw Gateway Token 未配置，请在 Niuma Chat 设置中对「龙虾」点一键连接"
          });
          return;
        }
        if (p0.transport !== "openclaw" && cfg.provider !== "ollama" && !cfg.apiKey) {
          post({ type: "niuma_palette_agent_error", reqId: reqId, cardId: cid, message: "请先配置 API Key" });
          return;
        }
        var agentSys = String(systemPrompt || "").trim();
        var sessionRefOut = resolvePaletteAgentGatewaySessionKey(s, {
          sessionRef: sessionRef,
          cardId: cid,
          reqId: rid
        });
        sessionRefOut = applyPaletteGatewaySessionKey(s, sessionRefOut);
        try {
          post({
            type: "niuma_palette_agent_chunk",
            reqId: reqId,
            cardId: cid,
            delta: "🔗 Gateway session · " + String(sessionRefOut || "").slice(0, 64) + "\n",
            liveThought: "绑定 OpenClaw · " + String(sessionRefOut || "").slice(0, 48),
            sessionRef: String(sessionRefOut || "")
          });
        } catch (_) {}
        try {
          var waitStart = Date.now();
          var waitTimer = setInterval(function () {
            if (paletteAgentStreamWasCancelled(rid)) return;
            var sec = Math.round((Date.now() - waitStart) / 1000);
            post({
              type: "niuma_palette_agent_chunk",
              reqId: reqId,
              cardId: cid,
              delta: "⏳ OpenClaw 处理中… (" + sec + "s)\n",
              liveThought: "OpenClaw 处理中… (" + sec + "s)"
            });
          }, 15000);
          try {
            sessionRefOut = await paletteAgentExecuteViaGateway(sid, reqId, cid, q, agentSys, sessionRef);
          } finally {
            clearInterval(waitTimer);
          }
          if (paletteAgentStreamWasCancelled(rid)) return;
          var waitDeadline = Date.now() + waitMs;
          var pollN = 0;
          var content = paletteAgentContentReady(
            palettePickAssistantAnswerForAgent(reqId, q, { allowWhileSending: true })
          );
          while (!content && Date.now() < waitDeadline) {
            await new Promise(function (r) {
              setTimeout(r, waitPollMs);
            });
            if (paletteAgentStreamWasCancelled(rid)) return;
            pollN++;
            try {
              content = paletteAgentContentReady(
                await paletteHydrateAssistantFromGateway(reqId, q, { allowWhileSending: true })
              );
            } catch (_) {}
            if (!content) {
              content = paletteAgentContentReady(
                palettePickAssistantAnswerForAgent(reqId, q, { allowWhileSending: true })
              );
            }
            if (!content && pollN % 10 === 0) {
              var elapsed = Math.round((Date.now() - (waitDeadline - waitMs)) / 1000);
              post({
                type: "niuma_palette_agent_chunk",
                reqId: reqId,
                cardId: cid,
                delta: "⏳ 等待 OpenClaw 回复… (" + elapsed + "s)\n",
                liveThought: "Gateway 处理中… (" + elapsed + "s)"
              });
            }
          }
          if (content && (paletteAgentAnswerCompleteEnough(content, q) || content.length >= 1200)) {
            var sFin = sessionById(sid);
            if (sFin && sFin._paletteOpenClawSessionKey) sessionRefOut = String(sFin._paletteOpenClawSessionKey);
            else if (S.inflightByReqId[rid] && S.inflightByReqId[rid].sessionRef) {
              sessionRefOut = String(S.inflightByReqId[rid].sessionRef);
            } else if (sFin && sFin.gatewaySessionKey) sessionRefOut = String(sFin.gatewaySessionKey);
            paletteNotifyPaletteAgentEnd(reqId, cid, content, sessionRefOut);
            paletteStreamContentDelivered = true;
          } else if (content && content.length >= 480 && (/\|/.test(content) || content.length >= 800)) {
            paletteNotifyPaletteAgentEnd(reqId, cid, content, sessionRefOut);
            paletteStreamContentDelivered = true;
          } else if (content) {
            post({
              type: "niuma_palette_agent_chunk",
              reqId: reqId,
              cardId: cid,
              delta: "⏳ 已同步部分回复，继续从 Gateway 拉取完整内容…\n",
              liveThought: "继续同步完整回复…"
            });
            if (S.inflightByReqId[rid]) S.inflightByReqId[rid].sessionRef = String(sessionRefOut || "");
            armPaletteAgentLateRecover(rid);
          } else {
            post({
              type: "niuma_palette_agent_chunk",
              reqId: reqId,
              cardId: cid,
              delta: "⏳ OpenClaw 回复较慢，后台继续从 Gateway 同步…\n",
              liveThought: "后台等待 Gateway 完整回复…"
            });
            if (S.inflightByReqId[rid]) S.inflightByReqId[rid].sessionRef = String(sessionRefOut || "");
            armPaletteAgentLateRecover(rid);
          }
        } catch (err) {
          if (!paletteAgentStreamWasCancelled(rid)) {
            var errFallback = paletteAgentContentReady(
              palettePickAssistantAnswerForAgent(reqId, q, { allowWhileSending: true })
            );
            if (errFallback) {
              paletteNotifyPaletteAgentEnd(reqId, cid, errFallback, sessionRefOut);
              paletteStreamContentDelivered = true;
            } else {
              post({
                type: "niuma_palette_agent_error",
                reqId: reqId,
                cardId: cid,
                message: err && err.message ? err.message : "未知错误"
              });
            }
          }
        } finally {
          var sCl = sessionById(sid);
          if (sCl) {
            try {
              delete sCl._paletteAgentChunkHook;
            } catch (_) {}
            try {
              delete sCl._paletteAgentSystemPrompt;
            } catch (_) {}
            paletteClearTransientOpenClawKey(sCl);
          }
        }
      } finally {
        if (sid) setSessionSending(sid, false);
        if (!paletteStreamContentDelivered) {
          if (S.inflightByReqId[rid] && !(S.lateRecoverTimers && S.lateRecoverTimers[rid])) {
            armPaletteAgentLateRecover(rid);
          }
        }
        if (S.activeReqId === rid) S.activeReqId = "";
        S.running = false;
      }
    }

    function runPaletteAgentStream(reqId, cardId, query, provider, systemPrompt, sessionRef) {
      var rid = String(reqId || "").trim();
      var q = String(query || "").trim();
      var cid = String(cardId || "");
      if (!q) {
        post({ type: "niuma_palette_agent_error", reqId: reqId, cardId: cid, message: "空问题" });
        return Promise.resolve();
      }
      for (var qi = 0; qi < S.queue.length; qi++) {
        if (String(S.queue[qi].reqId || "") === rid) {
          try {
            post({ type: "niuma_palette_agent_trace", step: "agent_stream_queue_dup", detail: "req=" + rid });
          } catch (_) {}
          return Promise.resolve();
        }
      }
      if (rid && S.inflightByReqId[rid] && !paletteAgentStreamWasCancelled(rid)) {
        try {
          post({ type: "niuma_palette_agent_trace", step: "agent_stream_dup_skip", detail: "req=" + rid });
        } catch (_) {}
        return Promise.resolve();
      }
      palettePrepareAgentStreamForCard(cid, rid);
      S.cancelled = false;
      return runPaletteAgentStreamOnce(reqId, cardId, q, provider, systemPrompt, sessionRef)
        .catch(function (eRun) {
          try {
            post({
              type: "niuma_palette_agent_error",
              reqId: rid,
              cardId: cid,
              message: eRun && eRun.message ? eRun.message : String(eRun)
            });
          } catch (_) {}
        })
        .finally(function () {
          return drainPaletteAgentStreamQueue();
        });
    }

    root.runPaletteAgentStream = runPaletteAgentStream;
    root.paletteNotifyPaletteAgentEnd = paletteNotifyPaletteAgentEnd;
    root.palettePrepareAgentStreamForCard = palettePrepareAgentStreamForCard;

    return {
      version: VERSION,
      runPaletteAgentStream: runPaletteAgentStream,
      runPaletteAgentStreamOnce: runPaletteAgentStreamOnce,
      paletteNotifyPaletteAgentEnd: paletteNotifyPaletteAgentEnd,
      palettePrepareAgentStreamForCard: palettePrepareAgentStreamForCard,
      paletteAgentStreamWasCancelled: paletteAgentStreamWasCancelled,
      drainPaletteAgentStreamQueue: drainPaletteAgentStreamQueue
    };
  }

  root.NmerPaletteAgentBridge = {
    VERSION: VERSION,
    install: install
  };
})(typeof window !== "undefined" ? window : typeof globalThis !== "undefined" ? globalThis : this);
