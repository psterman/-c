import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repo = path.resolve(__dirname, "..");
const lines = fs.readFileSync(path.join(repo, "html", "CommandPalette.html"), "utf8").split(/\r?\n/);

function sliceLines(from1, to1) {
  return lines.slice(from1 - 1, to1).join("\n");
}

const historyInner = sliceLines(7184, 7330);
const managerInner = sliceLines(7334, 7498);
const hubInner = sliceLines(9307, 9336);
const hostInner = sliceLines(9340, 10009);

const FN_NAMES = [
  "probeOc5ProtocolClosure",
  "probeGrayRoute",
  "prepareAdapterOfficialA2uiProbe",
  "probeAdapterOfficialA2ui",
  "applyWailsBridgeConfig",
  "applyPaletteFlags",
  "paletteFastInput",
  "updateVoiceHint",
  "purgeActionEmptyHint",
  "renderActionHistoryList",
  "syncActionResultsLayout",
  "syncWindowSize",
  "maybeRequestAgentCardSync",
  "actionHasStoredCards",
  "updateResults",
  "scheduleQueryPaintMark",
  "appendAiChunk",
  "finishAiStream",
  "showAiStreamError",
  "resetAiStreamState",
  "runQuery",
  "restoreAiSession",
  "applyAiProviders",
  "agentDebugLog",
  "clearActionHistoryLoading",
  "renderActionCardSync",
  "showActionEmptyIfNeeded",
  "applyAgentCardDetailDto",
  "applyAgentCardNew",
  "resolveActionCard",
  "applyPipelineToolEvent",
  "refreshActionCardPreview",
  "getActionCard",
  "upsertActionCardFromDto",
  "cardIsOfficialA2uiRoute",
  "isAgentStatusPreview",
  "setCardLiveThought",
  "scheduleAgentCardDomRefresh",
  "cardHasPipelineReply",
  "clipStreamText",
  "scheduleAgentPipelineIngest",
  "hideCardLiveThoughtIfReply",
  "flushAgentCardDomRefresh",
  "cardFollowUpInFlight",
  "finalizeAgentCardAnswer",
  "cardEndFinalizeNeeded",
  "cardMissingExpectedA2ui",
  "cardHasSubstantialRawAnswer",
  "cardAnswerLooksIncomplete",
  "shouldSkipProseFinalize",
  "shouldPreferIncomingGatewayAnswer",
  "finalizeOfficialA2uiCard",
  "pipelineTurnCount",
  "cardHasPipelineA2ui",
  "cardLatestTurnHasReply",
  "maybeHealDoneCardPipelineBlocks",
  "ensureCardPipelineRendered",
  "showFollowUpCompleteToast",
  "scrollToLatestReply",
  "scheduleAgentCardsRecover",
  "ensureHeaderInputVisible",
  "refreshIntentResults",
  "ensureActionResultsVisible",
  "scheduleDiscreteLayout",
  "applyTheme",
  "mountOfficialA2uiFixture",
  "hideCardHoverPreview",
  "syncExpandedCardsToHistoryFilter",
  "refreshActionHistoryHead",
  "removeActionLiveDock",
  "cardMatchesHistoryFilter",
  "isActionCardRunning",
  "sortCardIds",
  "ensureActionCardSection",
  "mountActionCardIntoList",
  "historyFilterEmptyMessage",
  "agentProviderLabel",
  "replayExpandedCardPipelineBlocks",
  "syncActionDetailNav",
  "syncActionListLayout",
  "getInputEl",
  "ensureActionCardDom",
  "actionCardUiLabel",
  "refreshActionCardPreview",
  "updateActionLiveDock",
  "syncActionResultsLayout",
  "agentDebugLog",
  "esc",
  "writeAgentRichText",
  "renderAgentPlainMarkdown",
  "isAgentStatusPreview",
  "handleHostMessage"
];

function convertBody(src, opts) {
  opts = opts || {};
  let out = src;
  out = out.replace(/state-/g, "__STATE_DASH__");
  out = out.replace(/\bactionState\b/g, "api.actionState");
  out = out.replace(/\baiPhase\b/g, "api.aiPhase");
  out = out.replace(/\baiStreamReqId\b/g, "api.aiStreamReqId");
  out = out.replace(/\baiStreamText\b/g, "api.aiStreamText");
  out = out.replace(/\baiChunkBatcher\b/g, "api.aiChunkBatcher");
  out = out.replace(/\bcomposing\b/g, "api.composing");
  out = out.replace(/\bIntentRouter\b/g, "api.IntentRouter");
  out = out.replace(/\bstate\b/g, "api.state");
  out = out.replace(/__STATE_DASH__/g, "state-");
  const sorted = [...new Set(FN_NAMES)].sort((a, b) => b.length - a.length);
  for (const fn of sorted) {
    if (opts.skipHandleHostMessage && fn === "handleHostMessage") continue;
    if (opts.skipRenderHistory && fn === "renderActionHistoryList") continue;
    const re = new RegExp("\\b" + fn + "\\s*\\(", "g");
    out = out.replace(re, "api." + fn + "(");
  }
  if (opts.managerSelf) {
    out = out.replace(/actionCardManager\.transitionCardState/g, "manager.transitionCardState");
    out = out.replace(/actionCardManager\.onBlockUpdate/g, "manager.onBlockUpdate");
  }
  if (opts.renderHistorySelf) {
    out = out.replace(/api\.renderActionHistoryList\(/g, "renderActionHistoryList(");
  }
  return out;
}

const agentSummary = `(function (global) {
  "use strict";
  var api = null;
  var _renderActionHistoryLock = false;
  function install(ctx) {
    api = ctx || {};
  }
  function renderActionHistoryList() {
${convertBody(historyInner, { renderHistorySelf: true, skipRenderHistory: true }).replace(/^/gm, "    ")}
  }
  global.PaletteAgentSummary = {
    install: install,
    renderActionHistoryList: renderActionHistoryList
  };
})(typeof window !== "undefined" ? window : globalThis);
`;

const agentDetail = `(function (global) {
  "use strict";
  function createActionCardManager(api) {
    var manager = {
${convertBody(managerInner, { managerSelf: true }).replace(/^/gm, "      ")}
    };
    return manager;
  }
  global.PaletteAgentDetail = { createActionCardManager: createActionCardManager };
})(typeof window !== "undefined" ? window : globalThis);
`;

const hostBridge = `(function (global) {
  "use strict";
  var api = null;
  function install(ctx) {
    api = ctx || {};
  }
  function handleHostMessage(d) {
${convertBody(hostInner).replace(/^/gm, "    ")}
  }
  function handleHubAgentEvent(ev) {
${convertBody(hubInner, { skipHandleHostMessage: true }).replace(/^/gm, "    ")}
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
`;

fs.mkdirSync(path.join(repo, "html", "palette", "agent"), { recursive: true });
fs.writeFileSync(path.join(repo, "html", "palette", "agent", "agent-summary.js"), agentSummary);
fs.writeFileSync(path.join(repo, "html", "palette", "agent", "agent-detail.js"), agentDetail);
fs.writeFileSync(path.join(repo, "html", "palette", "app", "host-bridge.js"), hostBridge);
console.log("wave3 modules regenerated (line-based)");
