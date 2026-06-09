package poc

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestA2UIProviderConfigDefaultsToFake(t *testing.T) {
	provider, name, err := NewA2UIProvider(A2UIProviderConfig{})
	if err != nil {
		t.Fatal(err)
	}
	if name != "fake" {
		t.Fatalf("expected fake provider, got %s", name)
	}
	if _, ok := provider.(FakeA2UIProvider); !ok {
		t.Fatalf("unexpected provider type: %T", provider)
	}
}

func TestHTTPA2UIProviderRejectsRemoteEndpointByDefault(t *testing.T) {
	_, err := NewHTTPA2UIProvider(A2UIProviderConfig{
		Mode:     "http",
		Endpoint: "https://example.com/a2ui/action",
	})
	if err == nil || !strings.Contains(err.Error(), "ALLOW_REMOTE") {
		t.Fatalf("expected remote endpoint rejection, got %v", err)
	}
}

func TestHTTPA2UIProviderStreamsValidatedContext(t *testing.T) {
	action := testA2UIAction("req-http-provider")
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodPost {
			t.Fatalf("unexpected method: %s", r.Method)
		}
		if r.Header.Get("Authorization") != "Bearer test-token" {
			t.Fatalf("missing bearer token")
		}
		var received A2UIActionEnvelope
		if err := json.NewDecoder(r.Body).Decode(&received); err != nil {
			t.Fatal(err)
		}
		if received.RequestID != action.RequestID {
			t.Fatalf("wrong action request: %#v", received)
		}
		w.Header().Set("Content-Type", "application/x-ndjson")
		for seq, message := range []map[string]interface{}{
			{
				"version": A2UIProtocolVersion,
				"createSurface": map[string]interface{}{
					"surfaceId": "surface-http",
					"catalogId": A2UIBasicCatalogID,
				},
			},
			{
				"version": A2UIProtocolVersion,
				"updateDataModel": map[string]interface{}{
					"surfaceId": "surface-http",
					"path":      "/title",
					"value":     "HTTP provider works",
				},
			},
		} {
			rawMessage, err := json.Marshal(message)
			if err != nil {
				t.Fatal(err)
			}
			envelope := A2UIEnvelope{
				SchemaVersion: A2UITransportVersion,
				EventID:       fmt.Sprintf("evt-http-%d", seq+1),
				RequestID:     action.RequestID,
				CorrelationID: action.CorrelationID,
				CardID:        action.CardID,
				SurfaceID:     "surface-http",
				Seq:           seq + 1,
				Final:         seq == 1,
				Message:       rawMessage,
			}
			if err := json.NewEncoder(w).Encode(envelope); err != nil {
				t.Fatal(err)
			}
		}
	}))
	defer server.Close()

	provider, err := NewHTTPA2UIProvider(A2UIProviderConfig{
		Mode:     "http",
		Endpoint: server.URL,
		Token:    "test-token",
	})
	if err != nil {
		t.Fatal(err)
	}
	var emitted []A2UIEnvelope
	err = provider.HandleAction(context.Background(), action, func(envelope A2UIEnvelope) error {
		emitted = append(emitted, envelope)
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(emitted) != 2 || emitted[1].Seq != 2 {
		t.Fatalf("unexpected envelopes: %#v", emitted)
	}
}

func TestHTTPA2UIProviderRejectsCrossActionEnvelope(t *testing.T) {
	action := testA2UIAction("req-http-cross")
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		rawMessage, _ := json.Marshal(map[string]interface{}{
			"version": A2UIProtocolVersion,
			"updateDataModel": map[string]interface{}{
				"surfaceId": "surface-http",
				"path":      "/title",
				"value":     "wrong card",
			},
		})
		_ = json.NewEncoder(w).Encode(A2UIEnvelope{
			SchemaVersion: A2UITransportVersion,
			EventID:       "evt-cross",
			RequestID:     action.RequestID,
			CorrelationID: action.CorrelationID,
			CardID:        "another-card",
			SurfaceID:     "surface-http",
			Seq:           1,
			Message:       rawMessage,
		})
	}))
	defer server.Close()

	provider, err := NewHTTPA2UIProvider(A2UIProviderConfig{Mode: "http", Endpoint: server.URL})
	if err != nil {
		t.Fatal(err)
	}
	err = provider.HandleAction(context.Background(), action, func(A2UIEnvelope) error {
		t.Fatal("cross-action envelope was emitted")
		return nil
	})
	if err == nil || !strings.Contains(err.Error(), "does not match") {
		t.Fatalf("expected context rejection, got %v", err)
	}
}
