# A2UI Rollout TODO

本文把当前 A2UI 改造整理为一份按优先级和时间顺序执行的 TODO。

目标不是“一次性做完所有 A2UI”，而是先把 R3 官方 A2UI 安全接入生产灰度，同时保证 R1/R2 随时可回退。

## P0 先决条件

### Day 0

- [x] 跑 `OC-5 L3` 本机探针基线（`OC5_PASS`；见 [`a2ui-rollout-l3-20260609.md`](./a2ui-rollout-l3-20260609.md)）
- [x] 记录当前 `protocolClosure`、reply 闭合率、fallback 基线 → [`a2ui-rollout-baseline-20260608.md`](./a2ui-rollout-baseline-20260608.md)
- [x] 确认 fixtures 全绿（**155/155**，见 [`fixtures-count-history.md`](./fixtures-count-history.md)）
- [x] 固化一份“改造前”内存基线（空载已采；多卡档位待补）

验收：

- `OC-5 L3` 结果有记录
- 当前生产链路没有新增回归
- 有一份可比较的 baseline 数据

### Day 0.5

- [x] 定稿灰度切流策略文档 → [`a2ui-gray-cutover-policy.md`](./a2ui-gray-cutover-policy.md)
- [x] 定义切流拓扑：`R1/R2` 默认，`R3` 灰度
- [x] 定义灰度粒度：本机、白名单（provider/采样 Wave 3+）
- [x] 定义回退决策树：`sidecar down / malformed / unsupported / stale seq`
- [x] 定义指标清单：成功率、fallback 率、超时率、内存峰值、闭合率 + 量化决策阈值
- [x] 给指标落埋点位置
- [x] OpenClaw `sessionRef` 命名空间约定（ADP-0）→ [`openclaw-ws-contract.md`](./openclaw-ws-contract.md)

验收：

- 有一份“切流宪法”
- 后续开发都能对照这份文档实施

## P1 生产接入最小闭环

### Day 1

- [x] 落地 `OpenClaw Adapter`（[`openclaw_adapter.go`](../apps/nmer-wails/poc/openclaw_adapter.go) + WS；CP 派发已接；实网烟测：[`Run-OpenClawAdapterSmoke.ps1`](../scripts/Run-OpenClawAdapterSmoke.ps1)）
- [x] 同步定稿多 Surface 生命周期契约 → [`a2ui-surface-lifecycle.md`](./a2ui-surface-lifecycle.md)
- [x] 规定新 surface 替换旧 surface 的幂等规则 → 同上 §1.2
- [x] 规定 `final` 后清理规则 → 同上 §1.3
- [x] 规定 replay 按 `seq` 重建规则 → 同上 §1.2a + Go `a2uiReplaySnapshot`
- [x] 错误码 v1 接入 Go validate / ActionPolicy / WS reject（`errorCode` 回执 + `a2ui_error_test`）
- [x] 增加 `R1` 杀 sidecar 回退演练脚本 → [`Run-A2uiRollbackDrill.ps1`](../scripts/Run-A2uiRollbackDrill.ps1)
- [x] 增加 `R2` `forceNmerOnly=true` 回退演练脚本 → 同上

验收：

- OpenClaw 可以通过 Adapter 投递 R3
- 生命周期规则写清并跑通
- 回退脚本可以稳定复现降级

### Day 1.5

- [x] 完成 Action 权限模型（Go `A2UIActionPolicy` + JS `PaletteOfficialA2UIActionPolicy`）
- [x] 扩展动作白名单规则（`safe.follow-up`；客户端预检 + 服务端校验）
- [x] 补跨 `surface` / 跨 `cardId` 约束（`RegisterSurface` + `SEM_ACTION_CONTEXT_MISMATCH`）
- [x] 明确取消、超时、重复请求的策略（Go dedup/abort/timeout + 文案 `ActionLabels`）
- [x] 统一 Action 错误码与回执状态（`errorCode` + `errorDetail` 双轨）

验收：

- 不安全 Action 无法穿透
- 合法 Action 的状态可预测

## P2 灰度落地

### Day 2

- [x] 落地灰度开关（`PaletteOfficialA2UIGray` + `NmerWailsBridge`）
- [x] 落地 `commandWhitelist`
- [x] 前端展示错误码和 Action 状态（`PaletteOfficialA2UIActionLabels` + `PaletteOfficialA2UICardNotify`）
- [x] 明确 `accepted / completed / rejected / timeout / cancelled` 展示文案
- [x] 验证 `officialA2ui.enabled` 与 `rollback.forceNmerOnly` 互斥逻辑（fixtures + `isOfficialGloballyEnabled`）

