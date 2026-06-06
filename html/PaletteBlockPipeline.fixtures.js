/**
 * Palette Pipeline fixtures — mock blocks 验收
 */
(function (root) {
  var FIXTURES = {
    mock_all_slots: {
      description: "各槽位 mock blocks",
      blocks: [
        {
          id: "blk_mock_plan",
          type: "plan",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 1,
          turnId: 1,
          traceId: "tr_mock",
          items: [
            { text: "检查 gateway 状态", state: "done" },
            { text: "重启 gateway", state: "interrupted" }
          ]
        },
        {
          id: "blk_mock_status",
          type: "status",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 2,
          turnId: 1,
          traceId: "tr_mock",
          items: [{ text: "gateway 重启被中断", level: "warning" }]
        },
        {
          id: "blk_mock_question",
          type: "question",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 3,
          turnId: 1,
          traceId: "tr_mock",
          title: "要继续吗？",
          markdown: "M3 升级只差最后一步——重启生效。",
          status: "waiting"
        },
        {
          id: "blk_mock_reply",
          type: "reply",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 4,
          turnId: 1,
          traceId: "tr_mock",
          title: "任务回复",
          markdown: "早上好！\n\n## 结论\n\n可以继续重启 gateway。"
        },
        {
          id: "blk_mock_a2ui",
          type: "a2ui",
          state: "final",
          source: "system",
          confidence: 1,
          seq: 5,
          turnId: 1,
          traceId: "tr_mock",
          component: "ComparisonTable",
          props: { columns: ["A", "B"], rows: [["1", "2"]] }
        }
      ]
    },
    protocol_basic: {
      description: "四标签 protocol finalize 输入样例",
      rawAnswer:
        "::PLAN_START:: 步骤1：检查 | 步骤2：重启 ::PLAN_END::\n" +
        "::STATUS_START:: [执行器] 进行中\n日志 ::STATUS_END::\n" +
        "::REPLY_START:: 任务完结\n早上好！ ::REPLY_END::"
    },
    plain_markdown: {
      description: "无标签纯 Markdown → raw reply fallback",
      rawAnswer: "早上好！\n\n**结论**：可以继续。"
    }
  };

  function getFixture(name) {
    return FIXTURES[name] || null;
  }

  function getMockRenderer() {
    if (typeof root.runMockRenderBlocks === "function") return root.runMockRenderBlocks;
    if (root.nmerPalette && typeof root.nmerPalette.runMockRenderBlocks === "function")
      return root.nmerPalette.runMockRenderBlocks;
    return null;
  }

  function runPalettePipelineFixture(name, cardId) {
    var fx = getFixture(name);
    if (!fx) return { ok: false, error: "unknown_fixture:" + name };
    var out = { fixture: name, description: fx.description || "" };
    var renderFn = getMockRenderer();
    if (fx.blocks) {
      out.input = { blocks: fx.blocks.length };
      out.blocks = fx.blocks;
      if (root.PaletteBlockSchema) out.blocks = PaletteBlockSchema.validateBlocks(fx.blocks).blocks;
      if (renderFn) out.render = renderFn(cardId || "mock-fixture-card", out.blocks);
      out.ok = true;
      return out;
    }
    if (fx.rawAnswer != null && root.PaletteBlockPipeline) {
      out.input = { rawLen: String(fx.rawAnswer).length };
      var result = PaletteBlockPipeline.finalize(fx.rawAnswer, { traceId: "fx_" + name });
      out.blocks = result.blocks;
      out.meta = result.meta;
      if (renderFn) out.render = renderFn(cardId || "mock-fixture-card", result.blocks);
      out.ok = true;
      return out;
    }
    return { ok: false, error: "empty_fixture" };
  }

  root.PaletteBlockFixtures = {
    FIXTURES: FIXTURES,
    getFixture: getFixture,
    runPalettePipelineFixture: runPalettePipelineFixture
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
