package poc

import (
	"bytes"
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

func TestA2UIValidatorRejectionsUseErrorContract(t *testing.T) {
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
}

func TestA2UIActionPolicyRejectionsUseErrorContract(t *testing.T) {
	policy := NewA2UIActionPolicy()
	action := testA2UIAction("req-action-dup")
	if err := policy.Validate(action); err != nil {
		t.Fatalf("safe action rejected: %v", err)
	}
	if err := policy.Validate(action); err == nil {
		t.Fatal("expected duplicate rejection")
	} else {
		assertA2UIErrorCode(t, err, "ACTION_DUPLICATE")
	}

	unsafe := testA2UIAction("req-action-unsafe")
	unsafe.Data["kind"] = "dangerous"
	assertA2UIErrorCode(t, policy.Validate(unsafe), "ACTION_KIND_UNSAFE")
}

func TestHTTPIngestReturnsErrorContract(t *testing.T) {
	hub := NewHub("127.0.0.1:0", "/agent/ws", nil, nil)
	request := httptest.NewRequest(http.MethodPost, A2UIIngestPath, bytes.NewReader([]byte(`{"schemaVersion":"broken"}`)))
	response := httptest.NewRecorder()
	hub.handleA2UIIngest(response, request)
	if response.Code != http.StatusBadRequest {
		t.Fatalf("unexpected status %d", response.Code)
	}
	var body map[string]interface{}
	if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	if body["ok"] != false {
		t.Fatalf("expected ok=false, got %#v", body["ok"])
	}
	errObj, ok := body["error"].(map[string]interface{})
	if !ok {
		t.Fatalf("missing error object: %#v", body)
	}
	if errObj["schemaVersion"] != A2UIErrorSchemaVersion {
		t.Fatalf("unexpected schemaVersion: %#v", errObj["schemaVersion"])
	}
	if errObj["code"] != "TPA_TRANSPORT_VERSION_UNSUPPORTED" {
		t.Fatalf("unexpected code: %#v", errObj["code"])
	}
}

func TestOfficialA2UIRejectedCarriesErrorObject(t *testing.T) {
	hub := NewHub("127.0.0.1:0", "/agent/ws", nil, nil)
	mux := http.NewServeMux()
	mux.HandleFunc(hub.path, hub.handleWS)
	server := httptest.NewServer(mux)
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + hub.path + "?clientId=reject-client"
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

	bad := WireMessage{
		Type: "official_a2ui_ingest",
		A2UI: &A2UIEnvelope{
			SchemaVersion: "broken.transport",
			EventID:       "evt-bad",
			RequestID:     "req-bad",
			CorrelationID: "corr-bad",
			CardID:        "card-bad",
			SurfaceID:     "surface-bad",
			Seq:           1,
			Message:       json.RawMessage(`{"version":"v0.9","createSurface":{"surfaceId":"surface-bad","catalogId":"https://a2ui.org/specification/v0_9/basic_catalog.json"}}`),
		},
	}
	if err := conn.WriteJSON(bad); err != nil {
		t.Fatal(err)
	}

	var reject WireMessage
	if err := conn.ReadJSON(&reject); err != nil {
		t.Fatal(err)
	}
	if reject.Type != "official_a2ui_rejected" {
		t.Fatalf("expected official_a2ui_rejected, got %s", reject.Type)
	}
	if reject.Error == nil {
		t.Fatalf("missing error object: %#v", reject)
	}
	if reject.Error.Code != "TPA_TRANSPORT_VERSION_UNSUPPORTED" {
		t.Fatalf("unexpected code: %s", reject.Error.Code)
	}
	if reject.Reason == "" {
		t.Fatal("expected legacy reason string")
	}
}

func TestActionRejectCarriesErrorDetail(t *testing.T) {
	hub := NewHub("127.0.0.1:0", "/agent/ws", nil, nil)
	mux := http.NewServeMux()
	mux.HandleFunc(hub.path, hub.handleWS)
	server := httptest.NewServer(mux)
	defer server.Close()

	wsURL := "ws" + strings.TrimPrefix(server.URL, "http") + hub.path + "?clientId=action-reject"
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

	action := testA2UIAction("req-action-reject")
	action.ActionName = "dangerous.run"
	if err := conn.WriteJSON(WireMessage{Type: "official_a2ui_action", A2UIAction: &action}); err != nil {
		t.Fatal(err)
	}
	var frame WireMessage
	if err := conn.ReadJSON(&frame); err != nil {
		t.Fatal(err)
	}
	if frame.A2UIActionResult == nil || frame.A2UIActionResult.Status != "rejected" {
		t.Fatalf("expected rejected action result, got %#v", frame)
	}
	if frame.A2UIActionResult.ErrorDetail == nil {
		t.Fatal("missing errorDetail on rejected action")
	}
	if frame.A2UIActionResult.ErrorDetail.Code != "ACTION_NOT_ALLOWED" {
		t.Fatalf("unexpected code: %s", frame.A2UIActionResult.ErrorDetail.Code)
	}
	if frame.A2UIActionResult.ErrorCode != "ACTION_NOT_ALLOWED" {
		t.Fatalf("unexpected errorCode: %s", frame.A2UIActionResult.ErrorCode)
	}
}

func assertA2UIErrorCode(t *testing.T, err error, want string) {
	t.Helper()
	if err == nil {
		t.Fatalf("expected error code %s", want)
	}
	var a2uiErr *A2UIError
	if !errors.As(err, &a2uiErr) {
		t.Fatalf("expected *A2UIError, got %T (%v)", err, err)
	}
	if a2uiErr.SchemaVersion != A2UIErrorSchemaVersion {
		t.Fatalf("unexpected schemaVersion: %s", a2uiErr.SchemaVersion)
	}
	if a2uiErr.Code != want {
		t.Fatalf("expected code %s, got %s", want, a2uiErr.Code)
	}
}