验收：

- 可以只对指定命令开启 R3
- 回退和状态展示都可见

### Day 2 - Day 3

- [ ] 做 `7x24` 灰度观察（脚本：[`Run-A2uiDailyObservation.ps1`](../tools/a2ui-diagnostics/Run-A2uiDailyObservation.ps1)；Wave4 准备：[`a2ui-rollout-wave4-prep-20260609.md`](./a2ui-rollout-wave4-prep-20260609.md)）
- [ ] 观察 fallback 率（`a2ui_observation_history.jsonl` + SearchDebug metrics）
- [ ] 观察 Action 超时率（同上）
- [ ] 观察 WebView2 私有内存（`capture-memory-baseline.ps1 -CardCount 1/5/20`）
- [ ] 观察 surface 泄漏
- [ ] 对比 `OC-5 L3` 基线

验收：

- 指标稳定
- 没有持续内存爬升
- 没有静默降级失控

## P3 Provider 扩展

### Day 3

- [x] 设计 `ProviderCapability` 框架 → [`a2ui-provider-capability.md`](./a2ui-provider-capability.md)
- [x] 区分 `fake / http adapter / openai-compatible`
- [x] 明确 provider 能力声明：stream、action、abort、R3（R1/R2 仍走 FTB）

验收：

- Provider 不再只是 mode 字符串
- 新 provider 可以按能力接入

### Day 3.5

- [x] 深化 Hermes 适配（mock 契约 + `ProviderCapability.experimental`）
- [ ] 验证 `openai-chat` provider 在 Hermes 上的稳定性（脚本：[`Run-HermesProviderLive.ps1`](../scripts/Run-HermesProviderLive.ps1)）
- [x] 补 Hermes 异常流测试：prose、非法 JSONL、组件越权、围栏 JSONL → `Run-HermesProviderContract.ps1`

说明：

- Hermes 是第三方 / OpenAI-compatible 实验 provider
- Hermes 不等于 OpenClaw Adapter

验收：

- Hermes 路径可稳定实验
- 不影响 OpenClaw 主生产链

## Day 4 决策点

- [ ] 评估是否扩大灰度范围（脚本：[`Run-A2uiDay4Decision.ps1`](../tools/a2ui-diagnostics/Run-A2uiDay4Decision.ps1)）
- [ ] 评估是否继续停留在 `B` 粒度
- [ ] 评估是否进入更大规模 R3 接入
- [x] L3 探针汇总脚本 → [`Run-A2uiL3ProbeSummary.ps1`](../scripts/Run-A2uiL3ProbeSummary.ps1)

决策依据：

- fallback 率
- timeout 率
- 内存峰值
- surface 泄漏
- 闭合率是否低于基线

## 并行项

这些项可以穿插做，但不应打断主链路：

- [x] Replay / reconnect 压测 → [`Run-A2uiWsReplayStress.ps1`](../scripts/Run-A2uiWsReplayStress.ps1) + `TestA2UIWebSocketReplayOnReconnect`
- [ ] 官方 Surface 视觉和 design tokens 收口
- [ ] 文档对齐：README、spike guide、architecture v2

## 暂时不要做

- [ ] 不把 R1/R2 fixtures 全量翻写成官方 A2UI
- [ ] 不把 Go 变成 SurfaceStore
- [ ] 不默认全量打开 `officialA2ui.enabled`
- [ ] 不把 `18789` 当 OpenAI HTTP 直接接入
- [ ] 不在这个阶段扩大量官方组件
- [ ] 不推动“全项目单 WebView”叙事

## 当前定义

- `OpenClaw Adapter`：生产目标适配层，把 OpenClaw 产物转成 `nmer.a2ui.transport.v1`
- `Hermes Provider`：实验 provider，走 OpenAI-compatible `/chat/completions`
- `R1`：协议块
- `R2`：NMER 组件块
- `R3`：官方 A2UI

## 完成标准

这一轮不是“官方 A2UI 全面替代旧系统”，而是达到下面这条线：

- [x] R3 可灰度接入（flags + 白名单 + Adapter 链；待本机 L3 探针）
- [x] R1/R2 可随时回退（回退演练脚本已绿）
- [x] 指标可观测（Metrics + 日检 + Evaluate）
- [x] 错误可定位（errorCode + 卡片状态行）
- [ ] 内存无持续恶化
- [x] OpenClaw 生产链不被实验 provider 干扰（默认 `fake` + `openai-chat` 标 experimental + 隔离单测）
