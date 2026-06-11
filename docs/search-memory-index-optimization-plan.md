# 搜索、内存与 Hybrid 侧车优化计划（修订版）

## 1. 验收结论

原方案方向正确，但不应直接进入四周实施。当前需要先修正若干配置和验收问题，否则会出现“配置看似关闭全盘索引，运行时仍扫描全盘”或“为了降内存破坏全文搜索可用性”的情况。

建议判定：

- 方向正确：Everything 负责文件发现，Bluge 负责全文索引，Go Hub 替代 Wails bridge-only。
- 实施顺序需调整：索引范围正确性和可观测性必须先于生命周期回收。
- `SearchCenterCore` 不能简单绑定搜索窗口开关。它同时提供查询、剪贴板和全文接口，退出条件必须基于活动任务和所有客户端，而不是单个 UI。
- `800 MiB` 只能作为初始观察阈值，不能直接作为无条件重启线。
- WebView2 进程数受 Edge 运行时版本和进程模型影响，不能把 `<= 4` 作为唯一硬门禁。

## 2. 已确认的实现问题

### P0-1 `autoDiscoverRoots:false` 当前无法生效

`mergeFullTextFilterConfig` 使用：

```go
out.AutoDiscoverRoots = override.AutoDiscoverRoots || out.AutoDiscoverRoots
```

默认值为 `true` 时，配置中的 `false` 无法覆盖它。应把布尔配置改为 `*bool` 或自定义可选布尔值，区分“未填写”和“明确关闭”。

### P0-2 显式根目录会再次被全 NTFS 盘覆盖

`fullTextRoots` 已经尊重 `knowledgeRoots`，但 `loadFullTextConfig` 随后调用 `mergeAnyTXTRoots`，重新把所有 NTFS 卷根加入扫描范围。显式根目录必须拥有最高优先级：

1. `knowledgeRoots` 非空：只使用这些根。
2. 环境变量根非空：只使用环境变量根。
3. `autoDiscoverRoots=true`：才允许发现盘符。
4. 都没有时：使用工作区目录，不得自动扩成所有卷。

### P0-3 文件大小配置没有形成一致预算

`shouldIndexByColdPath` 当前直接返回 `true`。`MaxFileSizeBytes` 因而没有在候选阶段生效；普通文本读取又主要使用 `HardReadLimit`，PDF/DOCX还有单独例外。

应统一为三道限制：

- `candidateMaxBytes`：文件是否进入解析队列。
- `extractReadMaxBytes`：解析器最多读取多少原始数据。
- `indexedTextMaxBytes`：抽取后最多写入多少文本。

默认建议：

| 类型 | candidate | extract/read | indexed text |
|---|---:|---:|---:|
| txt/md/code/json/csv | 4 MiB | 4 MiB | 2 MiB |
| docx/xlsx | 16 MiB | 16 MiB | 2 MiB |
| 文本 PDF | 32 MiB | 32 MiB | 2 MiB |
| OCR | 默认关闭 | 独立任务预算 | 1 MiB |

不要简单把统一硬限制设为 4 MiB，否则会丢失大量正常 Office/PDF 文档。

### P0-4 非系统盘会重复执行补充扫描

`scanInitialRoot` 对非系统卷根无条件运行 supplemental scan。主扫描成功后再次 Everything 枚举没有必要。补充扫描只应在以下条件触发：

- 主扫描失败；
- 主扫描返回 0；
- 与 Everything 预估数量差异超过阈值。

### P0-5 当前内存口径漏算 AHK

`capture-memory-baseline.ps1` 当前总量为：

```text
scoped WebView2 + nmer-wails + SearchCenterCore
```

必须加入 AHK host，并分别记录：

- `privateMiB`：主门禁；
- `workingSetMiB`：观察；
- `goHeapAllocMiB`、`goHeapSysMiB`：解释 Go 堆；
- `indexMappedMiB`：解释索引映射；
- 每个 WebView 宿主的数据目录和进程树。

## 3. 目标架构

```text
AHK / Search UI
       |
       +-- 文件名查询 ----------> Everything IPC
       |
       +-- 全文查询 ------------> SearchCenterCore query service
                                      |
                                      +-- Bluge index (持久化)
                                      +-- metadata (path/size/mtime/hash)
                                      |
                                      +-- disposable index workers
                                            +-- hot text parser
                                            +-- Office/PDF parser
                                            +-- optional OCR worker

AHK FloatingToolbar
       |
       +-- WebSocket/HTTP -------> nmer-hub.exe (纯 Go，无 WebView)
                                      |
                                      +-- OpenClaw adapter
                                      +-- shell_ftb
                                      +-- A2UI ingest/egress
```

