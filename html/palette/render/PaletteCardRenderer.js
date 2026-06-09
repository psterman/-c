/**
 * PaletteCardRenderer — Command Palette 卡片块渲染（plan/status/question/reply/a2ui/error + actions 槽）
 *
 * Cat-A Patch 1：从 CommandPalette.html 抽出；行为与迁移前一致。
 * TODO: Stage 7 收敛 options.deps，去除 window fallback。
 */
(function (root) {
  // TODO: Stage 7 收敛 deps — 暂由 CommandPalette 经 options.deps 注入

  var ACTION_CHIPS_COMPONENT = "ActionChips";
  var TRACE_REASONS =
    root.PaletteSlotRenderTrace && PaletteSlotRenderTrace.TRACE_REASONS
      ? PaletteSlotRenderTrace.TRACE_REASONS
      : {
          OK: "ok",
          INVALID_SCHEMA: "invalid_schema",
          UNKNOWN_BLOCK: "unknown_block",
          NO_LIT_COMPONENT: "no_lit_component",
          RENDER_ERROR: "render_error",
          UNSUPPORTED_ACTION: "unsupported_action"
        };

  function normalizeTraceReason(reason, renderer) {
    if (root.PaletteSlotRenderTrace && PaletteSlotRenderTrace.normalizeRenderReason) {
      return PaletteSlotRenderTrace.normalizeRenderReason(reason, renderer);
    }
    return String(reason || "").trim() || (renderer === "lit" ? TRACE_REASONS.OK : TRACE_REASONS.NO_LIT_COMPONENT);
  }

  function resolveBlockType(block) {
    if (!block) return "unknown";
    if (block.type === "a2ui") return String(block.component || "a2ui");
    return String(block.type || "unknown");
  }

  function traceRecord(slot, info) {
    if (root.PaletteSlotRenderTrace && PaletteSlotRenderTrace.record) {
      PaletteSlotRenderTrace.record(slot, info);
    }
  }

  function traceBlockRender(cardId, block, result, options) {
    result = result || {};
    block = block || {};
    var renderer = String(result.renderer || "legacy");
    var reason = normalizeTraceReason(result.reason, renderer);
    var blockType = result.blockType || resolveBlockType(block);
    var info = {
      cardId: String(cardId || ""),
      blockId: result.blockId || block.id || "",
      blockType: blockType,
      component: result.component || blockType,
      renderer: renderer,
      reason: reason,
      count: result.count != null ? result.count : 0
    };
    var slot =
      result.slot ||
      (block.type === "a2ui" ? String(block.component || "a2ui") : String(block.type || "unknown"));
    traceRecord(slot, info);
    var debugLog = resolveDeps(options).debugLog;
    if (!debugLog) return info;
    try {
      debugLog(
        "block_render_trace",
        JSON.stringify({
          cardId: info.cardId,
          blockId: info.blockId,
          blockType: info.blockType,
          renderer: info.renderer,
          reason: info.reason,
          count: info.count
        })
      );
    } catch (_) {}
    return info;
  }

  function isActionChipsBlock(block) {
    return !!(block && block.type === "a2ui" && String(block.component || "") === ACTION_CHIPS_COMPONENT);
  }

  function isComparisonTableBlock(block) {
    return !!(
      block &&
      block.type === "a2ui" &&
      String(block.component || "") === "ComparisonTable"
    );
  }

  function isStepsBlock(block) {
    return !!(
      block &&
      block.type === "a2ui" &&
      String(block.component || "") === "Steps"
    );
  }

  function isAlertBlock(block) {
    return !!(
      block &&
      block.type === "a2ui" &&
      String(block.component || "") === "Alert"
    );
  }

  function actionChipsCount(block) {
    return block && block.props && Array.isArray(block.props.actions) ? block.props.actions.length : 0;
  }

  function logActionChipsRender(cardId, block, result, options) {
    var debugLog = resolveDeps(options).debugLog;
    if (!debugLog) return;
    var renderer = result.renderer || "legacy";
    try {
      debugLog(
        "action_chips_render",
        JSON.stringify({
          cardId: cardId,
          blockId: (block && block.id) || "",
          component: ACTION_CHIPS_COMPONENT,
          blockType: ACTION_CHIPS_COMPONENT,
          renderer: renderer,
          reason: normalizeTraceReason(result.reason, renderer),
          count: result.count != null ? result.count : actionChipsCount(block)
        })
      );
    } catch (_) {}
  }

  function tryRenderActionChipsLit(cardId, dom, block, card, options) {
    if (!root.PaletteLitRenderer || !PaletteLitRenderer.renderActionChipsBlock) return null;
    if (!PaletteLitRenderer.isLitAvailableForTag("palette-action-chips")) return null;
    var box = dom && dom.querySelector ? dom.querySelector(".card-followup-chips") : null;
    if (!box) {
      return { ok: false, renderer: "legacy", reason: "bridge_unavailable", count: 0 };
    }
    return PaletteLitRenderer.renderActionChipsBlock(cardId, card, box, block, options);
  }

  function renderActionChipsPipelineBlock(cardId, dom, block, card, options) {
    var count = actionChipsCount(block);
    var litResult = tryRenderActionChipsLit(cardId, dom, block, card, options);
    if (litResult && litResult.ok && litResult.renderer === "lit") {
      traceBlockRender(
        cardId,
        block,
        {
          slot: "ActionChips",
          component: ACTION_CHIPS_COMPONENT,
          blockType: ACTION_CHIPS_COMPONENT,
          renderer: "lit",
          reason: TRACE_REASONS.OK,
          count: litResult.count != null ? litResult.count : count,
          blockId: block.id || ""
        },
        options
      );
      logActionChipsRender(cardId, block, litResult, options);
      if (card) {
        card._actionChipsLitRendered = true;
        card._actionChipsPipelineHandled = true;
      }
      var chipsBox = dom.querySelector(".card-followup-chips");
      if (chipsBox) chipsBox.hidden = false;
      return;
    }
    var fallbackReason =
      litResult && litResult.reason ? litResult.reason : TRACE_REASONS.NO_LIT_COMPONENT;
    traceBlockRender(
      cardId,
      block,
      {
        slot: "ActionChips",
        component: ACTION_CHIPS_COMPONENT,
        blockType: ACTION_CHIPS_COMPONENT,
        renderer: "legacy",
        reason: fallbackReason,
        count: count,
        blockId: block.id || ""
      },
      options
    );
    logActionChipsRender(
      cardId,
      block,
      { renderer: "legacy", reason: fallbackReason, count: count },
      options
    );
    if (card) card._actionChipsPipelineHandled = true;
  }

  function traceDroppedA2uiBlock(cardId, block, reason, options) {
    var comp = String((block && block.component) || "");
    var slot = comp === ACTION_CHIPS_COMPONENT ? "ActionChips" : "a2ui";
    traceBlockRender(
      cardId,
      block,
      {
        slot: slot,
        component: comp || "unknown",
        blockType: comp || "unknown",
        renderer: "fallback",
        reason: reason,
        count: 0,
        blockId: (block && block.id) || ""
      },
      options
    );
  }

  function traceDroppedBlocks(cardId, dropped, options) {
    if (!Array.isArray(dropped) || !dropped.length) return;
    var whitelist =
      root.PaletteBlockSchema && PaletteBlockSchema.A2UI_WHITELIST
        ? PaletteBlockSchema.A2UI_WHITELIST
        : [];
    for (var i = 0; i < dropped.length; i++) {
      var block = dropped[i];
      if (!block || block.type !== "a2ui") continue;
      var comp = String(block.component || "");
      if (!comp || whitelist.indexOf(comp) < 0) {
        traceDroppedA2uiBlock(cardId, block, TRACE_REASONS.UNKNOWN_BLOCK, options);
      } else if (comp === ACTION_CHIPS_COMPONENT) {
        traceDroppedA2uiBlock(cardId, block, TRACE_REASONS.INVALID_SCHEMA, options);
      } else {
        traceDroppedA2uiBlock(cardId, block, TRACE_REASONS.INVALID_SCHEMA, options);
      }
    }
  }

  function resolveDeps(options) {
    options = options || {};
    var deps = options.deps || {};
    return {
      esc: deps.esc,
      renderAgentPlainMarkdown: deps.renderAgentPlainMarkdown,
      getActionCard: deps.getActionCard,
      debugLog: options.debugLog || function () {},
      onAfterRender: options.onAfterRender || function () {}
    };
  }

  function buildCardReplyActionsHtml(cardId, block, esc) {
    if (!block || block.type !== "reply" || !String(block.markdown || "").trim()) return "";
    var bid = String(block.id || "");
    var tid = block.turnId != null ? Number(block.turnId) : 1;
    return (
      '<div class="card-reply-actions" role="toolbar" aria-label="回复操作">' +
      '<button type="button" class="card-reply-act-btn" data-reply-act="copy" data-card-id="' +
      esc(cardId) +
      '" data-block-id="' +
      esc(bid) +
      '" data-turn-id="' +
      tid +
      '" title="复制正文">复制</button>' +
      '<button type="button" class="card-reply-act-btn card-reply-act-danger" data-reply-act="regen" data-card-id="' +
      esc(cardId) +
      '" data-block-id="' +
      esc(bid) +
      '" data-turn-id="' +
      tid +
      '" title="删除此回复并重新生成">重答</button>' +
      '<button type="button" class="card-reply-act-btn" data-reply-act="tts" data-card-id="' +
      esc(cardId) +
      '" data-block-id="' +
      esc(bid) +
      '" data-turn-id="' +
      tid +
      '" title="语音朗读">朗读</button>' +
      '<button type="button" class="card-reply-act-btn" data-reply-act="export-md" data-card-id="' +
      esc(cardId) +
      '" data-block-id="' +
      esc(bid) +
      '" data-turn-id="' +
      tid +
      '" title="导出 Markdown">MD</button>' +
      '<button type="button" class="card-reply-act-btn" data-reply-act="export-txt" data-card-id="' +
      esc(cardId) +
      '" data-block-id="' +
      esc(bid) +
      '" data-turn-id="' +
      tid +
      '" title="导出纯文本">TXT</button>' +
      '<button type="button" class="card-reply-act-btn" data-reply-act="share" data-card-id="' +
      esc(cardId) +
      '" data-block-id="' +
      esc(bid) +
      '" data-turn-id="' +
      tid +
      '" title="复制分享">分享</button>' +
      "</div>"
    );
  }

  function ensureCardA2uiDomOrder(dom) {
    if (!dom) return;
    var body = dom.querySelector(".card-body");
    var a2 = dom.querySelector(".card-a2ui");
    var replies = dom.querySelector(".card-replies");
    if (!body || !a2 || !replies) return;
    if (replies.compareDocumentPosition(a2) & Node.DOCUMENT_POSITION_FOLLOWING) {
      body.insertBefore(a2, replies);
    }
  }

  function ensureCardRepliesHost(dom) {
    if (!dom) return null;
    var host = dom.querySelector(".card-replies");
    if (host) return host;
    host = document.createElement("div");
    host.className = "card-replies";
    var body = dom.querySelector(".card-body");
    var legacy = dom.querySelector(".card-reply");
    if (legacy && legacy.parentNode) legacy.parentNode.replaceChild(host, legacy);
    else if (body) body.appendChild(host);
    return host;
  }

  function syncActionCardStatusLogVisibility(dom) {
    if (!dom) return;
    var logBox = dom.querySelector(".card-status-log");
    var has = !!(logBox && logBox.querySelector(".b-status"));
    dom.classList.toggle("has-status-log", has);
  }

  function enrichStatusDescriptor(descriptor, block, options) {
    if (!descriptor || !block) return descriptor;
    var d = resolveDeps(options);
    var renderAgentPlainMarkdown = d.renderAgentPlainMarkdown || function (t) { return String(t || ""); };
    var items = Array.isArray(block.items) ? block.items : [];
    descriptor.props = descriptor.props || {};
    descriptor.props.entries = items.map(function (it) {
      it = it || {};
      return {
        text: it.text || "",
        level: it.level || "info",
        time: it.time || "",
        bodyHtml: renderAgentPlainMarkdown(it.text || "")
      };
    });
    descriptor.props.streaming = block.state === "streaming";
    descriptor.props.renderer = "lit";
    descriptor.tag = "palette-status-log";
    return descriptor;
  }

  function logStatusRender(cardId, descriptor, result, options) {
    var debugLog = resolveDeps(options).debugLog;
    if (!debugLog) return;
    try {
      debugLog(
        "status_block_render",
        JSON.stringify({
          cardId: cardId,
          blockId: (descriptor && descriptor.props && descriptor.props.blockId) || "",
          component: "status-log",
          slot: "status",
          count: result.count != null ? result.count : 0,
          renderer: result.renderer || "legacy",
          reason: result.reason || ""
        })
      );
    } catch (_) {}
  }

  function renderStatusBlockLegacy(cardId, dom, block, options) {
    if (!dom || !block || block.type !== "status") return;
    var d = resolveDeps(options);
    var esc = d.esc || function (t) { return String(t || ""); };
    var renderAgentPlainMarkdown = d.renderAgentPlainMarkdown || function (t) { return String(t || ""); };
    var logBox = dom.querySelector(".card-status-log");
    if (!logBox) return;
    (block.items || []).forEach(function (it) {
      var lv = it.level === "error" ? " is-error" : it.level === "warning" ? " is-warning" : "";
      var tail = document.createElement("div");
      tail.className = "b-status" + lv;
      tail.setAttribute("data-block-id", block.id || "");
      tail.innerHTML =
        '<div class="b-status-title">' +
        esc(it.time ? "[" + it.time + "] " : "[执行中]") +
        '</div><div class="b-status-log md-body">' +
        renderAgentPlainMarkdown(it.text || "") +
        "</div>";
      logBox.appendChild(tail);
    });
    logBox.scrollTop = logBox.scrollHeight;
  }

  function tryRenderStatusLit(cardId, dom, block, card, options) {
    if (!root.PaletteCardSlots || !PaletteCardSlots.toBlockDescriptor) return null;
    if (!root.PaletteLitRenderer || !PaletteLitRenderer.renderSlot) return null;
    var logBox = dom.querySelector(".card-status-log");
    if (!logBox) return null;
    var descriptor = PaletteCardSlots.toBlockDescriptor(card, block);
    if (!descriptor || descriptor.component !== "status-log") return null;
    descriptor = enrichStatusDescriptor(descriptor, block, options);
    return PaletteLitRenderer.renderSlot(cardId, logBox, descriptor, options);
  }

  function tryRenderComparisonTableLit(cardId, dom, block, card, options) {
    if (!root.PaletteCardSlots || !PaletteCardSlots.toBlockDescriptor) return null;
    if (!root.PaletteLitRenderer || !PaletteLitRenderer.renderSlot) return null;
    if (!PaletteLitRenderer.isLitAvailableForTag("palette-comparison-table")) return null;
    var host = dom.querySelector(".card-a2ui");
    if (!host) return null;
    host.hidden = false;
    var slot = document.createElement("div");
    slot.className = "a2ui-slot";
    slot.setAttribute("data-block-id", block.id || "");
    slot.setAttribute("data-component", block.component || "");
    host.appendChild(slot);
    var descriptor = PaletteCardSlots.toBlockDescriptor(card, block);
    var result = PaletteLitRenderer.renderSlot(cardId, slot, descriptor, options);
    if (!result || !result.ok || result.renderer !== "lit") slot.remove();
    return result;
  }

  function tryRenderStepsLit(cardId, dom, block, card, options) {
    if (!root.PaletteCardSlots || !PaletteCardSlots.toBlockDescriptor) return null;
    if (!root.PaletteLitRenderer || !PaletteLitRenderer.renderSlot) return null;
    if (!PaletteLitRenderer.isLitAvailableForTag("palette-steps")) return null;
    var host = dom.querySelector(".card-a2ui");
    if (!host) return null;
    host.hidden = false;
    var slot = document.createElement("div");
    slot.className = "a2ui-slot";
    slot.setAttribute("data-block-id", block.id || "");
    slot.setAttribute("data-component", block.component || "");
    host.appendChild(slot);
    var descriptor = PaletteCardSlots.toBlockDescriptor(card, block);
    var result = PaletteLitRenderer.renderSlot(cardId, slot, descriptor, options);
    if (!result || !result.ok || result.renderer !== "lit") slot.remove();
    return result;
  }

  function tryRenderAlertLit(cardId, dom, block, card, options) {
    if (!root.PaletteCardSlots || !PaletteCardSlots.toBlockDescriptor) return null;
    if (!root.PaletteLitRenderer || !PaletteLitRenderer.renderSlot) return null;
    if (!PaletteLitRenderer.isLitAvailableForTag("palette-alert")) return null;
    var host = dom.querySelector(".card-a2ui");
    if (!host) return null;
    host.hidden = false;
    var slot = document.createElement("div");
    slot.className = "a2ui-slot";
    slot.setAttribute("data-block-id", block.id || "");
    slot.setAttribute("data-component", block.component || "");
    host.appendChild(slot);
    var descriptor = PaletteCardSlots.toBlockDescriptor(card, block);
    var result = PaletteLitRenderer.renderSlot(cardId, slot, descriptor, options);
    if (!result || !result.ok || result.renderer !== "lit") slot.remove();
    return result;
  }

  function renderPipelineBlockImpl(cardId, dom, block, options) {
    if (!dom || !block) return;
    var d = resolveDeps(options);
    var esc = d.esc || function (t) { return String(t || ""); };
    var renderAgentPlainMarkdown = d.renderAgentPlainMarkdown || function (t) { return String(t || ""); };
    var getActionCard = d.getActionCard || function () { return null; };
    var debugLog = d.debugLog;

    if (block.type === "plan") {
      var tl = dom.querySelector(".card-timeline");
      if (!tl) return;
      (block.items || []).forEach(function (it, idx) {
        var div = document.createElement("div");
        div.className = "card-timeline-step";
        div.setAttribute("data-block-id", block.id || "");
        div.textContent = "步骤" + (idx + 1) + "：" + String(it.text || "");
        tl.appendChild(div);
      });
    } else if (block.type === "question") {
      var qEl = dom.querySelector(".card-question");
      if (qEl) {
        qEl.hidden = false;
        qEl.setAttribute("data-block-id", block.id || "");
        qEl.innerHTML =
          '<div class="card-question-title">' +
          esc(block.title || "需要您的确认") +
          '</div><div class="card-question-body md-body">' +
          renderAgentPlainMarkdown(block.markdown || "") +
          "</div>";
      }
    } else if (block.type === "reply") {
      var host = ensureCardRepliesHost(dom);
      if (!host) return;
      var turnId = block.turnId != null ? Number(block.turnId) : 1;
      if (turnId > 1 && !host.querySelector('[data-segment-turn="' + turnId + '"]')) {
        var divider = document.createElement("div");
        divider.className = "card-segment-divider";
        divider.setAttribute("data-segment-turn", String(turnId));
        var cardRef = getActionCard(cardId);
        var qHint = cardRef && (cardRef._lastFollowUpQuery || cardRef.activeQuery);
        divider.textContent = qHint
          ? "补充 · " + String(qHint).slice(0, 56)
          : "补充 · 第 " + turnId + " 轮";
        host.appendChild(divider);
      }
      var seg = document.createElement("div");
      seg.className = "card-reply-segment";
      seg.setAttribute("data-block-id", block.id || "");
      seg.setAttribute("data-turn-id", String(turnId));
      seg.innerHTML =
        '<div class="card-reply-title">' +
        esc(block.title || (turnId > 1 ? "补充回复" : "任务回复")) +
        '</div><div class="card-reply-body md-body">' +
        renderAgentPlainMarkdown(block.markdown || "") +
        "</div>" +
        buildCardReplyActionsHtml(cardId, block, esc);
      host.appendChild(seg);
    } else if (block.type === "a2ui") {
      var cardA2 = getActionCard(cardId);
      var a2 = dom.querySelector(".card-a2ui");
      if (a2) {
        a2.hidden = false;
        var slot = document.createElement("div");
        slot.className = "a2ui-slot";
        slot.setAttribute("data-block-id", block.id || "");
        slot.setAttribute("data-component", block.component || "");
        a2.appendChild(slot);
        if (typeof root.PaletteMiniA2UI !== "undefined" && PaletteMiniA2UI.render) {
          if (!PaletteMiniA2UI.render(slot, block)) {
            debugLog(
              "a2ui_render_failed",
              JSON.stringify({
                blockId: block.id || "",
                component: block.component || "",
                routeId: cardA2 && cardA2.routeId ? cardA2.routeId : "",
                reason: "render_error"
              }),
              "warn"
            );
            slot.remove();
          }
        }
      }
    } else if (block.type === "error") {
      var errLog = dom.querySelector(".card-status-log");
      if (errLog) {
        var errEl = document.createElement("div");
        errEl.className = "b-status is-error";
        errEl.setAttribute("data-block-id", block.id || "");
        errEl.innerHTML =
          '<div class="b-status-title">[错误]</div><div class="b-status-log">' +
          esc(block.message || "任务失败") +
          "</div>";
        errLog.appendChild(errEl);
      }
    }
  }

  function renderPipelineBlockInner(cardId, dom, block, options) {
    if (!dom || !block) return;
    var d = resolveDeps(options);
    var getActionCard = d.getActionCard || function () { return null; };
    var debugLog = d.debugLog;
    var card = getActionCard(cardId);

    if (root.PaletteCardSlots && PaletteCardSlots.toBlockDescriptor) {
      var descriptor = PaletteCardSlots.toBlockDescriptor(card, block);
      if (descriptor) {
        try {
          debugLog(
            "block_descriptor",
            JSON.stringify({
              cardId: cardId,
              blockId: descriptor.props.blockId || "",
              type: block.type || "",
              component: descriptor.component || "",
              slot: descriptor.slot || "",
              mount: descriptor.mount || "",
              renderer: descriptor.props.renderer || "legacy"
            })
          );
        } catch (_) {}
      }
    }

    if (isActionChipsBlock(block)) {
      renderActionChipsPipelineBlock(cardId, dom, block, card, options);
      return;
    }

    if (block.type === "status") {
      var statusCount = (block.items || []).length;
      var litResult = tryRenderStatusLit(cardId, dom, block, card, options);
      if (litResult && litResult.ok && litResult.renderer === "lit") {
        traceBlockRender(
          cardId,
          block,
          {
            slot: "status",
            component: "status-log",
            blockType: "status",
            renderer: "lit",
            reason: TRACE_REASONS.OK,
            count: litResult.count != null ? litResult.count : statusCount,
            blockId: block.id || ""
          },
          options
        );
        var logBoxLit = dom.querySelector(".card-status-log");
        if (logBoxLit) logBoxLit.scrollTop = logBoxLit.scrollHeight;
        return;
      }
      var fallbackReason =
        litResult && litResult.reason ? litResult.reason : TRACE_REASONS.NO_LIT_COMPONENT;
      logStatusRender(
        cardId,
        root.PaletteCardSlots && PaletteCardSlots.toBlockDescriptor
          ? enrichStatusDescriptor(PaletteCardSlots.toBlockDescriptor(card, block), block, options)
          : { props: { blockId: block.id || "" } },
        { ok: false, renderer: "legacy", reason: fallbackReason, count: statusCount },
        options
      );
      traceBlockRender(
        cardId,
        block,
        {
          slot: "status",
          component: "status-log",
          blockType: "status",
          renderer: "legacy",
          reason: fallbackReason,
          count: statusCount,
          blockId: block.id || ""
        },
        options
      );
      renderStatusBlockLegacy(cardId, dom, block, options);
      return;
    }

    if (isComparisonTableBlock(block)) {
      var tableCount = block.props && Array.isArray(block.props.rows) ? block.props.rows.length : 0;
      var tableLitResult = tryRenderComparisonTableLit(cardId, dom, block, card, options);
      if (tableLitResult && tableLitResult.ok && tableLitResult.renderer === "lit") {
        traceBlockRender(
          cardId,
          block,
          {
            slot: "a2ui",
            component: "ComparisonTable",
            blockType: "ComparisonTable",
            renderer: "lit",
            reason: TRACE_REASONS.OK,
            count: tableLitResult.count != null ? tableLitResult.count : tableCount,
            blockId: block.id || ""
          },
          options
        );
        return;
      }
      var tableFallbackReason =
        tableLitResult && tableLitResult.reason
          ? tableLitResult.reason
          : TRACE_REASONS.NO_LIT_COMPONENT;
      traceBlockRender(
        cardId,
        block,
        {
          slot: "a2ui",
          component: "ComparisonTable",
          blockType: "ComparisonTable",
          renderer: "legacy",
          reason: tableFallbackReason,
          count: tableCount,
          blockId: block.id || ""
        },
        options
      );
      renderPipelineBlockImpl(cardId, dom, block, options);
      var tableSlot = dom.querySelector(
        '.card-a2ui .a2ui-slot[data-block-id="' + String(block.id || "").replace(/"/g, '\\"') + '"]'
      );
      if (!tableSlot) {
        traceBlockRender(
          cardId,
          block,
          {
            slot: "a2ui",
            component: "ComparisonTable",
            blockType: "ComparisonTable",
            renderer: "fallback",
            reason: TRACE_REASONS.RENDER_ERROR,
            count: 0,
            blockId: block.id || ""
          },
          options
        );
      }
      return;
    }

    if (isStepsBlock(block)) {
      var stepsCount = block.props && Array.isArray(block.props.items) ? block.props.items.length : 0;
      var stepsLitResult = tryRenderStepsLit(cardId, dom, block, card, options);
      if (stepsLitResult && stepsLitResult.ok && stepsLitResult.renderer === "lit") {
        traceBlockRender(
          cardId,
          block,
          {
            slot: "a2ui",
            component: "Steps",
            blockType: "Steps",
            renderer: "lit",
            reason: TRACE_REASONS.OK,
            count: stepsLitResult.count != null ? stepsLitResult.count : stepsCount,
            blockId: block.id || ""
          },
          options
        );
        return;
      }
      var stepsFallbackReason =
        stepsLitResult && stepsLitResult.reason
          ? stepsLitResult.reason
          : TRACE_REASONS.NO_LIT_COMPONENT;
      traceBlockRender(
        cardId,
        block,
        {
          slot: "a2ui",
          component: "Steps",
          blockType: "Steps",
          renderer: "legacy",
          reason: stepsFallbackReason,
          count: stepsCount,
          blockId: block.id || ""
        },
        options
      );
      renderPipelineBlockImpl(cardId, dom, block, options);
      var stepsSlot = dom.querySelector(
        '.card-a2ui .a2ui-slot[data-block-id="' + String(block.id || "").replace(/"/g, '\\"') + '"]'
      );
      if (!stepsSlot) {
        traceBlockRender(
          cardId,
          block,
          {
            slot: "a2ui",
            component: "Steps",
            blockType: "Steps",
            renderer: "fallback",
            reason: TRACE_REASONS.RENDER_ERROR,
            count: 0,
            blockId: block.id || ""
          },
          options
        );
      }
      return;
    }

    if (isAlertBlock(block)) {
      var alertCount = block.props && String(block.props.text || "").trim() ? 1 : 0;
      var alertLitResult = tryRenderAlertLit(cardId, dom, block, card, options);
      if (alertLitResult && alertLitResult.ok && alertLitResult.renderer === "lit") {
        traceBlockRender(
          cardId,
          block,
          {
            slot: "a2ui",
            component: "Alert",
            blockType: "Alert",
            renderer: "lit",
            reason: TRACE_REASONS.OK,
            count: alertLitResult.count != null ? alertLitResult.count : alertCount,
            blockId: block.id || ""
          },
          options
        );
        return;
      }
      var alertFallbackReason =
        alertLitResult && alertLitResult.reason
          ? alertLitResult.reason
          : TRACE_REASONS.NO_LIT_COMPONENT;
      traceBlockRender(
        cardId,
        block,
        {
          slot: "a2ui",
          component: "Alert",
          blockType: "Alert",
          renderer: "legacy",
          reason: alertFallbackReason,
          count: alertCount,
          blockId: block.id || ""
        },
        options
      );
      renderPipelineBlockImpl(cardId, dom, block, options);
      var alertSlot = dom.querySelector(
        '.card-a2ui .a2ui-slot[data-block-id="' + String(block.id || "").replace(/"/g, '\\"') + '"]'
      );
      if (!alertSlot) {
        traceBlockRender(
          cardId,
          block,
          {
            slot: "a2ui",
            component: "Alert",
            blockType: "Alert",
            renderer: "fallback",
            reason: TRACE_REASONS.RENDER_ERROR,
            count: 0,
            blockId: block.id || ""
          },
          options
        );
      }
      return;
    }

    if (
      block.type === "plan" ||
      block.type === "reply" ||
      (block.type === "a2ui" &&
        !isActionChipsBlock(block) &&
        !isComparisonTableBlock(block) &&
        !isStepsBlock(block) &&
        !isAlertBlock(block))
    ) {
      var legDesc =
        root.PaletteCardSlots && PaletteCardSlots.toBlockDescriptor
          ? PaletteCardSlots.toBlockDescriptor(card, block)
          : null;
      var legComponent =
        legDesc && legDesc.component
          ? legDesc.component
          : block.type === "a2ui"
            ? String(block.component || "a2ui")
            : block.type === "reply"
              ? "reply-markdown"
              : "plan-timeline";
      traceBlockRender(
        cardId,
        block,
        {
          slot: block.type,
          component: legComponent,
          blockType: resolveBlockType(block),
          renderer: "legacy",
          reason: TRACE_REASONS.NO_LIT_COMPONENT,
          count:
            block.type === "reply" || block.type === "a2ui"
              ? 1
              : (block.items || []).length,
          blockId: block.id || ""
        },
        options
      );
    }

    renderPipelineBlockImpl(cardId, dom, block, options);

    if (block.type === "a2ui" && !isActionChipsBlock(block)) {
      var a2Slot = dom.querySelector(
        '.card-a2ui .a2ui-slot[data-block-id="' + String(block.id || "").replace(/"/g, '\\"') + '"]'
      );
      if (!a2Slot) {
        traceBlockRender(
          cardId,
          block,
          {
            slot: "a2ui",
            component: String(block.component || "a2ui"),
            blockType: String(block.component || "a2ui"),
            renderer: "fallback",
            reason: TRACE_REASONS.RENDER_ERROR,
            count: 0,
            blockId: block.id || ""
          },
          options
        );
      }
    }
  }

  function renderPipelineBlock(cardId, dom, block, options) {
    if (!dom || !block) return;
    try {
      renderPipelineBlockInner(cardId, dom, block, options);
    } catch (err) {
      var debugLog = resolveDeps(options).debugLog;
      traceBlockRender(
        cardId,
        block,
        {
          slot: block.type === "a2ui" ? String(block.component || "a2ui") : String(block.type || "unknown"),
          component: resolveBlockType(block),
          blockType: resolveBlockType(block),
          renderer: "fallback",
          reason: TRACE_REASONS.RENDER_ERROR,
          count: 0,
          blockId: block.id || ""
        },
        options
      );
      if (debugLog) {
        try {
          debugLog(
            "block_render_error",
            JSON.stringify({
              cardId: cardId,
              blockId: block.id || "",
              blockType: resolveBlockType(block),
              error: String(err && err.message ? err.message : err)
            })
          );
        } catch (_) {}
      }
    }
  }

  function renderBlocks(cardId, dom, blocks, options) {
    if (!dom) return { ok: false, blocks: [] };
    if (root.PaletteSlotRenderTrace && PaletteSlotRenderTrace.beginCardRender) {
      PaletteSlotRenderTrace.beginCardRender(cardId);
    }
    var d = resolveDeps(options);
    var debugLog = d.debugLog;
    var onAfterRender = d.onAfterRender;

    var validated =
      typeof root.PaletteBlockSchema !== "undefined"
        ? PaletteBlockSchema.validateBlocks(blocks || [])
        : { blocks: blocks || [], dropped: [] };
    var list = validated.blocks || [];
    traceDroppedBlocks(cardId, validated.dropped || [], options);
    var tl = dom.querySelector(".card-timeline");
    if (tl) tl.innerHTML = "";
    var logBox = dom.querySelector(".card-status-log");
    if (logBox) logBox.innerHTML = "";
    var qEl = dom.querySelector(".card-question");
    if (qEl) {
      qEl.hidden = true;
      qEl.innerHTML = "";
    }
    var repliesHost = ensureCardRepliesHost(dom);
    if (repliesHost) repliesHost.innerHTML = "";
    var legacyReply = dom.querySelector(".card-reply");
    if (legacyReply) {
      legacyReply.hidden = true;
      legacyReply.innerHTML = "";
    }
    var a2 = dom.querySelector(".card-a2ui");
    if (a2) {
      a2.hidden = true;
      a2.innerHTML = "";
    }
    ensureCardA2uiDomOrder(dom);
    for (var i = 0; i < list.length; i++) renderPipelineBlock(cardId, dom, list[i], options);
    if (a2 && !a2.hidden && a2.querySelector(".a2ui-slot") && !a2.querySelector(".card-a2ui-head")) {
      var a2Head = document.createElement("div");
      a2Head.className = "card-a2ui-head";
      a2Head.textContent = "结构化视图";
      a2.insertBefore(a2Head, a2.firstChild);
    }
    syncActionCardStatusLogVisibility(dom);
    onAfterRender(cardId);
    var a2uiBlockCount = 0;
    for (var ai = 0; ai < list.length; ai++) {
      if (list[ai] && list[ai].type === "a2ui") a2uiBlockCount++;
    }
    var a2uiRendered = dom.querySelectorAll(".card-a2ui .a2ui-slot").length;
    debugLog(
      "render_blocks",
      JSON.stringify({
        n: list.length,
        types: list
          .map(function (b) {
            return b.type;
          })
          .join(","),
        a2uiBlocks: a2uiBlockCount,
        a2uiRendered: a2uiRendered
      })
    );
    return { ok: true, blocks: list };
  }

  function renderActions(cardId, card, dom, options) {
    options = options || {};
    var decision =
      root.PaletteActionBinder && PaletteActionBinder.evaluateLegacyFollowUpRender
        ? PaletteActionBinder.evaluateLegacyFollowUpRender(card, dom)
        : { mode: "render", trace: "legacy_actions_rendered_no_action_chips", reason: "binder_unavailable" };

    if (decision.mode === "skip") {
      var litEl =
        root.PaletteActionBinder && PaletteActionBinder.queryActionChipsLitEl
          ? PaletteActionBinder.queryActionChipsLitEl(dom)
          : dom && dom.querySelector
            ? dom.querySelector(".card-followup-chips palette-action-chips")
            : null;
      if (litEl) {
        if (root.PaletteActionController && PaletteActionController.syncPendingToActionChipsDom) {
          PaletteActionController.syncPendingToActionChipsDom(cardId, card);
        } else if ("pendingActionId" in litEl) {
          litEl.pendingActionId = card && card.pendingActionId ? card.pendingActionId : "";
        }
      }
      if (root.PaletteActionBinder && PaletteActionBinder.logLegacyActionsEvent) {
        PaletteActionBinder.logLegacyActionsEvent(options, decision.trace, {
          cardId: cardId,
          reason: decision.reason || "",
          count: decision.count != null ? decision.count : litEl && litEl.actions ? litEl.actions.length : 0
        });
      }
      var skipCount =
        decision.count != null
          ? decision.count
          : litEl && litEl.actions && litEl.actions.length
            ? litEl.actions.length
            : 0;
      traceRecord("actions", {
        cardId: cardId,
        component: "ActionChips",
        blockType: "ActionChips",
        renderer: "lit",
        reason: TRACE_REASONS.OK,
        count: skipCount
      });
      return {
        ok: true,
        renderer: "lit",
        reason: decision.reason || "skipped_by_action_chips",
        count: skipCount,
        skippedByActionChips: true
      };
    }

    var result = { ok: false, renderer: "none", reason: "binder_unavailable", count: 0 };
    if (root.PaletteActionBinder && PaletteActionBinder.renderFollowUpChips) {
      result = PaletteActionBinder.renderFollowUpChips(
        cardId,
        card,
        Object.assign({}, options, { legacyRenderDecision: decision, dom: dom })
      );
    }
    var traceComponent = result.skippedByActionChips ? "ActionChips" : "follow-up-chips";
    var traceBlockType = result.skippedByActionChips ? "ActionChips" : "follow-up-chips";
    var traceRenderer = result.skippedByActionChips ? "lit" : result.renderer || "none";
    traceRecord("actions", {
      cardId: cardId,
      component: traceComponent,
      blockType: traceBlockType,
      renderer: traceRenderer,
      reason: normalizeTraceReason(
        result.reason || result.fallbackReason || decision.reason || "",
        traceRenderer === "lit" ? "lit" : result.renderer || "legacy"
      ),
      count: result.count != null ? result.count : 0
    });
    return result;
  }

  root.PaletteCardRenderer = {
    renderBlocks: renderBlocks,
    renderPipelineBlock: renderPipelineBlock,
    renderActions: renderActions,
    ensureCardRepliesHost: ensureCardRepliesHost,
    ensureCardA2uiDomOrder: ensureCardA2uiDomOrder,
    syncActionCardStatusLogVisibility: syncActionCardStatusLogVisibility
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
