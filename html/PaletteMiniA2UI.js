/**
 * Palette Mini-A2UI — finalize 后处理：Markdown → a2ui blocks
 *
 * C.1+ 范围：仅 finalize 阶段 enrich；A2UI 在 reply 前展示；
 * Option A 默认保留 reply 原表；hideOriginalTable:true 时剥离（Option B）。
 */
(function (root) {
  function extractMarkdownTables(markdown) {
    if (!root.PaletteComparisonTableMarkdown) return [];
    return PaletteComparisonTableMarkdown.extract(markdown);
  }

  /** 从 reply markdown 移除表格块（A2UI ComparisonTable 已承接时） */
  function stripMarkdownTables(markdown) {
    if (!root.PaletteComparisonTableMarkdown) return String(markdown || "").trim();
    return PaletteComparisonTableMarkdown.strip(markdown);
  }

  function extractSteps(markdown) {
    if (!root.PaletteA2UITextNormalizer) return [];
    return PaletteA2UITextNormalizer.extractSteps(markdown);
  }

  function extractAlerts(markdown) {
    if (!root.PaletteA2UITextNormalizer) return [];
    return PaletteA2UITextNormalizer.extractAlerts(markdown);
  }

  function makeA2UIBlock(component, props, ctx) {
    ctx = ctx || {};
    var now = Date.now();
    return {
      id: root.PaletteBlockSchema ? PaletteBlockSchema.genBlockId("blk_a2") : "blk_a2_" + now,
      type: "a2ui",
      state: "final",
      source: "markdown_table",
      confidence: 0.72,
      seq: typeof ctx.nextSeq === "function" ? ctx.nextSeq() : ctx.seq || now,
      turnId: ctx.turnId != null ? ctx.turnId : 1,
      traceId: ctx.traceId || "tr_a2ui",
      createdAt: now,
      updatedAt: now,
      component: component,
      props: props || {}
    };
  }

  function enrichBlocksWithA2UI(blocks, options) {
    options = options || {};
    var list = Array.isArray(blocks) ? blocks.slice() : [];
    var route = options.route || {};
    var candidates = route.a2uiCandidates && route.a2uiCandidates.length
      ? route.a2uiCandidates
      : ["ComparisonTable", "Steps", "Alert"];
    var replyMd = "";
    var replyIdx = -1;
    for (var i = list.length - 1; i >= 0; i--) {
      if (list[i] && list[i].type === "reply" && list[i].markdown) {
        replyMd = String(list[i].markdown);
        replyIdx = i;
        break;
      }
    }
    if (!replyMd) return { blocks: list, meta: { a2ui: [] } };
    var ctx = {
      turnId: options.turnId != null ? options.turnId : 1,
      traceId: options.traceId || "tr_a2ui",
      nextSeq: options.nextSeq
    };
    var inserts = [];
    var meta = [];

    if (candidates.indexOf("ComparisonTable") >= 0) {
      var tables = extractMarkdownTables(replyMd);
      for (var ti = 0; ti < tables.length; ti++) {
        var tb = tables[ti];
        if (!tb.columns.length || !tb.rows.length) continue;
        var blk = makeA2UIBlock("ComparisonTable", { columns: tb.columns, rows: tb.rows }, ctx);
        blk.source = "markdown_table";
        inserts.push(blk);
        var tableMeta = { component: "ComparisonTable", from: "markdown_table" };
        if (root.PaletteBlockSchema && PaletteBlockSchema.clipComparisonTableProps) {
          var tableClip = PaletteBlockSchema.clipComparisonTableProps(blk.props);
          if (tableClip.clipped) {
            tableMeta.clipped = true;
            tableMeta.originalRows = tableClip.originalRows;
            tableMeta.originalCols = tableClip.originalCols;
          }
        }
        meta.push(tableMeta);
      }
    }

    if (candidates.indexOf("Steps") >= 0 && inserts.length === 0) {
      var steps = extractSteps(replyMd);
      if (steps.length >= 2) {
        var stBlk = makeA2UIBlock("Steps", { items: steps }, ctx);
        stBlk.source = "heuristic";
        inserts.push(stBlk);
        meta.push({ component: "Steps", from: "numbered_list" });
      }
    }

    if (candidates.indexOf("Alert") >= 0) {
      var alerts = extractAlerts(replyMd);
      for (var ai = 0; ai < alerts.length; ai++) {
        var alBlk = makeA2UIBlock(
          "Alert",
          { variant: alerts[ai].variant, text: alerts[ai].text },
          ctx
        );
        alBlk.source = "heuristic";
        inserts.push(alBlk);
        meta.push({ component: "Alert", from: "inline_marker" });
      }
    }

    if (!inserts.length) return { blocks: list, meta: { a2ui: [] } };

    if (replyIdx >= 0) {
      list.splice.apply(list, [replyIdx, 0].concat(inserts));
    } else {
      list = list.concat(inserts);
    }

    var hideTables = options.hideOriginalTable === true;
    if (hideTables && replyIdx >= 0) {
      var hadTableA2ui = false;
      for (var mi = 0; mi < meta.length; mi++) {
        if (meta[mi] && meta[mi].component === "ComparisonTable") {
          hadTableA2ui = true;
          break;
        }
      }
      if (hadTableA2ui) {
        var replyAt = replyIdx + inserts.length;
        var rb = list[replyAt];
        if (rb && rb.type === "reply" && rb.markdown) {
          var stripped = stripMarkdownTables(String(rb.markdown));
          if (stripped && stripped !== rb.markdown) {
            list[replyAt] = Object.assign({}, rb, { markdown: stripped, updatedAt: Date.now() });
          }
        }
      }
    }

    if (root.PaletteBlockSchema && PaletteBlockSchema.validateBlocks) {
      list = PaletteBlockSchema.validateBlocks(list).blocks;
    }
    return { blocks: list, meta: { a2ui: meta } };
  }

  function render(container, block) {
    if (!root.PaletteA2UILegacyRenderer || !PaletteA2UILegacyRenderer.render) return false;
    return PaletteA2UILegacyRenderer.render(container, block);
  }

  root.PaletteMiniA2UI = {
    extractMarkdownTables: extractMarkdownTables,
    stripMarkdownTables: stripMarkdownTables,
    extractSteps: extractSteps,
    extractAlerts: extractAlerts,
    enrichBlocksWithA2UI: enrichBlocksWithA2UI,
    render: render
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
