package main

import (
	"embed"
	"os"
	"strings"

	"github.com/wailsapp/wails/v2"
	"github.com/wailsapp/wails/v2/pkg/options"
	"github.com/wailsapp/wails/v2/pkg/options/assetserver"
)

// buildMode is set via -ldflags at release build; default "shell" for dev baseline.
var buildMode = "shell"

//go:embed all:frontend/dist
var assets embed.FS

func main() {
	app := NewApp()
	bridgeOnly := strings.TrimSpace(os.Getenv("NMER_BRIDGE_ONLY")) == "1"
	title := "NMER Wails POC"
	if bridgeOnly {
		title = "NMER Bridge"
	}

	err := wails.Run(&options.App{
		Title:            title,
		Width:            960,
		Height:           720,
		StartHidden:      bridgeOnly,
		AssetServer: &assetserver.Options{
			Assets: assets,
		},
		BackgroundColour: &options.RGBA{R: 15, G: 22, B: 34, A: 1},
		OnStartup:        app.startup,
		OnShutdown:       app.shutdown,
		Bind: []interface{}{
			app,
		},
	})

	if err != nil {
		println("Error:", err.Error())
	}
}
