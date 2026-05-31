# AHK -> Wails Hole Overlay Frontend Bridge

洞前端已暴露 JS API：`window.HoleOverlay`

## 可调用方法

- `window.HoleOverlay.show(payload)`
- `window.HoleOverlay.update({ payload, proximity, x, y })`
- `window.HoleOverlay.drop({ payload })`
- `window.HoleOverlay.hide()`

参数说明：

- `payload`: `"file" | "text"`
- `proximity`: `0.0 ~ 1.0`（可选，若不传可用 `x,y` 计算）
- `x`, `y`: 屏幕坐标（可选）

## 推荐触发策略（AHK 预判）

1. 识别拖拽开始（文件/文本） -> 调 `show(payload)`
2. 拖拽移动 -> 周期调 `update({ payload, x, y })`
3. 松手完成 -> 调 `drop({ payload })`
4. 取消或离开 -> 调 `hide()`

## AHK 伪代码示例

```ahk
; 你已有 WebView2 对象时，执行 JS:
wv.ExecuteScript("window.HoleOverlay?.show('file')")
wv.ExecuteScript("window.HoleOverlay?.update({ payload: 'file', x: 960, y: 860 })")
wv.ExecuteScript("window.HoleOverlay?.drop({ payload: 'file' })")
wv.ExecuteScript("window.HoleOverlay?.hide()")
```

说明：若你已在 AHK 侧算好距离强度，可直接传 `proximity`，避免前端重复计算。
