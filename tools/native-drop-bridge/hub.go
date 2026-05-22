//go:build windows

package main

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

var wsUpgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type wsHub struct {
	mu      sync.RWMutex
	clients map[*websocket.Conn]struct{}
}

var globalHub wsHub

type wsInbound struct {
	Type    string `json:"type"`
	Prompt  string `json:"prompt"`
	APIKey  string `json:"apiKey"`
	BaseURL string `json:"baseUrl"`
	Model   string `json:"model"`
	Provider string `json:"provider"`
}

func (h *wsHub) start(addr string) {
	h.mu.Lock()
	h.clients = make(map[*websocket.Conn]struct{})
	h.mu.Unlock()

	mux := http.NewServeMux()
	mux.HandleFunc("/hole", h.handleWS)
	mux.HandleFunc("/hole/event", handleHoleEventHTTP)
	go func() {
		_ = http.ListenAndServe(addr, mux)
	}()
}

func handleHoleEventHTTP(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 1<<20))
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	if globalInteraction == nil {
		initInteractionManager(readLauncherModeFromINI())
	}
	if err := globalInteraction.HandleWSInbound(body); err != nil {
		log.Printf("[FSM] hole/event error: %v body=%s", err, string(body))
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_, _ = w.Write([]byte(`{"ok":true}`))
}

func (h *wsHub) handleWS(w http.ResponseWriter, r *http.Request) {
	conn, err := wsUpgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	h.mu.Lock()
	h.clients[conn] = struct{}{}
	h.mu.Unlock()
	defer func() {
		h.mu.Lock()
		delete(h.clients, conn)
		h.mu.Unlock()
		_ = conn.Close()
	}()
	h.emit(map[string]any{
		"type": "bridge_ready",
		"at":   time.Now().Format(time.RFC3339),
	})
	if globalInteraction != nil {
		globalInteraction.ReplayState()
	}
	for {
		_, body, err := conn.ReadMessage()
		if err != nil {
			break
		}
		var in wsInbound
		if err := json.Unmarshal(body, &in); err != nil {
			continue
		}
		if strings.EqualFold(strings.TrimSpace(in.Type), "manual_prompt") {
			cfg := llmConfig{
				APIKey:  strings.TrimSpace(in.APIKey),
				BaseURL: strings.TrimSpace(in.BaseURL),
				Model:   strings.TrimSpace(in.Model),
				Provider: strings.TrimSpace(in.Provider),
			}
			reqID := globalPipeline.beginManual(strings.TrimSpace(in.Prompt), cfg)
			if reqID == 0 {
				continue
			}
			h.emit(map[string]any{
				"type":        "drop",
				"at":          time.Now().Format(time.RFC3339),
				"requestId":   reqID,
				"manual":      true,
				"payloadKind": "text",
			})
		}
	}
}

func (h *wsHub) emit(payload map[string]any) {
	b, err := json.Marshal(payload)
	if err != nil {
		return
	}
	h.mu.RLock()
	defer h.mu.RUnlock()
	for c := range h.clients {
		_ = c.WriteMessage(websocket.TextMessage, b)
	}
}

func hubEmit(typ string, extra map[string]any) {
	m := map[string]any{"type": typ, "at": time.Now().Format(time.RFC3339)}
	for k, v := range extra {
		m[k] = v
	}
	globalHub.emit(m)
}
