/**
 * PaletteSkillRegistry — 声明层：skill / profile / followUpChips 单一注册源
 */
(function (root) {
  var SKILLS = [
    {
      id: "research_compare",
      label: "研究对比",
      weight: 90,
      match: function (q) {
        if (/vs\.?|对比|比较|相较|哪个好|优缺点|差异/i.test(q)) return true;
        if (/小米|meta|苹果|华为|google|microsoft/i.test(q) && /(和|与|vs|对比|比较)/i.test(q))
          return true;
        return false;
      },
      profile: {
        promptAddon:
          "【路由：研究对比】用户在做对比分析。REPLY 中优先给出结构化对比（表格或分点）；若内容适合表格，请用 Markdown 表格呈现关键维度。不必冗长 STATUS。",
        a2uiCandidates: ["ComparisonTable"],
        uiCandidates: {
          a2ui: ["ComparisonTable"],
          display: { hideOriginalTable: false },
          slots: { wantPlan: false, wantStatus: true, wantReply: true, wantQuestion: false }
        },
        uiHints: { wantPlan: false, wantStatus: true, wantReply: true, wantQuestion: false },
        followUpChips: [
          {
            id: "compare_dim",
            label: "补充对比维度",
            kind: "safe",
            intent: "append",
            prefill: "请补充更多对比维度："
          },
          {
            id: "compare_shorten",
            label: "缩短结论",
            kind: "safe",
            intent: "append",
            prefill: "请用更简洁的方式总结对比结论："
          }
        ]
      }
    },
    {
      id: "execute_task",
      label: "执行任务",
      weight: 80,
      match: function (q) {
        return /重启|启动|停止|安装|卸载|配置|执行|打开|关闭|运行|部署|升级|gateway|服务/i.test(q);
      },
      profile: {
        promptAddon:
          "【路由：执行任务】用户在要求执行具体操作。必须先输出 PLAN；执行过程用 STATUS 记录；遇权限/风险阻断时用 QUESTION；完成后 REPLY 复盘。",
        a2uiCandidates: ["Steps", "Alert"],
        uiCandidates: {
          a2ui: ["Steps", "Alert"],
          display: { hideOriginalTable: false },
          slots: { wantPlan: true, wantStatus: true, wantReply: true, wantQuestion: true }
        },
        uiHints: { wantPlan: true, wantStatus: true, wantReply: true, wantQuestion: true },
        followUpChips: []
      }
    },
    {
      id: "debug_diagnose",
      label: "排查诊断",
      weight: 75,
      match: function (q) {
        return /排查|诊断|报错|错误|失败|异常|bug|fix|为什么.*不|无法|不能|挂了|崩溃/i.test(q);
      },
      profile: {
        promptAddon:
          "【路由：排查诊断】用户在排查故障。PLAN 列出排查步骤；STATUS 记录每一步发现；结论写在 REPLY。日志要具体。",
        a2uiCandidates: ["Alert", "Steps"],
        uiCandidates: {
          a2ui: ["Alert", "Steps"],
          display: { hideOriginalTable: false },
          slots: { wantPlan: true, wantStatus: true, wantReply: true, wantQuestion: false }
        },
        uiHints: { wantPlan: true, wantStatus: true, wantReply: true, wantQuestion: false },
        followUpChips: [
          {
            id: "diag_more_log",
            label: "补充排查线索",
            kind: "safe",
            intent: "append",
            prefill: "补充更多排查线索或日志上下文："
          }
        ]
      }
    },
    {
      id: "qa_explain",
      label: "问答解释",
      weight: 60,
      match: function (q) {
        return /什么是|是什么|为什么|怎么理解|解释一下|介绍一下|讲讲|原理|含义/i.test(q);
      },
      profile: {
        promptAddon:
          "【路由：问答解释】用户在提问或要解释。重点输出 REPLY，内容清晰完整；非必要不要堆砌 STATUS。",
        a2uiCandidates: [],
        uiCandidates: {
          a2ui: [],
          display: { hideOriginalTable: false },
          slots: { wantPlan: false, wantStatus: false, wantReply: true, wantQuestion: false }
        },
        uiHints: { wantPlan: false, wantStatus: false, wantReply: true, wantQuestion: false },
        followUpChips: [
          {
            id: "explain_example",
            label: "换个例子",
            kind: "safe",
            intent: "append",
            prefill: "请换一个更通俗的例子说明："
          },
          {
            id: "explain_shorten",
            label: "缩短解释",
            kind: "safe",
            intent: "append",
            prefill: "请用更简短的方式解释："
          }
        ]
      }
    },
    {
      id: "general",
      label: "通用",
      weight: 0,
      match: function () {
        return true;
      },
      profile: {
        promptAddon: "",
        a2uiCandidates: ["ComparisonTable", "Steps", "Alert"],
        uiCandidates: {
          a2ui: ["ComparisonTable", "Steps", "Alert"],
          display: { hideOriginalTable: false },
          slots: { wantPlan: true, wantStatus: true, wantReply: true, wantQuestion: true }
        },
        uiHints: { wantPlan: true, wantStatus: true, wantReply: true, wantQuestion: true },
        followUpChips: [
          {
            id: "general_append",
            label: "补充说明",
            kind: "safe",
            intent: "append",
            prefill: "请补充说明："
          }
        ]
      }
    }
  ];

  var SKILL_MAP = {};
  for (var i = 0; i < SKILLS.length; i++) {
    SKILL_MAP[SKILLS[i].id] = SKILLS[i];
  }

  function normalizeQuery(text) {
    return String(text || "")
      .replace(/\s+/g, " ")
      .trim();
  }

  function getSkill(id) {
    return SKILL_MAP[id] || null;
  }

  function listSkills() {
    return SKILLS.slice();
  }

  function matchSkill(query, options) {
    options = options || {};
    var q = normalizeQuery(query);
    if (!q) return { skill: getSkill("general"), confidence: 0, reason: "empty_query" };
    if (options.forceRouteId && getSkill(options.forceRouteId)) {
      return { skill: getSkill(options.forceRouteId), confidence: 1, reason: "forced" };
    }
    var best = null;
    var bestScore = 0;
    var reason = "default";
    for (var si = 0; si < SKILLS.length; si++) {
      var sk = SKILLS[si];
      if (sk.id === "general") continue;
      try {
        if (sk.match(q)) {
          var score = sk.weight;
          if (score > bestScore) {
            bestScore = score;
            best = sk;
            reason = "rule:" + sk.id;
          }
        }
      } catch (_) {}
    }
    if (!best) best = getSkill("general");
    var confidence = best && best.id !== "general" ? Math.min(0.95, 0.55 + bestScore / 200) : 0.35;
    return { skill: best, confidence: confidence, reason: reason };
  }

  function toLegacyProfiles() {
    var out = {};
    for (var pi = 0; pi < SKILLS.length; pi++) {
      var s = SKILLS[pi];
      out[s.id] = Object.assign({ id: s.id, label: s.label }, s.profile);
    }
    return out;
  }

  root.PaletteSkillRegistry = {
    SKILLS: SKILLS,
    getSkill: getSkill,
    listSkills: listSkills,
    matchSkill: matchSkill,
    toLegacyProfiles: toLegacyProfiles,
    normalizeQuery: normalizeQuery
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
