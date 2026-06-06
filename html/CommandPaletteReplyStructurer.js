/**
 * Command Palette 动作 Tab — 无协议标签时的启发式块拆分（A.2 兜底）
 */
(function (root) {
  var PROTO_TAG = /::(PLAN|STATUS|QUESTION|REPLY)_(START|END)::/;

  function hasProtocolTags(text) {
    return PROTO_TAG.test(String(text || ""));
  }

  function structurePlainAgentReply(text) {
    var raw = String(text || "").trim();
    if (!raw || hasProtocolTags(raw)) return [];

    var lines = raw.split(/\r?\n/);
    var planSteps = [];
    var statusLines = [];
    var questionLines = [];
    var replyLines = [];
    var mode = "reply";
    var i;
    var line;
    var trimmed;

    for (i = 0; i < lines.length; i++) {
      line = lines[i];
      trimmed = line.trim();
      if (!trimmed) {
        if (mode === "reply") replyLines.push("");
        else if (mode === "status") statusLines.push("");
        else if (mode === "question") questionLines.push("");
        continue;
      }
      if (/^#{1,3}\s*(计划|步骤|PLAN)\b/i.test(trimmed)) {
        mode = "plan";
        continue;
      }
      if (/^步骤\s*\d+[:：]/i.test(trimmed)) {
        mode = "plan";
        planSteps.push(trimmed.replace(/^步骤\s*\d+[:：]\s*/i, "").trim());
        continue;
      }
      if (/^\d+[.)]\s+\S/.test(trimmed) && mode === "plan") {
        planSteps.push(trimmed.replace(/^\d+[.)]\s+/, "").trim());
        continue;
      }
      if (/^#{1,3}\s*(执行|状态|进度|STATUS)\b/i.test(trimmed) || /^\[(执行|工具|Agent)\]/i.test(trimmed)) {
        mode = "status";
        if (/^\[(执行|工具|Agent)\]/i.test(trimmed)) statusLines.push(line);
        continue;
      }
      if (/^#{1,3}\s*(确认|问题|QUESTION)\b/i.test(trimmed) || /^(要继续吗|是否|请确认|需要您)/.test(trimmed)) {
        mode = "question";
        questionLines.push(line);
        continue;
      }
      if (/^#{1,3}\s*(回复|结果|REPLY|总结)\b/i.test(trimmed)) {
        mode = "reply";
        continue;
      }
      if (mode === "plan") planSteps.push(trimmed);
      else if (mode === "status") statusLines.push(line);
      else if (mode === "question") questionLines.push(line);
      else replyLines.push(line);
    }

    var blocks = [];
    var seq = 0;
    if (planSteps.length >= 2) {
      seq += 1;
      blocks.push({
        type: "plan",
        closed: true,
        seq: seq,
        steps: planSteps,
        body: planSteps
          .map(function (s, idx) {
            return "步骤" + (idx + 1) + "：" + s;
          })
          .join(" | "),
        title: "执行计划",
        content: "",
        parseWarn: "heuristic_plan"
      });
    }
    if (statusLines.length) {
      seq += 1;
      blocks.push({
        type: "status",
        closed: true,
        seq: seq,
        title: "[执行中]",
        log: statusLines.join("\n"),
        body: statusLines.join("\n"),
        content: statusLines.join("\n"),
        parseWarn: "heuristic_status"
      });
    }
    if (questionLines.length) {
      seq += 1;
      blocks.push({
        type: "question",
        closed: true,
        seq: seq,
        title: "需要您的确认",
        content: questionLines.join("\n"),
        body: questionLines.join("\n"),
        parseWarn: "heuristic_question"
      });
    }
    var replyBody = replyLines.join("\n").trim() || raw;
    seq += 1;
    blocks.push({
      type: "reply",
      closed: true,
      seq: seq,
      title: "任务回复",
      content: replyBody,
      body: replyBody,
      parseWarn: blocks.length > 1 ? "heuristic_reply" : "heuristic_only"
    });
    return blocks;
  }

  root.CommandPaletteReplyStructurer = {
    hasProtocolTags: hasProtocolTags,
    structurePlainAgentReply: structurePlainAgentReply
  };
})(typeof globalThis !== "undefined" ? globalThis : typeof window !== "undefined" ? window : this);
