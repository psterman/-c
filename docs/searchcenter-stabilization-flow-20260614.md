# SearchCenter 稳定性修复流程梳理（2026-06-14）

## 目的

本文件只回答两件事：

1. SearchCenter 现在的打开、首屏、热键、全文、关闭链路到底怎么走。
2. 后续修复 blank / 闪动 / 后台劫持按键 / 关闭异常时，哪些点可以安全改，哪些点会影响内存优化方案。

原则：

- 先稳住 SearchCenter UI 生命周期。
- 不直接改 `SearchCenterCore` 的索引策略、租约回收、内存阈值。
- 不把“修空白页”和“改全文常驻策略”混成一个任务。

## 当前链路总览

```text
热键/入口
  -> SearchCenter Intent Queue
  -> SCWV_Show
  -> SCWV_Init / WebView2 创建
  -> html/SearchCenter.html ready
  -> UI_PAINT_READY
  -> Reveal 给用户
  -> 推 init / hostShow / 搜索请求 / 全文状态
  -> 用户交互
  -> requestHostClose / SCWV_Hide
```

对应关键入口：

- AHK 宿主：
  - `modules/SearchCenterWebViewCore.ahk:544` `SCWV_HandleIntent`
  - `modules/SearchCenterWebViewCore.ahk:683` `SCWV_TransitionTo`
  - `modules/SearchCenterWebViewCore.ahk:1146` `SCWV_Init`
  - `modules/SearchCenterWebViewCore.ahk:3830` `SCWV_Show`
  - `modules/SearchCenterWebViewCore.ahk:4109` `SCWV_Hide`
  - `modules/SearchCenterWebViewCore.ahk:4536` `SCWV_ProcessWebMessageJson`
- 前端：
  - `html/SearchCenter.html:3667` `scSendReadyOnce`
  - `html/SearchCenter.html:3681` `requestHostClose`
  - `html/SearchCenter.html:4055` `ensureFulltextBackgroundTasks`
  - `html/SearchCenter.html:9199` `triggerSearch`
  - `html/SearchCenter.html:9508` `keydown`
  - `html/SearchCenter.html:9627` `chrome.webview message`
- 热键：
  - `modules/VirtualKeyboardCore.ahk:3062` `_BindKey`
  - `modules/VirtualKeyboardCore.ahk:3391` `VK_SearchCenterResolveCapsChordCmd`
  - `modules/VirtualKeyboardCore.ahk:3431` `VirtualKeyboard_HandleKey`
  - `modules/VirtualKeyboardCore.ahk:3483` `_VkSearchCenterHostHotIfCb`
  - `modules/VirtualKeyboardCore.ahk:3674` `_VK_RegisterCapsLockDispatchHotkeys`

## 1. 打开链路

### 1.1 入口

入口先进入 intent 队列，再由：

- `SCWV_HandleIntent`
- `SCWV_TransitionTo`

决定进入 `OPENING` 还是 `CLOSED`。

这里已经不是“直接 show 一个窗口”这么简单，而是一个小状态机。

### 1.2 Show 阶段

`SCWV_Show` 负责：

- 必要时触发 `SCWV_Init`
- 判断当前是否可以 reveal
- 先隐藏宿主或先显示壳
- 安排 watchdog：
  - `SCWV_ForceRevealIfStuck`
  - `SCWV_ShowWaitTimeoutCheck`
- 推送 init / hostShow / 搜索请求

这也是 blank、闪动、开窗后加载慢的主要集中点。

### 1.3 风险判断

打开链路当前问题不是单一 bug，而是“阶段太多”：

- init
- ready
- ui ready
- paint ready
- reveal
- deferred search
- fulltext status
- focus/hotkey sync

只要这些阶段彼此抢时序，就容易出现：

- 白屏
- 先闪一个尺寸再稳定
- 焦点已经切走但内部仍认为自己 active

## 2. 首屏渲染链路

### 2.1 AHK 侧判定

首屏 reveal 关键点：

- `modules/SearchCenterWebViewCore.ahk:1217` `SCWV_OnCreated`
- `modules/SearchCenterWebViewCore.ahk:1518` `SCWV_CanRevealToUser`
- `modules/SearchCenterWebViewCore.ahk:1528` `SCWV_TryFinishReveal`
- `modules/SearchCenterWebViewCore.ahk:2171` `SCWV_ForceRevealIfStuck`
- `modules/SearchCenterWebViewCore.ahk:2176` `SCWV_ShowWaitTimeoutCheck`

当前宿主需要同时等：

- WebView created
- 页面 ready
- `UI_PAINT_READY`
- 某些 opening / focus pending 状态结束

### 2.2 前端 ready

前端现在的 ready 是两段：

1. `ready`
2. 两次 `requestAnimationFrame` 之后发 `UI_PAINT_READY`

入口在 `html/SearchCenter.html:3667` `scSendReadyOnce`。

这说明当前系统已经承认：

- “DOM ready” 不等于“用户可见首帧 ready”

这个方向是对的，但现在 reveal 逻辑仍然过于分散。

### 2.3 当前症状对应

最近 trace 里反复出现：

- `show_begin ... ready=0 ui_ready=0`
- `show_wait_ui_ready`
- `force_reveal_skip_not_ready`

说明“空白且无法加载”的核心不是搜索结果慢，而是 reveal 阶段还没真正收敛。

