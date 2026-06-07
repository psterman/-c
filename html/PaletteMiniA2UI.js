/**
 * Palette Mini-A2UI — finalize 后处理：Markdown → a2ui blocks
 *
 * C.1+ 范围：仅 finalize 阶段 enrich；A2UI 在 reply 前展示；
 * 已 enrich 的表格从 reply markdown 剥离（hideOriginalTable，默认开）。
 */
(function (root) {
  function escHtml(s) {
    return String(s || "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;");
  }

  function splitTableRow(line) {
    var t = String(line || "").trim();
    if (!t.includes("|")) return [];
    if (t.charAt(0) === "|") t = t.slice(1);
    if (t.charAt(t.length - 1) === "|") t = t.slice(0, -1);
    return t.split("|").map(function (c) {
      return c.trim();
    });
  }

  function isSeparatorRow(cells) {
    if (!cells || !cells.length) return false;
    return cells.every(function (c) {
      return /^:?-{2,}:?$/.test(String(c || "").trim());
    });
  }

  function extractMarkdownTables(markdown) {
    var lines = String(markdown || "").split(/\r?\n/);
    var tables = [];
    var i = 0;
    while (i < lines.length - 1) {
      var header = splitTableRow(lines[i]);
      var sep = splitTableRow(lines[i + 1]);
      if (header.length >= 2 && isSeparatorRow(sep)) {
        var rows = [];
        i += 2;
        while (i < lines.length) {
          var row = splitTableRow(lines[i]);
          if (row.length < 2) break;
          rows.push(row);
          i++;
        }
        tables.push({ columns: header, rows: rows });
        continue;
      }
      i++;
    }
    return tables;
  }

  /** 从 reply markdown 移除表格块（A2UI ComparisonTable 已承接时） */
  function stripMarkdownTables(markdown) {
    var lines = String(markdown || "").split(/\r?\n/);
    var out = [];
    var i = 0;
    while (i < lines.length) {
      var header = splitTableRow(lines[i]);
      var sep = i + 1 < lines.length ? splitTableRow(lines[i + 1]) : [];
      if (header.length >= 2 && isSeparatorRow(sep)) {
        i += 2;
        while (i < lines.length) {
          var row = splitTableRow(lines[i]);
          if (row.length < 2) break;
          i++;
        }
        if (out.length && String(out[out.length - 1]).trim() !== "") out.push("");
        continue;
      }
      out.push(lines[i]);
      i++;
    }
    return out
      .join("\n")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
  }

  function extractSteps(markdown) {
    var lines = String(markdown || "").split(/\r?\n/);
    var items = [];
    for (var i = 0; i < lines.length; i++) {
      var ln = lines[i].trim();
      var m =
        ln.match(/^\d+[\.\)、]\s+(.+)$/) ||
        ln.match(/^[-*]\s+\[[ xX]\]\s+(.+)$/) ||
        ln.match(/^步骤\s*\d+\s*[：:]\s*(.+)$/);
      if (m && m[1]) items.push(String(m[1]).trim());
    }
    return items.slice(0, 20);
  }

  function extractAlerts(markdown) {
    var lines = String(markdown || "").split(/\r?\n/);
    var alerts = [];
    for (var i = 0; i < lines.length; i++) {
      var ln = lines[i].trim();
      if (!ln) continue;
      var variant = null;
      if (/^(⚠️|⚠|警告|注意|风险提示)/.test(ln)) variant = "warning";
      else if (/^(❌|错误|失败|异常)/.test(ln)) variant = "error";
      else if (/^(✅|成功|完成)/.test(ln)) variant = "success";
      else if (/^(ℹ️|提示|说明)/.test(ln)) variant = "info";
      if (variant) alerts.push({ variant: variant, text: ln.replace(/^(⚠️|⚠|❌|✅|ℹ️)\s*/, "") });
    }
    return alerts.slice(0, 5);
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
        meta.push({ component: "ComparisonTable", from: "markdown_table" });
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

    var hideTables = options.hideOriginalTable !== false;
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

  function renderComparisonTable(el, props) {
    var cols = (props && props.columns) || [];
    var rows = (props && props.rows) || [];
    if (!cols.length) return false;
    var html =
      '<div class="a2ui-comparison"><table class="a2ui-table"><thead><tr>' +
      cols
        .map(function (c) {
          return "<th>" + escHtml(c) + "</th>";
        })
        .join("") +
      "</tr></thead><tbody>";
    for (var r = 0; r < rows.length; r++) {
      html += "<tr>";
      for (var c = 0; c < cols.length; c++) {
        html += "<td>" + escHtml(rows[r][c] != null ? rows[r][c] : "") + "</td>";
      }
      html += "</tr>";
    }
    html += "</tbody></table></div>";
    el.innerHTML = html;
    return true;
  }

  function renderSteps(el, props) {
    var items = (props && props.items) || [];
    if (!items.length) return false;
    el.innerHTML =
      '<div class="a2ui-steps"><ol class="a2ui-steps-list">' +
      items
        .map(function (it) {
          return "<li>" + escHtml(it) + "</li>";
        })
        .join("") +
      "</ol></div>";
    return true;
  }

  function renderAlert(el, props) {
    var text = String((props && props.text) || "").trim();
    if (!text) return false;
    var variant = String((props && props.variant) || "info");
    el.innerHTML =
      '<div class="a2ui-alert a2ui-alert-' +
      escHtml(variant) +
      '">' +
      escHtml(text) +
      "</div>";
    return true;
  }

  function render(container, block) {
    if (!container || !block) return false;
    container.hidden = false;
    container.setAttribute("data-component", block.component || "");
    container.setAttribute("data-block-id", block.id || "");
    var comp = String(block.component || "");
    var props = block.props || {};
    if (comp === "ComparisonTable") return renderComparisonTable(container, props);
    if (comp === "Steps") return renderSteps(container, props);
    if (comp === "Alert") return renderAlert(container, props);
    container.hidden = true;
    return false;
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
