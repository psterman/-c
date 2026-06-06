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
