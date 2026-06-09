package poc

import "testing"

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
