# 牛马 nmer 必记日志事件

> 归纳自 `NMER_Log(scope, event, detail)` 与专用 jsonl 文件。默认日志目录：`Nmer_DebugDir()` → `Cache/debug/`（可通过 `UserCacheRoot` 重定向）。

## 核心 API

```ahk
NMER_Log(scope, event, detail := "")
```

实现于根脚本 [`牛马.ahk`](../牛马.ahk)；`detail` 多为 `key=value` 拼接字符串。

## 已落地事件

| scope | event | 触发条件 | 输出 |
|-------|-------|----------|------|
| `startup` | `boot` | 主程序 GDI+ 初始化后 | `nmer_trace.log` |
| `startup` | `unhandled_error` | 顶层未捕获异常 | `nmer_trace.log` |
| `startup` | `sql_batch_done` | `SqlBatchHelper` / 启动 SQL 批完成 | `nmer_trace.log` |
| `startup` | `sql_batch_*` | `SqlBatchHelper` 批处理各阶段 | `nmer_trace.log` |
| `*` | `catch` | `NmerCatch(scope, err)` | `nmer_trace.log` |
| `update` | `check_done` | `AppUpdateCheck` 完成 | `nmer_trace.log` |
| `activation` | `runtime_deferred` / `runtime_hole_ready` / … | 激活模式延迟初始化 | `nmer_trace.log` |
| `cmdpal_agent` | 各 orchestrator 事件 | 命令面板 Agent 编排 | `nmer_trace.log` |
| `cmdpal_ai` | 各 AI 事件 | 命令面板 AI 调用 | `nmer_trace.log` |
| `P2_PUMP` / `P2_NAV` | 策略/导航 | 黑洞解耦泵 | `nmer_trace.log` |
| `health` | `snapshot_built` | 只读健康快照生成（`Nmer_BuildHealthSnapshot`） | `nmer_trace.log` |
| `llm_ping` | `route_start` / `route_done` | 设置/测试经 `Nmer_Llm_Route("ping")` 探活 | `nmer_trace.log` |

## 专用文件（非 NMER_Log 行格式）

| 文件 | 生产者 | 内容 |
|------|--------|------|
| `health_summary.json` | `NmerHealthSummary.ahk` | 侧车 / Surface / runtime 只读快照（读模型） |
| `surface_registry_snapshot.json` | `SurfaceRuntimeManager.ahk` | Surface 登记簿导出 |
| `nmer_telemetry.json` | `NmerTelemetry.ahk` | 本机埋点聚合（次数 / 最近一次成功失败 / 摘要） |
| `studio_llm_test.log` | `ConfigWebView_LogStudioLlmTest` | 设置页 LLM 测试：`prov` / `keyLen` / `st` / `viaRoute` |
| `searchcore_lifecycle.jsonl` | `SearchCoreLifecycle.ahk` | SearchCenterCore 启停、健康检查 |
| `scwv_trace.log` | SearchCenter WebView 核心 | SCWV 嵌入/导航追踪 |
| `openclaw_timeline.jsonl` | OpenClaw 集成 | 时间线事件 |

收集脚本：`tools/ci/Collect-SearchCoreLogs.ps1`。

## 建议新增（本次不强制补埋点）

- Settings 保存失败聚合（`saveResult` err 计数）
- `Nmer_SecretStore` 迁移成功/失败单行
- Wails hub `CheckOrigin` 拒绝计数（Go 侧）
- `nmer_telemetry.json` 只做本机聚合，不做任何外发

符合治理边界：**不做埋点同步**，仅文档标注空缺。
