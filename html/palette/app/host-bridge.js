(function (global) {
  "use strict";
  var api = null;
  function install(ctx) {
    api = ctx || {};
  }
  function handleHostMessage(d) {
        if (!d || !d.type) return;
        if (d.type === "palette_oc5_probe_request") {
          var oc5ReqId = String(d.reqId || "");
          try {
            var out =
              typeof api.probeOc5ProtocolClosure === "function"
                ? api.probeOc5ProtocolClosure()
                : { ok: false, code: "OC5_PROBE_FN_MISSING" };
            var payload = {
              type: "palette_oc5_probe_result",
              reqId: oc5ReqId,
              ok: !!out.ok,
              code: String(out.code || ""),
              engine: out.engine || {},
              stats: out.stats || {},
              samples: out.samples || []
            };
            if (typeof PaletteHostAdapter !== "undefined" && PaletteHostAdapter.send) {
              PaletteHostAdapter.send("palette_oc5_probe_result", payload);
            } else if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
              window.chrome.webview.postMessage(JSON.stringify(payload));
            }
          } catch (e) {
            var errPayload = {
              type: "palette_oc5_probe_result",
              reqId: oc5ReqId,
              ok: false,
              code: "OC5_PROBE_ERR",
              err: String((e && e.message) || e)
            };
            if (typeof PaletteHostAdapter !== "undefined" && PaletteHostAdapter.send) {
              PaletteHostAdapter.send("palette_oc5_probe_result", errPayload);
            } else if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
              window.chrome.webview.postMessage(JSON.stringify(errPayload));
            }
          }
          return;
        }
        if (d.type === "palette_gray_probe_request") {
          var grayReqId = String(d.reqId || "");
          var grayQuery = String(d.query || "/search 测试");
          try {
            var grayOut =
              typeof api.probeGrayRoute === "function"
                ? api.probeGrayRoute(grayQuery)
                : { ok: false, code: "GRAY_PROBE_FN_MISSING" };
            var grayPayload = {
              type: "palette_gray_probe_result",
              reqId: grayReqId,
              ok: !!grayOut.ok,
              code: String(grayOut.code || ""),
              detail: grayOut
            };
            if (typeof PaletteHostAdapter !== "undefined" && PaletteHostAdapter.send) {
              PaletteHostAdapter.send("palette_gray_probe_result", grayPayload);
            } else if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
              window.chrome.webview.postMessage(JSON.stringify(grayPayload));
            }
          } catch (e) {
            var grayErr = {
              type: "palette_gray_probe_result",
              reqId: grayReqId,
              ok: false,
              code: "GRAY_PROBE_ERR",
              detail: { err: String((e && e.message) || e) }
            };
            if (typeof PaletteHostAdapter !== "undefined" && PaletteHostAdapter.send) {
              PaletteHostAdapter.send("palette_gray_probe_result", grayErr);
            } else if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
              window.chrome.webview.postMessage(JSON.stringify(grayErr));
            }
          }
          return;
        }
        if (d.type === "palette_adp_demo_prepare") {
          if (typeof api.prepareAdapterOfficialA2uiProbe === "function") {
            api.prepareAdapterOfficialA2uiProbe();
          }
          return;
        }
        if (d.type === "palette_adp_probe_request") {
          var adpReqId = String(d.reqId || "");
          try {
            var adpPrep =
              typeof api.prepareAdapterOfficialA2uiProbe === "function"
                ? api.prepareAdapterOfficialA2uiProbe()
                : { ok: false, code: "ADP_PREP_FN_MISSING" };
            var adpOut =
              typeof api.probeAdapterOfficialA2ui === "function"
                ? api.probeAdapterOfficialA2ui()
                : { ok: false, code: "ADP_PROBE_FN_MISSING" };
            if (adpOut && typeof adpOut === "object") {
              adpOut.prep = adpPrep;
            }
            var adpPayload = {
              type: "palette_adp_probe_result",
              reqId: adpReqId,
              ok: !!adpOut.ok,
              code: String(adpOut.code || ""),
              detail: adpOut
            };
            if (typeof PaletteHostAdapter !== "undefined" && PaletteHostAdapter.send) {
              PaletteHostAdapter.send("palette_adp_probe_result", adpPayload);
            } else if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
              window.chrome.webview.postMessage(JSON.stringify(adpPayload));
            }
          } catch (e) {
            var adpErr = {
              type: "palette_adp_probe_result",
              reqId: adpReqId,
              ok: false,
              code: "ADP_PROBE_ERR",
              detail: { err: String((e && e.message) || e) }
            };
            if (typeof PaletteHostAdapter !== "undefined" && PaletteHostAdapter.send) {
              PaletteHostAdapter.send("palette_adp_probe_result", adpErr);
            } else if (window.chrome && window.chrome.webview && window.chrome.webview.postMessage) {
              window.chrome.webview.postMessage(JSON.stringify(adpErr));
            }
          }
          return;
        }
        if (d.type === "palette_wails_bridge_config") {
          api.applyWailsBridgeConfig(d);
          return;
        }
        if (d.type === "palette_flags") {
          api.applyPaletteFlags(d);
          return;
        }
        if (d.type === "palette_command_snapshot") {
          if (typeof PaletteCommandIndex !== "undefined") {
            PaletteCommandIndex.load(d);
          }
          return;
        }
        if (d.type === "palette_results") {
          if (api.state.intent === "local" && api.state.input.trim()) return;
          var remoteGen = d.generation != null ? Number(d.generation) : Number(d.seq || 0);
          if (api.paletteFastInput() && typeof PaletteQueryController !== "undefined" && remoteGen > 0 && PaletteQueryController.dropIfStale(remoteGen)) {
            return;
          }
          if (api.paletteFastInput() && api.state._actionCmdQueryActive && api.state.actions.length > 0 && remoteGen > 0 && remoteGen !== api.state.querySeq) {
            return;
          }
          if (d.seq && Number(d.seq) !== api.state.querySeq) return;
          var items = Array.isArray(d.items) ? d.items : [];
          if (api.state.intent === "action") {
            items = items.filter(function (it) {
              return it && String(it.kind || "") !== "ai_provider";
            });
          }
          api.state.actions = items;
          api.state.resultMode = "command";
          api.state.turboItems = [];
          if (api.state.selected >= api.state.actions.length) api.state.selected = 0;
          api.state.voiceStatus = "idle";
          api.state.voiceHint = "";
          api.updateVoiceHint();
          if (api.state.intent === "action") {
            if (Object.keys(api.actionState.cards).length > 0 && !api.state.actionCmdBrowse) {
              api.purgeActionEmptyHint();
              api.renderActionHistoryList();
              api.syncActionResultsLayout();
              api.syncWindowSize();
              return;
            }
            if (!api.state.input.trim() && !api.state.actionCmdBrowse) {
              api.maybeRequestAgentCardSync();
              if (api.actionHasStoredCards()) {
                api.renderActionHistoryList();
                api.syncActionResultsLayout();
                api.syncWindowSize();
              } else {
                api.purgeActionEmptyHint();
                window.nmerPalette.setStatus("正在加载历史任务…", "idle");
              }
              return;
            }
            if (!api.state.actionCmdBrowse) {
              api.state._actionQueryCache = items;
              if (Object.keys(api.actionState.cards).length > 0) {
                api.renderActionHistoryList();
                api.syncActionResultsLayout();
              }
              return;
            }
            api.purgeActionEmptyHint();
            api.updateResults();
            api.scheduleQueryPaintMark(remoteGen || api.state.querySeq, api.state.actions.length, {
              source: "host_browse",
              emptyResult: !api.state.actions.length
            });
            return;
          }
          if (typeof PalettePerfMarks !== "undefined") {
            PalettePerfMarks.mark("remote_results_painted", {
              generation: remoteGen || api.state.querySeq,
              resultCount: api.state.actions.length
            });
          }
          api.updateResults();
        } else if (d.type === "palette_turbo_results") {
          if (api.state.intent !== "local") return;
          if (d.seq && Number(d.seq) !== api.state.querySeq) return;
          if (d.query && String(d.query) !== api.state.turboQuery && String(d.query) !== api.state.input.trim()) return;
          api.state.turboItems = Array.isArray(d.items) ? d.items.slice(0, 20) : [];
          api.state.resultMode = "turbo";
          api.state.actions = [];
          if (api.state.selected >= api.state.turboItems.length) api.state.selected = 0;
          api.state.voiceStatus = "idle";
          api.state.voiceHint = "";
          if (!api.state.turboItems.length) {
            api.state.voiceHint = "无本地匹配结果";
            api.state.voiceStatus = "idle";
          }
          api.updateVoiceHint();
          api.updateResults();
          api.scheduleQueryPaintMark(d.seq || api.state.querySeq, api.state.turboItems.length, {
            source: "turbo",
            emptyResult: !api.state.turboItems.length
          });
        } else if (d.type === "palette_turbo_error") {
          if (api.state.intent !== "local") return;
          api.state.turboItems = [];
          api.state.resultMode = "command";
          window.nmerPalette.setStatus(d.message || "本地搜索不可用", "error");
          api.updateResults();
        } else if (d.type === "palette_ai_status") {
          window.nmerPalette.setStatus(d.message || "", d.status || "idle");
        } else if (d.type === "palette_ai_chunk") {
          if (d.reqId) api.aiStreamReqId = String(d.reqId);
          api.appendAiChunk(d.delta || d.text || "");
        } else if (d.type === "palette_ai_end") {
          if (api.aiChunkBatcher) api.aiChunkBatcher.flushNow();
          if (d.reqId) api.aiStreamReqId = String(d.reqId);
          if (d.answer && String(d.answer).trim()) api.aiStreamText = String(d.answer);
          api.finishAiStream(d);
        } else if (d.type === "palette_ai_error") {
          if (api.aiChunkBatcher) api.aiChunkBatcher.flushNow();
          if (d.reqId) api.aiStreamReqId = String(d.reqId);
          api.showAiStreamError(d.message || d.error || "请求失败");
        } else if (d.type === "palette_ai_reset") {
          api.resetAiStreamState();
          if (api.state.intent === "ai") {
            api.runQuery(true);
            api.syncWindowSize();
          } else api.updateResults();
        } else if (d.type === "palette_ai_restore") {
          api.restoreAiSession(d);
          api.ensureHeaderInputVisible();
        } else if (d.type === "palette_ai_providers") {
          api.applyAiProviders(d.items, d.activeProvider || "");
          if (api.state.intent === "ai") {
            var hint = api.state.selectedAiProvider ? "已选模型 · Enter 发送" : "请选择模型";
            window.nmerPalette.setStatus(hint, "idle");
          }
        } else if (d.type === "palette_status") {
          window.nmerPalette.setStatus(d.message || "", d.status || "idle");
        } else if (d.type === "palette_agent_card_sync") {
          api.agentDebugLog("host_card_sync", "n=" + (Array.isArray(d.cards) ? d.cards.length : 0) + (d.summary ? " summary" : ""));
          var syncCards = d.cards || [];
          if (syncCards.length) {
            api.clearActionHistoryLoading();
            if (api.actionState._cardPullEmptyTimer) {
              clearTimeout(api.actionState._cardPullEmptyTimer);
              api.actionState._cardPullEmptyTimer = 0;
            }
          }
          api.renderActionCardSync(syncCards, { summary: !!d.summary });
          if (!syncCards.length && api.state.intent === "action" && !api.state.input.trim() && !api.state.actionCmdBrowse) {
            api.showActionEmptyIfNeeded();
          }
        } else if (d.type === "palette_agent_card_detail") {
          var detailCard = d.card;
          if (detailCard && detailCard.cardId) {
            api.agentDebugLog("host_card_detail", "card=" + String(detailCard.cardId));
            api.applyAgentCardDetailDto(detailCard);
          }
        } else if (d.type === "palette_agent_card_new") {
          api.agentDebugLog("host_card_new", "card=" + (d.cardId || "") + " req=" + (d.reqId || ""));
          api.applyAgentCardNew(d);
        } else if (d.type === "palette_agent_tool_event") {
          api.agentDebugLog(
            "host_tool_event",
            "card=" +
              (d.cardId || "") +
              " tool=" +
              (d.tool || "") +
              " phase=" +
              (d.phase || "")
          );
          var toolResolved = api.resolveActionCard(d.cardId, d.reqId);
          if (toolResolved.card && toolResolved.id) {
            api.applyPipelineToolEvent(toolResolved.id, {
              tool: d.tool,
              phase: d.phase,
              text: d.text || d.message || "",
              level: d.level || "info",
              ts: d.ts
            });
            api.refreshActionCardPreview(toolResolved.id);
          }
        } else if (d.type === "palette_agent_chunk") {
          api.agentDebugLog("host_chunk", "card=" + (d.cardId || "") + " req=" + (d.reqId || "") + " Δ=" + String(d.delta || d.text || "").slice(0, 48));
          var resolved = api.resolveActionCard(d.cardId, d.reqId);
          var card = resolved.card;
          var cid = resolved.id;
          if (!card && cid) {
            api.upsertActionCardFromDto({
              cardId: cid,
              reqId: d.reqId || "",
              uiState: "Running",
              title: "代理任务",
              query: "",
              running: true,
              ended: false
            });
            card = api.getActionCard(cid);
          }
          if (!card && (d.cardId || d.reqId)) {
            api.upsertActionCardFromDto({
              cardId: String(d.cardId || ""),
              reqId: d.reqId || "",
              uiState: "Running",
              title: "代理任务",
              query: "",
              running: true,
              ended: false
            });
            resolved = api.resolveActionCard(d.cardId, d.reqId);
            card = resolved.card;
            cid = resolved.id;
          }
          if (card) {
            var delta = String(d.delta || d.text || "");
            var preview = delta.replace(/\s+/g, " ").trim().slice(0, 160);
            var statusPreview = preview && api.isAgentStatusPreview(preview);
            if (api.cardIsOfficialA2uiRoute(card)) {
              if (statusPreview || !delta) {
                if (d.liveThought && statusPreview) api.setCardLiveThought(cid, String(d.liveThought), true);
                api.scheduleAgentCardDomRefresh(cid);
                return;
              }
              api.agentDebugLog("host_chunk_skip_prose", "route=r3 card=" + cid);
              return;
            }
            if (
              card.ended &&
              card.uiState === "Done" &&
              api.cardHasPipelineReply(card) &&
              (!delta || statusPreview)
            ) {
              return;
            }
            card.running = true;
            card.ended = false;
            card._summaryOnly = false;
            card._summaryPreview = "";
            if (api.isActionCardRunning(card) || card.uiState === "Planning" || card.uiState === "Running") {
              api.actionState.activeCardId = cid;
            }
            if (d.sessionRef) card.sessionRef = String(d.sessionRef);
            var domC = document.getElementById("card-" + cid);
            if (domC && api.isActionCardRunning(card)) {
              domC.classList.add("is-active");
              domC.classList.remove("is-collapsed");
            }
            var statusLive = d.liveThought && api.isAgentStatusPreview(d.liveThought);
            var hasBody = card.rawAnswer && !api.isAgentStatusPreview(card.rawAnswer);
            if (api.cardHasPipelineReply(card)) hasBody = true;
            if (card.parser && card.parser._buf && !api.isAgentStatusPreview(card.parser._buf)) hasBody = true;
            if (delta && !statusPreview) {
              if (!card.rawAnswer || api.isAgentStatusPreview(card.rawAnswer))
                card.rawAnswer = api.clipStreamText(delta);
              else card.rawAnswer = api.clipStreamText(String(card.rawAnswer || "") + delta);
            }
            var pipelineActive =
              typeof PaletteBlockPipeline !== "undefined" && typeof PaletteBlockPipeline.ingestDelta === "function";
            if (pipelineActive && delta) {
              var ingestOut = api.scheduleAgentPipelineIngest(cid, delta);
              var ingestStatusOnly = ingestOut && ingestOut.meta && ingestOut.meta.statusOnly;
              var ingestHasReply = api.cardHasPipelineReply(card);
              if (ingestHasReply) {
                api.hideCardLiveThoughtIfReply(cid);
                window.nmerPalette.setStatus("流式输出中…", "loading");
              } else if (ingestStatusOnly) {
                if (d.liveThought && (!hasBody || !statusLive))
                  api.setCardLiveThought(cid, String(d.liveThought), true);
                else if (preview && statusPreview && !hasBody) api.setCardLiveThought(cid, preview, true);
                if (statusLive || statusPreview)
                  window.nmerPalette.setStatus(
                    (d.liveThought || preview || "").slice(0, 80),
                    "loading"
                  );
              } else if (preview && !statusPreview) {
                var mergedBlocks =
                  (ingestOut && ingestOut.blocks) ||
                  getCardPipelineBlocks(card);
                var sum =
                  (mergedBlocks.length &&
                    PaletteBlockPipeline.blockPreviewSummary &&
                    PaletteBlockPipeline.blockPreviewSummary(mergedBlocks)) ||
                  "";
                if (!sum && preview) sum = preview;
                if (card._protoStarted || (domC && domC.classList.contains("has-status-log"))) {
                  window.nmerPalette.setStatus("流式输出中…", "loading");
                } else if (sum) {
                  api.setCardLiveThought(cid, sum, true);
                  window.nmerPalette.setStatus("流式输出中…", "loading");
                }
              }
            } else if (preview && !statusPreview) {
              if (card.parser && delta) {
                if (agentTextHasProtocolTags(delta)) card._protoStarted = true;
                card.parser.onChunk(delta);
              }
              if (card._protoStarted || (domC && domC.classList.contains("has-status-log"))) {
                window.nmerPalette.setStatus("流式输出中…", "loading");
              } else {
                var bodyPreview = "";
                var pipeBlocksPreview = getCardPipelineBlocks(card);
                if (
                  pipeBlocksPreview.length &&
                  typeof PaletteBlockPipeline !== "undefined" &&
                  PaletteBlockPipeline.blockPreviewSummary
                ) {
                  bodyPreview = PaletteBlockPipeline.blockPreviewSummary(pipeBlocksPreview);
                }
                if (!bodyPreview && card.parser && card.parser._buf) {
                  bodyPreview = sanitizeLiveThoughtDisplay(String(card.parser._buf).trim());
                }
                if (!bodyPreview) bodyPreview = sanitizeLiveThoughtDisplay(preview);
                if (bodyPreview) api.setCardLiveThought(cid, bodyPreview, true);
                window.nmerPalette.setStatus("流式输出中…", "loading");
              }
            } else if (d.liveThought && (!hasBody || !statusLive)) {
              api.setCardLiveThought(cid, String(d.liveThought), true);
              if (statusLive) window.nmerPalette.setStatus(String(d.liveThought).slice(0, 80), "loading");
            } else if (preview && statusPreview && !hasBody) {
              api.setCardLiveThought(cid, preview, true);
              window.nmerPalette.setStatus(preview.slice(0, 80), "loading");
            }
            if (card.uiState === "Planning") actionCardManager.transitionCardState(cid, "Running");
            if (
              card.uiState === "Done" &&
              !card.ended &&
              !api.cardHasPipelineReply(card) &&
              (statusPreview || statusLive || /同步 Niuma|OpenClaw 处理|chat\.send/i.test(preview))
            )
              actionCardManager.transitionCardState(cid, "Running");
            api.scheduleAgentCardDomRefresh(cid);
          }
        } else if (d.type === "palette_agent_end") {
          api.agentDebugLog("host_end", "card=" + (d.cardId || "") + " req=" + (d.reqId || "") + " len=" + String(d.answer || "").length);
          var endR = api.resolveActionCard(d.cardId, d.reqId);
          var cid2 = endR.id;
          if (cid2) api.flushAgentCardDomRefresh(cid2);
          var card2 = endR.card;
          var endSource = String(d.source || "host");
          if (card2 && api.shouldSkipProseFinalize(card2, { source: endSource === "hub_ws" ? "hub_ws" : "openclaw_sync" })) {
            api.agentDebugLog("host_end_skip_prose", "card=" + cid2 + " route=r3 source=" + endSource);
            if (card2 && d.sessionRef) card2.sessionRef = String(d.sessionRef);
            return;
          }
          var endAns = dedupeRepeatedAgentText(String(d.answer || "").trim());
          var prevRawLen = card2 ? String(card2.rawAnswer || "").length : 0;
          var endReady = endAns && agentEndAnswerReady(endAns, card2);
          var gatewayPrefer =
            card2 && api.shouldPreferIncomingGatewayAnswer(card2.rawAnswer, endAns, card2) && endAns.length >= 120;
          var forceFinalize =
            endAns &&
            (endReady ||
              gatewayPrefer ||
              (endAns.length >= 800 && endAns.length > prevRawLen) ||
              (endAns.length > prevRawLen + 120 && !agentLooksLikeThinkingPreambleOnly(endAns)));
          var followUpQuery = card2 ? String(card2._lastFollowUpQuery || card2.activeQuery || "").trim() : "";
          var wasCollapsed = card2 && !card2.expanded;
          if (card2 && forceFinalize && api.cardEndFinalizeNeeded(card2, d.reqId, endAns)) {
            ensureFollowUpPriorBlocks(card2);
            card2._summaryOnly = false;
            card2._summaryPreview = "";
            card2.error = "";
            card2.rawAnswer = endAns;
            card2._rawReplaySig = endAns;
            card2.activeQuery = "";
            card2._lastAgentEndKey =
              String(d.reqId || card2.reqId || "") + ":" + endAns.length + ":" + endAns.slice(0, 160);
            card2._lastAgentEndTick = Date.now();
            api.finalizeAgentCardAnswer(cid2, endAns);
            card2._followUpMergedTick = Date.now();
            refreshActionCardDom(card2);
            api.ensureCardPipelineRendered(card2);
            scheduleExpandedCardLayout(card2);
          } else if (card2 && forceFinalize) {
            card2._summaryOnly = false;
            card2._summaryPreview = "";
            card2.rawAnswer = endAns;
            card2._rawReplaySig = endAns;
            card2.activeQuery = "";
            card2._lastAgentEndTick = Date.now();
            var fuPending =
              api.cardFollowUpInFlight(card2) ||
              String(card2._lastFollowUpQuery || "").trim();
            var needFuFinalize = false;
            if (fuPending) {
              ensureFollowUpPriorBlocks(card2);
              var latestFuMd = getLatestReplyMarkdownFromBlocks(getCardPipelineBlocks(card2)) || "";
              needFuFinalize = latestFuMd.trim() !== endAns.trim();
            }
            if (
              needFuFinalize ||
              api.cardMissingExpectedA2ui(card2, getCardPipelineBlocks(card2)) ||
              !api.cardHasPipelineReply(card2)
            ) {
              api.finalizeAgentCardAnswer(cid2, endAns);
              card2._followUpMergedTick = Date.now();
            }
            refreshActionCardDom(card2);
          }
          if (card2 && card2.parser && card2.parser.flush) card2.parser.flush();
          if (card2 && d.sessionRef) card2.sessionRef = String(d.sessionRef);
          if (card2) {
            if (!forceFinalize && (api.cardFollowUpInFlight(card2) || !api.cardHasPipelineReply(card2))) {
              card2.running = true;
              card2.ended = false;
              if (card2.uiState === "Done") actionCardManager.transitionCardState(cid2, "Running");
              card2.liveThought = card2.liveThought || "⏳ 等待 OpenClaw 回复同步…";
              refreshActionCardDom(card2);
              api.scheduleAgentCardsRecover();
              api.syncActionResultsLayout();
              return;
            }
            card2.running = false;
            card2.ended = true;
            var pipeBlocks =
              (card2.blockStore && card2.blockStore.blocks) || card2.pipelineBlocks || [];
            var waitingQ = false;
            for (var wi = 0; wi < pipeBlocks.length; wi++) {
              if (pipeBlocks[wi].type === "question" && pipeBlocks[wi].status === "waiting") {
                waitingQ = true;
                break;
              }
            }
            var endState =
              waitingQ || card2.waitingForUser || card2.uiState === "Waiting" ? "Waiting" : "Done";
            actionCardManager.transitionCardState(cid2, endState);
            if (endState === "Done") {
              card2.liveThought = "";
              api.maybeHealDoneCardPipelineBlocks(card2, cid2);
              api.ensureCardPipelineRendered(card2);
              var domDone = document.getElementById("card-" + cid2);
              if (domDone && api.cardHasPipelineReply(card2)) {
                var logDone = domDone.querySelector(".card-status-log");
                if (logDone) logDone.innerHTML = "";
                domDone.classList.remove("has-status-log");
                var ltDone = domDone.querySelector(".card-live-thought");
                if (ltDone) ltDone.style.display = "none";
              }
            }
            if (endState === "Done" && (api.pipelineTurnCount(card2) > 1 || followUpQuery)) {
              api.showFollowUpCompleteToast(cid2, followUpQuery);
              if (!wasCollapsed && card2.expanded) {
                setTimeout(function () {
                  api.scrollToLatestReply(cid2);
                }, 80);
              }
            }
          }
          api.updateActionLiveDock(cid2);
          document.querySelectorAll(".cmd-action-card").forEach(function (el) {
            el.classList.toggle("is-active", el.id === "card-" + cid2);
            el.classList.toggle("is-collapsed", el.id !== "card-" + cid2);
          });
          window.nmerPalette.setStatus("托管任务已完结", "idle");
          api.syncActionResultsLayout();
        } else if (d.type === "palette_agent_error" || (d.type === "palette_agent_status" && d.status === "error")) {
          var errMsg = d.message || "代理任务失败";
          api.agentDebugLog("host_error", errMsg, "err");
          window.nmerPalette.setStatus(errMsg, "error");
          var er = api.resolveActionCard(d.cardId, d.reqId);
          if (er.card && er.id) {
            er.card.running = false;
            er.card.ended = true;
            er.card.uiState = "Done";
            er.card.liveThought = errMsg;
            er.card.error = errMsg;
            actionCardManager.transitionCardState(er.id, "Done");
            api.setCardLiveThought(er.id, errMsg, false);
            var errDom = document.getElementById("card-" + er.id);
            if (errDom) {
              var errLog = errDom.querySelector(".card-status-log");
              if (errLog) {
                var errTail = errLog.querySelector(".b-status:last-child");
                if (errTail) {
                  errTail.querySelector(".b-status-title").textContent = "[失败]";
                  var errLogEl = errTail.querySelector(".b-status-log");
                  if (errLogEl) errLogEl.textContent = errMsg;
                }
              }
            }
            api.flushAgentCardDomRefresh(er.id);
          }
        } else if (d.type === "palette_agent_status") {
          api.agentDebugLog("host_status", String(d.message || "").slice(0, 80));
          window.nmerPalette.setStatus(d.message || "", d.status || "idle");
          var stR = api.resolveActionCard(d.cardId, d.reqId);
          if (stR.id) {
            api.setCardLiveThought(stR.id, d.message || "", d.status === "loading");
          }
        } else if (d.type === "palette_agent_heartbeat") {
          api.agentDebugLog("host_heartbeat", String(d.message || "").slice(0, 60), "warn");
          var hb = api.resolveActionCard(d.cardId, d.reqId);
          var hbMsg = String(d.liveThought || d.message || "等待响应…");
          if (hb.id) {
            api.setCardLiveThought(hb.id, hbMsg, true);
            window.nmerPalette.setStatus(hbMsg.slice(0, 80), "loading");
          }
        } else if (d.type === "palette_agent_session") {
          var cid3 = String(d.cardId || "");
          var card3 = api.getActionCard(cid3);
          if (card3) card3.sessionRef = String(d.sessionRef || "");
        } else if (d.type === "PALETTE_PHYSICAL_FEEDBACK") {
          var cid4 = String(d.cardId || "");
          var card4 = api.getActionCard(cid4);
          if (card4) {
            actionCardManager.onBlockUpdate(cid4, {
              type: "status",
              closed: true,
              seq: Date.now(),
              title: "[本地触达] " + String(d.actionType || ""),
              log: String(d.status || "") + (d.detail ? " · " + d.detail : ""),
              body: ""
            });
          }
        } else if (d.type === "palette_set_input") {
          window.nmerPalette.setInputText(d.text || "");
        } else if (d.type === "palette_set_intent") {
          api.state.intent = String(d.intent || "local");
          syncIntentUI();
          if (api.state.intent === "action") requestAgentCardSync();
          api.refreshIntentResults(true);
          api.syncWindowSize();
        } else if (d.type === "palette_memory_tier_mount") {
          var tierIds = Array.isArray(d.cardIds) ? d.cardIds : [];
          var tierFixture = String(d.fixtureId || "happy-six-components");
          for (var ti = 0; ti < tierIds.length; ti++) {
            api.mountOfficialA2uiFixture(String(tierIds[ti] || ""), tierFixture);
          }
          api.syncActionResultsLayout();
        } else if (d.type === "palette_focus" || d.type === "palette_show") {
          api.ensureHeaderInputVisible();
          if (api.state.intent === "action") {
            if (!api.actionHasStoredCards()) requestAgentCardSync();
            api.refreshIntentResults(true);
            api.ensureActionResultsVisible();
            api.renderActionHistoryList();
          }
          if (paletteDiscreteLayout() && api.state.intent === "action" && typeof PaletteLayout !== "undefined") {
            var needReset =
              typeof PaletteLayout.getLastMode === "function" && PaletteLayout.getLastMode() !== "list";
            if (needReset) PaletteLayout.resetMode();
            api.scheduleDiscreteLayout(needReset);
          } else {
            api.syncWindowSize();
          }
          api.getInputEl()?.focus();
        } else if (d.type === "set_theme") {
          api.applyTheme(d.themeMode || d.theme || "dark");
        }
  }
  function handleHubAgentEvent(ev) {
        if (!ev || !ev.kind) return;
        var kind = String(ev.kind || "");
        var cardId = String(ev.cardId || "");
        var payload = ev.payload && typeof ev.payload === "object" ? ev.payload : {};
        if (!cardId && payload.cardId) cardId = String(payload.cardId || "");
        var reqId = String(payload.reqId || "");
        var hubCard = cardId ? api.getActionCard(cardId) : null;
        if (hubCard && api.shouldSkipProseFinalize(hubCard, { source: "hub_ws" })) {
          api.agentDebugLog("hub_ws_skip_prose", "kind=" + kind + " card=" + cardId);
          return;
        }
        if (kind === "reply_delta") {
          handleHostMessage({
            type: "palette_agent_chunk",
            cardId: cardId,
            reqId: reqId,
            delta: String(payload.delta || ""),
            source: "hub_ws"
          });
          return;
        }
        if (kind === "reply_final") {
          handleHostMessage({
            type: "palette_agent_end",
            cardId: cardId,
            reqId: reqId,
            answer: String(payload.answer || ""),
            source: "hub_ws"
          });
        }
  }
  global.PaletteHostBridge = {
    install: install,
    handleHostMessage: handleHostMessage,
    handleHubAgentEvent: handleHubAgentEvent,
    bindAdapter: function () {
      if (typeof global.PaletteHostAdapter !== "undefined" && global.PaletteHostAdapter.onMessage) {
        global.PaletteHostAdapter.onMessage(handleHostMessage);
      }
    }
  };
})(typeof window !== "undefined" ? window : globalThis);
