//go:build windows

package main

import (
	"log"
	"sync"
)

// AhkBridgeController emits window_policy over the WS hub; AHK executes via hole_starry relay.
type AhkBridgeController struct {
	mu sync.Mutex

	launcherMode string
	currentState InteractionState
	lastPolicy   map[string]any
}

func NewAhkBridgeController(launcherMode string) *AhkBridgeController {
	return &AhkBridgeController{
		launcherMode: normalizeLauncherMode(launcherMode),
		currentState: StateIdle,
	}
}

func normalizeLauncherMode(mode string) string {
	switch mode {
	case "panel", "both", "starry", "a", "b":
		if mode == "a" {
			return "starry"
		}
		if mode == "b" {
			return "panel"
		}
		return mode
	default:
		return "starry"
	}
}

func (w *AhkBridgeController) SetContextState(st InteractionState) {
	w.mu.Lock()
	w.currentState = st
	w.mu.Unlock()
}

func (w *AhkBridgeController) isStarryLauncherMode() bool {
	return w.launcherMode == "starry" || w.launcherMode == "both"
}

func (w *AhkBridgeController) emitPolicy(starry, launcher, panel string, x, y int) {
	w.mu.Lock()
	st := w.currentState
	w.mu.Unlock()
	payload := map[string]any{
		"state":    string(st),
		"starry":   starry,
		"launcher": launcher,
		"panel":    panel,
		"x":        x,
		"y":        y,
	}
	w.mu.Lock()
	w.lastPolicy = payload
	w.mu.Unlock()
	log.Printf("[FSM] window_policy state=%s starry=%s launcher=%s panel=%s x=%d y=%d", st, starry, launcher, panel, x, y)
	hubEmit("window_policy", payload)
}

func (w *AhkBridgeController) ShowHole() {
	w.emitPolicy("show_passthrough", "hide", "hide", 0, 0)
}

func (w *AhkBridgeController) HideHole() {
	w.emitPolicy("hide", "hide", "hide", 0, 0)
}

func (w *AhkBridgeController) ShowLauncher() {
	w.emitPolicy("show_passthrough", "show_topmost", "hide", 0, 0)
}

// emitResultingStarry — single window_policy for starry resulting (avoid hide→show launcher flicker).
func (w *AhkBridgeController) emitResultingStarry(x, y int) {
	w.emitPolicy("show_passthrough", "show_topmost", "hide", x, y)
}

func (w *AhkBridgeController) HideLauncher() {
	w.emitPolicy("show_passthrough", "hide", "hide", 0, 0)
}

func (w *AhkBridgeController) ShowPanel() {
	w.emitPolicy("hide", "hide", "show", 0, 0)
}

func (w *AhkBridgeController) HidePanel() {
	w.emitPolicy("show_passthrough", "hide", "hide", 0, 0)
}

func (w *AhkBridgeController) MoveTo(x, y int) {
	w.emitPolicy("show_passthrough", "hide", "hide", x, y)
}

func (w *AhkBridgeController) ReplayLastPolicy() {
	w.mu.Lock()
	p := w.lastPolicy
	w.mu.Unlock()
	if p == nil {
		return
	}
	m := map[string]any{"type": "window_policy", "at": ""}
	for k, v := range p {
		m[k] = v
	}
	globalHub.emit(m)
}
