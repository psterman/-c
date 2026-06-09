# Fixtures 数量审计线

`node html/run-palette-fixtures.mjs` 通过数变更记录。baseline 回看时必须能解释 ±N 原因，禁止只改终点数字。

| 日期 | 通过/总数 | 来源 | 变动说明 |
|------|-----------|------|----------|
| 2026-06-09 | 128/128 | [`openclaw-baseline-20260609.md`](./openclaw-baseline-20260609.md) OC-6 | 初始 OC 基线（R1/R2 pipeline + matcher） |
| 2026-06-09 | 131/131 | 同上 OC-5 行 | OC-5 协议 fixture 子集口径（含 `protocol_truncated_plan` 等） |
| 2026-06-xx | 153/153 | rollout 规划会话 | +22：新增 Official A2UI Gray、PaletteA2UIMetrics、PaletteRendererRegistry、PaletteA2UIDesignTokens 等套件 |
| **2026-06-08** | **153/153** | `run-palette-fixtures.mjs` Wave 0 | 全绿；与上一行一致，无新增/删除用例 |
| **2026-06-08** | **155/155** | Wave 2 + Action | +2：`action_label_contracts`、`action_policy_contracts` |

## 口径说明

- **128**：早期文档默认引用数（OC-6 渲染路径）。
- **131**：128 + OC-5 协议相关 fixture（与 128 有重叠计数口径，勿简单相减）。
- **153**：当前 headless 全量 runner 输出（`passed=N failed=0 ok=true`）。

## 漂移警报规则

| 变化 | 可能原因 | 动作 |
|------|----------|------|
| 总数增加 | 新套件 / 新灰度或 metrics fixture | 更新本表 + architecture 暂停线检查 |
| 总数减少 | 合并重复用例 / 删除废弃块 | 确认无行为回归后更新文档 |
| failed > 0 | 回归 | **暂停 rollout**，触发 architecture v2 §13 |
