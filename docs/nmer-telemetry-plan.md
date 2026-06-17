# 本地埋点分层

> 目标：用最少的埋点，最大化回答“谁被用了、哪一步失败、最近一次何时出问题”。

## P0

- `cmd:<cmdId>`: `ChordUsage_Record` 和弦/命令执行
- `surface:config_webview_open`
- `cmdpal:open|visible|query|submit|results`
- `surface:intent_open|intent_close|intent_dispose`
- `action:llm_test`
- `action:studio_save`
- `action:diagnostics_export`
- `action:health_snapshot`

原则：

- 只记结果，不记每个 UI 细动作
- 失败优先，成功只做计数
- 只写本机 `Cache/debug/nmer_telemetry.json`
- meta 必须做白名单过滤，只保留不含正文、搜索词、剪贴板内容的安全字段

## P1

- `surface.intent_open`
- `surface.intent_close`
- `surface.intent_dispose`
- `surface.request_coalesced`
- `surface:search_center_open`
- `surface:virtual_keyboard_open`
- `search:search_center_query`

用途：

- 统计 Surface 意图采用率
- 看清楚“是直调多，还是 intent 多”

## P2

- `settings.page_open`
- `settings.tab_switch`
- `diagnostics.open_folder`
- `migration.export/import`

用途：

- 看功能有没有被发现
- 观察入口使用分布，不参与修复决策
