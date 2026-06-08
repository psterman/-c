/**
 * Palette BlockStore — 磁盘持久化轻量 blocks（rawAnswer 保留完整原文）
 */
(function (root) {
  var L =
    root.PaletteBlockSchema && PaletteBlockSchema.LIMITS
      ? PaletteBlockSchema.LIMITS
      : {
          MAX_REPLY_MD: 20000,
          MAX_STATUS_TEXT: 8000,
          MAX_STATUS_ITEMS: 50,
          MAX_PLAN_ITEMS: 30,
          MAX_QUESTION_MD: 8000,
          MAX_TABLE_ROWS: 20,
          MAX_TABLE_COLS: 8,
          MAX_CELL: 500,
          MAX_BLOCKS: 40,
          MAX_STEPS: 20,
          MAX_ACTION_CHIPS: 24
        };

  function traceStore(opts, event, payload) {
    if (!opts || typeof opts.debugLog !== "function") return;
    try {
      opts.debugLog(event, typeof payload === "string" ? payload : JSON.stringify(payload));
    } catch (_) {}
  }

  function packActionChipForStore(action, index) {
    if (!root.PaletteBlockSchema || !PaletteBlockSchema.sanitizeActionChip) return null;
    var row = PaletteBlockSchema.sanitizeActionChip(action, index);
    if (!row) return null;
    var packed = {
      id: row.id,
      label: row.label,
      intent: row.intent,
      payload: {
        text:
          row.payload && row.payload.text != null
            ? trimText(row.payload.text, L.MAX_ACTION_CHIP_PAYLOAD_TEXT || 2000)
            : ""
      }
    };
    if (row.disabled) packed.disabled = true;
    if (row.tone) packed.tone = row.tone;
    return packed;
  }

  function packActionChipsProps(props) {
    props = props || {};
    var raw = Array.isArray(props.actions) ? props.actions : [];
    var actions = [];
    var max = L.MAX_ACTION_CHIPS || 24;
    for (var i = 0; i < raw.length && actions.length < max; i++) {
      var row = packActionChipForStore(raw[i], i);
      if (row) actions.push(row);
    }
    return { actions: actions };
  }

  function trimText(text, max) {
    if (root.PaletteBlockSchema && PaletteBlockSchema.trimText) return PaletteBlockSchema.trimText(text, max);
    var t = String(text != null ? text : "");
    if (t.length <= max) return t;
    return t.slice(0, max);
  }

  function packBlock(block, opts) {
    opts = opts || {};
    if (!block || typeof block !== "object") return null;
    var b = {};
    var keys = [
      "id",
      "type",
      "state",
      "source",
      "confidence",
      "seq",
      "turnId",
      "traceId",
      "title",
      "component",
      "status",
      "message",
      "code"
    ];
    for (var ki = 0; ki < keys.length; ki++) {
      if (block[keys[ki]] != null) b[keys[ki]] = block[keys[ki]];
    }
    if (block.type === "reply") {
      var md = String(block.markdown || "");
      b.markdown = trimText(md, L.MAX_REPLY_MD);
      if (md.length > L.MAX_REPLY_MD) {
        b.truncated = true;
        b.rawRef = "rawAnswer";
      }
      if (Array.isArray(block.actions) && block.actions.length) {
        b.actions =
          root.PaletteBlockSchema && PaletteBlockSchema.sanitizeActions
            ? PaletteBlockSchema.sanitizeActions(block.actions)
            : block.actions.slice(0, 8);
      }
    } else if (block.type === "plan" && Array.isArray(block.items)) {
      b.items = block.items.slice(0, L.MAX_PLAN_ITEMS).map(function (it) {
        return { text: trimText(it.text, 2000), state: it.state || "done" };
      });
    } else if (block.type === "status" && Array.isArray(block.items)) {
      if (block.source) b.source = block.source;
      b.items = block.items.slice(-L.MAX_STATUS_ITEMS).map(function (it) {
        var row = {
          text: trimText(it.text, L.MAX_STATUS_TEXT),
          level: it.level || "info",
          time: it.time || ""
        };
        if (it.tool != null) row.tool = trimText(it.tool, 120);
        if (it.phase != null) row.phase = String(it.phase).slice(0, 16);
        if (it.ts != null) row.ts = Number(it.ts) || 0;
        return row;
      });
    } else if (block.type === "question") {
      b.markdown = trimText(block.markdown, L.MAX_QUESTION_MD);
      b.title = trimText(block.title, 500);
    } else if (block.type === "a2ui" && block.component === "ComparisonTable" && block.props) {
      var clip =
        root.PaletteBlockSchema && PaletteBlockSchema.clipComparisonTableProps
          ? PaletteBlockSchema.clipComparisonTableProps(block.props)
          : { props: block.props };
      b.props = clip.props;
      b.component = "ComparisonTable";
    } else if (block.type === "a2ui" && block.component === "Steps" && block.props) {
      b.component = "Steps";
      b.props = {
        items: (block.props.items || []).slice(0, L.MAX_STEPS).map(function (it) {
          return trimText(it, 2000);
        })
      };
    } else if (block.type === "a2ui" && block.component === "Alert" && block.props) {
      b.component = "Alert";
      b.props = {
        variant: block.props.variant || "info",
        text: trimText(block.props.text, 2000)
      };
    } else if (block.type === "a2ui" && block.component === "ActionChips") {
      var chipProps = packActionChipsProps(block.props);
      if (!chipProps.actions.length) {
        traceStore(opts, "action_chips_block_pack_dropped", {
          blockId: block.id || "",
          reason: "empty_or_invalid_actions"
        });
        return null;
      }
      b.component = "ActionChips";
      b.props = chipProps;
      traceStore(opts, "action_chips_block_packed", {
        blockId: b.id || block.id || "",
        count: chipProps.actions.length
      });
    } else if (block.type === "error") {
      b.message = trimText(block.message, 4000);
    }
    return b;
  }

  function pack(blocks, meta) {
    meta = meta || {};
    var opts = { debugLog: meta.debugLog };
    var list = Array.isArray(blocks) ? blocks : [];
    var packed = [];
    for (var i = 0; i < list.length && packed.length < L.MAX_BLOCKS; i++) {
      var pb = packBlock(list[i], opts);
      if (pb) packed.push(pb);
    }
    var bv =
      root.PaletteBlockSchema && PaletteBlockSchema.BLOCK_VERSION
        ? PaletteBlockSchema.BLOCK_VERSION
        : meta.blockVersion || 1;
    var nv =
      root.PaletteBlockSchema && PaletteBlockSchema.NORMALIZER_VERSION
        ? PaletteBlockSchema.NORMALIZER_VERSION
        : meta.normalizerVersion || "2026-06-06";
    if (root.PaletteBlockSchema && PaletteBlockSchema.validateBlocks) {
      packed = PaletteBlockSchema.validateBlocks(packed).blocks;
    }
    return {
      blocks: packed,
      blockVersion: bv,
      normalizerVersion: nv,
      packedAt: Date.now()
    };
  }

  function unpack(store, opts) {
    opts = opts || {};
    if (!store) return { blocks: [], blockVersion: 1, normalizerVersion: "2026-06-06" };
    var blocks = Array.isArray(store.blocks) ? store.blocks : [];
    if (root.PaletteBlockSchema && PaletteBlockSchema.validateBlocks) {
      blocks = PaletteBlockSchema.validateBlocks(blocks).blocks;
    }
    for (var ri = 0; ri < blocks.length; ri++) {
      var rb = blocks[ri];
      if (
        rb &&
        rb.type === "a2ui" &&
        rb.component === "ActionChips" &&
        rb.props &&
        Array.isArray(rb.props.actions) &&
        rb.props.actions.length
      ) {
        traceStore(opts, "action_chips_block_replayed", {
          blockId: rb.id || "",
          count: rb.props.actions.length
        });
      }
    }
    return {
      blocks: blocks,
      blockVersion: store.blockVersion != null ? store.blockVersion : 1,
      normalizerVersion: store.normalizerVersion || "2026-06-06",
      packedAt: store.packedAt || 0
    };
  }

  root.PaletteBlockStore = {
    pack: pack,
    unpack: unpack,
    packBlock: packBlock,
    packActionChipsProps: packActionChipsProps
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
