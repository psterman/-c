/**
 * Palette A2UI contract characterization fixtures.
 *
 * Locks the current canonical block boundary before renderer migration.
 * These fixtures intentionally cover valid, legacy-normalized, and dirty inputs.
 */
(function (root) {
  var COMPONENTS = ["ComparisonTable", "Steps", "Alert", "ActionChips"];

  function baseBlock(component, props, id) {
    return {
      id: id || "blk_contract_" + component.toLowerCase(),
      type: "a2ui",
      state: "final",
      source: "system",
      confidence: 1,
      seq: 1,
      turnId: 1,
      traceId: "tr_a2ui_contract",
      component: component,
      props: props
    };
  }

  function validBlocks() {
    return [
      baseBlock(
        "ComparisonTable",
        { columns: ["维度", "A", "B"], rows: [["速度", "快", "稳"]] },
        "blk_contract_table"
      ),
      baseBlock("Steps", { items: ["检查", "执行", "验证"] }, "blk_contract_steps"),
      baseBlock("Alert", { variant: "warning", text: "端口被占用" }, "blk_contract_alert"),
      baseBlock(
        "ActionChips",
        {
          actions: [
            {
              id: "contract_prefill",
              label: "补充说明",
              intent: "prefill",
              payload: { text: "请补充说明" }
            }
          ]
        },
        "blk_contract_actions"
      )
    ];
  }

  function makeMockContainer() {
    return {
      hidden: true,
      innerHTML: "",
      attrs: {},
      setAttribute: function (key, value) {
        this.attrs[key] = String(value);
      }
    };
  }

  function findComponent(blocks, component) {
    for (var i = 0; i < (blocks || []).length; i++) {
      var block = blocks[i];
      if (block && block.type === "a2ui" && block.component === component) return block;
    }
    return null;
  }

  function runCanonicalRoundtrip() {
    var result = PaletteBlockSchema.validateBlocks(validBlocks());
    var missing = [];
    for (var i = 0; i < COMPONENTS.length; i++) {
      if (!findComponent(result.blocks, COMPONENTS[i])) missing.push(COMPONENTS[i]);
    }
    return {
      fixture: "canonical_roundtrip",
      ok: result.ok && result.blocks.length === 4 && missing.length === 0,
      blockCount: result.blocks.length,
      missing: missing,
      errors: result.errors || []
    };
  }

  function runLegacyNormalizerContracts() {
    var cases = [
      {
        component: "ComparisonTable",
        markdown: "| A | B |\n|---|---|\n| 1 | 2 |"
      },
      {
        component: "Steps",
        markdown: "1. 检查连接\n2. 执行任务\n3. 验证结果"
      },
      {
        component: "Alert",
        markdown: "⚠ Gateway 端口被占用"
      }
    ];
    var missing = [];
    for (var i = 0; i < cases.length; i++) {
      var item = cases[i];
      var result = PaletteMiniA2UI.enrichBlocksWithA2UI(
        [
          {
            id: "blk_contract_reply_" + i,
            type: "reply",
            state: "final",
            source: "raw",
            confidence: 1,
            seq: 1,
            turnId: 1,
            traceId: "tr_contract_normalizer",
            markdown: item.markdown
          }
        ],
        {
          turnId: 1,
          traceId: "tr_contract_normalizer",
          route: { a2uiCandidates: [item.component] }
        }
      );
      if (!findComponent(result.blocks, item.component)) missing.push(item.component);
    }
    return {
      fixture: "legacy_normalizer_contracts",
      ok: missing.length === 0,
      missing: missing
    };
  }

  function runDirtyPropsIsolation() {
    var reply = {
      id: "blk_contract_reply_safe",
      type: "reply",
      state: "final",
      source: "raw",
      confidence: 1,
      seq: 1,
      turnId: 1,
      traceId: "tr_contract_dirty",
      markdown: "脏 A2UI 数据不能影响正文。"
    };
    var dirty = baseBlock("ComparisonTable", null, "blk_contract_dirty_table");
    dirty.seq = 2;
    var validated = PaletteBlockSchema.validateBlocks([reply, dirty]);
    var safeReply = validated.blocks.some(function (block) {
      return block && block.type === "reply" && block.markdown === reply.markdown;
    });
    var safeDirty = findComponent(validated.blocks, "ComparisonTable");
    var container = makeMockContainer();
    var rendered = false;
    var threw = false;
    try {
      rendered = PaletteMiniA2UI.render(container, safeDirty || dirty);
    } catch (_) {
      threw = true;
    }
    return {
      fixture: "dirty_props_isolated",
      ok:
        safeReply &&
        !!safeDirty &&
        safeDirty.props &&
        Array.isArray(safeDirty.props.columns) &&
        safeDirty.props.columns.length === 0 &&
        Array.isArray(safeDirty.props.rows) &&
        safeDirty.props.rows.length === 0 &&
        rendered === false &&
        threw === false,
      replyPreserved: safeReply,
      rendered: rendered,
      threw: threw
    };
  }

  function runUnknownComponentIsolation() {
    var reply = {
      id: "blk_contract_unknown_reply",
      type: "reply",
      state: "final",
      source: "raw",
      confidence: 1,
      seq: 1,
      turnId: 1,
      traceId: "tr_contract_unknown",
      markdown: "未知组件被丢弃时正文仍保留。"
    };
    var unknown = baseBlock("UnknownWidget", { value: 1 }, "blk_contract_unknown");
    unknown.seq = 2;
    var result = PaletteBlockSchema.validateBlocks([reply, unknown]);
    var hasReply = result.blocks.some(function (block) {
      return block && block.type === "reply";
    });
    var hasUnknown = result.blocks.some(function (block) {
      return block && block.component === "UnknownWidget";
    });
    return {
      fixture: "unknown_component_isolated",
      ok:
        hasReply &&
        !hasUnknown &&
        result.dropped.length === 1 &&
        result.errors.indexOf("unsupported_component:UnknownWidget") >= 0,
      errors: result.errors || []
    };
  }

  function runActionPayloadPreserved() {
    var input = validBlocks()[3];
    var safe = PaletteBlockSchema.sanitizeBlock(input);
    var action =
      safe &&
      safe.props &&
      Array.isArray(safe.props.actions) &&
      safe.props.actions.length
        ? safe.props.actions[0]
        : null;
    return {
      fixture: "action_payload_preserved",
      ok:
        !!action &&
        action.id === "contract_prefill" &&
        action.intent === "prefill" &&
        action.payload &&
        action.payload.text === "请补充说明"
    };
  }

  function runTypedPropsSanitized() {
    var table = PaletteBlockSchema.sanitizeBlock(
      baseBlock(
        "ComparisonTable",
        {
          columns: [" A ", null, "C"],
          rows: [[" 1 ", null, "3"], "invalid-row"]
        },
        "blk_contract_sanitize_table"
      )
    );
    var steps = PaletteBlockSchema.sanitizeBlock(
      baseBlock(
        "Steps",
        { items: [" 第一步 ", "", null, "第二步"] },
        "blk_contract_sanitize_steps"
      )
    );
    var alert = PaletteBlockSchema.sanitizeBlock(
      baseBlock(
        "Alert",
        { variant: "unexpected", text: " 提示内容 " },
        "blk_contract_sanitize_alert"
      )
    );
    return {
      fixture: "typed_props_sanitized",
      ok:
        !!table &&
        table.props.columns.length === 3 &&
        table.props.columns[0] === " A " &&
        table.props.columns[1] === "" &&
        table.props.rows.length === 1 &&
        table.props.rows[0][1] === "" &&
        !!steps &&
        steps.props.items.length === 2 &&
        steps.props.items[0] === "第一步" &&
        !!alert &&
        alert.props.variant === "info" &&
        alert.props.text === "提示内容"
    };
  }

  function runSchemaVersionRoundtrip() {
    var input = baseBlock(
      "Alert",
      { variant: "success", text: "完成" },
      "blk_contract_schema_version"
    );
    var safe = PaletteBlockSchema.sanitizeBlock(input);
    var packed = PaletteBlockStore.pack([safe], {});
    var replayed = PaletteBlockStore.unpack(packed);
    var block = replayed.blocks[0];
    return {
      fixture: "schema_version_roundtrip",
      ok:
        !!safe &&
        safe.schemaVersion === 1 &&
        !!block &&
        block.schemaVersion === 1 &&
        packed.blockVersion === PaletteBlockSchema.BLOCK_VERSION
    };
  }

  function runAdapterLegacyAliases() {
    var table = PaletteA2UIAdapter.createBlock(
      "ComparisonTable",
      { headers: ["维度", "A"], data: [["速度", "快"]] },
      { id: "blk_adapter_table", seq: 1 }
    );
    var steps = PaletteA2UIAdapter.createBlock(
      "Steps",
      { steps: [{ text: "检查" }, { title: "执行" }, "验证"] },
      { id: "blk_adapter_steps", seq: 2 }
    );
    var alert = PaletteA2UIAdapter.createBlock(
      "Alert",
      { severity: "warning", message: "端口占用" },
      { id: "blk_adapter_alert", seq: 3 }
    );
    var actions = PaletteA2UIAdapter.createBlock(
      "ActionChips",
      {
        chips: [
          {
            id: "legacy_chip",
            label: "继续",
            intent: "append",
            prefill: "继续处理"
          }
        ]
      },
      { id: "blk_adapter_actions", seq: 4 }
    );
    return {
      fixture: "adapter_legacy_aliases",
      ok:
        !!table &&
        table.props.columns[0] === "维度" &&
        table.props.rows[0][1] === "快" &&
        !!steps &&
        steps.props.items.join("|") === "检查|执行|验证" &&
        !!alert &&
        alert.props.variant === "warning" &&
        alert.props.text === "端口占用" &&
        !!actions &&
        actions.props.actions[0].intent === "prefill" &&
        actions.props.actions[0].payload.text === "继续处理"
    };
  }

  function runAdapterInvalidIsolation() {
    var unknown = PaletteA2UIAdapter.createBlock("UnknownWidget", {}, {});
    var emptyActions = PaletteA2UIAdapter.createBlock("ActionChips", { actions: [] }, {});
    var dirtyTable = PaletteA2UIAdapter.createBlock("ComparisonTable", null, {
      id: "blk_adapter_dirty_table"
    });
    return {
      fixture: "adapter_invalid_isolation",
      ok:
        unknown === null &&
        emptyActions === null &&
        !!dirtyTable &&
        Array.isArray(dirtyTable.props.columns) &&
        dirtyTable.props.columns.length === 0
    };
  }

  function runRegistryContracts() {
    var actionDef = PaletteComponentRegistry.get("ActionChips");
    var byId = PaletteComponentRegistry.getById("ActionChips");
    var resolved = PaletteComponentRegistry.resolve({ component: "status-log" });
    var names = PaletteComponentRegistry.list();
    var registered = PaletteComponentRegistry.register("ContractLazy", {
      componentId: "contract-lazy",
      tag: "palette-contract-lazy",
      load: function () {
        return true;
      }
    });
    var lazy = PaletteComponentRegistry.getById("contract-lazy");
    var removed = PaletteComponentRegistry.unregister("ContractLazy");
    return {
      fixture: "registry_contracts",
      ok:
        !!actionDef &&
        actionDef.tag === "palette-action-chips" &&
        byId === actionDef &&
        !!resolved &&
        resolved.tag === "palette-status-log" &&
        names.indexOf("ActionChips") >= 0 &&
        registered &&
        !!lazy &&
        removed &&
        PaletteComponentRegistry.get("ContractLazy") === null
    };
  }

  function runComparisonTableLitContract() {
    var block = baseBlock(
      "ComparisonTable",
      { columns: ["维度", "A"], rows: [["速度", "快"]] },
      "blk_contract_lit_table"
    );
    var descriptor = PaletteCardSlots.toBlockDescriptor({ id: "card_contract_table" }, block);
    var definition = PaletteComponentRegistry.get("ComparisonTable");
    var element = {};
    definition.applyProps(element, descriptor.props);
    return {
      fixture: "comparison_table_lit_contract",
      ok:
        !!descriptor &&
        descriptor.component === "ComparisonTable" &&
        descriptor.tag === "palette-comparison-table" &&
        PaletteLitRenderer.validateComparisonTableDescriptor(descriptor) &&
        element.cardId === "card_contract_table" &&
        element.blockId === "blk_contract_lit_table" &&
        element.columns.length === 2 &&
        element.rows[0][1] === "快"
    };
  }

  function runComparisonTableInvalidFallback() {
    var block = baseBlock("ComparisonTable", { columns: [], rows: [] }, "blk_contract_bad_table");
    var descriptor = PaletteCardSlots.toBlockDescriptor({ id: "card_contract_bad_table" }, block);
    return {
      fixture: "comparison_table_invalid_fallback",
      ok:
        !!descriptor &&
        !PaletteLitRenderer.validateComparisonTableDescriptor(descriptor) &&
        descriptor.props.columns.length === 0
    };
  }

  function runStepsLitContract() {
    var block = baseBlock("Steps", { items: ["检查", "执行", "验证"] }, "blk_contract_lit_steps");
    var descriptor = PaletteCardSlots.toBlockDescriptor({ id: "card_contract_steps" }, block);
    var definition = PaletteComponentRegistry.get("Steps");
    var element = {};
    definition.applyProps(element, descriptor.props);
    return {
      fixture: "steps_lit_contract",
      ok:
        !!descriptor &&
        descriptor.component === "Steps" &&
        descriptor.tag === "palette-steps" &&
        PaletteLitRenderer.validateStepsDescriptor(descriptor) &&
        element.cardId === "card_contract_steps" &&
        element.blockId === "blk_contract_lit_steps" &&
        element.items.join("|") === "检查|执行|验证"
    };
  }

  function runStepsInvalidFallback() {
    var block = baseBlock("Steps", { items: [] }, "blk_contract_bad_steps");
    var descriptor = PaletteCardSlots.toBlockDescriptor({ id: "card_contract_bad_steps" }, block);
    return {
      fixture: "steps_invalid_fallback",
      ok:
        !!descriptor &&
        !PaletteLitRenderer.validateStepsDescriptor(descriptor) &&
        descriptor.props.items.length === 0
    };
  }

  function runAlertLitContract() {
    var block = baseBlock("Alert", { variant: "warning", text: "端口被占用" }, "blk_contract_lit_alert");
    var descriptor = PaletteCardSlots.toBlockDescriptor({ id: "card_contract_alert" }, block);
    var definition = PaletteComponentRegistry.get("Alert");
    var element = {};
    definition.applyProps(element, descriptor.props);
    return {
      fixture: "alert_lit_contract",
      ok:
        !!descriptor &&
        descriptor.component === "Alert" &&
        descriptor.tag === "palette-alert" &&
        PaletteLitRenderer.validateAlertDescriptor(descriptor) &&
        element.cardId === "card_contract_alert" &&
        element.blockId === "blk_contract_lit_alert" &&
        element.variant === "warning" &&
        element.text === "端口被占用"
    };
  }

  function runAlertInvalidFallback() {
    var block = baseBlock("Alert", { variant: "danger", text: "   " }, "blk_contract_bad_alert");
    var descriptor = PaletteCardSlots.toBlockDescriptor({ id: "card_contract_bad_alert" }, block);
    return {
      fixture: "alert_invalid_fallback",
      ok:
        !!descriptor &&
        !PaletteLitRenderer.validateAlertDescriptor(descriptor) &&
        String(descriptor.props.text || "").trim() === ""
    };
  }

  function runAllContractFixtures() {
    var runners = [
      runCanonicalRoundtrip,
      runLegacyNormalizerContracts,
      runDirtyPropsIsolation,
      runUnknownComponentIsolation,
      runActionPayloadPreserved,
      runTypedPropsSanitized,
      runSchemaVersionRoundtrip,
      runAdapterLegacyAliases,
      runAdapterInvalidIsolation,
      runRegistryContracts,
      runComparisonTableLitContract,
      runComparisonTableInvalidFallback,
      runStepsLitContract,
      runStepsInvalidFallback,
      runAlertLitContract,
      runAlertInvalidFallback
    ];
    var results = [];
    var passed = 0;
    for (var i = 0; i < runners.length; i++) {
      var result;
      try {
        result = runners[i]();
      } catch (err) {
        result = {
          fixture: "contract_fixture_" + i,
          ok: false,
          error: String(err && err.message ? err.message : err)
        };
      }
      results.push(result);
      if (result.ok) passed++;
    }
    return {
      ok: passed === results.length,
      passed: passed,
      failed: results.length - passed,
      results: results
    };
  }

  root.PaletteA2UIContractFixtures = {
    COMPONENTS: COMPONENTS,
    validBlocks: validBlocks,
    runAllContractFixtures: runAllContractFixtures
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
