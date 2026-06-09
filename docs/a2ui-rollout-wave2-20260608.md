# A2UI Rollout Wave 2 进度（灰度落地）

Wave 2 目标：灰度开关可观测、Action/拒收文案统一、自动化基线可复跑。

---

## 已完成

| 项 | 交付 | 验证 |
|----|------|------|
| **灰度路由** | 既有 `PaletteOfficialA2UIGray.js` + mutex 单测补强 | `run-gray-a2ui-smoke.mjs` |
| **Action 文案** | `PaletteOfficialA2UIActionLabels.js` | accepted/completed/rejected/timeout/cancelled 中文 |
| **卡片状态行** | `PaletteOfficialA2UICardNotify.js` | WS action-result / rejected → `.card-status-log` |
| **路由展示** | `cardMetaLineText` | 卡元信息行显示 R3 或 R1+R2·原因 |
| **flags 模板** | [`nmer-flags.example.json`](./nmer-flags.example.json) | 复制到 `local/nmer-flags.json` |
| **Wave 2 基线** | [`Run-Wave2GrayBaseline.ps1`](../tools/a2ui-diagnostics/Run-Wave2GrayBaseline.ps1) | `wave2_gray_baseline_last.json` |

---

## 本机启用 R3 灰度

1. 复制 `docs/nmer-flags.example.json` → `local/nmer-flags.json`
2. 确认 **未** 同时设 `rollback.forceNmerOnly=true`（与 `officialA2ui.enabled` 互斥，force 优先）
3. 重载 `牛马.ahk`，sidecar 健康（`:18791`）
4. 新卡提交白名单命令，如 `/search ...`
5. **Ctrl+Shift+G** → `gray_probe_last.json` 预期 `GRAY_PASS`

---

## Wave 2.5（观察 + 构建）

| 项 | 脚本 |
|----|------|
| 构建 sidecar | [`Build-NmerWails.ps1`](../scripts/Build-NmerWails.ps1) |
| 日检快照 | [`Run-A2uiDailyObservation.ps1`](../tools/a2ui-diagnostics/Run-A2uiDailyObservation.ps1) |
| 合并门禁 | [`Run-A2uiRolloutGate.ps1`](../tools/a2ui-diagnostics/Run-A2uiRolloutGate.ps1) |

多卡内存档位（CP 打开 N 张 R3 卡后）：

```powershell
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\capture-memory-baseline.ps1 -CardCount 5
```

## 命令

```powershell
node html/run-gray-a2ui-smoke.mjs
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Run-Wave2GrayBaseline.ps1
powershell -ExecutionPolicy Bypass -File tools\a2ui-diagnostics\Run-A2uiRolloutGate.ps1
```

---

## 待观察（Day 2–3）

- 7×24 fallback / timeout / 内存
- OC-5 L3 与 Wave 0 基线对比
- Adapter 实网（`OPENCLAW_GATEWAY_TOKEN`）
