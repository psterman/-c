/**
 * PaletteA2UITextNormalizer — Markdown heuristics for Steps and Alert.
 */
(function (root) {
  function extractSteps(markdown) {
    var lines = String(markdown || "").split(/\r?\n/);
    var items = [];
    for (var index = 0; index < lines.length; index++) {
      var line = lines[index].trim();
      var match =
        line.match(/^\d+[\.\)、]\s+(.+)$/) ||
        line.match(/^[-*]\s+\[[ xX]\]\s+(.+)$/) ||
        line.match(/^步骤\s*\d+\s*[：:]\s*(.+)$/);
      if (match && match[1]) items.push(String(match[1]).trim());
    }
    return items.slice(0, 20);
  }

  function extractAlerts(markdown) {
    var lines = String(markdown || "").split(/\r?\n/);
    var alerts = [];
    for (var index = 0; index < lines.length; index++) {
      var line = lines[index].trim();
      if (!line) continue;
      var variant = "";
      if (/^(⚠️|⚠|警告|注意|风险提示)/.test(line)) variant = "warning";
      else if (/^(❌|错误|失败|异常)/.test(line)) variant = "error";
      else if (/^(✅|成功|完成)/.test(line)) variant = "success";
      else if (/^(ℹ️|提示|说明)/.test(line)) variant = "info";
      if (!variant) continue;
      alerts.push({
        variant: variant,
        text: line.replace(/^(⚠️|⚠|❌|✅|ℹ️)\s*/, "")
      });
    }
    return alerts.slice(0, 5);
  }

  function matchesCandidate(component, markdown) {
    if (component === "Steps") return extractSteps(markdown).length >= 2;
    if (component === "Alert") return extractAlerts(markdown).length > 0;
    return false;
  }

  root.PaletteA2UITextNormalizer = {
    extractSteps: extractSteps,
    extractAlerts: extractAlerts,
    matchesCandidate: matchesCandidate
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
