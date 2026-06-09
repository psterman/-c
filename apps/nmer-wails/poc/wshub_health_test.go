package poc

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"testing"
	"time"
)

func TestHubHealthEndpoint(t *testing.T) {
	hub := NewHub("127.0.0.1:0", DefaultWSPath, nil, nil)
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	if err := hub.Start(ctx); err != nil {
		t.Fatalf("hub start: %v", err)
	}
	defer cancel()
	time.Sleep(80 * time.Millisecond)

	st := hub.Status()
	if !st.Running {
		t.Fatal("expected hub running after start")
	}

	resp, err := http.Get("http://" + st.Addr + A2UIHealthPath)
	if err != nil {
		t.Fatalf("health get: %v", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("health status=%d", resp.StatusCode)
	}
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		t.Fatalf("health read: %v", err)
	}
	var payload map[string]interface{}
	if err := json.Unmarshal(body, &payload); err != nil {
		t.Fatalf("health json: %v body=%q", err, string(body))
	}
	if payload["ok"] != true {
		t.Fatalf("health ok=%v", payload["ok"])
	}
	if payload["provider"] != "fake" {
		t.Fatalf("health provider=%v", payload["provider"])
	}
	cap, ok := payload["capability"].(map[string]interface{})
	if !ok || cap["provider"] != "fake" {
		t.Fatalf("health capability=%#v", payload["capability"])
	}
}
