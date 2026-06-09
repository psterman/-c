/**
 * P2 · Go JSONL → CommandPalette StreamClient 契约烟测（无 WebView2）。
 * 验证 ingest 信封经 deliver() 进入 nmerPalette.applyOfficialA2uiEnvelope。
 */
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import vm from "node:vm";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = __dirname;

function read(rel) {
  return fs.readFileSync(path.join(root, rel), "utf8");
}

function loadScript(rel, sandbox) {
  const code = read(rel);
  vm.runInContext(code, sandbox, { filename: rel });
}

const sandbox = {
  console,
  setTimeout,
  clearTimeout,
  setInterval,
  clearInterval,
  CustomEvent: class CustomEvent {
    constructor(type, init) {
      this.type = type;
      this.detail = init && init.detail;
    }
  },
  document: {
    addEventListener() {},
    dispatchEvent() { return true; }
  },
  window: {},
  globalThis: {}
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);

const delivered = [];
sandbox.window.nmerPalette = {
  applyOfficialA2uiEnvelope(envelope) {
    delivered.push(envelope);
    return { ok: true, reason: "mock_accept" };
  },
  setStatus() {}
};

for (const rel of [
  "palette/observability/PaletteA2UIMetrics.js",
  "palette/official/PaletteOfficialA2UIBridge.js",
  "palette/official/PaletteOfficialA2UIStreamClient.js"
]) {
  loadScript(rel, sandbox);
}

const jsonlPath = path.join(root, "..", "apps", "nmer-wails", "poc", "testdata", "a2ui-command-palette.jsonl");
const lines = fs.readFileSync(jsonlPath, "utf8")
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter(Boolean);

const client = sandbox.PaletteOfficialA2UIStreamClient;
if (!client || typeof client.deliver !== "function") {
  console.error("FAIL PaletteOfficialA2UIStreamClient missing");
  process.exit(1);
}

let okCount = 0;
for (const line of lines) {
  const envelope = JSON.parse(line);
  const ok = client.deliver(envelope, false);
  if (ok) okCount += 1;
}

const last = delivered[delivered.length - 1] || {};
const titleMsg = lines.map((l) => JSON.parse(l)).find((m) => {
  const v = m?.message?.updateDataModel?.value;
  return typeof v === "string" && v.indexOf("JSONL") >= 0;
});

let pass = true;
if (delivered.length !== 4) {
  console.error(`FAIL expected 4 delivered envelopes, got ${delivered.length}`);
  pass = false;
}
if (String(last.cardId || "") !== "p2-a2ui-demo") {
  console.error(`FAIL last cardId=${last.cardId}`);
  pass = false;
}
if (!titleMsg) {
  console.error("FAIL jsonl missing final title line");
  pass = false;
}
if (okCount !== 4) {
  console.error(`FAIL deliver ok count=${okCount}`);
  pass = false;
}

if (pass) {
  console.log("PASS p2-cp-stream deliver=4 cardId=p2-a2ui-demo");
  console.log(`PASS final_title=${titleMsg.message.updateDataModel.value}`);
  process.exit(0);
}
process.exit(1);
