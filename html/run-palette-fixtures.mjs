/**
 * Headless Palette fixture runner (pipeline + BlockStore + C.3; no DOM).
 * Usage: node html/run-palette-fixtures.mjs
 */
import vm from "vm";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const sandbox = { console };
sandbox.globalThis = sandbox;
sandbox.window = sandbox;
sandbox.__stId = 0;
sandbox.__stQueue = [];
sandbox.setTimeout = function (fn, delay) {
  if (typeof fn !== "function") return 0;
  const id = ++sandbox.__stId;
  if (!delay) {
    fn();
    return id;
  }
  sandbox.__stQueue.push({ id, fn, delay });
  return id;
};
sandbox.clearTimeout = function (id) {
  sandbox.__stQueue = sandbox.__stQueue.filter((t) => t.id !== id);
};

function loadScript(name) {
  const code = fs.readFileSync(path.join(__dirname, name), "utf8");
  vm.runInNewContext(code, sandbox, { filename: name });
}

[
  "PaletteBlockSchema.js",
  "PaletteSkillRegistry.js",
  "PaletteProfileComposer.js",
  "PalettePromptComposer.js",
  "PaletteActionPolicy.js",
  "PaletteUIEventContract.js",
  "palette/render/PaletteComponentRegistry.js",
  "PaletteCardSlots.js",
  "PaletteLitRenderer.js",
  "palette/actions/PaletteActionController.js",
  "palette/actions/PaletteA2UIEventBridge.js",
  "PaletteActionBinder.js",
  "palette/render/PaletteSlotRenderTrace.js",
  "palette/render/PaletteA2UILegacyRenderer.js",
  "palette/render/PaletteCardRenderer.js",
  "palette/theme/PaletteA2UIDesignTokens.js",
  "palette/official/PaletteOfficialA2UIBridge.js",
  "palette/render/PaletteRendererRegistry.js",
  "palette/observability/PaletteA2UIMetrics.js",
  "palette/official/PaletteOfficialA2UIActionLabels.js",
  "palette/official/PaletteOfficialA2UIActionPolicy.js",
  "palette/official/PaletteOfficialA2UIGray.js",
  "palette/official/PaletteOfficialA2UIStreamClient.js",
  "PaletteUIEventBridge.js",
  "PaletteRouterSkill.js",
  "palette/normalizers/PaletteComparisonTableMarkdown.js",
  "palette/normalizers/PaletteA2UITextNormalizer.js",
  "PaletteMiniA2UI.js",
  "PaletteComponentMatcher.js",
  "palette/adapters/PaletteA2UIAdapter.js",
  "palette/adapters/PaletteActionChipsAdapter.js",
  "palette/adapters/PaletteActionChipsProdInjector.js",
  "CommandPaletteStreamParser.js",
  "PaletteBlockPipeline.js",
  "PaletteBlockStore.js",
  "PaletteBlockPipeline.fixtures.js",
  "PaletteC3.fixtures.js",
  "PaletteActionChips.fixtures.js",
  "PaletteActionController.fixtures.js",
  "PaletteActionChipsLit.fixtures.js",
  "PaletteBlockRenderTrace.fixtures.js",
  "palette/test/PaletteActionChipsTestHelpers.js",
  "PaletteActionChipsMvp.fixtures.js",
  "PaletteActionBoundary.fixtures.js",
  "PaletteActionChipsProd.fixtures.js",
  "PaletteActionChipsDedupe.fixtures.js",
  "PaletteBlockStoreActionChips.fixtures.js",
  "PaletteA2UIContract.fixtures.js",
  "PaletteOfficialA2UI.fixtures.js",
  "palette/official/PaletteOfficialA2UIGray.fixtures.js",
  "palette/official/PaletteOfficialA2UIActionLabels.fixtures.js",
  "palette/official/PaletteOfficialA2UIActionPolicy.fixtures.js",
  "palette/theme/PaletteA2UIDesignTokens.fixtures.js",
  "palette/render/PaletteRendererRegistry.fixtures.js",
  "palette/observability/PaletteA2UIMetrics.fixtures.js",
  "palette/app/perf-marks.js",
  "palette/search/command-index.js",
  "palette/app/query-controller.js",
  "palette/views/result-list.js",
  "palette/app/palette-layout.js",
  "palette/app/stream-batcher.js",
  "palette/app/agent-chunk-coalescer.js",
  "palette/test/command-index.fixtures.js",
  "palette/test/stream-batcher.fixtures.js"
].forEach(loadScript);

