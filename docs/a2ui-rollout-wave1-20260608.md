# A2UI Rollout Wave 1 进度（2026-06-08）

Wave 1 首批交付：ADP-0、FTB-2、回退演练、Adapter 骨架、transport 锁定预备。

---

## 已完成

| 票 | 交付 | 验证 |
|----|------|------|
| **ADP-0** | [`openclaw-ws-contract.md`](./openclaw-ws-contract.md) — sessionKey **free-form**；`niuma-adp-` 可用 | Go/JS 单测 |
| **FTB-2** | [`openclaw-session-keys.js`](../html/ftb/palette/openclaw-session-keys.js) + [`run-openclaw-session-keys.mjs`](../html/run-openclaw-session-keys.mjs) | `OPENCLAW_SESSION_KEYS ok=true` |
| **1.2** | [`a2ui-surface-lifecycle.md`](./a2ui-surface-lifecycle.md) | 文档 + 既有 `a2ui_test.go` |
| **R1/R2** | [`scripts/Run-A2uiRollbackDrill.ps1`](../scripts/Run-A2uiRollbackDrill.ps1) | `rollback_drill_last.json` pass=true |
| **ADP-1 骨架** | [`openclaw_adapter.go`](../apps/nmer-wails/poc/openclaw_adapter.go) `POST /a2ui/openclaw/action` | 校验 session → `501 ADAPTER_NOT_WIRED` |
| **ADP-2 预备** | Orchestrator `agentTransport` 锁定 + adapter sessionKey 函数 | adapter 路径暂 **defer 到 ftb**（等 ADP-1 接线） |

---

## Wave 1 续（2026-06-08 晚）

| 票 | 状态 | 说明 |
|----|------|------|
| **ADP-1** | **已接线** | `openclaw_gateway.go` WS + `BuildOpenClawTextSurfaceEnvelopes` + ingest；mock 集成测试 PASS |
| **ADP-2** | **已接线** | Orchestrator `transport=adapter` → `POST /a2ui/openclaw/action`；失败回退 FTB |
| **ADP-3** | **L1/L2 已绿** | [`Run-AdpCpIntegration.ps1`](../scripts/Run-AdpCpIntegration.ps1) + [`run-adp-cp-stream.mjs`](../html/run-adp-cp-stream.mjs)；**L3** 待 CP 打开后 **Ctrl+Shift+U**（先 ingest 演示 JSONL） |
| **1.4** | **Go 已接线** | `RegisterSurface` + `SEM_ACTION_CONTEXT_MISMATCH`；`TestA2UIActionPolicyRejectsCrossCardSurface` |

**本机启用 Adapter 路径：**

1. 设置环境变量 `OPENCLAW_GATEWAY_TOKEN`（或本机 OpenClaw 等价配置）
2. **重编译** `apps/nmer-wails` → 重启 sidecar（重载 `牛马.ahk`）
3. `local/nmer-flags.json` 开灰度且 `/search` 在白名单
4. 新卡提交 `/search ...`（非旧卡追问）

```powershell
powershell -ExecutionPolicy Bypass -File scripts/Run-OpenClawAdapterSmoke.ps1
powershell -ExecutionPolicy Bypass -File scripts/Run-AdpCpIntegration.ps1
# L3：CP 可见 → curl ingest 演示 JSONL → Ctrl+Shift+U → Cache/debug/adp_probe_last.json
```

---

## 命令

```powershell
node html/run-openclaw-session-keys.mjs
cd apps/nmer-wails; go test ./poc/...
powershell -ExecutionPolicy Bypass -File scripts/Run-A2uiRollbackDrill.ps1
curl -X POST http://127.0.0.1:18791/a2ui/openclaw/action -H "Content-Type: application/json" -d "{\"cardId\":\"c1\",\"query\":\"/search hi\",\"sessionRef\":\"agent:main:niuma-adp-c1\"}"
```

---

## 结论

Wave 1 **ADP-0~3（L1/L2）+ 1.4 跨卡约束已绿**；待你本机完成 **ADP-3 L3**（Ctrl+Shift+U）与 Adapter 实网烟测（`OPENCLAW_GATEWAY_TOKEN`）。
