# nmer 本机埋点 / Telemetry 摘要（P0 标准）

> 仅限本机 JSON 统计，不做任何远程上报。用于支撑默认配置、面板排序、AI 链路调优与排障。

## 1. 总体原则

- **本机优先**：所有统计只落到当前机器的 `Cache/debug/nmer_telemetry.json`。
- **行为而非内容**：只记录「哪个能力被触发、成败与耗时」，不记录正文、搜索词或剪贴板内容。
- **失败可忽略**：`Nmer_Telemetry_Record` 任何错误都不得影响主逻辑；统计是旁路。
- **单一入口**：所有埋点统一走 `Nmer_Telemetry_Record(scope, action, ok := true, meta := Map())`。

---

## 2. 事件模型：scope / action / meta

### 2.1 scope

`scope` 表示功能域，小写字符串，当前约定：

- `surface`：UI 面板与 Surface（SearchCenter、Clipboard、PromptQuickPad、ChordPad、FloatingToolbar 等）
- `cmd`：命令执行（快捷键、命令面板落到的具体 `cmdId`）
- `cmdpal`：命令面板自身行为（打开、关闭、AI 请求等）
- `cmdpal_agent`：命令面板 Agent/编排链
- `search`：SearchCenter 查询行为
- `settings`：设置页操作（保存、切 tab 等）
- `health`：健康快照与读模型构建
- `diagnostics`：诊断包导出等
- `migration`：迁移包导出 / 预览 / 导入
- `llm`：统一 LLM 层（Settings 测试、路由等）
- `niuma_chat`：Niuma Chat 抽屉与 LLM 调用
- `vk`：虚拟键盘配置（Keybinder 等）

> 新增 scope 前优先考虑是否可以落在上述之一，避免泛滥。

### 2.2 action

`action` 表示该域下的具体事件，小写下划线风格，例如：

- 面板类：`search_center_open` / `search_center_close` / `chord_pad_open`
- 命令类：`cp_paste` / `cp_delete` / `cp_pin`
- AI 类：`send` / `send_ok` / `send_fail` / `request_start` / `request_done`
- 配置类：`saveUserStudio` / `exportMigrationPack` / `importMigrationPack`

命名规则：

- 优先「动词_宾语」：`open_drawer`、`export_bundle`。
- 同一 scope 下 action 不重复使用不同含义。

### 2.3 meta（字段白名单）

`meta` 是可选 Map，对每个 scope 有**严格白名单**。示例：

- `surface`：`surfaceId`, `source`, `mode`, `reason`, `triggerSource`, `navigateTab`
- `cmd`：`source`（如 `VK_Execute`、`command_palette`）
- `cmdpal`：`durationMs`, `generation`, `resultCount`, `layoutMode`, `sessionId`
- `cmdpal_agent`：`source`, `event`, `kind`
- `search`：`source`（入口），可选枚举型参数（如分类 id）
- `llm`：`provider`, `baseUrl`（可选简化为标签）, `endpoint`, `elapsedMs`, `status`
- `niuma_chat`：`source`, `status`, `elapsedMs`
- `vk`：`cmdId`, `policy`, `sceneId`, `source`
- `diagnostics`：`files`（文件数或短标识）、`trigger`
- `migration`：`source`、`files`（同上）、`ok`
- `health`：`trigger`
- `settings`：`tab`, `source`

白名单由 `Nmer_Telemetry_SanitizeMeta(scope, action, meta)` 实施：

- 未在白名单中的 meta 字段会被丢弃。
- 对不同 scope 返回不同裁剪后的 Map。

---

## 3. 全局禁记项

以下信息严禁进入 `nmer_telemetry.json` 中的任何字段（包括 `lastError`）：

- **用户正文**：聊天内容、命令面板 prompt、PromptQuickPad 文本等。
- 搜索词 / SQL 片段 / 剪贴板内容。
- 完整文件路径（可考虑只保留短 id 或类型标签，例如 `kind=db_clipboard`）。
- 任意 token / API Key / 密钥或其前缀。

如果确实需要临时调试，可继续使用 `nmer_trace.log`（`NMER_Log`），但不得混入 telemetry 聚合。

---

## 4. 存储与结构

- 文件路径：`Cache/debug/nmer_telemetry.json`（经 `Nmer_TelemetryPath()` 决定）。
- 结构示意（AHK Map → JSON）：

```json
{
  "generatedAt": "2026-06-17 16:00:00",
  "scopes": {
    "surface": {
      "total": 120,
      "ok": 118,
      "fail": 2,
      "lastAt": "2026-06-17 15:59:30",
      "lastOk": true,
      "lastError": "",
      "actions": {
        "search_center_open": {
          "count": 80,
          "ok": 80,
          "fail": 0,
          "lastAt": "2026-06-17 15:58:00",
          "lastOk": true,
          "lastError": "",
          "lastMeta": { "source": "SCWV_Show" }
        }
      }
    }
  }
}
```

> 聚合写入由 `Nmer_Telemetry_Write` 完成，失败会被 `NmerCatch` 吸收，不抬高退出码。

---

## 5. 查看入口：设置页「本机统计」

设置页高级区提供只读视图（通过 Config WebView → `Nmer_Telemetry_BuildSummary(limit)`）：

