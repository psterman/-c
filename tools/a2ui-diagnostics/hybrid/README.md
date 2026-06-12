# Hybrid 终验

Hybrid 模式下的运行态签收：Wails 桥、FTB、命令面板 hello 注入、UI 环、Hub 链、周期恢复。

**入口**：`Run-HybridSignoff.ps1`（根目录 Shim 同名可用）

**前提**：牛马已启动且 Hybrid 配置已开；部分步骤通过 `Cache/debug/hybrid_manual_probe.json` 与 AHK 文件 IPC 交互。

**输出**：`Cache/debug/hybrid_signoff_dashboard.json`、`hybrid_manual_signoff.json` 等。
