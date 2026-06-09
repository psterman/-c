package poc

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func testA2UIEnvelope(t *testing.T, seq int, message map[string]interface{}) []byte {
	t.Helper()
	rawMessage, err := json.Marshal(message)
	if err != nil {
		t.Fatal(err)
	}
	envelope := A2UIEnvelope{
		SchemaVersion: A2UITransportVersion,
		EventID:       "evt-test-" + fmt.Sprint(seq),
		RequestID:     "req-test",
		CorrelationID: "corr-test",
		CardID:        "card-test",
		SurfaceID:     "surface-test",
		Seq:           seq,
		Message:       rawMessage,
	}
	raw, err := json.Marshal(envelope)
	if err != nil {
		t.Fatal(err)
	}
	return raw
}

func testA2UIAction(requestID string) A2UIActionEnvelope {
	return A2UIActionEnvelope{
		SchemaVersion: A2UIActionVersion,
		EventID:       "evt-action",
		RequestID:     requestID,
		CorrelationID: "corr-action",
		CardID:        "card-test",
		SurfaceID:     "surface-test",
		ComponentID:   "submit",
		ActionName:    "safe.follow-up",
		Depth:         0,
		TimeoutMs:     3_000,
		AbortID:       "abort-action",
		Data: map[string]interface{}{
			"kind":     "safe",
			"question": "继续验证 A2UI",
		},
	}
}

func TestA2UIActionPolicyRejectsUnsafeDepthAndDuplicates(t *testing.T) {
	policy := NewA2UIActionPolicy()
	action := testA2UIAction("req-action-1")
	if err := policy.Validate(action); err != nil {
		t.Fatalf("safe action rejected: %v", err)
	}
	if err := policy.Validate(action); err == nil {
		t.Fatalf("expected duplicate rejection")
	} else {
		assertA2UIErrorCode(t, err, "ACTION_DUPLICATE")
	}

	unsafe := testA2UIAction("req-action-2")
	unsafe.Data["kind"] = "dangerous"
	assertA2UIErrorCode(t, policy.Validate(unsafe), "ACTION_KIND_UNSAFE")

	deep := testA2UIAction("req-action-3")
	deep.Depth = maxA2UIActionDepth + 1
	assertA2UIErrorCode(t, policy.Validate(deep), "ACTION_DEPTH_EXCEEDED")
}

func TestA2UIActionPolicyRejectsCrossCardSurface(t *testing.T) {
	policy := NewA2UIActionPolicy()
	policy.RegisterSurface("surface-test", "card-owner")

	intruder := testA2UIAction("req-cross-1")
	intruder.CardID = "card-intruder"
	assertA2UIErrorCode(t, policy.Validate(intruder), "SEM_ACTION_CONTEXT_MISMATCH")

	owner := testA2UIAction("req-cross-2")
	owner.CardID = "card-owner"
	if err := policy.Validate(owner); err != nil {
		t.Fatalf("owner card should pass: %v", err)
	}
}

func TestA2UIValidatorAcceptsBasicCatalogStream(t *testing.T) {
	validator := NewA2UIValidator()
	create := testA2UIEnvelope(t, 1, map[string]interface{}{
		"version": A2UIProtocolVersion,
		"createSurface": map[string]interface{}{
			"surfaceId": "surface-test",
			"catalogId": A2UIBasicCatalogID,
		},
	})
	update := testA2UIEnvelope(t, 2, map[string]interface{}{
		"version": A2UIProtocolVersion,
		"updateComponents": map[string]interface{}{
			"surfaceId": "surface-test",
			"components": []interface{}{
				map[string]interface{}{
					"id": "root", "component": "Text", "text": "hello",
				},
			},
		},
	})
	if _, err := validator.Validate(create); err != nil {
		t.Fatalf("create rejected: %v", err)
	}
	if _, err := validator.Validate(update); err != nil {
		t.Fatalf("update rejected: %v", err)
	}
}

func TestA2UIValidatorRejectsUnknownComponentAndStaleSeq(t *testing.T) {
	validator := NewA2UIValidator()
	unknown := testA2UIEnvelope(t, 1, map[string]interface{}{
		"version": A2UIProtocolVersion,
		"updateComponents": map[string]interface{}{
			"surfaceId": "surface-test",
			"components": []interface{}{
				map[string]interface{}{"id": "root", "component": "RemoteScript"},
			},
		},
	})
	_, err := validator.Validate(unknown)
	assertA2UIErrorCode(t, err, "A2UI_COMPONENT_UNSUPPORTED")

	valid := testA2UIEnvelope(t, 1, map[string]interface{}{
		"version": A2UIProtocolVersion,
		"updateDataModel": map[string]interface{}{
			"surfaceId": "surface-test",
			"path":      "/title",
			"value":     "ok",
		},
	})
	if _, err := validator.Validate(valid); err != nil {
		t.Fatalf("valid message rejected: %v", err)
	}
	_, err = validator.Validate(valid)
	assertA2UIErrorCode(t, err, "TPA_SEQ_STALE")
}

