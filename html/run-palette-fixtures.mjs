/**
 * Headless Palette fixture runner (pipeline + BlockStore; no DOM).
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
  "PaletteMiniA2UI.js",
  "PaletteBlockPipeline.js",
  "PaletteBlockStore.js",
  "PaletteBlockPipeline.fixtures.js"
].forEach(loadScript);

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
console.log("---");
console.log("passed=" + summary.passed + " failed=" + summary.failed + " ok=" + summary.ok);
process.exit(summary.ok ? 0 : 1);
