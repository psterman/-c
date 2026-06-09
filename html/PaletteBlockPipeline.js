/**
 * Palette Block Pipeline — v2：ingestDelta + finalize
 */
(function (root) {
  var PROTO_RE = /::(PLAN|STATUS|QUESTION|REPLY)_(START|END)::/;
  var PROTO_TAG_NAMES = ["PLAN", "STATUS", "QUESTION", "REPLY"];

  function hasProtocolTags(text) {
    return PROTO_RE.test(String(text || ""));
  }

  function detectMissingEndsInSource(raw) {
    var s = String(raw || "");
    var missing = [];
    for (var ti = 0; ti < PROTO_TAG_NAMES.length; ti++) {
      var tag = PROTO_TAG_NAMES[ti];
      var startRe = new RegExp("::" + tag + "_START::", "g");
      var endRe = new RegExp("::" + tag + "_END::", "g");
      var starts = (s.match(startRe) || []).length;
      var ends = (s.match(endRe) || []).length;
      for (var mi = 0; mi < starts - ends; mi++) missing.push(tag.toLowerCase());
    }
    return missing;
  }

  function analyzeProtocolClosure(raw) {
    raw = String(raw || "");
    if (!hasProtocolTags(raw)) {
      return {
        ok: true,
        code: "OK",
        forcedCloses: [],
        missingEnds: [],
        nestedCuts: [],
        synthesizedReply: false
      };
    }
    var forcedCloses = [];
    var nestedCuts = [];
    if (typeof StreamTagParser !== "undefined") {
      var parser = new StreamTagParser(function (b) {
        if (!b || !b.forcedClose) return;
        var entry = { type: String(b.type || ""), parseWarn: String(b.parseWarn || "forced") };
        forcedCloses.push(entry);
        if (entry.parseWarn === "nested_cut") nestedCuts.push(entry);
      });
      parser.onChunk(raw);
      parser.flush();
    }
    var missingEnds = detectMissingEndsInSource(raw);
    var hasNested = nestedCuts.length > 0;
    var hasIssue = forcedCloses.length > 0 || missingEnds.length > 0;
    return {
      ok: !hasIssue,
      code: hasNested ? "SEM_PROTOCOL_TAG_NESTED" : hasIssue ? "SEM_PROTOCOL_TAG_UNCLOSED" : "OK",
      forcedCloses: forcedCloses,
      missingEnds: missingEnds,
      nestedCuts: nestedCuts,
      synthesizedReply: false
    };
  }

  function synthesizeTruncatedReply(blocks, closure, ctx) {
    var lines = ["任务已结束（协议未完整闭合，以下为可用摘要）"];
    var list = blocks || [];
    for (var i = 0; i < list.length; i++) {
      var b = list[i];
      if (!b) continue;
      if (b.type === "plan" && b.items && b.items.length) {
        var planParts = [];
        for (var pi = 0; pi < b.items.length; pi++) {
          if (b.items[pi] && b.items[pi].text) planParts.push(String(b.items[pi].text));
        }
        if (planParts.length) lines.push("计划：" + planParts.join(" · "));
      }
      if (b.type === "status" && b.items && b.items.length) {
        var stParts = [];
        for (var si = 0; si < b.items.length; si++) {
          if (b.items[si] && b.items[si].text) stParts.push(String(b.items[si].text));
        }
        if (stParts.length) lines.push("状态：" + stParts.join(" · "));
      }
    }
    if (closure && closure.missingEnds && closure.missingEnds.length) {
      lines.push("未闭合标签：" + closure.missingEnds.join(", "));
    }
    var md = lines.join("\n\n").trim();
    if (!md) return null;
    var now = Date.now();
    var reply = {
      id: root.PaletteBlockSchema ? PaletteBlockSchema.genBlockId("blk_syn") : "blk_syn_" + now,
      type: "reply",
      state: "final",
      source: "protocol_repair",
      confidence: 0.55,
      seq: ctx.nextSeq(),
      turnId: ctx.turnId,
      traceId: ctx.traceId,
      createdAt: now,
      updatedAt: now,
      title: "任务完结（协议修复）",
      markdown: md
    };
    if (root.PaletteBlockSchema) reply = PaletteBlockSchema.sanitizeBlock(reply);
    return reply;
  }

  function protocolBlockToCanonical(block, ctx) {
    if (!block || !block.closed) return null;
    var type = String(block.type || "").toLowerCase();
    var now = Date.now();
    var base = {
      id: root.PaletteBlockSchema ? PaletteBlockSchema.genBlockId("blk") : "blk_" + now,
      state: "final",
      source: "protocol",
      confidence: 0.95,
      seq: ctx.nextSeq(),
      turnId: ctx.turnId,
      traceId: ctx.traceId,
      createdAt: now,
      updatedAt: now
    };

    if (type === "plan") {
      var steps = Array.isArray(block.steps) ? block.steps : [];
      if (!steps.length && block.body) {
        steps = String(block.body)
          .split("|")
          .map(function (s) {
            return s.trim();
          })
          .filter(Boolean);
      }
      if (!steps.length) return null;
      return Object.assign(base, {
        type: "plan",
        items: steps.map(function (s) {
          return { text: String(s), state: "done" };
        })
      });
    }

    if (type === "status") {
      var stText = String(block.log || block.content || block.body || "").trim();
      if (!stText) stText = String(block.title || "[执行中]").trim();
      if (!stText) return null;
      return Object.assign(base, {
        type: "status",
        items: [{ text: stText, level: "info" }]
      });
    }

    if (type === "question") {
      var qMd = String(block.content || block.body || "").trim();
      return Object.assign(base, {
        type: "question",
        title: String(block.title || "需要您的确认"),
        markdown: qMd,
        status: "waiting"
      });
    }

    if (type === "reply") {
      var rMd = String(block.content || block.body || "").trim();
      if (!rMd) return null;
      return Object.assign(base, {
        type: "reply",
        title: String(block.title || "任务完结"),
        markdown: rMd
      });
    }

    if (type === "orphan") {
      var oMd = String(block.content || block.body || "").trim();
      if (!oMd) return null;
      return Object.assign(base, {
        type: "reply",
        source: "protocol",
        confidence: 0.7,
        title: "任务回复",
        markdown: oMd
      });
    }

    return null;
  }

  function collectProtocolBlocks(raw, ctx) {
    if (typeof StreamTagParser === "undefined") return [];
    var collected = [];
    var parser = new StreamTagParser(function (b) {
      collected.push(b);
    });
    parser.onChunk(String(raw || ""));
    parser.flush();
    var out = [];
    for (var i = 0; i < collected.length; i++) {
      var c = protocolBlockToCanonical(collected[i], ctx);
      if (c) out.push(c);
    }
    return out;
  }

  function hasFinalReply(blocks) {
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i] && blocks[i].type === "reply" && String(blocks[i].markdown || "").trim()) return true;
    }
    return false;
  }

  function hasStreamingReply(blocks) {
    for (var i = 0; i < blocks.length; i++) {
      if (blocks[i] && blocks[i].type === "reply" && blocks[i].state === "streaming") return true;
    }
    return false;
  }

  function stripProtocolTags(text) {
    return String(text || "")
      .replace(/::(?:PLAN|STATUS|QUESTION|REPLY)_(?:START|END)::/g, "")
      .replace(/\s+/g, " ")
      .trim();
  }

  function isStatusOnlyAgentText(text) {
    var p = String(text || "").replace(/\s+/g, " ").trim();
    if (!p) return true;
    if (/^[🔗⏳📨💭]/.test(p)) return true;
    if (/chat\.send/i.test(p)) return true;
    if (/Gateway session/i.test(p)) return true;
    if (/绑定 OpenClaw/i.test(p)) return true;
    if (/^\[执行中\]/.test(p)) return true;
    return /^(正在|等待|任务已|仍连接|OpenClaw 流式|OpenClaw 处理|OpenClaw 已发送|已提交至 Gateway|同步 Niuma|流式输出中)/.test(p);
  }

  function validateBlocksList(blocks) {
    if (root.PaletteBlockSchema && PaletteBlockSchema.validateBlocks) {
      return PaletteBlockSchema.validateBlocks(blocks || []);
    }
    return { ok: true, blocks: blocks || [], errors: [], dropped: [] };
  }

  function createIngestState(options) {
    options = options || {};
    return {
      turnId: options.turnId != null ? Number(options.turnId) : 1,
      traceId: String(options.traceId || "tr_" + Date.now()),
      seq: 0,
      rawBuffer: "",
      statusItems: [],
      blocks: [],
      protoStarted: false
    };
  }

  function nextSeq(state) {
    return ++state.seq;
  }

  function makeCtx(state) {
    return {
      turnId: state.turnId,
      traceId: state.traceId,
      nextSeq: function () {
        return nextSeq(state);
      }
    };
  }

  function findOrCreateStatusBlock(state, source) {
    var now = Date.now();
    var src = String(source || "system");
    var statusBlock = null;
    for (var j = state.blocks.length - 1; j >= 0; j--) {
      var sb = state.blocks[j];
      if (sb && sb.type === "status" && String(sb.source || "system") === src) {
        statusBlock = sb;
        break;
      }
    }
    if (!statusBlock) {
      statusBlock = {
        id: root.PaletteBlockSchema ? PaletteBlockSchema.genBlockId("blk_st") : "blk_st_" + now,
        type: "status",
        state: "streaming",
        source: src,
        confidence: 0.9,
        seq: nextSeq(state),
        turnId: state.turnId,
        traceId: state.traceId,
        createdAt: now,
        updatedAt: now,
        items: []
      };
      state.blocks.push(statusBlock);
    }
    return statusBlock;
  }

  function statusItemDedupeKey(item) {
    if (!item) return "";
    return (
      String(item.tool || "") +
      "|" +
      String(item.phase || "") +
      "|" +
      String(item.text || "").replace(/\s+/g, " ").trim()
    );
  }

  function appendStatusEvent(state, event) {
    event = event || {};
    var t = String(event.text != null ? event.text : "").replace(/\s+/g, " ").trim();
    if (!t) return;
    var source = event.source === "tool_event" ? "tool_event" : "system";
    var item = {
      text: t,
      level: String(event.level || "info"),
      ts: event.ts != null ? Number(event.ts) : Date.now()
    };
    if (event.tool != null) item.tool = String(event.tool);
    if (event.phase != null) item.phase = String(event.phase);
    var dedupeKey = statusItemDedupeKey(item);
    if (source === "system") {
      for (var i = 0; i < state.statusItems.length; i++) {
        if (state.statusItems[i] === t) return;
      }
      state.statusItems.push(t);
    } else {
      if (!state._toolEventKeys) state._toolEventKeys = {};
      if (state._toolEventKeys[dedupeKey]) return;
      state._toolEventKeys[dedupeKey] = true;
    }
    var statusBlock = findOrCreateStatusBlock(state, source);
    for (var ki = 0; ki < statusBlock.items.length; ki++) {
      if (statusItemDedupeKey(statusBlock.items[ki]) === dedupeKey) return;
    }
    statusBlock.items.push(item);
    statusBlock.updatedAt = Date.now();
  }

  function appendStatusItem(state, text) {
    appendStatusEvent(state, { text: text, source: "system", level: "info" });
  }

  function ingestToolEvent(state, payload) {
    payload = payload || {};
    appendStatusEvent(state, {
      source: "tool_event",
      text: payload.text || payload.message || "",
      tool: payload.tool || "",
      phase: payload.phase || "progress",
      level: payload.level || "info",
      ts: payload.ts
    });
    return {
      blocks: state.blocks,
      meta: { toolEvent: true, tool: payload.tool, phase: payload.phase }
    };
  }

  function upsertStreamingReply(state, markdown) {
    var md = String(markdown || "").trim();
    if (!md || isStatusOnlyAgentText(md)) return;
    var found = null;
    for (var i = state.blocks.length - 1; i >= 0; i--) {
      if (state.blocks[i] && state.blocks[i].type === "reply") {
        found = state.blocks[i];
        break;
      }
    }
    var now = Date.now();
    if (!found) {
      found = {
        id: root.PaletteBlockSchema ? PaletteBlockSchema.genBlockId("blk_stream") : "blk_stream_" + now,
        type: "reply",
        state: "streaming",
        source: "raw",
        confidence: 0.45,
        seq: nextSeq(state),
        turnId: state.turnId,
        traceId: state.traceId,
        createdAt: now,
        updatedAt: now,
        title: "任务回复",
        markdown: md
      };
      state.blocks.push(found);
    } else {
      found.markdown = md;
      found.state = found.state === "final" ? "final" : "streaming";
      found.updatedAt = now;
    }
  }

  function rebuildProtocolBlocks(state) {
    var ctx = makeCtx(state);
    var protocolBlocks = collectProtocolBlocks(state.rawBuffer, ctx);
    var statusBlocks = state.blocks.filter(function (b) {
      return b && b.type === "status";
    });
    state.blocks = statusBlocks.concat(protocolBlocks);
    if (!hasFinalReply(state.blocks) && !hasStreamingReply(state.blocks)) {
      var tail = stripProtocolTags(state.rawBuffer);
      if (tail && !isStatusOnlyAgentText(tail)) upsertStreamingReply(state, tail);
    }
  }

  function ingestDelta(state, delta, meta) {
    meta = meta || {};
    if (!state) state = createIngestState(meta);
    var d = String(delta || "");
    if (!d) {
      var v0 = validateBlocksList(state.blocks);
      return { blocks: v0.blocks || [], meta: { protoStarted: state.protoStarted, statusOnly: true } };
    }

    if (isStatusOnlyAgentText(d) && !hasProtocolTags(d)) {
      appendStatusItem(state, d.trim());
      var vSt = validateBlocksList(state.blocks);
      state.blocks = vSt.blocks || [];
      return { blocks: state.blocks, meta: { protoStarted: state.protoStarted, statusOnly: true } };
    }

    state.rawBuffer += d;
    if (hasProtocolTags(state.rawBuffer) || hasProtocolTags(d)) {
      state.protoStarted = true;
      rebuildProtocolBlocks(state);
    } else if (!state.protoStarted) {
      upsertStreamingReply(state, state.rawBuffer);
    }

    var validated = validateBlocksList(state.blocks);
    state.blocks = validated.blocks || [];
    var ingestClosure =
      state.rawBuffer && hasProtocolTags(state.rawBuffer)
        ? analyzeProtocolClosure(state.rawBuffer)
        : null;
    return {
      blocks: state.blocks,
      meta: {
        protoStarted: state.protoStarted,
        statusOnly: false,
        protocolClosure: ingestClosure,
        errors: validated.errors || [],
        dropped: (validated.dropped || []).length
      }
    };
  }

  function finalize(rawAnswer, options) {
    options = options || {};
    var raw = String(rawAnswer || "").trim();
    var turnId = options.turnId != null ? Number(options.turnId) : 1;
    var traceId = String(options.traceId || "tr_" + Date.now());
    var seq = 0;
    function nextSeqFn() {
      return ++seq;
    }
    var ctx = { turnId: turnId, traceId: traceId, nextSeq: nextSeqFn };

    var protocolClosure = analyzeProtocolClosure(raw);
    var blocks = [];
    if (raw && hasProtocolTags(raw)) {
      blocks = collectProtocolBlocks(raw, ctx);
    }

    if (root.PaletteBlockSchema) {
      blocks = blocks
        .map(function (b) {
          return PaletteBlockSchema.sanitizeBlock(b);
        })
        .filter(Boolean);
    }

    if (raw && !hasFinalReply(blocks)) {
      if (hasProtocolTags(raw) && !protocolClosure.ok) {
        var synReply = synthesizeTruncatedReply(blocks, protocolClosure, ctx);
        if (synReply) {
          blocks.push(synReply);
          protocolClosure = Object.assign({}, protocolClosure, { synthesizedReply: true });
        }
      } else {
        var fbSource = hasProtocolTags(raw) ? "markdown" : "raw";
        var fbMd = fbSource === "raw" ? raw : stripProtocolTags(raw);
        if (fbMd && !isStatusOnlyAgentText(fbMd)) {
          var fallback = {
            id: root.PaletteBlockSchema ? PaletteBlockSchema.genBlockId("blk_raw") : "blk_raw_" + Date.now(),
            type: "reply",
            state: "final",
            source: fbSource,
            confidence: fbSource === "raw" ? 0.5 : 0.6,
            seq: nextSeqFn(),
            turnId: turnId,
            traceId: traceId,
            createdAt: Date.now(),
            updatedAt: Date.now(),
            title: "任务回复",
            markdown: fbMd
          };
          if (root.PaletteBlockSchema) fallback = PaletteBlockSchema.sanitizeBlock(fallback);
          if (fallback) blocks.push(fallback);
        }
      }
    }

    for (var fi = 0; fi < blocks.length; fi++) {
      if (blocks[fi]) blocks[fi].state = "final";
    }

    var validated = validateBlocksList(blocks);
    blocks = validated.blocks || [];
    var a2meta = [];
    var matcherMeta = null;
    var uiMatches = [];
    var displayPolicy = null;
    if (root.PaletteComponentMatcher && PaletteComponentMatcher.match) {
      var enriched = PaletteComponentMatcher.match(blocks, {
        route: options.route || {},
        turnId: turnId,
        traceId: traceId,
        nextSeq: nextSeqFn,
        hideOriginalTable: options.hideOriginalTable
      });
      blocks = enriched.blocks || blocks;
      a2meta = (enriched.meta && enriched.meta.a2ui) || [];
      matcherMeta = enriched.meta && enriched.meta.matcher ? enriched.meta.matcher : null;
      uiMatches = (enriched.meta && enriched.meta.uiMatches) || [];
      displayPolicy = (enriched.meta && enriched.meta.displayPolicy) || null;
    } else if (root.PaletteMiniA2UI && PaletteMiniA2UI.enrichBlocksWithA2UI) {
      var enrichedFallback = PaletteMiniA2UI.enrichBlocksWithA2UI(blocks, {
        route: options.route || {},
        turnId: turnId,
        traceId: traceId,
        nextSeq: nextSeqFn,
        hideOriginalTable: options.hideOriginalTable === true
      });
      blocks = enrichedFallback.blocks || blocks;
      a2meta = (enrichedFallback.meta && enrichedFallback.meta.a2ui) || [];
    }

    var metaErrors = (validated.errors || []).slice();
    if (!protocolClosure.ok) {
      metaErrors.push({
        code: protocolClosure.code,
        layer: "semantic",
        retryable: false,
        forcedCloses: protocolClosure.forcedCloses,
        missingEnds: protocolClosure.missingEnds
      });
    }

    return {
      blocks: blocks,
      meta: {
        protoStarted: hasProtocolTags(raw),
        protocolClosure: protocolClosure,
        traceId: traceId,
        turnId: turnId,
        a2ui: a2meta,
        matcher: matcherMeta,
        uiMatches: uiMatches,
        displayPolicy: displayPolicy,
        errors: metaErrors,
        dropped: (validated.dropped || []).length
      }
    };
  }

  function finalizeFromState(state, options) {
    options = options || {};
    if (!state) return finalize("", options);
    return finalize(state.rawBuffer, {
      turnId: state.turnId,
      traceId: state.traceId,
      route: options.route || state.route || {}
    });
  }

  function freezeBlocks(blocks) {
    if (!Array.isArray(blocks)) return [];
    return blocks.map(function (b) {
      if (!b || typeof b !== "object") return b;
      if (b.state === "streaming") {
        return Object.assign({}, b, { state: "final", updatedAt: Date.now() });
      }
      return b;
    });
  }

  function maxTurnId(blocks) {
    var m = 0;
    for (var i = 0; i < (blocks || []).length; i++) {
      var t = blocks[i] && blocks[i].turnId != null ? Number(blocks[i].turnId) : 0;
      if (t > m) m = t;
    }
    return m || 0;
  }

  function dedupeMergedBlocks(blocks) {
    var list = Array.isArray(blocks) ? blocks.slice() : [];
    var replyByTurn = {};
    var a2uiByKey = {};
    var others = [];
    for (var i = 0; i < list.length; i++) {
      var b = list[i];
      if (!b || !b.type) continue;
      if (b.type === "reply") {
        var rt = b.turnId != null ? Number(b.turnId) : 1;
        replyByTurn[rt] = b;
      } else if (b.type === "a2ui") {
        var at = b.turnId != null ? Number(b.turnId) : 1;
        a2uiByKey[at + ":" + String(b.component || "")] = b;
      } else {
        others.push(b);
      }
    }
    var merged = others
      .concat(
        Object.keys(replyByTurn)
          .sort(function (a, b) {
            return Number(a) - Number(b);
          })
          .map(function (k) {
            return replyByTurn[k];
          }),
        Object.keys(a2uiByKey)
          .sort()
          .map(function (k) {
            return a2uiByKey[k];
          })
      );
    merged.sort(function (a, b) {
      var ta = a && a.turnId != null ? Number(a.turnId) : 1;
      var tb = b && b.turnId != null ? Number(b.turnId) : 1;
      if (ta !== tb) return ta - tb;
      return (a && a.seq ? a.seq : 0) - (b && b.seq ? b.seq : 0);
    });
    return validateBlocksList(merged);
  }

  function mergeSegmentBlocks(priorBlocks, segmentBlocks) {
    var prior = freezeBlocks(priorBlocks || []);
    var seg = Array.isArray(segmentBlocks) ? segmentBlocks.slice() : [];
    var merged = prior.concat(seg);
    merged.sort(function (a, b) {
      var ta = a && a.turnId != null ? Number(a.turnId) : 1;
      var tb = b && b.turnId != null ? Number(b.turnId) : 1;
      if (ta !== tb) return ta - tb;
      return (a && a.seq ? a.seq : 0) - (b && b.seq ? b.seq : 0);
    });
    return dedupeMergedBlocks(merged);
  }

  function a2uiBlockSummary(block) {
    if (!block || block.type !== "a2ui") return "";
    if (block.component === "ComparisonTable") {
      var cols = (block.props && block.props.columns) || [];
      var rows = (block.props && block.props.rows) || [];
      return "对比表格 · " + cols.length + " 列 · " + rows.length + " 行";
    }
    if (block.component === "Steps") {
      var stepItems = (block.props && block.props.items) || [];
      return "执行步骤 · " + stepItems.length + " 步";
    }
    if (block.component === "Alert") {
      var alertTxt = (block.props && block.props.text) || "";
      return String(alertTxt).trim().slice(0, 80) || "⚠ 警告";
    }
    return "";
  }

  function blockPreviewSummaryWithSource(blocks) {
    var list = blocks || [];
    var bestReply = null;
    var bestTurn = -1;
    for (var pi = 0; pi < list.length; pi++) {
      var pb = list[pi];
      if (pb && pb.type === "reply" && pb.markdown) {
        var tid = pb.turnId != null ? Number(pb.turnId) : 1;
        if (tid >= bestTurn) {
          bestTurn = tid;
          bestReply = pb;
        }
      }
    }
    if (bestReply) {
      var replyMd = String(bestReply.markdown);
      var lead = extractNonTablePreview(replyMd);
      if (lead) return { text: lead.slice(0, 160), source: "reply_lead" };
      var tblSum = inferTablePreviewFromMarkdown(replyMd);
      if (tblSum) return { text: tblSum, source: "reply_table" };
      return {
        text: replyMd.replace(/\s+/g, " ").trim().slice(0, 160),
        source: "reply"
      };
    }
    var bestA2 = null;
    var bestA2Turn = -1;
    for (var pa = 0; pa < list.length; pa++) {
      var a2 = list[pa];
      if (!a2 || a2.type !== "a2ui") continue;
      var at = a2.turnId != null ? Number(a2.turnId) : 1;
      if (at >= bestA2Turn) {
        bestA2Turn = at;
        bestA2 = a2;
      }
    }
    if (bestA2) {
      var a2Sum = a2uiBlockSummary(bestA2);
      if (a2Sum) return { text: a2Sum.slice(0, 160), source: "a2ui" };
    }
    for (var pj = 0; pj < list.length; pj++) {
      var ps = list[pj];
      if (ps && ps.type === "plan" && ps.items && ps.items.length) {
        var planPipe = ps.items
          .slice(0, 2)
          .map(function (it, i) {
            return "步骤" + (i + 1) + "：" + (it.text || "");
          })
          .join(" · ");
        if (planPipe) return { text: planPipe.slice(0, 160), source: "plan" };
      }
    }
    for (var pk = list.length - 1; pk >= 0; pk--) {
      var st = list[pk];
      if (st && st.type === "status" && st.items && st.items.length) {
        var lt = String(st.items[st.items.length - 1].text || "").trim();
        if (lt) {
          return {
            text: lt.slice(0, 160),
            source: st.source === "tool_event" ? "tool_event_status" : "status"
          };
        }
      }
    }
    return { text: "", source: "none" };
  }

  function blockPreviewSummary(blocks) {
    var r = blockPreviewSummaryWithSource(blocks);
    return r && r.text ? r.text : "";
  }

  function inferTablePreviewFromMarkdown(md) {
    if (root.PaletteMiniA2UI && PaletteMiniA2UI.extractMarkdownTables) {
      var tables = PaletteMiniA2UI.extractMarkdownTables(md);
      if (tables.length && tables[0].columns && tables[0].columns.length) {
        var tb = tables[0];
        return ("对比表格 · " + tb.columns.length + " 列 · " + (tb.rows || []).length + " 行").slice(0, 160);
      }
    }
    return "";
  }

  function extractNonTablePreview(md) {
    var lines = String(md || "").split(/\r?\n/);
    var parts = [];
    for (var i = 0; i < lines.length; i++) {
      var ln = lines[i].trim();
      if (!ln) continue;
      if (/^\|/.test(ln)) continue;
      if (/^:?-{2,}:?(\s*\|\s*:?-{2,}:?)*$/.test(ln.replace(/\s/g, ""))) continue;
      parts.push(ln.replace(/\*\*/g, ""));
      if (parts.join(" ").length > 100) break;
    }
    return parts.join(" ").replace(/\s+/g, " ").trim();
  }

  root.PaletteBlockPipeline = {
    createIngestState: createIngestState,
    ingestDelta: ingestDelta,
    finalize: finalize,
    finalizeFromState: finalizeFromState,
    mergeSegmentBlocks: mergeSegmentBlocks,
    dedupeMergedBlocks: dedupeMergedBlocks,
    freezeBlocks: freezeBlocks,
    maxTurnId: maxTurnId,
    appendStatusEvent: appendStatusEvent,
    ingestToolEvent: ingestToolEvent,
    blockPreviewSummary: blockPreviewSummary,
    blockPreviewSummaryWithSource: blockPreviewSummaryWithSource,
    a2uiBlockSummary: a2uiBlockSummary,
    inferTablePreviewFromMarkdown: inferTablePreviewFromMarkdown,
    extractNonTablePreview: extractNonTablePreview,
    hasProtocolTags: hasProtocolTags,
    hasFinalReply: hasFinalReply,
    isStatusOnlyAgentText: isStatusOnlyAgentText,
    analyzeProtocolClosure: analyzeProtocolClosure,
    detectMissingEndsInSource: detectMissingEndsInSource,
    synthesizeTruncatedReply: synthesizeTruncatedReply
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