let allOk = true;
let totalPassed = 0;
let totalFailed = 0;

const { PaletteBlockFixtures } = sandbox;
if (!PaletteBlockFixtures || !PaletteBlockFixtures.runAllPaletteFixtures) {
  console.error("PaletteBlockFixtures unavailable");
  process.exit(1);
}

const summary = PaletteBlockFixtures.runAllPaletteFixtures();
for (const r of summary.results) {
  const tag = r.ok && (!r.assert || r.assert.pass) ? "PASS" : "FAIL";
  const err =
    r.error ||
    (r.assertErrors && r.assertErrors.join(",")) ||
    (r.assert && r.assert.errors && r.assert.errors.join(",")) ||
    "";
  console.log(tag + " " + r.fixture + (err ? " — " + err : ""));
}
totalPassed += summary.passed;
totalFailed += summary.failed;
if (!summary.ok) allOk = false;

console.log("--- C.3 ---");

const { PaletteC3Fixtures } = sandbox;
if (PaletteC3Fixtures && PaletteC3Fixtures.runAllC3Fixtures) {
  const c3 = PaletteC3Fixtures.runAllC3Fixtures();
  for (const r of c3.results) {
    const tag = r.ok && (!r.assert || r.assert.pass) ? "PASS" : "FAIL";
    const err =
      r.error || (r.assert && r.assert.errors && r.assert.errors.join(",")) || "";
    console.log(tag + " c3:" + r.fixture + (err ? " — " + err : ""));
  }
  totalPassed += c3.passed;
  totalFailed += c3.failed;
  if (!c3.ok) allOk = false;
} else {
  console.error("PaletteC3Fixtures unavailable");
  allOk = false;
}

console.log("--- ActionChips ---");

const { PaletteActionChipsFixtures } = sandbox;
if (PaletteActionChipsFixtures && PaletteActionChipsFixtures.runAllActionChipsFixtures) {
  const ac = PaletteActionChipsFixtures.runAllActionChipsFixtures();
  for (const r of ac.results) {
    const tag = r.ok ? "PASS" : "FAIL";
    const err = r.error || "";
    console.log(tag + " ac:" + r.fixture + (err ? " — " + err : ""));
  }
  totalPassed += ac.passed;
  totalFailed += ac.failed;
  if (!ac.ok) allOk = false;
} else {
  console.error("PaletteActionChipsFixtures unavailable");
  allOk = false;
}

console.log("--- ActionController ---");

const { PaletteActionControllerFixtures } = sandbox;
if (PaletteActionControllerFixtures && PaletteActionControllerFixtures.runAllControllerFixtures) {
  const ctrl = PaletteActionControllerFixtures.runAllControllerFixtures();
  for (const r of ctrl.results) {
    const tag = r.ok ? "PASS" : "FAIL";
    const err = r.error || "";
    console.log(tag + " ctrl:" + r.fixture + (err ? " — " + err : ""));
  }
  totalPassed += ctrl.passed;
  totalFailed += ctrl.failed;
  if (!ctrl.ok) allOk = false;
} else {
  console.error("PaletteActionControllerFixtures unavailable");
  allOk = false;
}

console.log("--- ActionChips Lit ---");

const { PaletteActionChipsLitFixtures } = sandbox;
if (PaletteActionChipsLitFixtures && PaletteActionChipsLitFixtures.runAllLitFixtures) {
  const lit = PaletteActionChipsLitFixtures.runAllLitFixtures();
  for (const r of lit.results) {
    const tag = r.ok ? "PASS" : "FAIL";
    const err = r.error || "";
    console.log(tag + " lit:" + r.fixture + (err ? " — " + err : ""));
  }
  totalPassed += lit.passed;
  totalFailed += lit.failed;
  if (!lit.ok) allOk = false;
} else {
  console.error("PaletteActionChipsLitFixtures unavailable");
  allOk = false;
}

console.log("--- Block Render Trace ---");

