package main

import (
	"context"
	"log"
	"os"
	"strings"
	"sync"

	"github.com/wailsapp/wails/v2/pkg/runtime"

	"nmer-wails/poc"
)

const shellVersion = "0.1.0-poc"

// AppInfo is exposed to the frontend via Wails bindings.
type AppInfo struct {
	AppName    string `json:"appName"`
	Version    string `json:"version"`
	BuildMode  string `json:"buildMode"`
	BridgeOnly bool   `json:"bridgeOnly"`
}

// App is the Wails shell application struct.
type App struct {
	ctx context.Context
	hub *poc.Hub

	mu sync.Mutex
}

// NewApp creates a new App application struct.
func NewApp() *App {
	return &App{}
}

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
	hubAddr := strings.TrimSpace(os.Getenv("NMER_A2UI_BRIDGE_ADDR"))
	if hubAddr == "" {
		hubAddr = poc.DefaultWSAddr
	}
	a.hub = poc.NewHub(hubAddr, poc.DefaultWSPath, a.onAgentEvent, a.onHubStatus)
	provider, providerName, providerErr := poc.NewA2UIProvider(poc.A2UIProviderConfigFromEnv())
	if providerErr != nil {
		log.Printf("[a2ui-provider] config rejected, keeping fake provider: %v", providerErr)
	} else {
		a.hub.SetA2UIProvider(providerName, provider)
	}
	if err := a.hub.Start(ctx); err != nil {
		log.Printf("[poc-hub] start failed: %v", err)
	}
	a.onHubStatus(a.hub.Status())
	a.hub.SetShellFtbEmit(func(event string, payload interface{}) {
		if a.ctx != nil {
			runtime.EventsEmit(a.ctx, event, payload)
		}
	})
}

func (a *App) onAgentEvent(ev poc.AgentEvent) {
	if a.ctx == nil {
		return
	}
	runtime.EventsEmit(a.ctx, "ws:agent_event", ev)
}

func (a *App) onHubStatus(st poc.HubStatus) {
	if a.ctx == nil {
		return
	}
	runtime.EventsEmit(a.ctx, "ws:hub_status", st)
}

// GetAppInfo returns minimal shell metadata for the frontend ready banner.
func (a *App) GetAppInfo() AppInfo {
	bridgeOnly := strings.TrimSpace(os.Getenv("NMER_BRIDGE_ONLY")) == "1"
	appName := "NMER Wails POC"
	if bridgeOnly {
		appName = "NMER Bridge"
	}
	return AppInfo{
		AppName:    appName,
		Version:    shellVersion,
		BuildMode:  buildMode,
		BridgeOnly: bridgeOnly,
	}
}

// GetWsHubStatus returns WebSocket hub metrics for POC 2.
func (a *App) GetWsHubStatus() poc.HubStatus {
	if a.hub == nil {
		return poc.HubStatus{Addr: poc.DefaultWSAddr, Path: poc.DefaultWSPath}
	}
	return a.hub.Status()
}

// GetWsUrl returns the WebSocket URL for the POC client.
func (a *App) GetWsUrl() string {
	if a.hub == nil {
		return "ws://" + poc.DefaultWSAddr + poc.DefaultWSPath
	}
	return a.hub.URL()
}

// GetA2UIIngestURL returns the local JSONL endpoint used by P2 providers.
func (a *App) GetA2UIIngestURL() string {
	if a.hub == nil {
		return "http://" + poc.DefaultWSAddr + poc.A2UIIngestPath
	}
	return a.hub.A2UIIngestURL()
}

// StartWsFakePump starts the Go-side scripted event pump (POC 2).
func (a *App) StartWsFakePump() {
	if a.hub != nil {
		a.hub.StartFakePump()
	}
}

// StopWsFakePump stops the Go-side fake pump.
func (a *App) StopWsFakePump() {
	if a.hub != nil {
		a.hub.StopFakePump()
	}
}

// GetFtbShellStatus returns S10 phase-2 FTB shell mount state.
func (a *App) GetFtbShellStatus() poc.ShellFtbStatus {
	if a.hub == nil {
		return poc.ShellFtbStatus{Phase: 2}
	}
	return a.hub.ShellFtbStatus()
}

func (a *App) shutdown(ctx context.Context) {
	if a.hub != nil {
		a.hub.StopFakePump()
	}
}
