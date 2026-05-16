# SearchCenter 资源验证清单

## 启动

在项目根目录执行：

```powershell
tools\search-diagnostics\start.ps1
```

启动后会自动打开：

`http://127.0.0.1:8765/dashboard.html`

## 能看到什么

- `rg.exe` / `searchcenter.exe` / `SearchCenterCore.exe` 的实时 CPU、内存、存活时长
- 并发搜索任务是否堆叠
- 排除参数覆盖率（用于判断扫描范围是否失控）
- 回压风险（输出速率过大导致主进程处理不过来）
- 近 3 分钟趋势图（内存与 CPU）

## 停止

启动脚本会输出两个 PID，执行：

```powershell
Stop-Process -Id <collector_pid>,<server_pid>
```

## 扫描脚本

```powershell
tools\search-diagnostics\scan-driver.ps1
```

- 批量请求典型查询词（短词/长词/中文/英文/路径/高命中）
- 输出：
  - `tools\search-diagnostics\results\search_scan_*.jsonl`
  - `tools\search-diagnostics\results\search_scan_summary_*.json`

## 压测脚本

```powershell
# smoke 30 秒
tools\search-diagnostics\pressure.ps1 -DurationSec 30 -Concurrency 2 -Qps 8

# baseline 5 分钟
tools\search-diagnostics\pressure.ps1 -DurationSec 300 -Concurrency 4 -Qps 10
```

- 输出：`tools\search-diagnostics\results\search_pressure_*.json`
- 统一字段：`ts` / `scenario` / `metrics` / `errors`
