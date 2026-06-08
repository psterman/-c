/**
 * ActionChips MVP fixture runner（仅 MVP 矩阵）
 * Usage: node html/run-action-chips-mvp.mjs
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
  "PaletteActionPolicy.js",
  "PaletteUIEventContract.js",
  "PaletteCardSlots.js",
  "PaletteLitRenderer.js",
  "palette/actions/PaletteActionController.js",
  "palette/actions/PaletteA2UIEventBridge.js",
  "PaletteActionBinder.js",
  "palette/render/PaletteSlotRenderTrace.js",
  "palette/render/PaletteCardRenderer.js",
  "palette/adapters/PaletteActionChipsAdapter.js",
  "palette/test/PaletteActionChipsTestHelpers.js",
  "PaletteActionChipsMvp.fixtures.js"
].forEach(loadScript);

const { PaletteActionChipsMvpFixtures } = sandbox;
if (!PaletteActionChipsMvpFixtures || !PaletteActionChipsMvpFixtures.runAllMvpFixtures) {
  console.error("PaletteActionChipsMvpFixtures unavailable");
  process.exit(1);
}

const summary = PaletteActionChipsMvpFixtures.runAllMvpFixtures();
let lastCategory = "";
for (const r of summary.results) {
  if (r.category !== lastCategory) {
    console.log("--- " + (r.category || "misc") + " ---");
    lastCategory = r.category;
  }
  const tag = r.ok ? "PASS" : "FAIL";
  const err = r.error || "";
  console.log(tag + " mvp:" + r.fixture + (err ? " — " + err : ""));
}

console.log("---");
console.log("mvp passed=" + summary.passed + " failed=" + summary.failed + " ok=" + summary.ok);
process.exit(summary.ok ? 0 : 1);