func TestDecodeA2UIJSONLIsAtomic(t *testing.T) {
	validator := NewA2UIValidator()
	first := testA2UIEnvelope(t, 1, map[string]interface{}{
		"version": A2UIProtocolVersion,
		"updateDataModel": map[string]interface{}{
			"surfaceId": "surface-test",
			"path":      "/title",
			"value":     "first",
		},
	})
	bad := []byte(`{"schemaVersion":"broken"}`)
	_, err := decodeA2UIJSONL(bytes.NewReader(bytes.Join([][]byte{first, bad}, []byte("\n"))), validator)
	if err == nil {
		t.Fatal("expected batch failure")
	}
	if _, err := validator.Validate(first); err != nil {
		t.Fatalf("failed batch consumed sequence: %v", err)
	}
}

func TestA2UIHTTPIngestBroadcastsAcceptedMessages(t *testing.T) {
	hub := NewHub("127.0.0.1:0", "/agent/ws", nil, nil)
	first := testA2UIEnvelope(t, 1, map[string]interface{}{
		"version": A2UIProtocolVersion,
		"createSurface": map[string]interface{}{
			"surfaceId": "surface-test",
			"catalogId": A2UIBasicCatalogID,
		},
	})
	request := httptest.NewRequest(http.MethodPost, A2UIIngestPath, bytes.NewReader(first))
	response := httptest.NewRecorder()
	hub.handleA2UIIngest(response, request)
	if response.Code != http.StatusOK {
		t.Fatalf("unexpected status %d: %s", response.Code, response.Body.String())
	}
	if len(hub.a2uiReplaySnapshot()) != 1 {
		t.Fatalf("expected replay message, got %d", len(hub.a2uiReplaySnapshot()))
	}
}

func TestA2UIWebSocketReplayOnReconnect(t *testing.T) {
	hub := NewHub("127.0.0.1:0", "/agent/ws", nil, nil)
	mux := http.NewServeMux()
	mux.HandleFunc(hub.path, hub.handleWS)
	mux.HandleFunc(A2UIIngestPath, hub.handleA2UIIngest)
	server := httptest.NewServer(mux)
	defer server.Close()

	line := testA2UIEnvelope(t, 1, map[string]interface{}{
		"version": A2UIProtocolVersion,
		"createSurface": map[string]interface{}{
			"surfaceId": "surface-test",
			"catalogId": A2UIBasicCatalogID,
		},
	})
	resp, err := http.Post(server.URL+A2UIIngestPath, "application/x-ndjson", bytes.NewReader(line))
	if err != nil {
		t.Fatal(err)
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("ingest status=%d", resp.StatusCode)
	}

	dial := func() *websocket.Conn {
		wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + hub.path + "?clientId=replay-client"
		conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
		if err != nil {
			t.Fatal(err)
		}
		_ = conn.SetReadDeadline(time.Now().Add(3 * time.Second))
		return conn
	}

	conn1 := dial()
	var ack1 WireMessage
	if err := conn1.ReadJSON(&ack1); err != nil {
		t.Fatal(err)
	}
	if ack1.Type != "hello_ack" {
		t.Fatalf("first hello_ack missing: %#v", ack1)
	}
	conn1.Close()

	conn2 := dial()
	defer conn2.Close()
	var ack2 WireMessage
	if err := conn2.ReadJSON(&ack2); err != nil {
		t.Fatal(err)
	}
	if ack2.Type != "hello_ack" {
		t.Fatalf("reconnect hello_ack missing: %#v", ack2)
	}
	if len(ack2.A2UIReplay) != 1 {
		t.Fatalf("expected 1 replay envelope, got %d", len(ack2.A2UIReplay))
	}
	if ack2.A2UIReplay[0].SurfaceID != "surface-test" {
		t.Fatalf("replay surface=%s", ack2.A2UIReplay[0].SurfaceID)
	}
}

func TestA2UIHTTPToWebSocketEndToEnd(t *testing.T) {
	hub := NewHub("127.0.0.1:0", "/agent/ws", nil, nil)
	mux := http.NewServeMux()
	mux.HandleFunc(hub.path, hub.handleWS)
	mux.HandleFunc(A2UIIngestPath, hub.handleA2UIIngest)
	server := httptest.NewServer(mux)
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + hub.path + "?clientId=test-client"
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	_ = conn.SetReadDeadline(time.Now().Add(3 * time.Second))

	var ack WireMessage
	if err := conn.ReadJSON(&ack); err != nil {
		t.Fatal(err)
	}
	if ack.Type != "hello_ack" {
		t.Fatalf("expected hello_ack, got %s", ack.Type)
	}

	line := testA2UIEnvelope(t, 1, map[string]interface{}{
		"version": A2UIProtocolVersion,
		"createSurface": map[string]interface{}{
			"surfaceId": "surface-test",
			"catalogId": A2UIBasicCatalogID,
		},
	})
	response, err := http.Post(server.URL+A2UIIngestPath, "application/x-ndjson", bytes.NewReader(line))
	if err != nil {
		t.Fatal(err)
	}
	defer response.Body.Close()
	if response.StatusCode != http.StatusOK {
		t.Fatalf("unexpected ingest status: %s", response.Status)
	}

	var frame WireMessage
	if err := conn.ReadJSON(&frame); err != nil {
		t.Fatal(err)
	}
	if frame.Type != "official_a2ui_event" || frame.A2UI == nil {
		t.Fatalf("unexpected websocket frame: %#v", frame)
	}
	if frame.A2UI.CardID != "card-test" || frame.A2UI.Seq != 1 {
		t.Fatalf("wrong envelope: %#v", frame.A2UI)
	}
}

