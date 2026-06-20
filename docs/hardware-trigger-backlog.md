# 硬件触发层 — 待办 backlog

> 状态：**待做**（记录于 2026-06-19）  
> 关联实验：`Desktop/hid_mixed_experiment_v2.ahk`、`docs/Y6_音量键联动总结.md`

## 目标

将 Y6 / Yiser-J6 等 BLE HID 设备接入牛马，让用户在**设置页**自定义「手势 → 命令」，复用现有 `cmdId` / `VK_Execute` 体系。

## 架构（三层）

1. **硬件层**：原始 HID（如 `Volume_Up/Down`）
2. **手势层**（新增）：拦截、单击/双击判定、消系统音量副作用
3. **动作层**（已有）：`cmdId` → `VK_Execute` / `SurfaceIntent_Open`

成功时序：**先立即触发单击 → 短窗（约 260ms）内第二次升级为双击**。

## 待办清单

### P1 — 最小可用

- [ ] 新增 `modules/HardwareTriggerBridge.ahk`（从 `hid_mixed_experiment_v2.ahk` 提炼）
- [ ] 新增 `modules/HardwareProfiles.ahk`（Y6 内置 preset）
- [ ] `Commands.json` 增加 `HardwareProfiles` 配置节
- [ ] `牛马.ahk` 在 `InitConfig()` 后 `HardwareTrigger_Init()`
- [ ] 默认 preset：单击 `hub_capsule`，双击 Esc/取消命令

### P2 — 用户可配置

- [ ] 设置页「硬件触发」子页（`settings-app.js` + `ConfigWebViewModule.ahk`）
- [ ] 手势绑定 UI：单击/双击 → 命令下拉（复用 KeyBinder 命令列表）
- [ ] 预设方案：AI 输入 / 牛马日常 / 剪贴板流
- [ ] INI：`Settings/HardwareEnabled`、`Settings/HardwareProfileId`

### P3 — 可扩展

- [ ] `tools/hid_y6_probe.ahk` 探测日志
- [ ] 设备能力矩阵文档（单击/双击/长按/副作用）
- [ ] 支持 F13/F14 类无音量副作用设备
- [ ] 可选独立 helper + `VkExecQueue` IPC

## 配置草案

```json
"HardwareProfiles": {
  "y6_ring": {
    "label": "Yiser-J6 戒指",
    "enabled": true,
    "interceptVolume": true,
    "doubleClickMs": 260,
    "gestures": {
      "volume:single": { "cmdId": "hub_capsule" },
      "volume:double": { "cmdId": "sys_escape" }
    }
  }
}
```

## 不复用/注意

- 不要让用户把 `Volume_Up` 直接绑进 `Bindings`（与系统冲突）
- Y6 长按 = 关机，不做长按手势
- Typeless 的粘贴感可能是正常链路，需在 UI 标明

## 参考文件

| 文件 | 用途 |
|------|------|
| `modules/VirtualKeyboardExecCmd.ahk` | `VK_Execute` 统一入口 |
| `modules/ChordPad.ahk` | 槽位 → cmdId 模式参考 |
| `modules/SurfaceIntentRouter.ahk` | 开面板时 `triggerSource: hardware_*` |
| `html/settings/settings-app.js` | 热键绑定 UI 扩展点 |
