# A2UI 灰度切流宪法

R3 官方 A2UI 生产灰度的**切流、回退、观测与决策**唯一对照文档。

相关：[architecture v2](./a2ui-architecture-v2.md) · [错误码 v1](./nmer-a2ui-error-v1.md) · [rollout TODO](./a2ui-rollout-todo.md) · [fixtures 审计](./fixtures-count-history.md)

---

## 1. 拓扑

| 轨 | 默认 | 灰度开启后 |
|----|------|------------|
| R1 协议块 | **开** | 开 |
| R2 NMER 组件 | **开** | 开 |
| R3 官方 A2UI | **关** | 仅 `commandWhitelist` 命中 + bridge 健康 |

配置：`local/nmer-flags.json`（不进 Git，模板见 [`env.example`](../env.example)）。

---

## 2. 显式开关（二维）

| 维度 | 字段 | 默认 |
|------|------|------|
| D1 进程/通道 | `wailsBridge.enabled` | `true` |
| D1 官方 Surface | `officialA2ui.enabled` | **`false`** |
| D1 白名单 | `officialA2ui.commandWhitelist` | `[]` |
| 强制回退 | `rollback.forceNmerOnly` | `false` |
| D2 Agent 传输 | `paletteAgent.transport` | `ftb`（adapter 见 Wave 1 ADP-2） |

### routeMode 派生标签（baseline 快照用）

| routeMode | 条件 |
|-----------|------|
| `force_nmer_only` | `rollback.forceNmerOnly=true` |
| `r1r2_only` | `officialA2ui.enabled=false`（Wave 0 预期） |
| `r3_gray` | `officialA2ui.enabled=true` 且未 force |

采集：`tools/a2ui-diagnostics/capture-gray-flags-snapshot.ps1` → `Cache/debug/gray_flags_baseline.json`。

---

## 3. 回退决策树

```text
forceNmerOnly=true
  → 禁止一切 R3（优先于 official.enabled）

officialA2ui.enabled=false
  → 不挂载 official WS；R1/R2 不受影响

wailsBridge 不健康 / sidecar down
  → resolveSubmit → r1r2，reason=bridge_not_healthy
  → 生产仍走 FTB OpenClaw 四标签

malformed JSONL / 组件越权
  → WS reject + nmer.a2ui.error.v1
  → 卡片 fallback 文案；保留 R1 reply / R2 blocks

stale seq (TPA_SEQ_STALE)
  → 拒收；客户端重连 + replay

R3 Surface 渲染失败
  → 级联：R1 markdown + R2 a2ui + fallback 条（不白屏）
```

### 演练清单（architecture v2 §5.4）

| ID | 场景 | 预期 |
|----|------|------|
| R1 | 杀侧车进程（`sidecarHost=hub` → `nmer-hub`；否则 `nmer-wails`） | R1/R2 正常；R3 降级；`:18791` health 不可达 |
| R2 | `forceNmerOnly=true` | 无 official WS；fixtures 全绿 |
| R3 | malformed JSONL | fallback + 旧 reply 可见 |
| R4 | OpenClaw 断连 | 明确错误；可 recover |
| R5 | B3 回滚 | `CommandPaletteUseWebView` 恢复 |

自动化：`scripts/Run-A2uiRollbackDrill.ps1`（Wave 1 交付）。

---

## 4. OpenClaw sessionRef 命名空间约定

> **ADP-0 已结案（2026-06-08）**：Gateway `sessionKey` 为 **free-form** 字符串；详见 [`openclaw-ws-contract.md`](./openclaw-ws-contract.md)。

| 路径 | sessionRef 模式 | 适用范围 |
|------|-----------------|----------|
| FTB 生产 | `agent:main:niuma-cp-{cardId}` | 默认；OC-7 已验收 |
| Adapter 灰度（候选） | `agent:main:niuma-adp-{cardId}` | **仅新卡**；前缀以 ADP-0 抓包结论为准 |

**硬规则（ADP-2）：**

1. adapter **仅新卡**；旧卡追问永远 `transport=ftb`。
2. 首次 dispatch 写死 `card.meta.transportLocked`，禁止中途 FTB↔adapter 切换。
3. 禁止跨卡复用 `sessionRef`（对齐 OC-7）。

调研交付：`docs/openclaw-ws-contract.md`（Wave 1 FTB-2 + ADP-0）。

---

## 5. 指标落点

| 指标 | 埋点 | 读取 |
|------|------|------|
| 灰度路由 | `PaletteOfficialA2UIGray.js` | `a2ui_gray_route_total{route,reason}` |
| WS 拒收 | `wshub.go` / Bridge | `a2ui_error_total{code}` |
| fallback | `PaletteOfficialA2UIBridge.js` | `a2ui_fallback_total{hint}` |
| Action 结果 | StreamClient / Go | `a2ui_action_result_total{status}` |
| 协议闭合 | `PaletteBlockPipeline` | `protocolClosure` on card meta |

Debug UI：`CommandPaletteSearchDebug.html`。日检快照：`Cache/debug/a2ui_action_result_daily.json`（Wave 2）。

---

## 6. Wave 4 量化决策阈值

基线取自 Wave 0 归档（`a2ui-rollout-baseline-*.md` + `Cache/debug/*`）。

| 指标 | 扩大灰度 | 维持 | 回滚 |
|------|----------|------|------|
| OC-5 闭合率 | ≥ 基线 × **0.95** | 基线 × **0.85–0.95** | < 基线 × **0.85** |
| fallback 率 | ≤ 基线 × **1.1** 连续 **3 天** | ≤ 基线 × **1.3** | > 基线 × **1.3** 连续 **1 天** |
| Action accepted 滞留率（30s 无终态） | < **2%** | **2–5%**（调查） | > **5%** 连续 **6h** |
| Action timeout 率 | < 基线 × **1.1** | 基线 × **1.1–1.3** | > 基线 × **1.3** 连续 **1 天** |
| 单卡内存 delta | ≤ Wave0 `deltaPerCard` × **1.15** | × **1.15–1.3** | > × **1.3** 或 7 日单调涨 |
| routeMode 快照 | 与决策意图一致 | — | 与记录不符 |

---

## 7. B3 启动条件（不在本轮执行）

须**同时**满足：

1. Wave 2 灰度 **连续 14 天** 上表均为「扩大」或「维持」
2. Wave 3 `ProviderCapability` 框架就位
3. FTB-1：`runPaletteAgentStreamOnce` 迁入 `palette-agent-bridge.js`
4. Wave 4 决策日单独立项评审 B3

---

## 变更记录

| 日期 | 说明 |
|------|------|
| 2026-06-08 | Wave 0 初稿：切流宪法 + sessionRef 占位 + 量化阈值 |
