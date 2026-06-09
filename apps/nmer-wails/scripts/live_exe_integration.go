//go:build ignore

// 针对已启动的 nmer-wails.exe（:18791）做 live 集成测试。
// 用法：先启动 build/bin/nmer-wails.exe，再：
//   cd apps/nmer-wails && go run scripts/live_exe_integration.go
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gorilla/websocket"
)

const (
	defaultAddr  = "127.0.0.1:18791"
	wsPath       = "/agent/ws"
	ingestPath   = "/a2ui/ingest"
	waitTimeout  = 45 * time.Second
	stepDeadline = 12 * time.Second
)

type wireMessage struct {
	Type             string          `json:"type"`
	A2UI             json.RawMessage `json:"a2ui,omitempty"`
	A2UIActionResult json.RawMessage `json:"a2uiActionResult,omitempty"`
}

func main() {
	addr := strings.TrimSpace(os.Getenv("NMER_A2UI_BRIDGE_ADDR"))
	if addr == "" {
		addr = defaultAddr
	}
	baseHTTP := "http://" + addr
	wsURL := "ws://" + addr + wsPath + "?clientId=live-exe-test"

	fmt.Println("=== nmer-wails.exe live integration ===")
	fmt.Println("target:", baseHTTP)

	if err := waitForTCP(addr, waitTimeout); err != nil {
		fail("hub not listening: %v", err)
	}

	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		fail("ws dial: %v", err)
	}
	defer conn.Close()
	_ = conn.SetReadDeadline(time.Now().Add(stepDeadline))

	var ack wireMessage
	if err := conn.ReadJSON(&ack); err != nil {
		fail("hello_ack read: %v", err)
	}
	if ack.Type != "hello_ack" {
		fail("expected hello_ack, got %q", ack.Type)
	}
	pass("WS hello_ack")

	jsonlCandidates := []string{
		"poc/testdata/a2ui-command-palette.jsonl",
		"../poc/testdata/a2ui-command-palette.jsonl",
	}
	var body []byte
	var readErr error
	for _, jsonlPath := range jsonlCandidates {
		body, readErr = os.ReadFile(jsonlPath)
		if readErr == nil {
			break
		}
	}
	if readErr != nil {
		fail("read jsonl: %v", readErr)
	}
	client := &http.Client{Timeout: stepDeadline}
	resp, err := client.Post(baseHTTP+ingestPath, "application/x-ndjson", bytes.NewReader(body))
	if err != nil {
		fail("ingest post: %v", err)
	}
	respBody, _ := io.ReadAll(resp.Body)
	_ = resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		fail("ingest status %d: %s", resp.StatusCode, string(respBody))
	}
	pass("HTTP ingest 200")

	events := 0
	deadline := time.Now().Add(stepDeadline)
	for time.Now().Before(deadline) {
		_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
		var frame wireMessage
		if err := conn.ReadJSON(&frame); err != nil {
			continue
		}
		if frame.Type != "official_a2ui_event" {
			continue
		}
		events++
		var env map[string]interface{}
		if json.Unmarshal(frame.A2UI, &env) == nil {
			if card, _ := env["cardId"].(string); card != "p2-a2ui-demo" {
				fail("unexpected cardId %q", card)
			}
		}
		if events >= 4 {
			break
		}
	}
	if events < 4 {
		fail("expected >=4 official_a2ui_event, got %d", events)
	}
	pass(fmt.Sprintf("WS received %d official_a2ui_event frames", events))

	badResp, err := client.Post(
		baseHTTP+ingestPath,
		"application/x-ndjson",
		bytes.NewReader([]byte(`{"schemaVersion":"broken"}`+"\n")),
	)
	if err != nil {
		fail("bad ingest: %v", err)
	}
	_, _ = io.ReadAll(badResp.Body)
	_ = badResp.Body.Close()
	if badResp.StatusCode == http.StatusOK {
		fail("malformed ingest should not return 200")
	}
	pass(fmt.Sprintf("malformed ingest rejected status=%d", badResp.StatusCode))

	if err := conn.WriteJSON(map[string]interface{}{
		"type": "official_a2ui_action",
		"a2uiAction": map[string]interface{}{
			"schemaVersion": "nmer.a2ui.action.v1",
			"eventId":       "evt-live-action",
			"requestId":     "req-live-action",
			"correlationId": "corr-live-action",
			"cardId":        "p2-a2ui-demo",
			"surfaceId":     "surface-p2-demo",
			"componentId":   "button",
			"actionName":    "safe.follow-up",
			"depth":         0,
			"timeoutMs":     3000,
			"abortId":       "abort-live-action",
			"data": map[string]interface{}{
				"kind":     "safe",
				"question": "live exe integration",
			},
		},
	}); err != nil {
		fail("action write: %v", err)
	}

	accepted := false
	completed := false
	providerEvents := 0
	actionDeadline := time.Now().Add(15 * time.Second)
	for time.Now().Before(actionDeadline) {
		_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
		var frame wireMessage
		if err := conn.ReadJSON(&frame); err != nil {
			continue
		}
		switch frame.Type {
		case "official_a2ui_action_result":
			var result map[string]interface{}
			if json.Unmarshal(frame.A2UIActionResult, &result) == nil {
				switch result["status"] {
				case "accepted":
					accepted = true
				case "completed":
					completed = true
				case "rejected", "timeout":
					fail("action failed: %v", result)
				}
			}
		case "official_a2ui_event":
			providerEvents++
		}
		if accepted && completed && providerEvents >= 1 {
			break
		}
	}
	if !accepted || !completed {
		fail("action incomplete accepted=%v completed=%v providerEvents=%d", accepted, completed, providerEvents)
	}
	pass(fmt.Sprintf("Fake Provider action accepted+completed (%d follow-up events)", providerEvents))

	fmt.Println("---")
	fmt.Println("LIVE_INTEGRATION ok=true")
}

func waitForTCP(addr string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		conn, err := net.DialTimeout("tcp", addr, 2*time.Second)
		if err == nil {
			_ = conn.Close()
			return nil
		}
		time.Sleep(400 * time.Millisecond)
	}
	return fmt.Errorf("timeout waiting for %s", addr)
}

func pass(format string, args ...interface{}) {
	fmt.Printf("PASS %s\n", fmt.Sprintf(format, args...))
}

func fail(format string, args ...interface{}) {
	fmt.Printf("FAIL %s\n", fmt.Sprintf(format, args...))
	os.Exit(1)
}
