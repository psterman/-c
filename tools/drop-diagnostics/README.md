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
