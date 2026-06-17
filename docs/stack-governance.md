# 混栈治理手册

> AHK · Go · Node · WebView2 混栈仓库的组织成熟度、执行阶段与契约成熟度。**改面板、合 PR、跑门禁前请先读本章 §0。**

## 0. 术语映射（必读）

**三套命名空间，不得混用。**

### A. 组织成熟度 `L0`–`L5`（整仓混栈治理水平）

| 级别 | 含义 |
|------|------|
| L0–L1 | 混乱 / 边界初定 |
| **L1.5–L2** | 有 MinimalGate、有收口意图；SCWV 已 **stable** |
| **L2–L3** | **本仓当前推进中**：Phase 3 契约可回归；组织路径仍待完全收敛 |
| **L3** | 可控混栈：改面板主要看少数文件；**≠ SCWV 已 production** |
| L4–L5 | 成熟收敛 |

> **「推进到 L3」= 组织成熟度到 L3，不是说协议已进入 production。**

### B. 执行阶段 `Phase 0`–`Phase 4`（本手册做事顺序）

| Phase | 名称 | 产出侧重 |
|-------|------|----------|
| 0 | 现状对齐 | MinimalGate 绿 |
| 1 | 契约锚定与边界 | [`scwv-message-contract.md`](scwv-message-contract.md)（**anchor**） |
| 2 | 入口与冻结审计 | DevMenu、PR 清单、静态门 |
| 3 | 契约 **stable** | fixtures、可稳定回归 |
| 4 | 门禁 **production** 化 | fixtures 升 required；**仍须与 L3 组织成熟度区分** |

### C. SCWV 契约成熟度 `anchor` / `stable` / `production`（仅指消息协议）

| 术语 | 一句话 | 合入阻断？ |
|------|--------|------------|
| **anchor** | 仅锚定：`type` 白名单 + `schemaVersion` 占位 | 否 |
| **stable** | 可稳定回归：fixtures 绿，变更须改契约 | 否（DevMenu optional） |
| **production** | 可进 **MinimalGate required** | 是（针对该契约项） |

**交叉对照（防混读）：**

```
Phase 1 完成  →  SCWV 通常为 anchor（不是 stable/production）
Phase 3 完成  →  SCWV 可标记 stable（仍不是 production）
Phase 4 完成  →  SCWV 可标记 production；组织成熟度目标约 L3（二者不同维）
```

**快速问答：L3 是不是 production？** → **否。** L3 是组织成熟度；production 是 SCWV 契约成熟度。

---

## 1. 用途与当前位置

- **当前**：组织成熟度约 **L3**（MinimalGate `-Strict` 含 Contract Production；SCWV **production**）。
- **远期**：组织 **L4–L5**（全仓机械验证与成熟收敛，非本阶段目标）。
- **入口脚本**：`powershell -NoProfile -File tools\dev\Run-DevMenu.ps1`

---

## 2. 底线清单

1. 用户路径经 `LocalPaths.ahk` / `NmerConfig_Get()`，禁止硬编码散落路径。
2. 业务 catch 经 `NmerCatch`；禁止 `modules/` 内裸 `catch {}`（见 `Validate-CatchPolicy.ps1`）。
3. 新模块不得直调 `LegacyConfigGui_Show` / `ShowClipboardManager`（见 `Validate-LegacyBypass.ps1`）。
4. Hub 不双写 Surface 状态（见 [`pr-architecture-discipline.md`](pr-architecture-discipline.md)）。
5. 默认入口文档不得把诊断包、历史 rollout 写成「日常操作路径」（见 §5 冻结审计）。

---

## 3. 混栈允许项 + Node/PS 编排约束

| 层 | 允许 | 约束 |
|----|------|------|
| AHK | 宿主、热键、WebView 桥、SearchCore 编排 | 面板消息经 SCWV 契约，不另造平行协议 |
| Go | SearchCenter Core、Hub 传输 | 不存 UI 卡片状态 |
| Node | palette fixtures、构建辅助 | DevMenu 为 **optional**；node 不在 PATH 时 **SKIP** |
| PS | CI 门、DevMenu、迁移脚本 | required 门失败抬高 summary exit |

