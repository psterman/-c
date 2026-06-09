/**
 * PaletteRendererRegistry — R1/R2/R3 单一渲染调度表（architecture-v2 §1.2）。
 * 同一 Registry、不同 backend：R2 NMER Lit/Legacy、R3 官方 Surface。
 */
(function (root) {
  var REPRESENTATIONS = {
    R1: "r1",
    R2: "r2",
    R3: "r3"
  };

  var BACKENDS = {
    R1_LEGACY_DOM: "r1-legacy-dom",
    R2_NMER_LIT: "r2-nmer-lit",
    R2_NMER_LEGACY: "r2-nmer-legacy",
    R3_OFFICIAL_SURFACE: "r3-official-a2ui-surface",
    R3_OFFICIAL_INTERNAL: "r3-official-a2ui-internal"
  };

  var OFFICIAL_A2UI_COMPONENTS = ["Text", "Row", "Column", "Card", "Button", "TextField"];

  var R1_BLOCK_TYPES = ["plan", "status", "question", "reply", "error"];

  var R2_NMER_COMPONENTS = [
    "ComparisonTable",
    "Steps",
    "Alert",
    "ActionChips",
    "FollowUpChips",
    "StatusLog"
  ];

  var R1_MOUNTS = {
    plan: ".card-timeline",
    status: ".card-status-log",
    question: ".card-question",
    reply: ".card-replies",
    error: ".card-status-log"
  };

  var entries = {};

  function registerEntry(name, meta) {
    var key = String(name || "").trim();
    if (!key || !meta || typeof meta !== "object") return false;
    entries[key] = Object.assign({ name: key }, meta);
    return true;
  }

  function bootstrap() {
    R1_BLOCK_TYPES.forEach(function (type) {
      registerEntry("r1:" + type, {
        representation: REPRESENTATIONS.R1,
        backend: BACKENDS.R1_LEGACY_DOM,
        blockType: type,
        mount: R1_MOUNTS[type] || ""
      });
    });

    R2_NMER_COMPONENTS.forEach(function (name) {
      registerEntry(name, {
        representation: REPRESENTATIONS.R2,
        backend: BACKENDS.R2_NMER_LIT,
        fallbackBackend: BACKENDS.R2_NMER_LEGACY,
        registryKey: name,
        blockType: "a2ui"
      });
    });

    registerEntry("OfficialSurface", {
      representation: REPRESENTATIONS.R3,
      backend: BACKENDS.R3_OFFICIAL_SURFACE,
      hostTag:
        root.PaletteOfficialA2UIBridge && PaletteOfficialA2UIBridge.HOST_TAG
          ? PaletteOfficialA2UIBridge.HOST_TAG
          : "nmer-official-a2ui-surface",
      mount: ".card-official-a2ui",
      blockType: "official-a2ui"
    });

    OFFICIAL_A2UI_COMPONENTS.forEach(function (name) {
      registerEntry("r3:" + name, {
        representation: REPRESENTATIONS.R3,
        backend: BACKENDS.R3_OFFICIAL_INTERNAL,
        parent: "OfficialSurface",
        officialComponent: name
      });
    });
  }

  bootstrap();

  function get(name) {
    return entries[String(name || "").trim()] || null;
  }

  function list() {
    return Object.keys(entries);
  }

  function listByRepresentation(rep) {
    var target = String(rep || "").trim();
    return list().filter(function (key) {
      return entries[key] && entries[key].representation === target;
    });
  }

  function listByBackend(backend) {
    var target = String(backend || "").trim();
    return list().filter(function (key) {
      var entry = entries[key];
      return entry && (entry.backend === target || entry.fallbackBackend === target);
    });
  }

  function resolveBlock(block) {
    if (!block) return null;
    var type = String(block.type || "");
    if (type === "a2ui") {
      var comp = String(block.component || "").trim();
      if (comp && get(comp)) return get(comp);
      return null;
    }
    return get("r1:" + type) || null;
  }

  function resolveDescriptor(descriptor) {
    descriptor = descriptor || {};
    var comp = String(descriptor.component || "").trim();
    if (!comp) return null;
    if (get(comp)) return get(comp);
    if (comp.indexOf("r3:") === 0) return get(comp);
    if (OFFICIAL_A2UI_COMPONENTS.indexOf(comp) >= 0) return get("r3:" + comp);
    if (root.PaletteComponentRegistry && PaletteComponentRegistry.resolve) {
      var def = PaletteComponentRegistry.resolve(descriptor);
      if (def && def.componentId) return get(def.componentId) || get(comp);
    }
    return null;
  }

  function cardBlocks(card) {
    card = card || {};
    return (card.blockStore && card.blockStore.blocks) || card.pipelineBlocks || [];
  }

  function describeCard(card) {
    card = card || {};
    var blocks = cardBlocks(card);
    var representations = [];
    var backends = [];
    var components = [];
    var i;
    var entry;

    if (blocks.length) representations.push(REPRESENTATIONS.R1);

    for (i = 0; i < blocks.length; i++) {
      entry = resolveBlock(blocks[i]);
      if (!entry) continue;
      if (representations.indexOf(entry.representation) < 0) {
        representations.push(entry.representation);
      }
      if (entry.backend && backends.indexOf(entry.backend) < 0) backends.push(entry.backend);
      if (entry.fallbackBackend && backends.indexOf(entry.fallbackBackend) < 0) {
        backends.push(entry.fallbackBackend);
      }
      if (blocks[i].type === "a2ui" && blocks[i].component) {
        components.push(String(blocks[i].component));
      } else if (entry.blockType) {
        components.push(String(entry.blockType));
      }
    }

    if (card.officialA2ui) {
      if (representations.indexOf(REPRESENTATIONS.R3) < 0) representations.push(REPRESENTATIONS.R3);
      var surface = get("OfficialSurface");
      if (surface && surface.backend && backends.indexOf(surface.backend) < 0) {
        backends.push(surface.backend);
      }
      backends.push(BACKENDS.R3_OFFICIAL_INTERNAL);
      components.push("OfficialSurface");
    }

    return {
      cardId: String(card.id || ""),
      representations: representations,
      backends: backends,
      components: components,
      official: card.officialA2ui || null
    };
  }

  function renderBlocks(cardId, dom, blocks, options) {
    if (!root.PaletteCardRenderer || !PaletteCardRenderer.renderBlocks) {
      return { ok: false, blocks: blocks || [], reason: "card_renderer_unavailable" };
    }
    return PaletteCardRenderer.renderBlocks(cardId, dom, blocks, options);
  }

  function renderActions(cardId, card, dom, options) {
    if (!root.PaletteCardRenderer || !PaletteCardRenderer.renderActions) {
      return { ok: false, renderer: "none", reason: "card_renderer_unavailable", count: 0 };
    }
    return PaletteCardRenderer.renderActions(cardId, card, dom, options);
  }

  function syncOfficialCard(card, dom, options) {
    if (!root.PaletteOfficialA2UIBridge || !PaletteOfficialA2UIBridge.syncCard) {
      return { ok: false, reason: "official_bridge_unavailable" };
    }
    return PaletteOfficialA2UIBridge.syncCard(card, dom, options);
  }

  function applyOfficialEnvelope(cardId, dom, envelope, options) {
    if (!root.PaletteOfficialA2UIBridge || !PaletteOfficialA2UIBridge.applyEnvelope) {
      return { ok: false, reason: "official_bridge_unavailable" };
    }
    return PaletteOfficialA2UIBridge.applyEnvelope(cardId, dom, envelope, options);
  }

  function clearOfficial(dom) {
    if (!root.PaletteOfficialA2UIBridge || !PaletteOfficialA2UIBridge.clear) return false;
    return PaletteOfficialA2UIBridge.clear(dom);
  }

  function ensureOfficialContainer(dom) {
    if (!root.PaletteOfficialA2UIBridge || !PaletteOfficialA2UIBridge.ensureContainer) return null;
    return PaletteOfficialA2UIBridge.ensureContainer(dom);
  }

  function refreshCard(card, dom, options) {
    options = options || {};
    var actionsResult = renderActions(card && card.id, card, dom, options);
    var officialResult = syncOfficialCard(card, dom, options);
    return {
      actions: actionsResult,
      official: officialResult,
      describe: describeCard(card)
    };
  }

  function resetForTest() {
    entries = {};
    bootstrap();
  }

  root.PaletteRendererRegistry = {
    REPRESENTATIONS: REPRESENTATIONS,
    BACKENDS: BACKENDS,
    OFFICIAL_A2UI_COMPONENTS: OFFICIAL_A2UI_COMPONENTS.slice(),
    R2_NMER_COMPONENTS: R2_NMER_COMPONENTS.slice(),
    registerEntry: registerEntry,
    get: get,
    list: list,
    listByRepresentation: listByRepresentation,
    listByBackend: listByBackend,
    resolveBlock: resolveBlock,
    resolveDescriptor: resolveDescriptor,
    describeCard: describeCard,
    renderBlocks: renderBlocks,
    renderActions: renderActions,
    syncOfficialCard: syncOfficialCard,
    applyOfficialEnvelope: applyOfficialEnvelope,
    clearOfficial: clearOfficial,
    ensureOfficialContainer: ensureOfficialContainer,
    refreshCard: refreshCard,
    _resetForTest: resetForTest
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
