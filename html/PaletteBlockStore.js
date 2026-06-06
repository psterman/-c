/**
 * Palette BlockStore — 磁盘持久化轻量 blocks（rawAnswer 保留完整原文）
 */
(function (root) {
  var MAX_REPLY_MD = 20000;
  var MAX_STATUS_TEXT = 8000;
  var MAX_STATUS_ITEMS = 50;
  var MAX_PLAN_ITEMS = 30;
  var MAX_QUESTION_MD = 8000;
  var MAX_TABLE_ROWS = 20;
  var MAX_TABLE_COLS = 8;
  var MAX_CELL = 500;
  var MAX_BLOCKS = 40;

  function trimText(text, max) {
    var t = String(text != null ? text : "");
    if (t.length <= max) return t;
    return t.slice(0, max);
  }

  function packBlock(block) {
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
      b.markdown = trimText(md, MAX_REPLY_MD);
      if (md.length > MAX_REPLY_MD) {
        b.truncated = true;
        b.rawRef = "rawAnswer";
      }
    } else if (block.type === "plan" && Array.isArray(block.items)) {
      b.items = block.items.slice(0, MAX_PLAN_ITEMS).map(function (it) {
        return { text: trimText(it.text, 2000), state: it.state || "done" };
      });
    } else if (block.type === "status" && Array.isArray(block.items)) {
      b.items = block.items.slice(-MAX_STATUS_ITEMS).map(function (it) {
        return {
          text: trimText(it.text, MAX_STATUS_TEXT),
          level: it.level || "info",
          time: it.time || ""
        };
      });
    } else if (block.type === "question") {
      b.markdown = trimText(block.markdown, MAX_QUESTION_MD);
      b.title = trimText(block.title, 500);
    } else if (block.type === "a2ui" && block.component === "ComparisonTable" && block.props) {
      var cols = (block.props.columns || []).slice(0, MAX_TABLE_COLS).map(function (c) {
        return trimText(c, MAX_CELL);
      });
      var rows = (block.props.rows || []).slice(0, MAX_TABLE_ROWS).map(function (row) {
        return (row || []).slice(0, MAX_TABLE_COLS).map(function (c) {
          return trimText(c, MAX_CELL);
        });
      });
      b.props = { columns: cols, rows: rows };
      b.component = "ComparisonTable";
    } else if (block.type === "a2ui" && block.component === "Steps" && block.props) {
      b.component = "Steps";
      b.props = {
        items: (block.props.items || []).slice(0, 20).map(function (it) {
          return trimText(it, 2000);
        })
      };
    } else if (block.type === "a2ui" && block.component === "Alert" && block.props) {
      b.component = "Alert";
      b.props = {
        variant: block.props.variant || "info",
        text: trimText(block.props.text, 2000)
      };
    } else if (block.type === "error") {
      b.message = trimText(block.message, 4000);
    }
    return b;
  }

  function pack(blocks, meta) {
    meta = meta || {};
    var list = Array.isArray(blocks) ? blocks : [];
    var packed = [];
    for (var i = 0; i < list.length && packed.length < MAX_BLOCKS; i++) {
      var pb = packBlock(list[i]);
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

  function unpack(store) {
    if (!store) return { blocks: [], blockVersion: 1, normalizerVersion: "2026-06-06" };
    var blocks = Array.isArray(store.blocks) ? store.blocks : [];
    if (root.PaletteBlockSchema && PaletteBlockSchema.validateBlocks) {
      blocks = PaletteBlockSchema.validateBlocks(blocks).blocks;
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
    packBlock: packBlock
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
