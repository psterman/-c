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
  "PaletteActionBinder.js",
  "PaletteUIEventBridge.js",
  "PaletteRouterSkill.js",
  "PaletteMiniA2UI.js",
  "PaletteComponentMatcher.js",
  "PaletteBlockPipeline.js",
  "PaletteBlockStore.js",
  "PaletteBlockPipeline.fixtures.js",
  "PaletteC3.fixtures.js"
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

console.log("---");
console.log("passed=" + totalPassed + " failed=" + totalFailed + " ok=" + allOk);
process.exit(allOk ? 0 : 1);
