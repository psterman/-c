# Drop 事件诊断面板

启动：

```powershell
tools\drop-diagnostics\start.ps1
```

作用：

- 实时显示 `Cache\native_drop_events.jsonl` 里的桥接事件
- 实时显示 `Cache\drop_diagnostics_runtime.log` 里的 AHK 路由事件
- 快速判断“事件没到”还是“事件到了但洞没显示”

停止：

```powershell
Stop-Process -Id <server_pid>
```

## 事件探针脚本

```powershell
tools\drop-diagnostics\probe.ps1
```

- 统计 `Cache\native_drop_events.jsonl` 与 `Cache\drop_diagnostics_runtime.log`
- 输出：`tools\drop-diagnostics\results\drop_probe_*.json`
- 指标包含：到达数、丢失率、乱序数、近似延迟

## 压测脚本

```powershell
# smoke 30 秒
tools\drop-diagnostics\pressure.ps1 -DurationSec 30 -EventsPerSec 20

# baseline 5 分钟
tools\drop-diagnostics\pressure.ps1 -DurationSec 300 -EventsPerSec 30
```

- 输出：`tools\drop-diagnostics\results\drop_pressure_*.json`
- 统一字段：`ts` / `scenario` / `metrics` / `errors`
