package poc

import (
	"os"
	"testing"
)

func TestOpenClawGatewayConnectClientDefaults(t *testing.T) {
	_ = os.Unsetenv("OPENCLAW_GATEWAY_CLIENT_ID")
	_ = os.Unsetenv("OPENCLAW_GATEWAY_CLIENT_MODE")
	client := openClawGatewayConnectClient()
	if client["id"] != openClawBackendClientID {
		t.Fatalf("id: got %v", client["id"])
	}
	if client["mode"] != openClawBackendClientMode {
		t.Fatalf("mode: got %v", client["mode"])
	}
}

func TestOpenClawPickAssistantFromHistory(t *testing.T) {
	got := openClawPickAssistantFromHistory(map[string]interface{}{
		"messages": []interface{}{
			map[string]interface{}{"role": "user", "text": "hi"},
			map[string]interface{}{"role": "assistant", "text": "hello from gateway"},
		},
	})
	if got != "hello from gateway" {
		t.Fatalf("history pick: got %q", got)
	}
}

func TestOpenClawExtractAssistantText(t *testing.T) {
	pl := map[string]interface{}{
		"state": "delta",
		"message": map[string]interface{}{
			"content": []interface{}{
				map[string]interface{}{"type": "text", "text": "hello adapter"},
			},
		},
	}
	if got := openClawExtractAssistantText(pl); got != "hello adapter" {
		t.Fatalf("extract: got %q", got)
	}
}

func TestOpenClawGetChatBroadcastPayload(t *testing.T) {
	msg := map[string]interface{}{
		"type": "event",
		"payload": map[string]interface{}{
			"event": "chat",
			"payload": map[string]interface{}{
				"state": "final",
				"text":  "done",
			},
		},
	}
	pl := openClawGetChatBroadcastPayload(msg)
	if pl == nil || openClawExtractAssistantText(pl) != "done" {
		t.Fatalf("broadcast payload not parsed")
	}
}
