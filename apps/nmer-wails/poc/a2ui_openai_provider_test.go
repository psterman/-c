package poc

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"
)

func TestOpenAIChatA2UIProviderEmitsWrappedMessages(t *testing.T) {
	action := testA2UIAction("req-openai-chat")
	var expectedSurfaceID string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/v1/chat/completions" {
			t.Fatalf("unexpected path: %s", r.URL.Path)
		}
		var body map[string]interface{}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			t.Fatal(err)
		}
		if body["model"] != "hermes-agent" {
			t.Fatalf("wrong model: %#v", body["model"])
		}
		expectedSurfaceID = providerSurfaceID(action)
		content := strings.Join([]string{
			`{"version":"v0.9","createSurface":{"surfaceId":"` + expectedSurfaceID + `","catalogId":"` + A2UIBasicCatalogID + `"}}`,
			`{"version":"v0.9","updateComponents":{"surfaceId":"` + expectedSurfaceID + `","components":[{"id":"root","component":"Text","text":"Hermes A2UI"}]}}`,
			`{"version":"v0.9","updateDataModel":{"surfaceId":"` + expectedSurfaceID + `","path":"/title","value":"done"}}`,
		}, "\n")
		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"choices": []map[string]interface{}{
				{"message": map[string]interface{}{"content": content}},
			},
		})
	}))
	defer server.Close()

	provider, err := NewOpenAIChatA2UIProvider(A2UIProviderConfig{
		Mode:     "openai-chat",
		Endpoint: server.URL + "/v1",
		Model:    "hermes-agent",
	})
	if err != nil {
		t.Fatal(err)
	}
	validator := NewA2UIValidator()
	var emitted []A2UIEnvelope
	err = provider.HandleAction(context.Background(), action, func(envelope A2UIEnvelope) error {
		raw, marshalErr := json.Marshal(envelope)
		if marshalErr != nil {
			return marshalErr
		}
		validated, validateErr := validator.Validate(raw)
		if validateErr != nil {
			return validateErr
		}
		emitted = append(emitted, validated)
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if len(emitted) != 3 || !emitted[2].Final {
		t.Fatalf("unexpected envelopes: %#v", emitted)
	}
	if emitted[0].SurfaceID != expectedSurfaceID {
		t.Fatalf("wrong surface: %s", emitted[0].SurfaceID)
	}
}

func TestOpenAIChatA2UIProviderRejectsProse(t *testing.T) {
	action := testA2UIAction("req-openai-prose")
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"choices": []map[string]interface{}{
				{"message": map[string]interface{}{"content": "Here is your UI:\nnot-json"}},
			},
		})
	}))
	defer server.Close()

	provider, err := NewOpenAIChatA2UIProvider(A2UIProviderConfig{
		Mode:     "openai-chat",
		Endpoint: server.URL,
		Model:    "hermes-agent",
	})
	if err != nil {
		t.Fatal(err)
	}
	err = provider.HandleAction(context.Background(), action, func(A2UIEnvelope) error {
		t.Fatal("invalid model output was emitted")
		return nil
	})
	if err == nil || !strings.Contains(err.Error(), "invalid A2UI JSONL") {
		t.Fatalf("expected JSONL rejection, got %v", err)
	}
}

func TestOpenAIChatA2UIProviderRejectsMalformedJSONL(t *testing.T) {
	action := testA2UIAction("req-openai-malformed")
	surfaceID := providerSurfaceID(action)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		content := strings.Join([]string{
			`{"version":"v0.9","createSurface":{"surfaceId":"` + surfaceID + `","catalogId":"` + A2UIBasicCatalogID + `"}}`,
			`{not-json`,
		}, "\n")
		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"choices": []map[string]interface{}{
				{"message": map[string]interface{}{"content": content}},
			},
		})
	}))
	defer server.Close()

	provider, err := NewOpenAIChatA2UIProvider(A2UIProviderConfig{
		Mode:     "openai-chat",
		Endpoint: server.URL,
		Model:    "hermes-agent",
	})
	if err != nil {
		t.Fatal(err)
	}
	err = provider.HandleAction(context.Background(), action, func(A2UIEnvelope) error {
		t.Fatal("malformed JSONL should not emit")
		return nil
	})
	if err == nil || !strings.Contains(err.Error(), "invalid A2UI JSONL") {
		t.Fatalf("expected malformed JSONL rejection, got %v", err)
	}
}

