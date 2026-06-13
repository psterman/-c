import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const htmlPath = path.join(path.resolve(__dirname, ".."), "html", "CommandPalette.html");
const lines = fs.readFileSync(htmlPath, "utf8").split(/\r?\n/);

function removeRange(from1, to1) {
  lines.splice(from1 - 1, to1 - from1 + 1);
}

// Remove bottom-up (1-based line numbers from pre-removal file)
removeRange(9306, 10010); // handleHubAgentEvent + handleHostMessage
removeRange(7333, 7499); // actionCardManager
removeRange(7181, 7331); // _renderActionHistoryLock + renderActionHistoryList

const insertAt = 7181 - 1;
const stub = [
  "  var actionCardManager = null;",
  "  function renderActionHistoryList() {",
  "    if (typeof PaletteAgentSummary !== \"undefined\") PaletteAgentSummary.renderActionHistoryList();",
  "  }",
  ""
];
lines.splice(insertAt, 0, ...stub);

const scriptInsert = [
  '<script src="palette/agent/agent-summary.js?v=1"></script>',
  '<script src="palette/agent/agent-detail.js?v=1"></script>',
  '<script src="palette/app/host-bridge.js?v=1"></script>'
];
const cmdResultsIdx = lines.findIndex((l) => l.includes("palette/views/command-results.js"));
if (cmdResultsIdx >= 0) {
  lines.splice(cmdResultsIdx + 1, 0, ...scriptInsert);
}

fs.writeFileSync(htmlPath, lines.join("\n"));
console.log("spliced CommandPalette.html, new line count:", lines.length);
