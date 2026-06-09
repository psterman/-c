package poc

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestOpenClawAdapterRejectsCpSessionRef(t *testing.T) {
	hub := NewHub("127.0.0.1:0", DefaultWSPath, nil, nil)
	mux := http.NewServeMux()
	mux.HandleFunc(OpenClawAdapterActionPath, hub.handleOpenClawAdapterAction)
	body, _ := json.Marshal(OpenClawActionRequest{
		CardID:     "card_test_1",
		RequestID:  "req-1",
		Query:      "/search hello",
		SessionRef: OpenClawSessionKeyForCard("card_test_1", OpenClawNamespaceCP),
	})
	req := httptest.NewRequest(http.MethodPost, OpenClawAdapterActionPath, bytes.NewReader(body))
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusConflict {
		t.Fatalf("status: got %d body=%s", rec.Code, rec.Body.String())
	}
}

func TestOpenClawAdapterMissingOpenClawConfig(t *testing.T) {
	hub := NewHub("127.0.0.1:0", DefaultWSPath, nil, nil)
	mux := http.NewServeMux()
	mux.HandleFunc(OpenClawAdapterActionPath, hub.handleOpenClawAdapterAction)
	body, _ := json.Marshal(OpenClawActionRequest{
		CardID:     "card_test_2",
		RequestID:  "req-2",
		Query:      "/search hello",
		SessionRef: OpenClawSessionKeyForCard("card_test_2", OpenClawNamespaceAdapter),
	})
	req := httptest.NewRequest(http.MethodPost, OpenClawAdapterActionPath, bytes.NewReader(body))
	rec := httptest.NewRecorder()
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusServiceUnavailable {
		t.Fatalf("status: got %d body=%s", rec.Code, rec.Body.String())
	}
}