## 3. 数据初始化链路

打开 SearchCenter 后，首屏附近会混入几类工作：

- `init` 状态推送
- 搜索请求
- 搜索历史加载
- 全文状态请求
- 全文 SSE / heartbeat
- 热键绑定同步

对应前端入口：

- `html/SearchCenter.html:3738` `runSearchGoPipeline`
- `html/SearchCenter.html:4055` `ensureFulltextBackgroundTasks`
- `html/SearchCenter.html:4064` `scheduleScHotkeyBindingsSync`
- `html/SearchCenter.html:6077` `requestFulltextStatus`
- `html/SearchCenter.html:9199` `triggerSearch`

结论：

- “打开慢”并不完全等于 SearchCenterCore 慢。
- 很大一部分延迟来自首屏阶段把太多任务叠在一起。

## 4. 热键与按键链路

### 4.1 当前已有收敛

现在已经有两层保护：

1. AHK 侧把部分 SearchCenter 命令改成 host-scoped。
2. 前端 `keydown` 增加 `scHostInputActive()` 判定。

前端关键点：

- `html/SearchCenter.html:4034` `scHostInputActive`
- `html/SearchCenter.html:9508` `document.addEventListener("keydown", ...)`

AHK 关键点：

- `_VK_IsScHostScopedCmd`
- `_VkSearchCenterHostHotIfCb`
- `SCWV_ScCapsInputAllowed`

### 4.2 仍存在的问题

现状更像“部分止血”，还不是完全收口：

- 只有一部分 `sc_*` 命令做了 host gate。
- 全局 `keydown` 监听还在，只是前面多了一层 return。
- 关闭和失焦时，前后端的 active/foreground 状态未必同步。

所以会出现：

- 切走焦点后还吃快捷键
- 面板关不掉时，内部热键仍继续响应

## 5. 关闭链路

前端关闭现在是多次兜底触发：

- `html/SearchCenter.html:3681` `requestHostClose`
- 先发 lifecycle close
- 再发一次 `close`
- 再延时发一次 `close`

AHK 侧在 `SCWV_Hide` 和 web message `close` 分支里也有多层 fallback。

这说明当前“关不掉”不是用户误操作，而是链路本身不够单一：

- 前端想关
- 宿主想保活
- opening/closing 状态机又在拦
- 还有 reveal watchdog/focus pending 在同时工作

## 6. 全文与内存优化边界

### 6.1 哪些属于内存优化主线

以下内容属于 SearchCenterCore 内存治理主线，修 UI bug 时不应直接改动：

- 全文索引根目录策略
- 索引任务冷热分层
- SearchCenterCore 活动租约
- 空闲停索引 / 空闲退出
- soft/hard memory limit
- fulltext reader/writer/cache 回收

对应参考文档：

- `docs/search-memory-index-optimization-plan.md`

### 6.2 哪些属于 UI 稳定性安全区

以下内容可以优先修，而且基本不改变内存方案方向：

- reveal 时机
- 初始化阶段窗口尺寸稳定
- 首屏前不要过早触发非必要前端任务
- 热键 foreground gate
- close ownership 单一化
- blank screen watchdog 判定

这些改动最多影响“何时发请求”，不应改变 SearchCenterCore 的根本资源模型。

## 7. 建议的修复顺序

### P0：先收敛 reveal，不碰索引策略

目标：

- 不再一片空白
- 初始化不闪尺寸

建议动作：

- 把“用户可见 reveal”收敛成单出口，只认 `SCWV_TryFinishReveal`
- `SCWV_Show` 里减少重复 show/hide 切换
- 首帧前固定窗口尺寸，不在 opening 阶段反复重算和 show

### P1：再收紧 foreground / hotkey ownership

目标：

- 后台不再劫持按键
- 切到别的软件后，SearchCenter 不再激活内部快捷方式

建议动作：

- 扩大 AHK 侧 SearchCenter scoped 命令范围
- 统一“允许吃键”的单一判定，前后端共用同一语义
- close / blur 后尽快下发 `hostForeground=false`

### P2：最后处理首屏任务分流

目标：

- 打开后更快有内容
- 不让首屏等待全文状态和后台任务

建议动作：

- 把全文状态、heartbeat、SSE 放到首屏稳定后再起
- 空关键字首页先只加载轻量数据
- 把搜索历史 / 默认结果和 fulltext status 解耦

## 8. 不建议现在做的事

- 不建议为了修 blank screen，直接把 SearchCenterCore 改成打开即拉起或关闭即退出。
- 不建议为了修按键劫持，直接粗暴禁掉所有全局热键。
- 不建议把“文件名搜索 / 全文搜索 / 排序学习”一起重构。
- 不建议在未稳住 reveal 前去动 SearchCenter → Wails host 灰度。

## 9. 当前执行建议

下一步按这个顺序实施最稳：

1. 先修 reveal / 窗口闪动 / 空白页。
2. 再修 foreground 热键劫持与无法关闭。
3. 最后做首屏加载拆分。

这样改动主要留在：

- `modules/SearchCenterWebViewCore.ahk`
- `html/SearchCenter.html`
- `modules/VirtualKeyboardCore.ahk`

并尽量不碰：

- `searchcore/`
- SearchCenterCore 内存治理参数
- 全文索引策略与租约生命周期

