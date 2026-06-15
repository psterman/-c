# PR 架构纪律 — 禁止双写

> 对应问题 **#4**：Go SurfaceStore 与 TS `MessageProcessor` 不得并行持有 UI 状态。本文是 **流程约束**，不要求本周改历史代码。

## 铁律

1. **R3 A2UI 卡片状态**以 TS `MessageProcessor` + BlockStore 为唯一真相源。
2. **Go Hub** 只做传输、鉴权、广播、replay 快照；**不得**新增「第二份 Surface 状态机」。
3. 新功能若需持久化，先问：属于 **命令面板会话**、**设置 INI/JSON**，还是 **SearchCore**？不要默认塞进 Hub。

## PR 自检（改以下路径时必填）

| 若你改了… | 必须确认 |
|-----------|----------|
| `apps/nmer-wails/poc/*.go`（Hub） | 未新增/未扩展「按 cardId 存 UI 字段」的 Map |
| `html/palette/**` MessageProcessor | 未把应由 Go 持有的状态复制到 Go |
| `html/command-palette/**` A2UI 渲染 | fixtures 仍绿：`node html/run-palette-fixtures.mjs` |
| 新增 WebView ↔ AHK 消息 type | 与现有 `ConfigWebViewModule` 分支不重复造协议 |

## 禁止模式（review 直接打回）

- Go 里 `surfaceState[cardId] = ...` 且 TS 里也有同字段可写
- 「先写 Go 再 sync 到 TS」或反向的双向同步
- 为赶进度在 Hub 加临时字段，注释「TODO 以后删」

## 允许模式

- Go 转发 `WireMessage` / `A2UIReplay`（只读回放）
- TS 单写 + `NMER_Log` / metrics 记录异常
- AHK 持久化 INI/JSON（设置、UserStudio），与 A2UI 会话隔离

## 验收命令

```powershell
node html/run-palette-fixtures.mjs
powershell tools/ci/Validate-WsPolicy.ps1
```

## 相关文档

- [nmer-conventions.md](nmer-conventions.md)
- [ci-minimal-gate.md](ci-minimal-gate.md)
