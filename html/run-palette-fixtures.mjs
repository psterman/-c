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
  "PaletteCardSlots.js",
  "PaletteLitRenderer.js",
  "palette/actions/PaletteActionController.js",
  "palette/actions/PaletteA2UIEventBridge.js",
  "PaletteActionBinder.js",
  "palette/render/PaletteSlotRenderTrace.js",
  "palette/render/PaletteCardRenderer.js",
  "PaletteUIEventBridge.js",
  "PaletteRouterSkill.js",
  "PaletteMiniA2UI.js",
  "PaletteComponentMatcher.js",
  "palette/adapters/PaletteActionChipsAdapter.js",
  "palette/adapters/PaletteActionChipsProdInjector.js",
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
  "PaletteBlockStoreActionChips.fixtures.js"
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

console.log("---");
console.log("passed=" + totalPassed + " failed=" + totalFailed + " ok=" + allOk);
process.exit(allOk ? 0 : 1);