Everything 只负责快速得到路径候选，不承担内容索引。全文仍由 Bluge 完成，这一点与 AnyTXT 类方案一致。

## 4. 实施阶段

### P0 正确性与测量（2-4 天）

1. 修复 `autoDiscoverRoots` 的可选布尔合并。
2. 删除 `mergeAnyTXTRoots` 对显式根目录的覆盖。
3. 让 `shouldIndexByColdPath` 真正执行扩展名、路径和候选大小策略。
4. 去掉成功扫描后的无条件 supplemental scan。
5. 统一 AHK 显示默认值与 Go 运行默认值，避免 UI 显示 2 MiB、Go 实际使用 8 MiB。
6. 内存基线纳入 AHK host。
7. 增加 1/5/20 卡片采样脚本和 30 分钟 soak 脚本。

P0 验收：

- `knowledgeRoots` 非空时，日志不得出现未配置盘符根。
- `autoDiscoverRoots:false` 有自动化测试。
- 大小策略对 txt/docx/pdf 分别有边界测试。
- 内存 JSON 的组件和等于总量，误差小于 1 MiB。

### P1 AnyTXT 式全文索引管线（1-2 周）

#### 文件发现

- 初次发现优先使用 Everything IPC。
- Everything 不可用时，只允许对配置根执行 `WalkDir`。
- MFT/USN 作为可选能力，不再作为自动全盘回退。
- 当前机器 USN probe 失败时必须禁用，避免持续失败和回退。

#### 增量更新

- 保留已存在的 path/size/mtime/fast-hash 元数据。
- 文件系统 watcher 用于低延迟更新。
- 每 10-30 分钟通过 Everything 对配置根做轻量差异校验，弥补 watcher 丢事件。
- USN 可用时只作为增量事件来源，事件进入配置根过滤后再处理。

#### 分层解析

- Hot：txt/md/code/json/csv，立即或短延迟处理。
- Cold：docx/xlsx/pdf，仅在系统空闲或手动触发时处理。
- OCR：单独队列、单 worker、默认关闭，不能阻塞普通全文索引。
- 每个解析任务有超时、最大输出、失败退避和隔离日志。

#### 查询

- 查询只访问已提交索引，不在请求链现场解析原文件。
- snippet 从索引字段生成；全文预览按需读取。
- 限制命中数、snippet 数量和单条长度，保持现有前端瘦身策略。

P1 验收：

- 初扫无 C:/D:/E: 全盘 `WalkDir`。
- 查询期间没有 Office/PDF 解析子任务。
- 文件新增、修改、删除可在目标时限内反映。
- 重启后不进行无条件全量重建。

### P2 生命周期与内存回收（3-5 天）

不要在搜索窗口关闭时立即停止 `SearchCenterCore`。改用活动租约：

- 查询请求持有短租约。
- 索引队列、写批次、SSE 状态订阅持有任务租约。
- 所有租约释放且空闲 5 分钟后，停止 indexer、关闭 reader/writer/cache。
- 再空闲 10 分钟后，允许整个进程退出；任一客户端下次请求时由 AHK 拉起。

内存回收分两级：

- Soft limit：例如 `600 MiB`，仅在无写任务时关闭缓存 reader、执行 GC，并记录回收前后值。
- Hard limit：例如 `900 MiB` 且持续 3 次采样，只在批次已提交、没有活跃查询时优雅退出。
- 重启采用指数退避，防止索引较大时反复重启。

阈值需在加入 Go heap、mmap 和组件归因后校准，不能预先把 `800 MiB` 当成泄漏结论。

### P3 纯 Go Hub（1 周）

`apps/nmer-wails/poc` 当前不依赖 Wails runtime，可以先在同一 Go module 中增加纯 Go 入口，无需第一步就搬包：

```text
apps/nmer-wails/cmd/nmer-hub/main.go
```

该入口直接创建 `poc.NewHub`，不调用 `wails.Run`。后续再根据边界稳定情况迁移到 `pkg/nmerhub`。

AHK bridge 按顺序寻找：

1. `nmer-hub.exe`
2. `nmer-wails.exe` bridge-only（回滚兼容）

P3 验收：

- hybrid 模式不启动 `nmer-wails.exe`。
- Hub 不产生 `msedgewebview2.exe`。
- `:18791` health、inject、egress、OpenClaw 流式回复全部通过。
- CommandPalette 的 `hello` 不出现 `deliver_ready_timeout`。

### P4 FTB 拆分（1-2 周）

