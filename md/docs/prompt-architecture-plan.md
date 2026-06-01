# Prompt 数据整合方案（2026-05-08）

## 1) 现状归纳：分类与来源
- 来源 A：`prompts.json`（用户条目）
- 来源 B：`PromptTemplates.ini`（模板条目）
- 来源 C：`CursorShortcut.ini` + AHK 全局变量（内置快捷提示词内容与默认分类）
- 来源 D：前端本地缓存（最近/高频分类统计）

当前问题：
- 多来源合并导致分类管理分散，易出现编码污染和重复分类。
- 导入导出无法覆盖全部条目（历史上仅覆盖用户 JSON 条目）。
- 后续云同步缺统一快照结构和变更口。

## 2) prompts.json v2 功能策略
采用单一对象结构：

```json
{
  "version": 2,
  "updatedAt": "UTC时间戳",
  "entries": [],
  "settings": {
    "selectedCategory": "全部"
  },
  "sync": {
    "cloudEnabled": false,
    "lastSyncAt": "",
    "syncEndpoint": "pqp://local-sync"
  }
}
```

条目 `entries[]` 统一字段：
- `id`
- `source` (`json|template|builtin`)
- `title`
- `content`
- `category`
- `tags`
- `hotkey`
- `enabled`
- `updatedAt`
- `templateId`（可选）

## 3) 整合规则
- 启动读取时兼容旧格式：
  - 顶层数组：按 legacy 读入并归一化
  - 顶层对象：读取 `entries`
- 运行时统一从 `entries` 渲染列表和分类。
- 仅在首次/兼容期迁移 legacy 来源（模板、内置）到 `entries`，并去重。
- 所有新增/编辑/删除统一写回 `prompts.json`。

## 4) 同步端口（本地 API）
已预留函数：
- `PromptQuickPad_SyncExportSnapshot()`：导出完整快照（v2 对象）
- `PromptQuickPad_SyncImportSnapshot(snapshot, merge := true)`：导入快照（覆盖或合并）
- `PromptQuickPad_SyncGetEntriesSince(utcTs := "")`：按时间戳读取增量

Web 消息端口：
- `syncExport` -> `syncExportResult`
- `syncImport` -> `syncImportResult`
- `syncGetSince` -> `syncSinceResult`

后续接云建议：
- 在 `sync.syncEndpoint` 记录远端地址
- 基于 `updatedAt` 做轻量增量同步
- 冲突策略优先 `updatedAt` 新者覆盖，再按 `id` 合并

