package main

import (
	"embed"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
	"github.com/wailsapp/wails/v2/pkg/options/windows"
)

//go:embed all:frontend/dist
var assets embed.FS

func main() {
	app := NewApp()

	err := wails.Run(&options.App{
		Title:            "NMER Wails Input",
		Width:            760,
		Height:           76,
		MinWidth:         760,
		MinHeight:        76,
		DisableResize:    true,
		Frameless:        true,
		AlwaysOnTop:      true,
		AssetServer:      &assetserver.Options{Assets: assets},
		// 窗体透明，仅 Web 内 .raycast-palette 卡片不透明（悬浮无黑底）
		BackgroundColour: &options.RGBA{R: 0, G: 0, B: 0, A: 0},
		Windows: &windows.Options{
			WebviewIsTransparent: true,
			WindowIsTranslucent:  false,
			BackdropType:         windows.None,
		},
		OnStartup:  app.startup,
		OnShutdown: app.shutdown,
		Bind: []interface{}{
			app,
		},
	})

	if err != nil {
		println("Error:", err.Error())
	}
}
