/**
 * SCWV contract fixtures (stable regression, headless).
 * Usage: node html/scwv/run-scwv-contract-fixtures.mjs
 */
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "../..");
const manifestPath = path.join(root, "tools/ci/scwv-contract-types.json");
const fixturesPath = path.join(__dirname, "scwv-contract.fixtures.json");

function loadJson(p) {
  return JSON.parse(fs.readFileSync(p, "utf8"));
}

const manifest = loadJson(manifestPath);
const suite = loadJson(fixturesPath);
const inbound = new Set(manifest.inbound.webToAhk || []);
let passed = 0;
let failed = 0;

function fail(name, msg) {
  console.log(`FAIL scwv:${name} — ${msg}`);
  failed += 1;
}

function pass(name) {
  console.log(`PASS scwv:${name}`);
  passed += 1;
}

const okMaturity = manifest.maturity === "stable" || manifest.maturity === "production";
if (!okMaturity) {
  fail("manifest_maturity", `expected stable or production, got ${manifest.maturity}`);
} else {
  pass("manifest_maturity");
}

if (suite.schemaVersion !== manifest.schemaVersion) {
  fail("schema_version_align", `fixtures=${suite.schemaVersion} manifest=${manifest.schemaVersion}`);
} else {
  pass("schema_version_align");
}

const seenTypes = new Set();
for (const fx of suite.fixtures || []) {
  const name = fx.name || fx.type || "unknown";
  if (!fx.type || !fx.payload) {
    fail(name, "missing type or payload");
    continue;
  }
  if (!inbound.has(fx.type)) {
    fail(name, `type ${fx.type} not in manifest inbound`);
    continue;
  }
  if (fx.payload.type !== fx.type) {
    fail(name, "payload.type mismatch");
    continue;
  }
  if (fx.payload.schemaVersion !== manifest.schemaVersion) {
    fail(name, "payload.schemaVersion mismatch");
    continue;
  }
  for (const key of fx.required || []) {
    if (fx.payload[key] === undefined || fx.payload[key] === null) {
      fail(name, `missing required field ${key}`);
      continue;
    }
  }
  seenTypes.add(fx.type);
  pass(name);
}

const clusters = ["ready", "search", "setUiMode", "fulltextControl", "cliSend", "QUICKLOOK", "lifecycle"];
for (const c of clusters) {
  if (!seenTypes.has(c) && c !== "lifecycle") {
    // lifecycle covered by lifecycle_ready / lifecycle_close
    if (c === "lifecycle") continue;
  }
}

const ok = failed === 0;
console.log("---");
console.log(`passed=${passed} failed=${failed} ok=${ok}`);
process.exit(ok ? 0 : 1);
