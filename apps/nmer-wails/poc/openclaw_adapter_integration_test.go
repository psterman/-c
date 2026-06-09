package poc

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
)

func TestOpenClawAdapterIngestWithMockGateway(t *testing.T) {
	gateway := newMockOpenClawGatewayServer(t)
	t.Setenv("OPENCLAW_GATEWAY_TOKEN", "test-token")
	t.Setenv("OPENCLAW_BASE_URL", gateway.URL)

	hub := NewHub("127.0.0.1:0", DefaultWSPath, nil, nil)
	mux := http.NewServeMux()
	mux.HandleFunc(OpenClawAdapterActionPath, hub.handleOpenClawAdapterAction)
	server := httptest.NewServer(mux)
	defer server.Close()

	body, _ := json.Marshal(OpenClawActionRequest{
		CardID:     "card_adp_int",
		RequestID:  "req-adp-int",
		Query:      "/search adapter integration",
		SessionRef: OpenClawSessionKeyForCard("card_adp_int", OpenClawNamespaceAdapter),
	})
	resp, err := http.Post(server.URL+OpenClawAdapterActionPath, "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("status: %d", resp.StatusCode)
	}
	var out openClawActionResponse
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		t.Fatalf("decode: %v", err)
	}
	if !out.OK || out.Accepted != 3 {
		t.Fatalf("unexpected response: %+v", out)
	}
	if len(hub.a2uiReplaySnapshot()) == 0 {
		t.Fatalf("expected replay buffer entries")
	}
}

func TestOpenClawAdapterMissingConfig(t *testing.T) {
	hub := NewHub("127.0.0.1:0", DefaultWSPath, nil, nil)
	mux := http.NewServeMux()
	mux.HandleFunc(OpenClawAdapterActionPath, hub.handleOpenClawAdapterAction)
	server := httptest.NewServer(mux)
	defer server.Close()

	_ = os.Unsetenv("OPENCLAW_GATEWAY_TOKEN")
	_ = os.Unsetenv("OPENCLAW_TOKEN")

	body, _ := json.Marshal(OpenClawActionRequest{
		CardID:    "card_x",
		RequestID: "req-x",
		Query:     "hello",
	})
	resp, err := http.Post(server.URL+OpenClawAdapterActionPath, "application/json", bytes.NewReader(body))
	if err != nil {
		t.Fatalf("post: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusServiceUnavailable {
		t.Fatalf("status: %d", resp.StatusCode)
	}
}

func newMockOpenClawGatewayServer(t *testing.T) *httptest.Server {
	t.Helper()
	upgrader := wsUpgrader
	return httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		conn, err := upgrader.Upgrade(w, r, nil)
		if err != nil {
			t.Errorf("upgrade: %v", err)
			return
		}
		defer conn.Close()
		connected := false
		for {
			_, data, err := conn.ReadMessage()
			if err != nil {
				return
			}
			var msg map[string]interface{}
			if err := json.Unmarshal(data, &msg); err != nil {
				continue
			}
			id, _ := msg["id"].(string)
			method, _ := msg["method"].(string)
			if method == "connect" {
				connected = true
				_ = conn.WriteJSON(map[string]interface{}{"type": "res", "id": id, "ok": true, "result": map[string]interface{}{}})
				continue
			}
			if connected && method == "chat.send" {
				_ = conn.WriteJSON(map[string]interface{}{"type": "res", "id": id, "ok": true})
				_ = conn.WriteJSON(map[string]interface{}{
					"type": "event",
					"payload": map[string]interface{}{
						"event": "chat",
						"payload": map[string]interface{}{
							"state": "final",
							"text":  "mock openclaw answer",
						},
					},
				})
				return
			}
			if strings.HasPrefix(id, "connect-") {
				_ = conn.WriteJSON(map[string]interface{}{"type": "event", "event": "connect.challenge"})
			}
		}
	}))
}
