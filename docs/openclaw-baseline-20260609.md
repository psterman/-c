# OpenClaw 基线验收（2026-06-09）

手工 + 自动化探测记录。对应 [`ftb-module-map.md`](./ftb-module-map.md) §8。

**环境：** Windows 10 · 牛马 AHK 运行中 · `nmer-wails.exe` sidecar（B2）· Hub `127.0.0.1:18791` 健康

---

## P2 · 生产 CommandPalette 联调（优先）

| 层 | 检查项 | 结果 | 证据 |
|----|--------|------|------|
| L1 传输 | Hub `/agent/health` | **PASS** | `200 {"ok":true}` |
| L1 传输 | `live_exe_integration.go` | **PASS** | `LIVE_INTEGRATION ok=true`（WS hello、ingest 200、4×official_a2ui_event、malformed 400、action accepted+completed） |
| L1 传输 | `curl` ingest JSONL | **PASS** | `Run-P2CpIntegration.ps1` → HTTP 200 |
| L2 JS 契约 | `html/run-p2-cp-stream.mjs` | **PASS** | `deliver=4 cardId=p2-a2ui-demo final_title=P2 · JSONL 流转发完成` |
| L3 WebView2 | CP 内 `p2-a2ui-demo` 卡可视化 | **待你本机确认** | 打开 Command Palette → 重跑 `scripts/Run-P2CpIntegration.ps1` → 应出现官方 A2UI 区，标题含「JSONL 流转发完成」 |
| L3 探针 | `CommandPalette_ProbeP2OfficialA2ui()` | **待 CP 打开后执行** | 预期 `code=P2_PASS`，`wsState=open` |

**自动化结论：** `P2_AUTOMATION ok=true`（L1+L2 已绿）

**手工一步（WebView2）：**

```powershell
# 1. 打开 Command Palette（动作模式）
# 2. 执行：
powershell -ExecutionPolicy Bypass -File scripts/Run-P2CpIntegration.ps1
# 3. 在 AHK 调试或即时窗口执行：
#    CommandPalette_ProbeP2OfficialA2ui()
```

---

## OC-1 ~ OC-7 基线表

| ID | 检查项 | 结果 | 说明 / 证据 |
|----|--------|------|-------------|
| **OC-1** | `g_FTB_WV2_FrameReady` | **PASS（推断）** | 历史卡 `agent_cards.json` 有多条 OpenClaw 成功任务（如 `card_1078937_6165`、`card_3579250_8894`）；派发日志有 `dispatch_scheduled` 且无 `BRIDGE_FTB_NOT_READY` |
| **OC-2** | Gateway Token | **PASS（推断）** | 同上卡片的 `sessionRef` 均为 `agent:main:niuma-cp-*`，说明 Gateway 建连成功 |
| **OC-3** | `runPaletteAgentStream` | **PASS（推断）** | `cmdpal_agent_wire.log` 有连续 `dispatch_scheduled`；卡片的 `streamDispatched` 路径曾跑通 |
| **OC-4** | chunk 到达 CP | **PASS** | 卡 `card_1078937_6165` / `card_3579250_8894` 的 `blockStore.blocks` 含 `type=status` 流式日志（20+ 条 `⏳ OpenClaw 处理中…`）；`rawAnswer` 非空卡 ≥10 张 |
| **OC-5** | 四标签闭合率 | **加固 PASS（fixtures）** | **闭合样本：** `card_3579250_8894` — 四标签完整<br>**截断修复：** `PaletteBlockPipeline.finalize` 检测 `SEM_PROTOCOL_TAG_UNCLOSED` → 合成 `protocol_repair` reply；`card.protocolClosure` 持久化至 AHK<br>**fixtures：** `protocol_truncated_plan` / `stream_protocol_truncated` / `protocol_reply_only`（131/131 PASS） |
| **OC-6** | finalize → R2 a2ui | **PASS** | 对比类任务普遍产出 `type=a2ui`：`ComparisonTable`（如姜文对比卡）、`Steps`（让子弹飞三步卡）、`ActionChips`；`node html/run-palette-fixtures.mjs` = **128/128** |
| **OC-7** | sessionRef 不串卡 | **PASS** | 每卡独立 `sessionRef`（`agent:main:niuma-cp-{cardId}`）；同卡追问（如 `card_1078937` 3 条 `messages`）共用同一 `sessionRef`；`agent_cards.json` 无跨卡重复 `sessionRef` |

### OC 汇总

| 维度 | 状态 |
|------|------|
| 基础设施 OC-1~3 | 生产路径可用（基于历史任务 + 日志） |
| 流式 OC-4 | 通过 |
| 协议 OC-5 | **需持续观察** — 约 1/3 抽样卡完整四标签，长任务偶发截断 |
| 渲染 OC-6 | 通过 |
| 隔离 OC-7 | 通过 |

---

## 已知问题（写入基线，不阻塞 P2）

1. **OC-5 截断：** `card_2213015_7265`（内存检查任务）`PLAN` 未闭合即 finalize → 仅有 plan/status 块 + 短 reply。
2. **失败样本：** `card_12771437_9124` 同步超时；`card_50430812_4803` 引擎超时 — 与 Gateway/会话负载相关，非 CP 渲染问题。
3. **P2 GUI：** 自动化未覆盖 WebView2 内 `nmer-official-a2ui-surface` 真渲染；需 CP 打开后点「安全回调」验证 action `accepted→completed`。

---

## 复现命令

```powershell
# P2 自动化（Hub 需已启动）
powershell -ExecutionPolicy Bypass -File scripts/Run-P2CpIntegration.ps1

# 全量 palette fixtures（OC-6 回归）
node html/run-palette-fixtures.mjs

# 导出 OC 探测 JSON（牛马运行中，在 AHK 即时窗口）
# CommandPalette_AgentExportOcBaseline("openclaw")
# → Cache/debug/oc_baseline_export.json
```

---

## 下一步建议

1. **你本机完成 P2 L3：** CP 打开 + curl → 截图 `p2-a2ui-demo` 卡 → `CommandPalette_ProbeP2OfficialA2ui()` 应为 `P2_PASS`
2. ~~**OC-5 加固**~~ ✅ 已实现 `analyzeProtocolClosure` + 合成 reply + `ProbeOc5` 读 `protocolClosure`

**本机 OC-5 验证（三层）：**

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Run-Oc5LocalVerify.ps1
```

| 层 | 内容 | 通过标准 |
|----|------|----------|
| L1 | `node html/run-oc5-verify.mjs` | `OC5_L1 ok=true` |
| L2 | 读 `Cache\debug\agent_cards.json` | 存在 `protocolClosure` 且 `repaired` 或 `closed` > 0（新任务后） |
| L3 | CP 打开后 AHK：`CommandPalette_ProbeOc5ProtocolClosure()` | `code=OC5_ENGINE_PASS_NEEDS_LIVE` 或 `OC5_PASS`；截断任务见 debug `pipeline_protocol_closure` |

导出：`CommandPalette_AgentExportOcBaseline()` → `oc_baseline_export.json` 含 `oc5CpProbe` + `openclawBaseline.oc5`
3. **B2 后常态：** 日常只开牛马，不手动开 `nmer-wails.exe`；Hub 由 `Nmer_AutoStartWailsBridge` 守护

---

*生成：2026-06-09 · 探测代码：`CommandPalette_AgentProbeOc4~7`、`CommandPalette_ProbeP2OfficialA2ui`*
