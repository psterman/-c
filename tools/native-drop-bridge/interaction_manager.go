//go:build windows

package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"strings"
	"sync"
)

// InteractionState — single source of truth (Go/Wails). AHK must not Move/Hide WebView hosts.
type InteractionState string

const (
	StateIdle        InteractionState = "idle"
	StateWeakPreview InteractionState = "weak_preview"
	StateAnalyzing   InteractionState = "analyzing"
	StateResulting   InteractionState = "resulting"
	StateDragging    InteractionState = "dragging"
)

// WindowController drives physical HWND policy (P2: AhkBridgeController → window_policy WS).
type WindowController interface {
	ShowHole()
	HideHole()
	ShowLauncher()
	HideLauncher()
	ShowPanel()
	HidePanel()
	MoveTo(x, y int)
}

type policyContext interface {
	WindowController
	SetContextState(InteractionState)
}

// InteractionManager serializes all hole/panel transitions and broadcasts to WS clients.
type InteractionManager struct {
	mu sync.Mutex

	ctx          context.Context
	state InteractionState
	version      uint64
	text         string
	reason       string
	anchorX      int
	anchorY      int

	controller   WindowController
	launcherMode   string

	onAnalyzing func(text string) error
}

func NewInteractionManager(ctx context.Context, controller WindowController, launcherMode string) *InteractionManager {
	if ctx == nil {
		ctx = context.Background()
	}
	return &InteractionManager{
		ctx:          ctx,
		state:        StateIdle,
		controller:   controller,
		launcherMode: normalizeLauncherMode(launcherMode),
	}
}

func (im *InteractionManager) isStarryLauncherMode() bool {
	return im.launcherMode == "starry" || im.launcherMode == "both"
}

func (im *InteractionManager) SetAnalyzingHandler(fn func(text string) error) {
	im.mu.Lock()
	defer im.mu.Unlock()
	im.onAnalyzing = fn
}

func (im *InteractionManager) State() (InteractionState, uint64, string, int, int) {
	im.mu.Lock()
	defer im.mu.Unlock()
	return im.state, im.version, im.text, im.anchorX, im.anchorY
}

// TransitionTo is the only legal state change entry (mutex + window policy + WS).
func (im *InteractionManager) TransitionTo(newState InteractionState, reason string, text string, ax, ay int) error {
	im.mu.Lock()
	defer im.mu.Unlock()

	if !im.allowTransition(im.state, newState) {
		return fmt.Errorf("interaction: transition %s -> %s not allowed (%s)", im.state, newState, reason)
	}
	prev := im.state
	textIn := strings.TrimSpace(text)
	textSame := (textIn == "" || textIn == strings.TrimSpace(im.text))
	anchorSame := (ax == 0 && ay == 0) || (ax == im.anchorX && ay == im.anchorY)
	if prev == newState && strings.TrimSpace(reason) == strings.TrimSpace(im.reason) && textSame && anchorSame {
		return nil
	}
	im.state = newState
	im.version++
	im.reason = reason
	if textIn != "" {
		im.text = textIn
	}
	if ax != 0 || ay != 0 {
		im.anchorX, im.anchorY = ax, ay
	}
	im.applyWindowPolicy(prev, newState)
	im.BroadcastState(prev, reason)
	if newState == StateAnalyzing {
		fn := im.onAnalyzing
		if fn != nil && strings.TrimSpace(im.text) != "" {
			if err := fn(im.text); err != nil {
				return err
			}
		}
	}
	return nil
}

func (im *InteractionManager) allowTransition(from, to InteractionState) bool {
	if from == to {
		return true
	}
	switch from {
	case StateIdle:
		return to == StateWeakPreview
	case StateWeakPreview:
		return to == StateAnalyzing || to == StateIdle || to == StateResulting
	case StateAnalyzing:
		return to == StateResulting || to == StateIdle || to == StateDragging
	case StateResulting:
		return to == StateDragging || to == StateIdle || to == StateAnalyzing
	case StateDragging:
		return to == StateResulting || to == StateWeakPreview || to == StateIdle
	default:
		return false
	}
}

