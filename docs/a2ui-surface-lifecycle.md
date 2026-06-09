# A2UI Surface 生命周期

R3 官方 Surface 的创建、替换、终结与重放规则。代码分两层子票（Wave 1.2）。

---

## 1. 幂等键

| 操作 | 键 | 说明 |
|------|-----|------|
| 信封排序 | `(cardId, surfaceId, seq)` | `seq` 单调递增，权威序 |
| Surface 替换 | 同 `surfaceId` 新 `createSurface` | 覆盖同卡同 surface 渲染 |
| 卡级隔离 | `cardId` | 禁止跨卡复用 `surfaceId` 状态 |

---

## 2. 状态机

```text
(none) --createSurface--> active
active --updateComponents*--> active
active --updateDataModel--> active
active --deleteSurface/final--> cleared
```

`final: true` 信封：标记流结束；Ledger 在窗口后裁剪（Go buffer 128，CP 客户端约 20 卡）。

---

## 3. 代码落点

| 子票 | 层 | 文件 | 职责 |
|------|-----|------|------|
| **1.2a** | L1 replay | [`wshub.go`](../apps/nmer-wails/poc/wshub.go) | `a2uiReplaySnapshot`、`validateA2UISequence`、`handleA2UIIngest` |
| **1.2b** | L2 投递 | [`openclaw_adapter.go`](../apps/nmer-wails/poc/openclaw_adapter.go) | Adapter 产出 JSONL 顺序；`final` 收尾 |

前端：[`PaletteOfficialA2UIStreamClient.js`](../html/palette/official/PaletteOfficialA2UIStreamClient.js) `resetStreamState`；[`PaletteOfficialA2UIBridge.js`](../html/palette/official/PaletteOfficialA2UIBridge.js) fallback。

---

## 4. replay 规则

- WS 重连：Hub 重放最近 `a2uiReplayBufferSize`（128）条 envelope
- 客户端按 `seq` 去重；`TPA_SEQ_STALE` 拒收乱序
- `ts` 仅日志，不参与排序

---

## 5. 测试

- Go：`a2ui_test.go`（ingest、malformed、replay）
- Wave 1 补强：`openclaw_adapter_test.go` session 冲突
- Fixtures：`PaletteOfficialA2UI*.fixtures.js`

---

## 变更记录

| 日期 | 说明 |
|------|------|
| 2026-06-08 | Wave 1.2 初稿 |