const { PaletteBlockRenderTraceFixtures } = sandbox;
if (PaletteBlockRenderTraceFixtures && PaletteBlockRenderTraceFixtures.runAllTraceFixtures) {
  const tr = PaletteBlockRenderTraceFixtures.runAllTraceFixtures();
  for (const r of tr.results) {
    const tag = r.ok ? "PASS" : "FAIL";
    const err = r.error || "";
    console.log(tag + " trace:" + r.fixture + (err ? " — " + err : ""));
  }
  totalPassed += tr.passed;
  totalFailed += tr.failed;
  if (!tr.ok) allOk = false;
} else {
  console.error("PaletteBlockRenderTraceFixtures unavailable");
  allOk = false;
}

console.log("--- Action Boundary ---");

const { PaletteActionBoundaryFixtures } = sandbox;
if (PaletteActionBoundaryFixtures && PaletteActionBoundaryFixtures.runAllBoundaryFixtures) {
  const bd = PaletteActionBoundaryFixtures.runAllBoundaryFixtures();
  for (const r of bd.results) {
    const tag = r.ok ? "PASS" : "FAIL";
    const err = r.error || "";
    console.log(tag + " bd:" + r.fixture + (err ? " — " + err : ""));
  }
  totalPassed += bd.passed;
  totalFailed += bd.failed;
  if (!bd.ok) allOk = false;
} else {
  console.error("PaletteActionBoundaryFixtures unavailable");
  allOk = false;
}

console.log("--- ActionChips MVP ---");

const { PaletteActionChipsMvpFixtures } = sandbox;
if (PaletteActionChipsMvpFixtures && PaletteActionChipsMvpFixtures.runAllMvpFixtures) {
  const mvp = PaletteActionChipsMvpFixtures.runAllMvpFixtures();
  for (const r of mvp.results) {
    const tag = r.ok ? "PASS" : "FAIL";
    const err = r.error || "";
    console.log(tag + " mvp:" + r.fixture + (err ? " — " + err : ""));
  }
  totalPassed += mvp.passed;
  totalFailed += mvp.failed;
  if (!mvp.ok) allOk = false;
} else {
  console.error("PaletteActionChipsMvpFixtures unavailable");
  allOk = false;
}

console.log("--- ActionChips Prod ---");

const { PaletteActionChipsProdFixtures } = sandbox;
if (PaletteActionChipsProdFixtures && PaletteActionChipsProdFixtures.runAllProdFixtures) {
  const prod = PaletteActionChipsProdFixtures.runAllProdFixtures();
  for (const r of prod.results) {
    const tag = r.ok ? "PASS" : "FAIL";
    const err = r.error || "";
    console.log(tag + " prod:" + r.fixture + (err ? " — " + err : ""));
  }
  totalPassed += prod.passed;
  totalFailed += prod.failed;
  if (!prod.ok) allOk = false;
} else {
  console.error("PaletteActionChipsProdFixtures unavailable");
  allOk = false;
}

console.log("--- ActionChips Dedupe ---");

const { PaletteActionChipsDedupeFixtures } = sandbox;
if (PaletteActionChipsDedupeFixtures && PaletteActionChipsDedupeFixtures.runAllDedupeFixtures) {
  const dedupe = PaletteActionChipsDedupeFixtures.runAllDedupeFixtures();
  for (const r of dedupe.results) {
    const tag = r.ok ? "PASS" : "FAIL";
    const err = r.error || "";
    console.log(tag + " dedupe:" + r.fixture + (err ? " — " + err : ""));
  }
  totalPassed += dedupe.passed;
  totalFailed += dedupe.failed;
  if (!dedupe.ok) allOk = false;
} else {
  console.error("PaletteActionChipsDedupeFixtures unavailable");
  allOk = false;
}

console.log("--- BlockStore ActionChips ---");

const { PaletteBlockStoreActionChipsFixtures } = sandbox;
if (PaletteBlockStoreActionChipsFixtures && PaletteBlockStoreActionChipsFixtures.runAllStoreFixtures) {
  const store = PaletteBlockStoreActionChipsFixtures.runAllStoreFixtures();
  for (const r of store.results) {
    const tag = r.ok ? "PASS" : "FAIL";
    const err = r.error || "";
    console.log(tag + " store:" + r.fixture + (err ? " — " + err : ""));
  }
  totalPassed += store.passed;
  totalFailed += store.failed;
  if (!store.ok) allOk = false;
} else {
  console.error("PaletteBlockStoreActionChipsFixtures unavailable");
  allOk = false;
}