func (im *InteractionManager) applyWindowPolicy(prev, next InteractionState) {
	c := im.controller
	if c == nil {
		return
	}
	if pc, ok := c.(policyContext); ok {
		pc.SetContextState(next)
	}
	starryMode := im.isStarryLauncherMode()
	switch next {
	case StateIdle:
		c.HideLauncher()
		c.HidePanel()
		c.HideHole()
	case StateWeakPreview:
		c.HidePanel()
		c.HideLauncher()
		c.ShowHole()
		if im.anchorX != 0 || im.anchorY != 0 {
			c.MoveTo(im.anchorX, im.anchorY)
		}
	case StateAnalyzing:
		c.HidePanel()
		c.HideLauncher()
		c.ShowHole()
	case StateResulting:
		if starryMode {
			if bc, ok := c.(*AhkBridgeController); ok {
				bc.emitResultingStarry(im.anchorX, im.anchorY)
			} else {
				c.ShowHole()
				c.ShowLauncher()
				c.HidePanel()
			}
		} else {
			c.HideLauncher()
			c.HideHole()
			c.ShowPanel()
		}
	case StateDragging:
		if starryMode {
			c.ShowHole()
			c.HideLauncher()
			c.ShowPanel()
		} else {
			c.HideHole()
			c.HideLauncher()
			c.ShowPanel()
		}
	default:
		_ = prev
	}
}

// ReplayState re-sends the current FSM snapshot to a newly connected WS client (no version bump).
func (im *InteractionManager) ReplayState() {
	im.mu.Lock()
	st := im.state
	ver := im.version
	textLen := len(im.text)
	ax, ay := im.anchorX, im.anchorY
	im.mu.Unlock()
	if st == StateIdle {
		return
	}
	hubEmit("interaction_state", map[string]any{
		"prev":    "",
		"state":   string(st),
		"reason":  "replay",
		"version": ver,
		"textLen": textLen,
		"anchorX": ax,
		"anchorY": ay,
	})
	if globalInteraction != nil && globalInteraction.controller != nil {
		if bc, ok := globalInteraction.controller.(*AhkBridgeController); ok {
			bc.SetContextState(st)
			bc.ReplayLastPolicy()
		}
	}
}

// BroadcastState pushes interaction_state to all WS clients (panel.html / hole_starry passive UI).
func (im *InteractionManager) BroadcastState(prev InteractionState, reason string) {
	log.Printf("[FSM] BroadcastState: state=%s prev=%s reason=%s ver=%d", im.state, prev, reason, im.version)
	hubEmit("interaction_state", map[string]any{
		"prev":    string(prev),
		"state":   string(im.state),
		"reason":  reason,
		"version": im.version,
		"textLen": len(im.text),
		"anchorX": im.anchorX,
		"anchorY": im.anchorY,
	})
}

// OnSelectionPreview — AHK messenger:划选完成，仅弱预览星空（对应原 OpenSelectionTextPreview）。
func (im *InteractionManager) OnSelectionPreview(text string, anchorX, anchorY int) error {
	text = strings.TrimSpace(text)
	if text == "" {
		return fmt.Errorf("interaction: empty selection")
	}
	return im.TransitionTo(StateWeakPreview, "selection_preview", text, anchorX, anchorY)
}

// OnHoleCommit — 用户点击黑洞/近距提交：weak_preview → analyzing。
func (im *InteractionManager) OnHoleCommit() error {
	im.mu.Lock()
	st := im.state
	im.mu.Unlock()
	if st != StateWeakPreview && st != StateResulting {
		return fmt.Errorf("interaction: commit from %s", st)
	}
	return im.TransitionTo(StateAnalyzing, "hole_commit", "", 0, 0)
}

// OnPointerMove — AHK 只上报坐标，由 controller.MoveTo 定位（禁止 AHK MoveWindow）。
func (im *InteractionManager) OnPointerMove(x, y int) error {
	im.mu.Lock()
	st := im.state
	im.anchorX, im.anchorY = x, y
	c := im.controller
	im.mu.Unlock()
	if st == StateDragging && c != nil {
		c.MoveTo(x, y)
	}
	return nil
}

func (im *InteractionManager) OnDragStart() error {
	im.mu.Lock()
	st := im.state
	im.mu.Unlock()
	if st == StateAnalyzing {
		return fmt.Errorf("interaction: cannot drag while analyzing")
	}
	return im.TransitionTo(StateDragging, "panel_drag_start", "", 0, 0)
}

