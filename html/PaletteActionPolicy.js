/**
 * PaletteActionPolicy — 动作策略层：safe actions / chips 过滤
 */
(function (root) {
  var DANGER_PATTERN = /重启|部署|删除|写文件|gateway|执行|安装|卸载|停止服务|格式化/i;

  function sanitizeList(actions) {
    if (root.PaletteBlockSchema && PaletteBlockSchema.sanitizeActions)
      return PaletteBlockSchema.sanitizeActions(actions);
    return Array.isArray(actions) ? actions : [];
  }

  function isDangerousText(text) {
    return DANGER_PATTERN.test(String(text || ""));
  }

  function evaluateChip(chip, context) {
    context = context || {};
    chip = chip || {};
    if (String(chip.kind || "safe") === "confirm") {
      return { allowed: false, reason: "confirm_not_wired", chip: chip };
    }
    if (chip.disabled) return { allowed: false, reason: "disabled", chip: chip };
    if (String(chip.kind || "safe") !== "safe") {
      return { allowed: false, reason: "kind_not_safe", chip: chip };
    }
    var label = String(chip.label || "");
    var prefill = String(chip.prefill || chip.label || "");
    if (isDangerousText(label) || isDangerousText(prefill)) {
      return { allowed: false, reason: "dangerous_text", chip: chip };
    }
    if (!label.trim()) return { allowed: false, reason: "missing_label", chip: chip };
    return { allowed: true, reason: "ok", chip: chip };
  }

  function filterSafeActions(actions, context) {
    context = context || {};
    var list = sanitizeList(actions);
    var out = [];
    var logFn = context.debugLog;
    for (var i = 0; i < list.length; i++) {
      var ev = evaluateChip(list[i], context);
      if (ev.allowed) out.push(ev.chip);
      else if (logFn) {
        try {
          logFn(
            "action_rejected",
            JSON.stringify({
              id: list[i].id || "",
              reason: ev.reason,
              label: list[i].label || ""
            })
          );
        } catch (_) {}
      }
    }
    return out;
  }

  root.PaletteActionPolicy = {
    DANGER_PATTERN: DANGER_PATTERN,
    evaluateChip: evaluateChip,
    filterSafeActions: filterSafeActions,
    isDangerousText: isDangerousText
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
