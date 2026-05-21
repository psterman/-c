# 选中文本 → 黑洞 → 输入面板

解耦拓扑（`GDHO_DECOUPLED_TOPOLOGY`）：星空 `hole_starry.html` + 独立面板 `hole_panel.html`。

## 交互相位（`GDHO_GetInteractionPhase`）

| 相位 | 含义 | 允许的操作 |
|------|------|------------|
| `idle` | 无活跃文本黑洞会话 | 划选 → 弱预览 |
| `weak_preview` | 仅星空弱预览 | 靠近/点击提交、2.6s 超时收回 |
| `committing` | 已提交，吸入动画中 | 等待 `hole_expand_complete`，禁止新弱预览 |
| `panel_open` | 输入面板已锁定 | 仅面板 × / Esc / 全局 Esc 关闭 |
| `closing` | 正在关闭（瞬态） | — |

## 用户三条动线

1. **只要黑洞**：划选松手 → 弱预览出现 → 不要移入洞心 → 约 2.6s 自动消失，或 Esc。
2. **打开面板**：移入洞心（~108px）或点击黑洞 → 等吸入动画（~1.2s）→ 在面板输入。
3. **稳定关闭**：优先用面板 **×** 或面板内 **Esc**；全局 Esc 会先关闭文本面板再统一关闭搜索/星空。

**避免误触**：无划选移动不要期待黑洞；面板打开后再次划选不会叠弱预览（需先关闭面板）。

## 代码入口

- 划选：`SelectionSense_OnLButtonUp` → `ProcessDeferred` → `TryActivateHoleFromSelection`
- 弱预览：`GDHO_OpenSelectionTextPreview`
- 提交：`GDHO_CommitTextHoleToPanel`（proximity / click）
- 呈现：`GDHO_PresentPanelAfterTextHoleDrop`（主路径：`hole_expand_complete`；兜底：`GDHO_TextHoleExpandFallback`）
- 关闭：`GDHO_DismissTextHolePanel`（`panel_close_btn` / `panel_escape` / `esc_global`）

## 调试

查看 `Cache/nmer_trace.log`、`NativeDropDiag_Log` 中带 `[TextHole]` / `[TextHoleSM]` / `phase=` 的行。