func (im *InteractionManager) OnDragEnd() error {
	im.mu.Lock()
	st := im.state
	im.mu.Unlock()
	if st != StateDragging {
		return nil
	}
	next := StateIdle
	if strings.TrimSpace(im.text) != "" {
		next = StateResulting
	}
	return im.TransitionTo(next, "panel_drag_end", "", 0, 0)
}

func (im *InteractionManager) OnPanelClicked() error {
	im.mu.Lock()
	st := im.state
	im.mu.Unlock()
	switch st {
	case StateWeakPreview:
		return im.OnHoleCommit()
	case StateResulting:
		hubEmit("panel_action", map[string]any{"action": "focus", "state": string(st)})
		return nil
	case StateIdle:
		return im.TransitionTo(StateResulting, "panel_click_idle", "", 0, 0)
	default:
		return nil
	}
}

func (im *InteractionManager) OnAnalyzeComplete() error {
	im.mu.Lock()
	st := im.state
	im.mu.Unlock()
	if st != StateAnalyzing {
		return nil
	}
	return im.TransitionTo(StateResulting, "analyze_complete", "", 0, 0)
}

func (im *InteractionManager) Dismiss(reason string) error {
	return im.TransitionTo(StateIdle, reason, "", 0, 0)
}

// HandleWSInbound — AHK/前端 JSON 信使协议（P0）。
func (im *InteractionManager) HandleWSInbound(raw []byte) error {
	var in struct {
		Type     string `json:"type"`
		Text     string `json:"text"`
		Reason   string `json:"reason"`
		ScreenX  int    `json:"screenX"`
		ScreenY  int    `json:"screenY"`
		AnchorX  int    `json:"anchorX"`
		AnchorY  int    `json:"anchorY"`
	}
	if err := json.Unmarshal(raw, &in); err != nil {
		return err
	}
	typ := strings.ToLower(strings.TrimSpace(in.Type))
	ax, ay := in.AnchorX, in.AnchorY
	if ax == 0 && ay == 0 {
		ax, ay = in.ScreenX, in.ScreenY
	}
	switch typ {
	case "selection_preview", "text_selected":
		return im.OnSelectionPreview(in.Text, ax, ay)
	case "hole_commit", "proximity_commit", "text_dragged":
		if in.Text != "" {
			im.mu.Lock()
			im.text = strings.TrimSpace(in.Text)
			im.mu.Unlock()
		}
		if im.getState() == StateIdle {
			_ = im.OnSelectionPreview(in.Text, ax, ay)
		}
		return im.OnHoleCommit()
	case "pointer_move", "panel_moved", "window_move":
		return im.OnPointerMove(ax, ay)
	case "panel_drag_start", "drag_start":
		return im.OnDragStart()
	case "panel_drag_end", "drag_end":
		return im.OnDragEnd()
	case "panel_clicked", "panel_click", "hole_click":
		return im.OnPanelClicked()
	case "panel_dismiss", "hole_close", "dismiss":
		return im.Dismiss(in.Reason)
	case "analyze_complete", "stream_done":
		return im.OnAnalyzeComplete()
	case "panel_present", "panel_show", "panel_open":
		txt := strings.TrimSpace(in.Text)
		st := im.getState()
		if st == StateIdle && txt != "" {
			if err := im.OnSelectionPreview(txt, ax, ay); err != nil {
				return err
			}
			st = im.getState()
		}
		if st == StateWeakPreview {
			if err := im.OnHoleCommit(); err != nil {
				return err
			}
		}
		return im.TransitionTo(StateResulting, "panel_present", txt, ax, ay)
	default:
		return fmt.Errorf("interaction: unknown type %s", typ)
	}
}

func (im *InteractionManager) getState() InteractionState {
	im.mu.Lock()
	defer im.mu.Unlock()
	return im.state
}

var globalInteraction *InteractionManager

func initInteractionManager(launcherMode string) {
	if globalInteraction != nil {
		return
	}
	ctrl := NewAhkBridgeController(launcherMode)
	globalInteraction = NewInteractionManager(context.Background(), ctrl, launcherMode)
	globalInteraction.SetAnalyzingHandler(func(text string) error {
		reqID := globalPipeline.beginManual(text, llmConfig{})
		if reqID == 0 {
			return fmt.Errorf("pipeline busy")
		}
		return nil
	})
}

func notifyStreamDone() {
	if globalInteraction == nil {
		return
	}
	_ = globalInteraction.OnAnalyzeComplete()
}
