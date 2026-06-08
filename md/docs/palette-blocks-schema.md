# Palette Blocks Schema（v1）

Command Palette 动作 Tab 统一块模型。`blockVersion: 1`，变更时 bump 版本。

## 公共字段

| 字段 | 类型 | 说明 |
|------|------|------|
| id | string | 唯一 id，如 `blk_xxx` |
| type | enum | `plan` \| `status` \| `question` \| `reply` \| `a2ui` \| `error` |
| state | enum | `streaming` \| `final` \| `stale` |
| source | enum | `protocol` \| `heuristic` \| `markdown` \| `markdown_table` \| `tool_event` \| `raw` \| `system` |
| confidence | number | 0–1 |
| seq | number | 同卡内排序（主序） |
| turnId | number | 对话轮次 / segment |
| traceId | string | 追踪 id |
| createdAt | number | ms |
| updatedAt | number | ms |

## 类型扩展

### plan

```json
{ "items": [{ "text": "检查 gateway", "state": "pending|running|done|error|interrupted" }] }
```

### status

过程日志；`level: error` 表示步骤失败但任务可继续。

`source: tool_event` 时 items 可带工具元数据（Gateway / Orchestrator 结构化事件）：

```json
{
  "source": "tool_event",
  "items": [{
    "text": "⏳ OpenClaw 正在调用工具 chat.send",
    "level": "info",
    "tool": "chat.send",
    "phase": "start|progress|done|error",
    "ts": 1710000000000
  }]
}
```

普通 status（`source: system`）：

```json
{ "items": [{ "text": "...", "level": "info|warning|error", "time": "10:32" }] }
```

### question

```json
{ "title": "...", "markdown": "...", "status": "waiting|answered|expired|cancelled", "answerTurnId": null }
```

### reply

```json
{ "markdown": "...", "title": "任务回复", "truncated": false, "rawRef": null }
```

### a2ui（白名单 component）

`ComparisonTable` | `Steps` | `Alert`

```json
{ "component": "ComparisonTable", "props": {} }
```

### error

卡片级终止错误（非 status.level=error）。

```json
{ "message": "...", "code": null }
```

## 渲染映射

| type | DOM 槽 |
|------|--------|
| plan | `.card-timeline` |
| status | `.card-status-log` |
| question | `.card-question` |
| reply | `.card-reply` |
| a2ui | `.card-a2ui` |
| error | 卡片错误条 / status-log 红色项 |

## 渲染优先级

```text
validateBlocks(final blocks) → renderBlocks
  > Pipeline.finalize(rawAnswer)
  > rawAnswer 占位 fallback
```

## 组件匹配与路由 profile

`PaletteBlockPipeline.finalize` 在协议归一化后调用 `PaletteComponentMatcher.match`，再由 `PaletteMiniA2UI` 做 Markdown 启发式提取。

### uiCandidates（广义 UI profile）

与 `a2uiCandidates` 并存；读取优先级：`uiCandidates.a2ui` → `a2uiCandidates`。

```json
{
  "uiCandidates": {
    "a2ui": ["ComparisonTable", "Steps", "Alert"],
    "display": { "hideOriginalTable": false },
    "slots": { "wantPlan": true, "wantStatus": true, "wantReply": true }
  },
  "promptAddon": "路由附加 system prompt 片段"
}
```

- `display.hideOriginalTable: false`（默认，Option A）：A2UI 在上，reply markdown 保留原表格
- `display.hideOriginalTable: true`（Option B）：生成 ComparisonTable 后从 reply 剥离原表

### ComparisonTable 裁剪上限

`PaletteBlockSchema.LIMITS` 与 BlockStore 共用：

| 字段 | 上限 |
|------|------|
| 行数 | 20 |
| 列数 | 8 |
| 单元格 | 500 字 |

enrich 阶段由 ComponentMatcher 裁剪；`BlockStore.pack` 持久化时二次兜底。

### Debug meta（finalize）

`PaletteComponentMatcher.match` 经 Pipeline 透传：

```json
{
  "uiMatches": [{ "component": "ComparisonTable", "from": "markdown_table", "matched": true, "clipped": false }],
  "displayPolicy": { "hideOriginalTable": false, "option": "A" },
  "matcher": { "a2uiCandidates": ["ComparisonTable"], "hideOriginalTable": false }
}
```

Debug 事件：`pipeline_matcher`（汇总）、`pipeline_a2ui`（数组）、`preview_source`（`{ source, textPreview }`）。

## 预留：actions[]

未接线执行链，仅 schema 占位。可挂在 reply block 或 card DTO：

```json
{
  "actions": [
    { "id": "follow_up_append", "label": "补充说明", "kind": "safe", "intent": "append", "disabled": false }
  ]
}
```

- `kind: safe` — v1 仅允许预填 follow-up 输入框
- `kind: confirm` — 危险操作预留，v1 不产出

## C.3-alpha 三层模块

```text
PaletteSkillRegistry（声明）
  → PaletteProfileComposer（routeProfile + followUpChips）
  → PalettePromptComposer（promptAddon / preserveRoute）
PaletteActionPolicy（safe 过滤）
  → PaletteActionBinder（FollowUpChips 渲染 + prefill）
```

## FollowUpChips（v1 已接线，prefill only）

- 位置：`.card-followup-chips`（输入框上方）
- 数据来源：`routeProfile.followUpChips`（SkillRegistry 声明）+ `reply.actions[]`（可选）
- 点击行为：仅预填 `.card-followup-input`，用户须手动点「补充」提交
- 策略：`PaletteActionPolicy` 拒绝 `kind: confirm` 与危险文案
- Debug：`followup_chips_render` / `action_clicked` / `action_rejected`
- follow-up append 时 `preserveRoute: true`，保持原 `promptAddon`

`confirm` / ActionBus 仍为后续 Phase，v1 不接线。