func TestOpenAIChatA2UIProviderRejectsUnsupportedComponent(t *testing.T) {
	action := testA2UIAction("req-openai-unsupported")
	surfaceID := providerSurfaceID(action)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		content := strings.Join([]string{
			`{"version":"v0.9","createSurface":{"surfaceId":"` + surfaceID + `","catalogId":"` + A2UIBasicCatalogID + `"}}`,
			`{"version":"v0.9","updateComponents":{"surfaceId":"` + surfaceID + `","components":[{"id":"root","component":"VideoPlayer"}]}}`,
		}, "\n")
		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"choices": []map[string]interface{}{
				{"message": map[string]interface{}{"content": content}},
			},
		})
	}))
	defer server.Close()

	provider, err := NewOpenAIChatA2UIProvider(A2UIProviderConfig{
		Mode:     "openai-chat",
		Endpoint: server.URL,
		Model:    "hermes-agent",
	})
	if err != nil {
		t.Fatal(err)
	}
	validator := NewA2UIValidator()
	err = provider.HandleAction(context.Background(), action, func(envelope A2UIEnvelope) error {
		raw, marshalErr := json.Marshal(envelope)
		if marshalErr != nil {
			return marshalErr
		}
		_, validateErr := validator.Validate(raw)
		return validateErr
	})
	if err == nil {
		t.Fatal("expected unsupported component rejection")
	}
	assertA2UIErrorCode(t, err, "A2UI_COMPONENT_UNSUPPORTED")
}

func TestOpenAIChatA2UIProviderAcceptsFencedJSONL(t *testing.T) {
	action := testA2UIAction("req-openai-fence")
	surfaceID := providerSurfaceID(action)
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		inner := `{"version":"v0.9","createSurface":{"surfaceId":"` + surfaceID + `","catalogId":"` + A2UIBasicCatalogID + `"}}`
		content := "```jsonl\n" + inner + "\n```"
		_ = json.NewEncoder(w).Encode(map[string]interface{}{
			"choices": []map[string]interface{}{
				{"message": map[string]interface{}{"content": content}},
			},
		})
	}))
	defer server.Close()

	provider, err := NewOpenAIChatA2UIProvider(A2UIProviderConfig{
		Mode:     "openai-chat",
		Endpoint: server.URL,
		Model:    "hermes-agent",
	})
	if err != nil {
		t.Fatal(err)
	}
	var emitted int
	err = provider.HandleAction(context.Background(), action, func(envelope A2UIEnvelope) error {
		emitted++
		return nil
	})
	if err != nil {
		t.Fatal(err)
	}
	if emitted != 1 {
		t.Fatalf("expected 1 envelope from fenced JSONL, got %d", emitted)
	}
}

func TestHermesProviderLiveSmoke(t *testing.T) {
	if os.Getenv("HERMES_LIVE") != "1" {
		t.Skip("set HERMES_LIVE=1 for live Hermes smoke")
	}
	token := strings.TrimSpace(os.Getenv("HERMES_API_SERVER_KEY"))
	if token == "" {
		token = strings.TrimSpace(os.Getenv("NMER_A2UI_PROVIDER_TOKEN"))
	}
	if token == "" {
		t.Fatal("HERMES_API_SERVER_KEY or NMER_A2UI_PROVIDER_TOKEN required")
	}
	endpoint := strings.TrimSpace(os.Getenv("NMER_A2UI_PROVIDER_URL"))
	if endpoint == "" {
		endpoint = "http://127.0.0.1:8642/v1"
	}
	model := strings.TrimSpace(os.Getenv("NMER_A2UI_PROVIDER_MODEL"))
	if model == "" {
		model = "hermes-agent"
	}
	allowRemote := strings.EqualFold(strings.TrimSpace(os.Getenv("NMER_A2UI_ALLOW_REMOTE_PROVIDER")), "true")
	provider, err := NewOpenAIChatA2UIProvider(A2UIProviderConfig{
		Mode:        "openai-chat",
		Endpoint:    endpoint,
		Token:       token,
		Model:       model,
		AllowRemote: allowRemote,
	})
	if err != nil {
		t.Fatal(err)
	}
	action := testA2UIAction("req-hermes-live-smoke")
	action.Data = map[string]interface{}{
		"question": "Reply with a minimal A2UI surface titled Hello Hermes.",
	}
	ctx, cancel := context.WithTimeout(context.Background(), 90*time.Second)
	defer cancel()
	var emitted []A2UIEnvelope
	err = provider.HandleAction(ctx, action, func(envelope A2UIEnvelope) error {
		emitted = append(emitted, envelope)
		return nil
	})
	if err != nil {
		t.Fatalf("hermes live smoke failed: %v", err)
	}
	if len(emitted) < 2 {
		t.Fatalf("expected >=2 envelopes from live Hermes, got %d", len(emitted))
	}
	t.Logf("hermes live ok envelopes=%d surface=%s", len(emitted), emitted[0].SurfaceID)
}
