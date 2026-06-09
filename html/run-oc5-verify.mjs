/**
 * OC-5 本机验证 L1：无头引擎 + protocol fixtures
 * Usage: node html/run-oc5-verify.mjs
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
  "CommandPaletteStreamParser.js",
  "PaletteBlockSchema.js",
  "PaletteBlockPipeline.js",
  "PaletteBlockPipeline.fixtures.js"
].forEach(loadScript);

const { PaletteBlockPipeline, PaletteBlockFixtures } = sandbox;
if (!PaletteBlockPipeline || !PaletteBlockFixtures) {
  console.error("OC5_L1 FAIL: pipeline/fixtures unavailable");
  process.exit(1);
}

let ok = true;
const lines = [];

function check(label, pass, detail) {
  const tag = pass ? "PASS" : "FAIL";
  lines.push(`${tag} ${label}${detail ? " — " + detail : ""}`);
  if (!pass) ok = false;
}

const truncated =
  "::PLAN_START:: 步骤1：检查内存 | 步骤2：分析 ::STATUS_START:: 进行中";
const closure = PaletteBlockPipeline.analyzeProtocolClosure(truncated);
check(
  "analyzeProtocolClosure detects unclosed",
  closure && closure.ok === false && closure.missingEnds && closure.missingEnds.length > 0,
  closure ? `code=${closure.code} missing=${(closure.missingEnds || []).join(",")}` : "null"
);

const fin = PaletteBlockPipeline.finalize(truncated, { traceId: "oc5_l1_" + Date.now() });
const repairReply = (fin.blocks || []).find(
  (b) => b && b.type === "reply" && /协议未完整闭合/.test(String(b.markdown || ""))
);
check(
  "finalize synthesizes repair reply",
  !!(repairReply && fin.meta && fin.meta.protocolClosure && fin.meta.protocolClosure.synthesizedReply),
  repairReply ? `blocks=${(fin.blocks || []).map((b) => b.type).join(",")}` : "no repair reply"
);

const replyOnly = "::REPLY_START:: 任务完结\n早上好！ ::REPLY_END::";
const fin2 = PaletteBlockPipeline.finalize(replyOnly, { traceId: "oc5_l1_reply" });
check(
  "reply-only protocol stays OK",
  !!(fin2.meta && fin2.meta.protocolClosure && fin2.meta.protocolClosure.ok === true),
  fin2.meta && fin2.meta.protocolClosure ? `code=${fin2.meta.protocolClosure.code}` : "no closure"
);

for (const name of ["protocol_truncated_plan", "protocol_reply_only", "stream_protocol_truncated"]) {
  const out = PaletteBlockFixtures.runPalettePipelineFixture(name, "oc5-" + name);
  const pass = out.ok && (!out.assert || out.assert.pass);
  check(`fixture:${name}`, pass, out.error || (out.assert && out.assert.errors && out.assert.errors.join(",")) || "");
}

for (const line of lines) console.log(line);
console.log("---");
console.log(ok ? "OC5_L1 ok=true" : "OC5_L1 ok=false");
process.exit(ok ? 0 : 1);
