# 文本黑洞回归清单

改完后按序手工验证，并在 `Cache/nmer_trace.log` 中确认 `phase=` / `[TextHole]` 行。

## 1. 误触发

- [ ] 无划选单击：不出现弱预览
- [ ] 400ms 内双击且无移动（非 Hub）：不触发 `ProcessDeferred`
- [ ] 空选区 / 剪贴板未变化：日志 `skip=clipboard_unchanged`，无黑洞

## 2. 位置

- [ ] 划选松手后洞心大致在选区末端上方
- [ ] 打开面板后面板相对星空宿主位置稳定（不跳屏）
- [ ] 双屏边界划选：面板落在工作区内

## 3. 面板保持

- [ ] 靠近提交后移开鼠标：吸入完成后面板仍出现
- [ ] 提交后等待 >2.6s：面板不被 `selection_copy_timeout` 关闭
- [ ] 面板内输入 focus：保持至显式关闭

## 4. 面板打开时不再激发黑洞

- [ ] 面板打开时再次划选：无弱预览（日志 `phase_not_idle` 或 `panel_active`）
- [ ] 关闭面板后划选：弱预览正常

## 5. 关闭动线

- [ ] 面板 × → `DismissTextHolePanel` → `phase=idle`
- [ ] 面板 Esc → 同上
- [ ] 全局 Esc（面板 engaged）→ `esc_global` dismiss，再 Esc 可关搜索中心
