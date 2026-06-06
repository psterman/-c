/**
 * PaletteRouterSkill — 任务路由 + UI profile + promptAddon
 */
(function (root) {
  var PROFILES = {
    research_compare: {
      id: "research_compare",
      label: "研究对比",
      promptAddon:
        "【路由：研究对比】用户在做对比分析。REPLY 中优先给出结构化对比（表格或分点）；若内容适合表格，请用 Markdown 表格呈现关键维度。不必冗长 STATUS。",
      a2uiCandidates: ["ComparisonTable"],
      uiHints: { wantPlan: false, wantStatus: true, wantReply: true, wantQuestion: false }
    },
    execute_task: {
      id: "execute_task",
      label: "执行任务",
      promptAddon:
        "【路由：执行任务】用户在要求执行具体操作。必须先输出 PLAN；执行过程用 STATUS 记录；遇权限/风险阻断时用 QUESTION；完成后 REPLY 复盘。",
      a2uiCandidates: ["Steps", "Alert"],
      uiHints: { wantPlan: true, wantStatus: true, wantReply: true, wantQuestion: true }
    },
    qa_explain: {
      id: "qa_explain",
      label: "问答解释",
      promptAddon:
        "【路由：问答解释】用户在提问或要解释。重点输出 REPLY，内容清晰完整；非必要不要堆砌 STATUS。",
      a2uiCandidates: [],
      uiHints: { wantPlan: false, wantStatus: false, wantReply: true, wantQuestion: false }
    },
    debug_diagnose: {
      id: "debug_diagnose",
      label: "排查诊断",
      promptAddon:
        "【路由：排查诊断】用户在排查故障。PLAN 列出排查步骤；STATUS 记录每一步发现；结论写在 REPLY。日志要具体。",
      a2uiCandidates: ["Alert", "Steps"],
      uiHints: { wantPlan: true, wantStatus: true, wantReply: true, wantQuestion: false }
    },
    general: {
      id: "general",
      label: "通用",
      promptAddon: "",
      a2uiCandidates: ["ComparisonTable", "Steps", "Alert"],
      uiHints: { wantPlan: true, wantStatus: true, wantReply: true, wantQuestion: true }
    }
  };

  var RULES = [
    {
      id: "research_compare",
      weight: 90,
      test: function (q) {
        if (/vs\.?|对比|比较|相较|哪个好|优缺点|差异/i.test(q)) return true;
        if (/小米|meta|苹果|华为|google|microsoft/i.test(q) && /(和|与|vs|对比|比较)/i.test(q)) return true;
        return false;
      }
    },
    {
      id: "execute_task",
      weight: 80,
      test: function (q) {
        return /重启|启动|停止|安装|卸载|配置|执行|打开|关闭|运行|部署|升级|gateway|服务/i.test(q);
      }
    },
    {
      id: "debug_diagnose",
      weight: 75,
      test: function (q) {
        return /排查|诊断|报错|错误|失败|异常|bug|fix|为什么.*不|无法|不能|挂了|崩溃/i.test(q);
      }
    },
    {
      id: "qa_explain",
      weight: 60,
      test: function (q) {
        return /什么是|是什么|为什么|怎么理解|解释一下|介绍一下|讲讲|原理|含义/i.test(q);
      }
    }
  ];

  function normalizeQuery(text) {
    return String(text || "")
      .replace(/\s+/g, " ")
      .trim();
  }

  function route(query, options) {
    options = options || {};
    var q = normalizeQuery(query);
    if (!q) {
      return buildResult(PROFILES.general, 0, "empty_query");
    }
    if (options.forceRouteId && PROFILES[options.forceRouteId]) {
      return buildResult(PROFILES[options.forceRouteId], 1, "forced");
    }
    var best = null;
    var bestScore = 0;
    var reason = "default";
    for (var i = 0; i < RULES.length; i++) {
      var rule = RULES[i];
      try {
        if (rule.test(q)) {
          var score = rule.weight;
          if (score > bestScore) {
            bestScore = score;
            best = rule.id;
            reason = "rule:" + rule.id;
          }
        }
      } catch (_) {}
    }
    var profile = PROFILES[best || "general"] || PROFILES.general;
    var confidence = best ? Math.min(0.95, 0.55 + bestScore / 200) : 0.35;
    return buildResult(profile, confidence, reason);
  }

  function buildResult(profile, confidence, reason) {
    profile = profile || PROFILES.general;
    return {
      routeId: profile.id,
      label: profile.label,
      profile: profile.id,
      promptAddon: profile.promptAddon || "",
      a2uiCandidates: (profile.a2uiCandidates || []).slice(),
      uiHints: Object.assign({}, profile.uiHints || {}),
      confidence: confidence,
      reason: reason || "default"
    };
  }

  function buildSystemPrompt(baseProtocol, routeResult) {
    var base = String(baseProtocol || "").trim();
    var addon = routeResult && routeResult.promptAddon ? String(routeResult.promptAddon).trim() : "";
    if (!addon) return base;
    if (!base) return addon;
    return base + "\n\n" + addon;
  }

  root.PaletteRouterSkill = {
    PROFILES: PROFILES,
    route: route,
    buildSystemPrompt: buildSystemPrompt
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
