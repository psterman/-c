# A2UI Rollout Wave 0 基线（2026-06-08）

Wave 0 收口产物。后续 Wave 2 观察与 Wave 4 决策均对照本文 + `Cache/debug/*`。

---

## 自动化验收

| 检查项 | 结果 | 证据 |
|--------|------|------|
| `run-palette-fixtures.mjs` | **PASS 153/153** | [`fixtures-count-history.md`](./fixtures-count-history.md) |
| `run-gray-a2ui-smoke.mjs` | **PASS 11/11** | headless gray + metrics |
| `run-oc5-verify.mjs` L1 | **PASS** | `OC5_L1 ok=true` |
| `go test ./poc/...` | **PASS** | nmer-wails sidecar 契约 |
| 灰度快照 | **PASS** | `routeMode=r1r2_only` → [`Cache/debug/gray_flags_baseline.json`](../Cache/debug/gray_flags_baseline.json) |
| 内存基线 | **部分** | 空载 `emptyLoadPrivateMiB=1493.29`（wv2×24 + sidecar）；1/5/20 卡待补采 |

一键重跑：

```powershell
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Run-Wave0Baseline.ps1
```

---

## 灰度状态（Wave 0 预期）

| 字段 | 值 |
|------|-----|
| `officialA2ui.enabled` | `false`（默认；无 `local/nmer-flags.json`） |
| `rollback.forceNmerOnly` | `false` |
| `commandWhitelist` | `[]` |
| **routeMode** | **`r1r2_only`** |

---

## 单卡内存成本（single-card-memory-cost）

| 档位 | 卡数 | 状态 |
|------|------|------|
| empty | 0 | 已采 **1493.29 MiB**（`a2ui_memory_baseline.json`） |
| basic | 1 | 待补采 |
| medium | 5 | 待补采 |
| replay_cap | 20 | 待补采 |

公式：`deltaPerCard = (N卡 totalPrivate - empty totalPrivate) / N`

---

## 手工待办（Wave 0 未自动化）

| 项 | 动作 |
|----|------|
| OC-5 L3 | 重载 `牛马.ahk` → **Ctrl+Shift+O** → `Cache/debug/oc5_probe_last.json` |
| 多卡内存 | CP 打开后按档位补采并更新本文 |

---

## 关联文档

- [切流宪法](./a2ui-gray-cutover-policy.md)
- [OpenClaw 基线 2026-06-09](./openclaw-baseline-20260609.md)
- [Rollout 计划](../.cursor/plans/a2ui_rollout_规划_e22b29b4.plan.md)

---

## Wave 0 结论

**自动化部分 PASS** — 可进入 Wave 1（ADP-0 sessionRef 调研）。**勿**在 Wave 1 回退演练完成前创建 `local/nmer-flags.json` 开灰度。