**编排原则**：产品默认路径写进 README / conventions / 本手册；一次性签收与诊断留在 `tools/a2ui-diagnostics/`（非默认入口）。

---

## 4. 必须统一项

- WebView ↔ AHK：**SearchCenter** 以 [`scwv-message-contract.md`](scwv-message-contract.md) 为准（当前 **production**；`-Strict` 进门禁）。
- 设置子页 iframe：经 `settings-bridge.js` 壳转发，不直调 `chrome.webview`。
- 密钥：`Nmer_SecretStore` + DPAPI，见 [`nmer-enterprise-ops.md`](nmer-enterprise-ops.md)。
- 本地最小 CI：[`ci-minimal-gate.md`](ci-minimal-gate.md) → `Run-MinimalGate.ps1 -Strict`。

---

## 5. 旧路径冻结 + 审计三层 + allowlist

### 三层

1. **代码门**：`Validate-LegacyBypass.ps1`（Legacy 直调）。
2. **文档门**：`Validate-FrozenPathPolicy.ps1`（默认文档引用冻结路径）。
3. **人工门**：PR 清单 + review（见 [`pull-request-checklist.md`](pull-request-checklist.md)）。

### 冻结路径（文档扫描命中即需 justify 或 allowlist）

- `tools/a2ui-diagnostics/<具体脚本或文件>`（诊断签收，非产品默认路径）
- `docs/a2ui-rollout-*.md`（历史归档；allowlist 已覆盖通配）

Legacy 直调由 **代码门** `Validate-LegacyBypass.ps1` 审计，不在本文档门重复扫符号名。

### allowlist（唯一源：`tools/ci/frozen-path-allowlist.txt`）

**仅三类可入列：**

| 类别 | 示例 | 用途 |
|------|------|------|
| **历史归档** | `docs/a2ui-rollout-*.md` | 已结束 rollout 记录，非操作入口 |
| **专项回退** | 见下文「回退操作」 | 明确 rollback only |
| **旧签收文档** | `tools/a2ui-diagnostics/README.md` | 诊断包自述，非产品默认路径 |

**禁止入列**：新功能说明、`README.md`、`md/AGENTS.md`、`docs/nmer-conventions.md`、本文件、通配整个 `docs/` 或 `tools/a2ui-diagnostics/`。

**变更规则**：新增一行须 PR 注明类别 + 理由 + 为何不是默认入口；禁止批量追加。

### 回退操作（rollback only）

以下仅供灰度/签收回退，**不得**写入产品默认路径文档正文：

- `tools/a2ui-diagnostics/Run-HybridSignoff.ps1`
- `tools/a2ui-diagnostics/Run-HybridCpSignoffPipeline.ps1`

回退后须在 PR 说明中标注「rollback only」并链回本节。

---

## 6. SCWV 契约成熟度

详见 [`scwv-message-contract.md`](scwv-message-contract.md)。摘要：

- **当前状态：production**（`Run-MinimalGate.ps1 -Strict` → Contract Production 套件）。

---

## 7. DevMenu Tier + Summary 输出规范

| Tier | 单项失败 | 计入 summary exit=1 |
|------|----------|---------------------|
| required | `[FAILED]` | **是** |
| optional | `[FAILED]` | **否** |
| skip-if-missing | `[SKIP]` | 否 |

**每次运行结束必须打印 Summary 块**（不可省略）：

```
======== DevMenu Summary ========
[OK]     MinimalGate (required)
[FAILED] SearchCore Lifecycle (optional) — exit=1 see Cache/ci/...
[SKIP]   Palette fixtures — node not in PATH
---------------------------------
OK=1  SKIP=1  FAILED=1
summary exit=0  (required 全部 OK；optional 失败不抬高退出码)
=================================
```

> 请看上方逐项状态；**不要只看 exit 码**。optional 失败会显示 `[FAILED]` 但 summary 可为 0。

---

## 8. L0–L5 详表