console.log("--- A2UI Contract ---");

const { PaletteA2UIContractFixtures } = sandbox;
if (PaletteA2UIContractFixtures && PaletteA2UIContractFixtures.runAllContractFixtures) {
  const contract = PaletteA2UIContractFixtures.runAllContractFixtures();
  for (const r of contract.results) {
    const tag = r.ok ? "PASS" : "FAIL";
    const err = r.error || (r.errors && r.errors.join(",")) || "";
    console.log(tag + " contract:" + r.fixture + (err && !r.ok ? " — " + err : ""));
  }
  totalPassed += contract.passed;
  totalFailed += contract.failed;
  if (!contract.ok) allOk = false;
} else {
  console.error("PaletteA2UIContractFixtures unavailable");
  allOk = false;
}

console.log("--- Official A2UI P1 ---");

const { PaletteOfficialA2UIFixtures } = sandbox;
if (PaletteOfficialA2UIFixtures && PaletteOfficialA2UIFixtures.runAllOfficialA2UIFixtures) {
  const official = PaletteOfficialA2UIFixtures.runAllOfficialA2UIFixtures();
  for (const r of official.results) {
    const tag = r.ok ? "PASS" : "FAIL";
    console.log(tag + " official:" + r.fixture + (r.error ? " — " + r.error : ""));
  }
  totalPassed += official.passed;
  totalFailed += official.failed;
  if (!official.ok) allOk = false;
} else {
  console.error("PaletteOfficialA2UIFixtures unavailable");
  allOk = false;
}

console.log("--- Renderer Registry ---");

const { PaletteRendererRegistryFixtures } = sandbox;
if (
  PaletteRendererRegistryFixtures &&
  PaletteRendererRegistryFixtures.runAllRendererRegistryFixtures
) {
  const registryFx = PaletteRendererRegistryFixtures.runAllRendererRegistryFixtures();
  for (const r of registryFx.results) {
    const tag = r.ok ? "PASS" : "FAIL";
    console.log(tag + " registry:" + r.fixture + (r.error ? " — " + r.error : ""));
  }
  totalPassed += registryFx.passed;
  totalFailed += registryFx.failed;
  if (!registryFx.ok) allOk = false;
} else {
  console.error("PaletteRendererRegistryFixtures unavailable");
  allOk = false;
}

console.log("--- A2UI Metrics ---");

const { PaletteA2UIMetricsFixtures } = sandbox;
if (PaletteA2UIMetricsFixtures && PaletteA2UIMetricsFixtures.runAllA2UIMetricsFixtures) {
  const metricsFx = PaletteA2UIMetricsFixtures.runAllA2UIMetricsFixtures();
  for (const r of metricsFx.results) {
    const tag = r.ok ? "PASS" : "FAIL";
    console.log(tag + " metrics:" + r.fixture + (r.error ? " — " + r.error : ""));
  }
  totalPassed += metricsFx.passed;
  totalFailed += metricsFx.failed;
  if (!metricsFx.ok) allOk = false;
} else {
  console.error("PaletteA2UIMetricsFixtures unavailable");
  allOk = false;
}

const streamClient = sandbox.PaletteOfficialA2UIStreamClient;
if (streamClient && streamClient.handleWireFrame && sandbox.PaletteA2UIMetrics) {
  sandbox.PaletteA2UIMetrics._resetForTest();
  streamClient.handleWireFrame({
    type: "official_a2ui_rejected",
    reason: "bad envelope",
    error: {
      schemaVersion: "nmer.a2ui.error.v1",
      code: "TPA_ENVELOPE_INVALID",
      message: "bad envelope",
      layer: "transport",
      retryable: false
    }
  });
  const snap = sandbox.PaletteA2UIMetrics.snapshot();
  if (snap.errorByCode.TPA_ENVELOPE_INVALID === 1) {
    console.log("PASS metrics:ws_rejected_wire");
    totalPassed += 1;
  } else {
    console.log("FAIL metrics:ws_rejected_wire");
    totalFailed += 1;
    allOk = false;
  }
} else {
  console.error("StreamClient metrics wire test unavailable");
  allOk = false;
  totalFailed += 1;
}

