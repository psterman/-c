//go:build windows

package main

import (
	"context"
	"sync"

	wailsruntime "github.com/wailsapp/wails/v2/pkg/runtime"
)

// wailsWindowController — WindowController via Wails runtime (main thread).
// Position updates should be triggered from EventsOn handlers on the UI thread.
type wailsWindowController struct {
	ctx      context.Context
	mu       sync.Mutex
	lastX    int
	lastY    int
	holeVis  bool
	panelVis bool
}

func newWailsWindowController(ctx context.Context) *wailsWindowController {
	return &wailsWindowController{ctx: ctx}
}

func (w *wailsWindowController) emit(payload map[string]interface{}) {
	if w.ctx == nil {
		return
	}
	wailsruntime.EventsEmit(w.ctx, "hole_window", payload)
}

func (w *wailsWindowController) ShowHole() {
	w.mu.Lock()
	w.holeVis = true
	w.mu.Unlock()
	wailsruntime.WindowShow(w.ctx)
	w.emit(map[string]interface{}{"role": "hole", "visible": true})
}

func (w *wailsWindowController) HideHole() {
	w.mu.Lock()
	w.holeVis = false
	w.mu.Unlock()
	w.emit(map[string]interface{}{"role": "hole", "visible": false})
}

func (w *wailsWindowController) ShowPanel() {
	w.mu.Lock()
	w.panelVis = true
	w.mu.Unlock()
	wailsruntime.WindowShow(w.ctx)
	w.emit(map[string]interface{}{"role": "panel", "visible": true})
}

func (w *wailsWindowController) HidePanel() {
	w.mu.Lock()
	w.panelVis = false
	w.mu.Unlock()
	w.emit(map[string]interface{}{"role": "panel", "visible": false})
}

func (w *wailsWindowController) MoveTo(x, y int) {
	w.mu.Lock()
	w.lastX, w.lastY = x, y
	w.mu.Unlock()
	// Prefer runtime position API when available; EventsEmit lets frontend/layout own final placement.
	w.emit(map[string]interface{}{"role": "hole", "action": "move", "x": x, "y": y})
}
