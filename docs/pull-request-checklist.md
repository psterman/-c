# Pull Request 自检清单

合入前请逐项确认。与 [`stack-governance.md`](stack-governance.md)、[`pr-architecture-discipline.md`](pr-architecture-discipline.md) 配套使用。

## 通用

- [ ] commit subject 为**简体中文**（见 `.cursor/rules/commit-zh.mdc`）
- [ ] 未提交 `local/`、`Cache/`、密钥、`.env` 等本地/敏感文件
- [ ] 改过默认入口文档（`README.md`、`md/AGENTS.md`、`docs/nmer-conventions.md`）时跑过 `Validate-FrozenPathPolicy.ps1`

## 门禁

- [ ] `Run-MinimalGate.ps1 -Strict` 通过（含 **Contract Production**；需 Node.js）
- [ ] 改 SCWV / palette 时：`Run-Phase3ContractSuite.ps1 -Required` 绿（已含于 MinimalGate `-Strict`）
- [ ] 跑过 DevMenu 时查看 **Summary 块**（optional 失败时 exit 仍可为 0）

## 架构纪律（改 Hub / palette / WebView 时）

- [ ] 未在 Go Hub 新增「第二份 Surface UI 状态」
- [ ] 改 `html/palette/**` 或 SCWV 后：`tools\ci\Run-Phase3ContractSuite.ps1` 绿（或分别跑 palette / SCWV fixtures）
- [ ] 改 SearchCenter WebView 消息：已更新 [`scwv-message-contract.md`](scwv-message-contract.md) 与 `tools/ci/scwv-contract-types.json`

## SCWV / SearchCenter

- [ ] 新 `type` 已加入 manifest + 契约文档（当前成熟度：**production**）
- [ ] 未将 `schemaVersion: 1` 误解为 production 契约

## 冻结路径与 allowlist

- [ ] 未在默认入口文档把 `tools/a2ui-diagnostics/` 写成日常产品路径
- [ ] 若修改 `tools/ci/frozen-path-allowlist.txt`：
  - [ ] 注明**类别**（历史归档 / 专项回退 / 旧签收文档）
  - [ ] 注明**理由**与**为何不是默认入口**
  - [ ] 未批量追加、未通配整个 `docs/` 或 `a2ui-diagnostics/`

## Legacy

- [ ] 未在非 Legacy 模块新增 `LegacyConfigGui_Show` / `ShowClipboardManager` 直调
- [ ] 若必须保留直调：已更新 `legacy-bypass-allowlist.txt` 并说明收口计划

## 术语（reviewer）

- [ ] PR 描述未将「组织 L3」与「SCWV production」混用
- [ ] Phase 标题未误写「L3」（L 级仅出现在成熟度章节）