- `Top Scopes`：按 `total` 排序的前 N 个 scope。
- `Top Actions`：按 `count` 排序的前 N 个 `(scope, action)` 组合。
- `recentFail`：最近一次失败的 `scope: error` 文本（若存在）。

用途：

- 快速判断「哪个面板/能力使用最多」。
- 快速识别「最近哪类动作持续失败」（如 `niuma_chat/send_fail`）。
- 为支持/诊断提供截图或复制文本。

---

## 6. 面板漏斗定义（P1 依赖本节）

对每个核心 UI 面板（Settings / SearchCenter / Clipboard / CommandPalette / FloatingToolbar / PromptQuickPad / ChordPad 等），约定统一漏斗事件：

- `surface/<panel>_open`：面板成功显示。
- `surface/<panel>_close`：面板关闭。
- `surface/<panel>_first_action`：打开后第一次用户动作（只记一次）。
- `surface/<panel>_open_without_action`：打开→关闭期间无任何动作。

实现约束：

- 每个面板维护一个布尔 `hasActionSinceOpen`：
  - `open` 时清零；
  - 第一次动作时置真并写入 `<panel>_first_action`；
  - `close` 时若仍为假，写 `<panel>_open_without_action`。
- 代码侧统一使用：
  - `Nmer_Telemetry_MarkSurfaceOpen(panel, meta)`
  - `Nmer_Telemetry_MarkSurfaceAction(panel, action, meta)`
  - `Nmer_Telemetry_MarkSurfaceClose(panel, meta)`

---

## 7. 命令与 AI 链路（简要约定，P2 详细）

命令侧（`scope=cmd`）：

- 业务侧可继续写原子事件（如 `cp_paste`、`open_settings`）。
- Telemetry 入口会自动镜像统一事件：
  - `cmd_execute`（附 `cmdId`）
  - `cmd_success` / `cmd_fail`（附 `cmdId`）

AI 侧（`scope=llm` / `cmdpal` / `niuma_chat`）：

- Niuma Chat 继续写 `send` / `send_ok` / `send_fail`。
- Telemetry 入口会自动镜像到 `scope=llm`：
  - `request_start` / `request_done` / `request_fail`

详细字段与挂点见后续执行计划（P2），本文件只锁定命名与隐私边界。

---

## 8. 稳定性与支持相关事件（简要约定，P3 详述）

重点范围：

- 桥接：`bridge_disconnect` / `bridge_reconnect`（当前接入 Wails Bridge 健康状态切换）。  
- Surface 重置：`surface_crash_or_reset`（如 SearchCenter FORCE_RESET）。  
- 健康快照：`health_snapshot_result`。  
- 迁移包与诊断导出：`migration.export` / `migration.preview` / `migration.import` / `diagnostics.export_bundle`。  
- 更新：`update_check_done` / `update_available` / `update_open_release_page`。

所有这些事件同样遵守本文件的命名、字段白名单与禁记项约束。

---

## 9. 扩展规范

新增埋点时，需满足：

1. 先选/复用合适的 `scope`，避免新增过多 domain 字符串。
2. `action` 使用小写下划线，语义清晰且与现有不冲突。
3. `meta` 中只使用本文件列出的白名单 key，若需新增 key，先补 `Nmer_Telemetry_SanitizeMeta` 与本文件说明。
4. 确保统计调用放在「**成功/失败已知的最后一公里**」，避免误计或重复。
5. 单元/集成测试或手动验证时，能在 Telemetry Summary 中看到对应的 scope/action 与计数变化。

这样可以保证埋点少而准、长期可维护，而不会演变成第三套难以理解的「隐形协议」。

---

## 10. P1 验收清单（核心 6 面板）

以下 6 个面板已按统一漏斗接入，手动验收时每个面板至少跑两轮：

- A 轮（有动作）：`open -> first_action -> close`
- B 轮（无动作）：`open -> close -> open_without_action`

面板与建议动作：

- `config_webview`：在设置页执行一次导入/导出/重置等 `invokeAction`
- `search_center`：打开后执行一次检索（触发 `search_center_query`）
- `clipboard_panel`：打开后执行一次复制/粘贴/置顶等剪贴板命令
- `command_palette`：打开后输入或提交一次查询
- `floating_toolbar`：打开后切换一次模式或发送一次 Niuma Chat
- `prompt_quick_pad`：打开后执行一次 `search` 或 `nmDockCmd`

验收观察点（设置页本机统计）：

- `Top Actions` 能看到 `<panel>_first_action` 与 `<panel>_open_without_action`
- 对同一次打开，只出现一次 `<panel>_first_action`

---

## 11. 一键自测脚本（P0-P3）

执行命令：

`powershell -NoProfile -File tools/dev/Run-TelemetrySelfTest.ps1 -Root .`

严格模式（将 advisory 也视为失败）：

`powershell -NoProfile -File tools/dev/Run-TelemetrySelfTest.ps1 -Root . -Strict`

输出说明：

- 控制台直接显示 `[PASS]/[WARN]/[FAIL]` 明细
- 报告文件：`Cache/ci/telemetry_selftest_report.txt`
- 退出码：
  - `0`：required 全通过
  - `1`：required 有失败
  - `2`：`-Strict` 下 advisory 有告警

若首次运行大量 FAIL，先按脚本末尾的 `quick manual trigger steps` 触发一轮真实行为，再重跑即可。