func TestA2UIActionToFakeProviderEndToEnd(t *testing.T) {
	hub := NewHub("127.0.0.1:0", "/agent/ws", nil, nil)
	mux := http.NewServeMux()
	mux.HandleFunc(hub.path, hub.handleWS)
	server := httptest.NewServer(mux)
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + hub.path + "?clientId=action-client"
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	_ = conn.SetReadDeadline(time.Now().Add(5 * time.Second))

	var ack WireMessage
	if err := conn.ReadJSON(&ack); err != nil {
		t.Fatal(err)
	}

	action := testA2UIAction("req-action-e2e")
	if err := conn.WriteJSON(WireMessage{
		Type:       "official_a2ui_action",
		A2UIAction: &action,
	}); err != nil {
		t.Fatal(err)
	}

	accepted := false
	completed := false
	providerEvents := 0
	for !completed || providerEvents < 3 {
		var frame WireMessage
		if err := conn.ReadJSON(&frame); err != nil {
			t.Fatal(err)
		}
		switch frame.Type {
		case "official_a2ui_action_result":
			if frame.A2UIActionResult == nil {
				t.Fatal("missing action result")
			}
			switch frame.A2UIActionResult.Status {
			case "accepted":
				accepted = true
			case "completed":
				completed = true
			case "rejected", "timeout":
				t.Fatalf("action failed: %#v", frame.A2UIActionResult)
			}
		case "official_a2ui_event":
			if frame.A2UI == nil {
				t.Fatal("missing provider envelope")
			}
			providerEvents++
			if !strings.Contains(frame.A2UI.SurfaceID, "-followup-") {
				t.Fatalf("provider reused source surface: %s", frame.A2UI.SurfaceID)
			}
		}
	}
	if !accepted {
		t.Fatal("missing accepted action result")
	}
	if len(hub.a2uiReplaySnapshot()) != 3 {
		t.Fatalf("expected 3 replay envelopes, got %d", len(hub.a2uiReplaySnapshot()))
	}
}

type blockingA2UIProvider struct{}

func (blockingA2UIProvider) HandleAction(
	ctx context.Context,
	_ A2UIActionEnvelope,
	_ func(A2UIEnvelope) error,
) error {
	<-ctx.Done()
	return ctx.Err()
}

func TestA2UIActionAbortCancelsProvider(t *testing.T) {
	hub := NewHub("127.0.0.1:0", "/agent/ws", nil, nil)
	hub.SetA2UIProvider("blocking", blockingA2UIProvider{})
	mux := http.NewServeMux()
	mux.HandleFunc(hub.path, hub.handleWS)
	server := httptest.NewServer(mux)
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + hub.path + "?clientId=abort-client"
	conn, _, err := websocket.DefaultDialer.Dial(wsURL, nil)
	if err != nil {
		t.Fatal(err)
	}
	defer conn.Close()
	_ = conn.SetReadDeadline(time.Now().Add(5 * time.Second))
	var ack WireMessage
	if err := conn.ReadJSON(&ack); err != nil {
		t.Fatal(err)
	}

	action := testA2UIAction("req-action-abort")
	if err := conn.WriteJSON(WireMessage{Type: "official_a2ui_action", A2UIAction: &action}); err != nil {
		t.Fatal(err)
	}
	var accepted WireMessage
	if err := conn.ReadJSON(&accepted); err != nil {
		t.Fatal(err)
	}
	if accepted.A2UIActionResult == nil || accepted.A2UIActionResult.Status != "accepted" {
		t.Fatalf("expected accepted, got %#v", accepted)
	}

	abort := A2UIAbortEnvelope{
		SchemaVersion: A2UIActionVersion,
		RequestID:     action.RequestID,
		AbortID:       action.AbortID,
	}
	if err := conn.WriteJSON(WireMessage{Type: "official_a2ui_abort", A2UIAbort: &abort}); err != nil {
		t.Fatal(err)
	}
	var cancelled WireMessage
	if err := conn.ReadJSON(&cancelled); err != nil {
		t.Fatal(err)
	}
	if cancelled.A2UIActionResult == nil || cancelled.A2UIActionResult.Status != "cancelled" {
		t.Fatalf("expected cancelled, got %#v", cancelled)
	}
}
