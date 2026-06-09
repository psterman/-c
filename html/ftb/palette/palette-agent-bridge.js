/**
 * FTB-1 — Palette Agent Bridge（M1）
 * 队列、prepare/cancel、结束通知、runPaletteAgentStream；runPaletteAgentStreamOnce 由宿主注入。
 */
(function (root) {
  "use strict";
  var VERSION = "ftb-1.1.0";

  function install(ctx) {
    if (!ctx || typeof ctx.post !== "function") {
      throw new Error("NmerPaletteAgentBridge: missing ctx.post");
    }
    if (!ctx.state) {
      throw new Error("NmerPaletteAgentBridge: missing ctx.state");
    }
    if (typeof ctx.runPaletteAgentStreamOnce !== "function") {
      throw new Error("NmerPaletteAgentBridge: missing ctx.runPaletteAgentStreamOnce");
    }

    var post = ctx.post;
    var S = ctx.state;
    var runPaletteAgentStreamOnce = ctx.runPaletteAgentStreamOnce;
    var paletteClearLateRecover = ctx.paletteClearLateRecover || function () {};
    var paletteSyncCardAnswerToNiumaSession = ctx.paletteSyncCardAnswerToNiumaSession || function () {
      return Promise.resolve();
    };
    var activeSession = ctx.activeSession || function () {
      return null;
    };
    var setSessionSending = ctx.setSessionSending || function () {};

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