1. OpenClaw 会话和重连迁入 Hub。
2. Browser Agent 首次使用时动态加载。
3. `_paletteAgent*` 按 cardId 做 LRU，默认最多 20 个会话。
4. 聊天列表使用虚拟化或 DOM 上限。
5. 会话持久化批量、节流写入。

## 5. 门禁修订

WebView2 门禁采用双指标：

- `hostWebviewCount`：由应用创建的 WebView 控件数量，固定预算；
- `scopedWebViewProcessCount`：仅作兼容观察，不因 Edge 版本波动直接判死；
- `scopedWebViewPrivateMiB`：内存硬门禁。

建议初始目标：

| 指标 | 阶段目标 |
|---|---:|
| hybrid Hub 新增 WebView | 0 |
| nmer-hub Private | <= 50 MiB |
| SearchCore 无活动任务 | 进程退出，或 <= 150 MiB |
| SearchCore 索引中 | 建立机器基线后下降 >= 30% |
| hybrid 相对 pure-AHK 增量 | <= 80 MiB |
| 30 分钟空闲内存斜率 | <= 1 MiB/分钟 |
| 10 轮开关后的恢复 | 回到初始空载 + 10% 内 |

不建议在迁移前直接要求 scoped WebView2 进程 `<= 4`。应先去掉 Wails Chromium 栈，再根据真实进程模型收紧。

## 6. 推荐顺序

| 周次 | 主路径 |
|---|---|
| W1 | P0 根目录、布尔配置、大小预算、内存归因 |
| W2 | P1 Everything 发现、差异校验、分层解析 |
| W3 | P2 活动租约、空闲关闭、软硬内存阈值 |
| W4 | P3 nmer-hub 纯 Go 入口与 AHK 切换 |
| W5 | P4 OpenClaw/Browser Agent/DOM 状态治理 |

## 7. 终验标准

终验必须同时满足：

- 配置根之外没有全盘遍历。
- 文件名搜索和全文搜索均可用。
- 初扫、增量、删除、重启恢复测试通过。
- hybrid 模式不再附带 Wails WebView。
- 空载内存包含 AHK 后仍达到目标。
- 长时间运行没有持续正向内存斜率。
- CP、FTB、OpenClaw 链路不因 SearchCore 或 Hub 回收而失联。

## 8. v4 已落地实现（RootPolicy / 三态契约 / 索引生命周期）

- `searchcore/root_policy.go`：`ResolveRoots` 为唯一根解析入口；`knowledgeRoots` + `rootsConfirmedAt` 记住向导选择；`autoDiscoverRoots` 使用 `*bool`。
- `searchcore/discovery_contract.go`：窄根 `walk_fallback`、盘符根 `degraded/skipped`、配置空 `setup_required` 三态分离。
- API：`GET/POST /v1/fulltext/roots`、`POST /v1/fulltext/roots/confirm`、`GET /v1/fulltext/memory`。
- `searchcore/index_lifecycle.go`：`manifest.json` + `active`/`legacy_readonly`/`building` 角色；避免 `version.tag` 不匹配时无脑 wipe。
- `apps/nmer-hub`：纯 Go Hub（无 WebView2）；hybrid 模式优先启动 `nmer-hub.exe`。
- 门禁脚本：`capture-memory-baseline.ps1` 纳入 AHK + 固定 WebView cap；`Run-MemorySoakTest.ps1` 分级斜率验收。
- P2 内存治理：`memory_governor_windows.go` 每 30s 采样；软限 600 MiB 回收 reader/meta/GC；硬限 900 MiB 连续 3 次且空闲停索引后 `os.Exit(0)`。
- 运行态切换：`tools/a2ui-diagnostics/Deploy-MemoryIndexBaseline.ps1`（重编译 Core/hub、迁移 `Data/search/*.json`、重启进程、采样 P0B/P0C）。

### 运行态签收命令

```powershell
# 重载牛马前可先执行（会短暂停止 SearchCenterCore / 切换 hub）
.\tools\a2ui-diagnostics\Deploy-MemoryIndexBaseline.ps1

# 仅重采样（索引空闲段斜率）
.\tools\a2ui-diagnostics\Run-MemorySoakTest.ps1 -PauseIndexerForIdleSlope -DurationMinutes 30

# P2 空闲进程退出（Quick 约 2 分钟；正式 15+ 分钟，期间勿开牛马 SSE/搜索）
.\tools\a2ui-diagnostics\Test-IdleProcessExit.ps1 -Quick
```

签收看 `Cache/debug/a2ui_memory_baseline.json`、`Cache/debug/memory_soak.json` 与 `Cache/debug/p2_idle_process_exit.json`。
