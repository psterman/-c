# 牛马 - Cursor 编辑器效率神器
<div align="center">
  <img src="../banner.jpg" alt="牛马" width="800">
</div>

[English](readme.en.md) | 简体中文

> **开发者**：首次参与定制或改仓库前请阅读 [AGENTS.md](AGENTS.md) 与 [混栈治理手册](../docs/stack-governance.md)。`local/` 下已存在配置**不会**在启动时被自动覆盖（仅缺失时迁移）。本地门禁：`tools/dev/Run-DevMenu.ps1` 或 `Run-MinimalGate -Strict`；文档中未经验证的说明请自行核对。
>
> **企业 / 运维**（密钥 DPAPI、导出 zip、清理）：[docs/nmer-enterprise-ops.md](../docs/nmer-enterprise-ops.md)

为 <a href="https://cursor.sh/" target="_blank">Cursor</a> 编辑器打造的 Windows 效率神器！通过「CapsLock 牛马召唤器」快捷键方案，让 Cursor 做牛做马，替你扛下繁琐工作，编程效率狂飙 100%～

## ✨ 牛马核心特色
- 🚀 **CapsLock 召唤器**：短按保持大小写切换功能，长按 0.5s 调出牛马快捷面板，贴心不添乱
- ⚡ **零延迟响应**：所有操作即时反馈，使唤牛马不等待
- 🎨 **Cursor 同源风格**：深色主题无缝融合，牛马也懂颜值控
- 📋 **牛马记忆剪贴板**：连续复制、合并粘贴、历史管理，素材收集不费劲
- 🤖 **AI 牛马打工魂**：一键让 Cursor 解释、重构、优化代码，不用手动敲提示词
- ⚙️ **高度可调教**：自定义提示词、快捷键、面板位置，打造专属贴心牛马

## 🎯 牛马核心功能
### 1. 代码操作打工面板
- **长按 CapsLock** 召唤牛马快捷面板
- **CapsLock + E**：代码翻译官（牛马用新手能懂的话讲清核心逻辑、易错点）
- **CapsLock + R**：代码规整师（按规范重构、添加注释，牛马式整理）
- **CapsLock + O**：代码加速器（分析性能瓶颈，给出优化方案）
- **CapsLock + S**：代码分割工（插入分割标记，方便批量处理）
- **CapsLock + B**：批量打工模式（一次性处理多个代码块，牛马高效摸鱼...啊不，干活）

### 2. 连续复制 + 合并粘贴
- **CapsLock + C**：牛马记忆收集（连续复制多个片段，静默操作不打扰）
- **CapsLock + V**：牛马整理输出（自动用空格/换行符合并内容，粘贴到 Cursor）
- **CapsLock + X**：记忆管理面板（查看所有复制历史，按需取用）

### 3. 牛马记忆管理面板
- 📋 预览所有复制历史，一目了然
- 🔄 双击快速召回，不用重复复制
- ✂️ 删除无用记忆，减轻牛马负担
- 📤 直接粘贴选中内容到 Cursor，一步到位
- 🗑️ 一键清空记录，让牛马喝下孟婆汤

### 4. 调教牛马面板（CapsLock + Q）
- 📁 指定 Cursor 安装路径，让牛马找对主人
- ⏱️ 调整 AI 响应等待时间，适配不同配置电脑
- 💬 自定义PUA话术（修改解释/重构/优化提示词）
- ⌨️ 重设快捷键，避免冲突不闹心（**设置 → 快捷键 → 唤起与冲突**：保存时自动检测冲突）
- 🖥️ 多屏幕支持，自定义面板显示位置

