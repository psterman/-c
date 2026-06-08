/**
 * Palette ComponentMatcher — finalize 后组件匹配中间件
 *
 * 职责：route → uiCandidates 解析、展示策略、表格裁剪，委托 MiniA2UI 做 Markdown 启发式提取。
 */
(function (root) {
  var DEFAULT_A2UI = ["ComparisonTable", "Steps", "Alert"];

  function resolveA2uiCandidates(route) {
    route = route || {};
    if (route.uiCandidates && route.uiCandidates.a2ui && route.uiCandidates.a2ui.length)
      return route.uiCandidates.a2ui.slice();
    if (route.a2uiCandidates && route.a2uiCandidates.length) return route.a2uiCandidates.slice();
    return DEFAULT_A2UI.slice();
  }

  function resolveHideOriginalTable(route, options) {
    options = options || {};
    route = route || {};
    if (options.hideOriginalTable != null) return !!options.hideOriginalTable;
    if (
      route.uiCandidates &&
      route.uiCandidates.display &&
      route.uiCandidates.display.hideOriginalTable != null
    )
      return !!route.uiCandidates.display.hideOriginalTable;
    return false;
  }

  function clipComparisonTableBlocks(blocks, a2meta) {
    if (!root.PaletteBlockSchema || !PaletteBlockSchema.clipComparisonTableProps) {
      return { blocks: blocks, meta: a2meta };
    }
    var list = Array.isArray(blocks) ? blocks.slice() : [];
    var meta = Array.isArray(a2meta) ? a2meta.slice() : [];
    var metaIdx = 0;
    for (var i = 0; i < list.length; i++) {
      var b = list[i];
      if (!b || b.type !== "a2ui" || b.component !== "ComparisonTable" || !b.props) continue;
      var clip = PaletteBlockSchema.clipComparisonTableProps(b.props);
      list[i] = Object.assign({}, b, { props: clip.props, updatedAt: Date.now() });
      if (clip.clipped) {
        while (metaIdx < meta.length && meta[metaIdx] && meta[metaIdx].component !== "ComparisonTable")
          metaIdx++;
        if (metaIdx < meta.length && meta[metaIdx]) {
          meta[metaIdx] = Object.assign({}, meta[metaIdx], {
            clipped: true,
            originalRows: clip.originalRows,
            originalCols: clip.originalCols
          });
        }
      }
      metaIdx++;
    }
    return { blocks: list, meta: meta };
  }

  function match(blocks, options) {
    options = options || {};
    var route = options.route || {};
    if (!root.PaletteMiniA2UI || !PaletteMiniA2UI.enrichBlocksWithA2UI) {
      return { blocks: blocks || [], meta: { a2ui: [] } };
    }
    var enrichRoute = Object.assign({}, route, { a2uiCandidates: resolveA2uiCandidates(route) });
    var enrichOpts = {
      route: enrichRoute,
      turnId: options.turnId,
      traceId: options.traceId,
      nextSeq: options.nextSeq,
      hideOriginalTable: resolveHideOriginalTable(route, options)
    };
    var enriched = PaletteMiniA2UI.enrichBlocksWithA2UI(blocks, enrichOpts);
    var outBlocks = enriched.blocks || blocks || [];
    var a2meta = (enriched.meta && enriched.meta.a2ui) || [];
    var clipped = clipComparisonTableBlocks(outBlocks, a2meta);
    var hideOriginalTable = enrichOpts.hideOriginalTable;
    var displayPolicy = {
      hideOriginalTable: hideOriginalTable,
      option: hideOriginalTable ? "B" : "A"
    };
    var uiMatches = (clipped.meta || []).map(function (m) {
      return {
        component: m.component,
        from: m.from,
        matched: true,
        clipped: !!m.clipped,
        originalRows: m.originalRows,
        originalCols: m.originalCols
      };
    });
    return {
      blocks: clipped.blocks,
      meta: {
        a2ui: clipped.meta,
        matcher: {
          a2uiCandidates: enrichRoute.a2uiCandidates,
          hideOriginalTable: hideOriginalTable
        },
        uiMatches: uiMatches,
        displayPolicy: displayPolicy,
        candidates: enrichRoute.a2uiCandidates.slice()
      }
    };
  }

  root.PaletteComponentMatcher = {
    resolveA2uiCandidates: resolveA2uiCandidates,
    resolveHideOriginalTable: resolveHideOriginalTable,
    match: match
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
