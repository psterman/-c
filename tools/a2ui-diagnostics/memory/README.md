# 内存与索引

SearchCenter 内存基线、索引根策略（P0A）、部署切换、soak 与空闲进程退出（P2）。

**常用**：

- `capture-memory-baseline.ps1` — 当前进程/WebView2 内存快照 → `a2ui_memory_baseline.json`
- `Deploy-MemoryIndexBaseline.ps1` — 重编译 Core/hub、迁移配置、正式签收流程
- `Run-MemorySoakTest.ps1` / `Test-IdleProcessExit.ps1` — 长跑与空闲退出

详见 [`docs/search-memory-index-optimization-plan.md`](../../../docs/search-memory-index-optimization-plan.md)。
