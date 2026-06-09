/**
 * 灰度 + A2UI 指标 headless 烟测（无需 WebView2 / SearchDebug）
 * Usage: node html/run-gray-a2ui-smoke.mjs
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
  vm.runInNewContext(fs.readFileSync(path.join(__dirname, name), "utf8"), sandbox, { filename: name });
}

[
  "palette/observability/PaletteA2UIMetrics.js",
  "palette/official/PaletteOfficialA2UIActionLabels.js",
  "palette/official/PaletteOfficialA2UIActionLabels.fixtures.js",
  "palette/official/PaletteOfficialA2UIActionPolicy.js",
  "palette/official/PaletteOfficialA2UIActionPolicy.fixtures.js",
  "palette/official/PaletteOfficialA2UIGray.js",
  "palette/official/PaletteOfficialA2UIGray.fixtures.js",
  "palette/observability/PaletteA2UIMetrics.fixtures.js",
  "palette/official/PaletteOfficialA2UIBridge.js",
  "palette/official/PaletteOfficialA2UIStreamClient.js"
].forEach(loadScript);

let ok = true;
let passed = 0;
let failed = 0;

function pass(name) {
  console.log("PASS " + name);
  passed += 1;
}

function fail(name, err) {
  console.log("FAIL " + name + (err ? " — " + err : ""));
  failed += 1;
  ok = false;
}

const {
  PaletteOfficialA2UIGrayFixtures,
  PaletteOfficialA2UIActionLabelsFixtures,
  PaletteOfficialA2UIActionPolicyFixtures,
  PaletteA2UIMetricsFixtures,
  PaletteOfficialA2UIGray,
  PaletteOfficialA2UIActionLabels,
  PaletteA2UIMetrics,
  PaletteOfficialA2UIStreamClient
} = sandbox;

try {
  PaletteOfficialA2UIGrayFixtures.runGrayRouteContracts();
  pass("gray:route_contracts");
} catch (e) {
  fail("gray:route_contracts", e.message);
}

try {
  PaletteOfficialA2UIActionLabelsFixtures.runActionLabelContracts();
  pass("gray:action_labels");
} catch (e) {
  fail("gray:action_labels", e.message);
}

try {
  PaletteOfficialA2UIActionPolicyFixtures.runActionPolicyContracts();
  pass("gray:action_policy");
} catch (e) {
  fail("gray:action_policy", e.message);
}

const metricsFx = PaletteA2UIMetricsFixtures.runAllA2UIMetricsFixtures();
for (const r of metricsFx.results) {
  if (r.ok) pass("metrics:" + r.fixture);
  else fail("metrics:" + r.fixture, r.error);
}

const cfg = {
  wailsBridge: { enabled: true, healthy: true },
  officialA2ui: { enabled: true, commandWhitelist: ["/search", "/explain", "/compare"] },
  rollback: { forceNmerOnly: false }
};
const decision = PaletteOfficialA2UIGray.resolveSubmit("/search 测试", cfg);
if (decision && decision.route === "r3" && decision.reason === "whitelist_hit") {
  pass("gray:resolve_search_whitelist");
} else {
  fail("gray:resolve_search_whitelist", JSON.stringify(decision));
}

PaletteA2UIMetrics._resetForTest();
PaletteOfficialA2UIGray.applyToCard({ id: "smoke-card", officialA2ui: null }, decision);
const snap = PaletteA2UIMetrics.snapshot();
if (snap.grayByRoute && snap.grayByRoute.r3 === 1 && snap.grayByReason && snap.grayByReason.whitelist_hit === 1) {
  pass("gray:metrics_counters");
} else {
  fail("gray:metrics_counters", JSON.stringify(snap));
}

PaletteA2UIMetrics._resetForTest();
PaletteOfficialA2UIStreamClient.handleWireFrame({
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
const errSnap = PaletteA2UIMetrics.snapshot();
if (errSnap.errorByCode && errSnap.errorByCode.TPA_ENVELOPE_INVALID === 1) {
  pass("metrics:ws_rejected");
} else {
  fail("metrics:ws_rejected", JSON.stringify(errSnap));
}

PaletteA2UIMetrics._resetForTest();
PaletteOfficialA2UIStreamClient.deliverActionResult({
  status: "rejected",
  requestId: "req-smoke-1",
  cardId: "card-smoke",
  errorCode: "ACTION_NOT_ALLOWED",
  error: "not allowed"
});
const actLine = PaletteOfficialA2UIActionLabels.formatActionResult({
  status: "rejected",
  errorCode: "ACTION_NOT_ALLOWED"
});
if (actLine.body.indexOf("ACTION_NOT_ALLOWED") >= 0 && actLine.title.indexOf("拒绝") >= 0) {
  pass("gray:action_result_labels");
} else {
  fail("gray:action_result_labels", JSON.stringify(actLine));
}

console.log("---");
console.log("passed=" + passed + " failed=" + failed + " ok=" + ok);
process.exit(ok ? 0 : 1);