console.log("--- A2UI Design Tokens ---");

const { PaletteA2UIDesignTokensFixtures } = sandbox;
if (
  PaletteA2UIDesignTokensFixtures &&
  PaletteA2UIDesignTokensFixtures.runAllDesignTokenFixtures
) {
  const tokens = PaletteA2UIDesignTokensFixtures.runAllDesignTokenFixtures();
  for (const r of tokens.results) {
    const tag = r.ok ? "PASS" : "FAIL";
    console.log(tag + " tokens:" + r.fixture + (r.error ? " — " + r.error : ""));
  }
  totalPassed += tokens.passed;
  totalFailed += tokens.failed;
  if (!tokens.ok) allOk = false;
} else {
  console.error("PaletteA2UIDesignTokensFixtures unavailable");
  allOk = false;
}

console.log("--- Official A2UI Gray ---");

const { PaletteOfficialA2UIGrayFixtures } = sandbox;
if (PaletteOfficialA2UIGrayFixtures && PaletteOfficialA2UIGrayFixtures.runGrayRouteContracts) {
  try {
    PaletteOfficialA2UIGrayFixtures.runGrayRouteContracts();
    console.log("PASS gray:gray_route_contracts");
    totalPassed += 1;
  } catch (e) {
    console.log("FAIL gray:gray_route_contracts — " + (e && e.message ? e.message : e));
    totalFailed += 1;
    allOk = false;
  }
} else {
  console.error("PaletteOfficialA2UIGrayFixtures unavailable");
  allOk = false;
}

const { PaletteOfficialA2UIActionLabelsFixtures } = sandbox;
if (PaletteOfficialA2UIActionLabelsFixtures && PaletteOfficialA2UIActionLabelsFixtures.runActionLabelContracts) {
  try {
    PaletteOfficialA2UIActionLabelsFixtures.runActionLabelContracts();
    console.log("PASS gray:action_label_contracts");
    totalPassed += 1;
  } catch (e) {
    console.log("FAIL gray:action_label_contracts — " + (e && e.message ? e.message : e));
    totalFailed += 1;
    allOk = false;
  }
} else {
  console.error("PaletteOfficialA2UIActionLabelsFixtures unavailable");
  allOk = false;
}

const { PaletteOfficialA2UIActionPolicyFixtures } = sandbox;
if (PaletteOfficialA2UIActionPolicyFixtures && PaletteOfficialA2UIActionPolicyFixtures.runActionPolicyContracts) {
  try {
    PaletteOfficialA2UIActionPolicyFixtures.runActionPolicyContracts();
    console.log("PASS gray:action_policy_contracts");
    totalPassed += 1;
  } catch (e) {
    console.log("FAIL gray:action_policy_contracts — " + (e && e.message ? e.message : e));
    totalFailed += 1;
    allOk = false;
  }
} else {
  console.error("PaletteOfficialA2UIActionPolicyFixtures unavailable");
  allOk = false;
}

console.log("--- StreamBatcher ---");
const { PaletteStreamBatcherFixtures } = sandbox;
if (PaletteStreamBatcherFixtures && PaletteStreamBatcherFixtures.run) {
  try {
    PaletteStreamBatcherFixtures.run();
    console.log("PASS stream-batcher:coalescer");
    totalPassed += 1;
  } catch (e) {
    console.log("FAIL stream-batcher:coalescer — " + (e && e.message ? e.message : e));
    totalFailed += 1;
    allOk = false;
  }
} else {
  console.error("PaletteStreamBatcherFixtures unavailable");
  allOk = false;
}

console.log("--- CommandIndex ---");
const { PaletteCommandIndexFixtures } = sandbox;
if (PaletteCommandIndexFixtures && PaletteCommandIndexFixtures.run) {
  try {
    PaletteCommandIndexFixtures.run();
    console.log("PASS command-index:search_generation");
    totalPassed += 1;
  } catch (e) {
    console.log("FAIL command-index:search_generation — " + (e && e.message ? e.message : e));
    totalFailed += 1;
    allOk = false;
  }
} else {
  console.error("PaletteCommandIndexFixtures unavailable");
  allOk = false;
}

console.log("---");
console.log("passed=" + totalPassed + " failed=" + totalFailed + " ok=" + allOk);
process.exit(allOk ? 0 : 1);
