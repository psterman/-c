/**
 * FTB-2 sessionKey 单测（headless）
 * Usage: node html/run-openclaw-session-keys.mjs
 */
import vm from "vm";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const sandbox = { console };
sandbox.globalThis = sandbox;
sandbox.window = sandbox;
vm.runInNewContext(
  fs.readFileSync(path.join(__dirname, "ftb/palette/openclaw-session-keys.js"), "utf8"),
  sandbox,
  { filename: "openclaw-session-keys.js" }
);

const K = sandbox.NmerOpenClawSessionKeys;
let ok = true;
function assert(name, cond) {
  if (cond) console.log("PASS " + name);
  else {
    console.log("FAIL " + name);
    ok = false;
  }
}

const cp = K.paletteSessionKeyForCard("card_123_456", "niuma-cp");
const adp = K.paletteSessionKeyForCard("card_123_456", "niuma-adp");
assert("canonical main", K.ocCanonicalSessionKey("main") === "agent:main:main");
assert("cp key prefix", K.isPaletteCpSessionKey(cp));
assert("adp key prefix", K.isPaletteAdapterSessionKey(adp));
assert("cp adp differ", cp !== adp);
assert("slug stable", K.cardIdSlug("card_AB-12") === "AB-12");

console.log(ok ? "OPENCLAW_SESSION_KEYS ok=true" : "OPENCLAW_SESSION_KEYS ok=false");
process.exit(ok ? 0 : 1);