| 级别 | 特征 | 本仓 |
|------|------|------|
| L0 | 无统一门、路径散落 | 历史 |
| L1 | 有部分约定文档 | 部分模块 |
| L1.5–L2 | MinimalGate + 冻结意图 + 契约 anchor | 已完成 |
| L2 | SCWV stable + Phase 3 套件 | 已完成 |
| L3 | MinimalGate 含 Contract Production；契约 production | **当前** |
| L4–L5 | 全仓机械验证、成熟收敛 | 远期 |
| L4–L5 | 契约 production、变更可机械验证 | 远期 |

---

## 9. Phase 0–4 可勾选步骤

### Phase 0 — 现状对齐

- [x] `Run-MinimalGate.ps1 -Strict` 绿
- [x] 确认组织成熟度 L1.5–L2

### Phase 1 — 契约锚定与边界

- [x] `scwv-message-contract.md` 存在（已由 anchor 升 **stable**）
- [ ] 新 SCWV `type` 先入白名单再实现（流程纪律）

### Phase 2 — 入口与冻结审计

- [x] `Run-DevMenu.ps1` 可用，Summary 可见
- [x] `Validate-FrozenPathPolicy.ps1` 绿
- [x] `pull-request-checklist.md` + PR 模板

### Phase 3 — 契约 stable

- [x] SCWV / palette fixtures 可稳定回归（`Run-Phase3ContractSuite.ps1`）
- [x] 契约文档标记 **stable**

### Phase 4 — 契约 production

- [x] 选定 fixtures 升 MinimalGate required（`-Strict` → `Run-Phase3ContractSuite.ps1 -Required`）
- [x] 契约文档标记 **production**（组织成熟度约 L3，非 L4）

---

## 10. 改动影响面速查

| 若你改… | 必跑 / 必读 |
|---------|-------------|
| `modules/SearchCenterWebViewCore.ahk` | SCWV 契约、`Run-Phase3ContractSuite.ps1`、SearchCore 生命周期 |
| `html/SearchCenter.html` | SCWV 契约、实机搜索烟雾 |
| `html/palette/**` | `Run-Phase3ContractSuite.ps1` 或 `node html/run-palette-fixtures.mjs` |
| `apps/nmer-wails/poc/*.go` | Validate-WsPolicy、Hub 纪律 |
| 默认入口文档 | Validate-FrozenPathPolicy |
| allowlist | PR 注明三类理由 |

---

## 11. DevMenu 菜单表

| 项 | Tier | 脚本 |
|----|------|------|
| MinimalGate | required | `tools/ci/Run-MinimalGate.ps1 -Strict`（含 **Contract Production**） |
| Frozen Path Policy | optional | `tools/ci/Validate-FrozenPathPolicy.ps1` |
| SearchCore Lifecycle | optional | `tools/ci/Run-SearchCoreLifecycleSuite.ps1` |
| Contract Suite（单独） | optional | `tools/ci/Run-Phase3ContractSuite.ps1`（未带 `-Required`；已含于 MinimalGate `-Strict`） |

---

## 12. 合入前清单

见 [`pull-request-checklist.md`](pull-request-checklist.md)。最低要求：

1. required DevMenu / MinimalGate 绿（或 CI 等价）。
2. 改 SCWV 则更新契约文档。
3. 改 allowlist 则三类理由齐全。
4. 中文 commit subject。

---

## 13. 相关文档索引

| 文档 | 用途 |
|------|------|
| [`nmer-conventions.md`](nmer-conventions.md) | 日常约定 |
| [`ci-minimal-gate.md`](ci-minimal-gate.md) | MinimalGate 步骤 |
| [`scwv-message-contract.md`](scwv-message-contract.md) | SCWV **production** 契约 + manifest |
| [`pull-request-checklist.md`](pull-request-checklist.md) | PR 自检 |
| [`pr-architecture-discipline.md`](pr-architecture-discipline.md) | Hub / palette 纪律 |
| [`md/AGENTS.md`](../md/AGENTS.md) | Agent 定制入口 |