## 📥 召唤牛马方式
### 方式一：便携包（推荐）
1. 访问 [Releases](https://github.com/psterman/nmer/releases) 页面
2. 下载最新版 `牛马-nmer-*-portable.zip`，解压到固定目录（建议：`D:\Tools\牛马\`）
3. 安装 [AutoHotkey v2](https://www.autohotkey.com/download/ahk-v2.exe) 与 [WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/)（Win10/11 通常已自带）
4. 双击解压目录中的 **`牛马.ahk`** 启动

便携包已包含 Everything、ttyd、SearchCenterCore、WebView2Loader 等运行时依赖，无需单独下载。

### 方式二：仅下载主脚本
若已有完整目录结构，可只更新 `牛马.ahk` 与 `modules/` 等变更文件。

### 方式三：安装 exe 懒人包版本
（见 Releases 中的 exe 构建，如有提供）

## 📁 目录说明

| 目录/文件 | 用途 |
|----------|------|
| `牛马.ahk` | **主入口**，双击启动 |
| `modules/` | 功能模块（AHK + 注入 JS），一般无需修改 |
| `html/` | WebView2 界面面板（SearchCenter、Settings、Niuma Chat 等） |
| `assets/` | WebView 静态资源（JS、图标、图片） |
| `lib/` | 第三方 AHK 库与运行时 DLL |
| `searchcore/` | Go 搜索内核（含 `SearchCenterCore.exe`） |
| `tools/` | 桥接工具、诊断脚本、rg/openlist 等 |
| `config/user_studio.defaults.json` | 智能定制模板；首次打开设置页会在 `local/` 生成本地 `user_studio.json` |
| `local/` | 用户私有数据（主配置、OpenClaw 状态）；**API Key 经 DPAPI 存 `secrets.vault.json`**，`user_studio.json` 无明文，勿提交 Git |
| `Data/` | 运行时数据（截图、Chat 附件等），可备份 |
| `Cache/` | 日志与缓存，可定期清空（不含 OpenClaw 状态） |
| `md/` | 项目文档（README、AGENTS、软件介绍、技术 docs） |
| `md/docs/` | 开发者/高级用户技术说明 |
| `archive/` | **保留目录，当前为空**；历史原型（如旧 Wails toolbar）已从 Git 删除，见 [`docs/wails-migration-boundary.md`](../docs/wails-migration-boundary.md)。仍在用的 Legacy 实现位于 `modules/Legacy*.ahk`，由 CI 白名单约束，**不在** `archive/` |

更完整的架构说明见 [软件介绍.md](软件介绍.md)。

## 🔧 牛马上岗准备
### 基础要求
- **操作系统**：Windows 10/11（牛马只认 Windows 老家）
- **AutoHotkey**：v2.0 或更高版本（牛马的口粮，必须安排）
- **WebView2 Runtime**：界面渲染依赖（多数 Win10/11 已预装）
- **Cursor 编辑器**：已安装并能正常运行（余粮也不能缺席）
- **Everything**（可选）：全局文件搜索加速；便携包已内置 `Everything.exe`

### 安装牛马口粮（AutoHotkey v2）
1. **下载口粮**：访问 [AutoHotkey 官网](https://www.autohotkey.com/)，[下载并安装 v2 版本](https://www.autohotkey.com/download/ahk-v2.exe)
2. **绑定口粮（可选）**：
   - 右键 `牛马.ahk` 文件 → 「打开方式」→ 选择 AutoHotkey
   - 勾选「始终使用此应用打开」，下次直接召唤

## 📦 调教牛马步骤
### 步骤 1：安置牛马
将便携包解压到固定目录（建议：`D:\Tools\牛马\`），或把 `牛马.ahk` 与 `modules/`、`lib/` 等目录放在同一文件夹下。

### 步骤 2：首次唤醒
1. 双击 `牛马.ahk` 文件
2. 提示获取管理员权限时，点击「是」（牛马需要权限才能监听指令）
3. 首次启动会在 `local/` 生成 `CursorShortcut.ini`，记录你的调教偏好（旧版根目录配置会自动迁入）
4. 首次使用「智能定制」（CapsLock + Q）时，会基于 `config/user_studio.defaults.json` 在 `local/` 生成本地 `user_studio.json`

### 步骤 3：指定主人（Cursor 路径）
1. 右键系统托盘中的牛马图标
2. 选择「打开配置面板」或者尝试按 `CapsLock + Q`
3. 若 Cursor 不在默认路径，点击「浏览」选中 `Cursor.exe`
4. 点击「保存配置」，牛马从此认你为主

### 步骤 4：设置牛马随叫随到（开机自启，可选）
1. 按 `Win + R` 打开运行框，输入 `shell:startup` 回车打开启动文件夹
2. 长按ctrl+alt+左键，将 `牛马.ahk` 的快捷方式复制到启动文件夹
3. 或用任务计划程序设置，开机自动唤醒牛马

## 🚀 使唤牛马快速指南
### 1. 让牛马解释代码
- 在 Cursor 中选中目标代码
- 长按 `CapsLock` 召唤面板，按 `E` 键
- 牛马自动复制代码 + 填入提示词 + 发送给 Cursor，坐等结果

### 2. 让牛马收集素材
- 选中第一段文本 → 按 `CapsLock + C`
- 选中第二段文本 → 按 `CapsLock + C`
- 重复收集...
- 在cursor输入框按 `CapsLock + V` 合并粘贴到 Cursor，完美！

### 3. 管理牛马记忆
- 按 `CapsLock + X` 打开记忆面板
- 双击需要的内容快速复制
- 用底部按钮删除/清空，按需操作
- 查找复制记忆精准

### 牛马指令大全（快捷键）
| 快捷键 | 功能描述 |
|--------|----------|
| `长按 CapsLock` | 召唤牛马快捷面板 |
| `CapsLock + E` | 解释代码（牛马翻译官） |
| `CapsLock + R` | 重构代码（牛马规划师） |
| `CapsLock + O` | 优化代码（牛马加速器） |
| `CapsLock + S` | 分割代码（牛马分割工） |
| `CapsLock + B` | 批量操作（牛马流水线） |
| `CapsLock + C` | 连续复制（牛马记忆收集） |
| `CapsLock + V` | 合并粘贴（合并整理输出） |
| `CapsLock + X` | 打开记忆面板（牛马备忘录） |
| `CapsLock + Q` | 打开调教面板（牛马后台设置） |
| `ESC` | 关闭面板（让牛马待命） |

## ⚠️ 牛马罢工排查

**优先用图形界面，不必手改 ini。**

| 入口 | 能做什么 |
|------|----------|
| **CapsLock + Q** → 设置 → **通用设置 → 故障排查** | 打开日志、复制最近日志、导出诊断包、跳健康快照 / 快捷键页、恢复默认 |
| **托盘图标右键** | 「系统健康」「导出诊断包」「健康详情」 |
| **设置 → 高级 → 系统健康** | 侧车 / Surface 只读快照 |

运行日志默认写在 `Cache/debug/nmer_trace.log`（会话 ID 见文件内时间戳）。

### 常见问题（GUI 对应操作）

#### 1. 牛马唤醒失败（双击无反应）
- 确认已安装 **AutoHotkey v2**，右键「以管理员身份运行」`牛马.ahk`
- 设置 → 故障排查 → **健康快照**，看侧车是否未运行
- 仍失败 → **导出诊断包** 发给开发者

#### 2. 反复要求管理员权限
- 正常现象（需监听键盘）。`牛马.ahk` 属性 → 兼容性 → 勾选「以管理员身份运行」

#### 3. 召唤后 Cursor 无反应
- 设置 → **通用设置** 检查 Cursor 路径
- 设置 → **高级** 将 AI 等待时间调到约 15 秒

#### 4. 快捷键冲突（牛马不听指令）
- 设置 → **故障排查 → 快捷键冲突**（或快捷键页 CapsLock 和弦层开关）
- 保存时会探测主键占用；可暂时**熄灭和弦层**，双击 CapsLock 仍可开命令面板

#### 5. 记忆面板打不开（CapsLock + X 无反应）
- 先用 CapsLock + C 复制过内容；看托盘是否有牛马图标
- 托盘 → **重启脚本**

#### 6. 面板显示位置不对
- 设置 → **外观设置** → 弹窗位置 / 面板屏幕

### 出错弹窗怎么办？

程序崩溃时会弹出带按钮的对话框（不再只有纯 MsgBox）：
- **复制报告** — 含错误栈 + 最近 `nmer_trace.log` 片段
- **打开日志目录** / **导出诊断包** — 打包 `Cache/debug` 下文件

### 深度调教（仍可用，非首选）

1. 日志：`Cache/debug/nmer_trace.log` 及同目录其它 `*.log`
2. 配置：`local/CursorShortcut.ini`（设置内「恢复默认」更安全）
3. 换机 / 备份：设置 → **存储与缓存 → 数据迁移**
4. 企业排障：[docs/nmer-enterprise-ops.md](../docs/nmer-enterprise-ops.md)

> **自动上报**：当前版本无云端遥测；请用「复制报告」或「导出诊断包」手动提交 Issue。

## 🛠️ 高级调教技巧
### 自定义打工话术
在调教面板中修改 3 类提示词，让牛马按你的风格干活：
- 解释代码提示词：控制牛马的解释语气（比如更详细/更简洁）
- 重构代码提示词：指定代码规范（比如 PEP8/公司编码标准）
- 优化代码提示词：强调优化方向（比如速度优先/内存优先）

### 性能调教
- **AI 响应等待时间**：
  - 低配机：建议 20000ms（给牛马足够干活时间）
  - 高配机：建议 10000-15000ms（牛马干活快，不用等）
  - 默认：15000ms（平衡配置）

### 多屏幕调教
- 支持多屏幕环境，在调教面板选择目标屏幕
- 面板自动居中显示，不用担心找不到牛马

## 📝 牛马进化日志
### v1.0.0
- ✨ 初始版本发布，牛马正式上岗
- ✨ CapsLock 召唤器功能
- ✨ 代码解释/重构/优化打工技能
- ✨ 连续复制 + 合并粘贴记忆功能
- ✨ 记忆管理面板
- ✨ 调教面板（自定义设置）
- ✨ 多屏幕支持

## 🤝 调教牛马贡献
欢迎提交 Issue 和 Pull Request，一起优化牛马技能，让它更懂程序员的心！

## 📄 牛马版权声明
本项目采用 **Apache License 2.0** 开源许可证。

### 你可以：
- ✅ **自由使用**：个人、商业用途均可，无限制
- ✅ **修改代码**：根据需求自由定制、修改源码
- ✅ **分发传播**：可自由分享、分发原始或修改后的版本
- ✅ **商用授权**：允许将项目集成到商业产品中
- ✅ **专利授权**：获得贡献者的专利使用授权（需遵循许可证条款）

### 你需要遵守：
- ⚠️ **保留声明**：必须保留原始版权声明、许可证文本和作者声明
- ⚠️ **明确标注**：修改后的版本需明确标注修改内容和修改时间
- ⚠️ **免责声明**：不得移除许可证中的免责声明和责任限制条款

### 详细条款
请访问 [Apache License 2.0 官方页面](https://www.apache.org/licenses/LICENSE-2.0) 查看完整法律条款。
[![AutoHotkey v2](https://img.shields.io/badge/AutoHotkey-v2-blue.svg)](https://www.autohotkey.com/)

## 🙏 致谢
- [AutoHotkey](https://www.autohotkey.com/) - 牛马的生存基础，强大的 Windows 自动化工具
- [Cursor](https://cursor.sh/) - 牛马的主人，优秀的 AI 代码编辑器（被 millions 开发者信任，Stripe/OpenAI 都在用）
- [capslock+](https://github.com/wo52616111/capslock-plus/) - 灵感来源之一，wo52616111 capslock-plus作者
- [SQLiteDB] (https://www.autohotkey.com/boards/viewtopic.php?t=95389) -  感谢justme 的SQLite 数据库的功能，方便牛马记忆管理
- 所有调教牛马的新老贡献者和用户，我们会越来越强！

## 📮 联系牛马饲养员
- **Issues**：[GitHub Issues](https://github.com/psterman/nmer/issues)（反馈问题，让牛马改进）
- 扫微信码加好友，一起探讨御牛马术：

<img width="950" height="1296" alt="mmqrcode1765714128545" src="https://github.com/user-attachments/assets/68b79c9f-1311-4762-811a-4bbad9b4997a" />

**⭐ 如果牛马对你有帮助，请给个 Star 鼓励一下吧！**
