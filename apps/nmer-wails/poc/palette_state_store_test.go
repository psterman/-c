package poc

import (
	"bytes"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"
)

func TestPaletteStateShadowStore_WriteAndStatus(t *testing.T) {
	t.Setenv("NMER_SCRIPT_DIR", t.TempDir())
	store := NewPaletteStateShadowStore()
	mux := http.NewServeMux()
	store.RegisterRoutes(mux)

	reqBody := PaletteShadowWriteRequest{
		Source:   "test",
		WriteSeq: 7,
		Cards: []map[string]interface{}{
			{"cardId": "c1", "title": "demo"},
		},
	}
	raw, _ := json.Marshal(reqBody)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, PaletteStateShadowPath, bytes.NewReader(raw))
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("POST status=%d body=%s", rec.Code, rec.Body.String())
	}

	stRec := httptest.NewRecorder()
	stReq := httptest.NewRequest(http.MethodGet, PaletteStateShadowStatusPath, nil)
	mux.ServeHTTP(stRec, stReq)
	if stRec.Code != http.StatusOK {
		t.Fatalf("GET status=%d", stRec.Code)
	}
	var st PaletteShadowStatus
	if err := json.Unmarshal(stRec.Body.Bytes(), &st); err != nil {
		t.Fatal(err)
	}
	if st.CardCount != 1 || st.WriteSeq != 7 || st.WriteKind != "full" {
		t.Fatalf("unexpected status: %+v", st)
	}
	if _, err := os.Stat(store.shadowFile); err != nil {
		t.Fatalf("shadow file missing: %v", err)
	}
}

func TestPaletteStateShadowStore_SummaryRejectsBlockStore(t *testing.T) {
	t.Setenv("NMER_SCRIPT_DIR", t.TempDir())
	store := NewPaletteStateShadowStore()
	mux := http.NewServeMux()
	store.RegisterRoutes(mux)

	reqBody := PaletteShadowWriteRequest{
		Source:    "test",
		WriteSeq:  8,
		WriteKind: "summary",
		Summary:   true,
		Cards: []map[string]interface{}{
			{"cardId": "c1", "summaryOnly": true, "blockStore": map[string]interface{}{"x": 1}},
		},
	}
	raw, _ := json.Marshal(reqBody)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, PaletteStateShadowPath, bytes.NewReader(raw))
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 got %d body=%s", rec.Code, rec.Body.String())
	}
}

func TestPaletteStateShadowStore_SummaryWrite(t *testing.T) {
	t.Setenv("NMER_SCRIPT_DIR", t.TempDir())
	store := NewPaletteStateShadowStore()
	mux := http.NewServeMux()
	store.RegisterRoutes(mux)

	reqBody := PaletteShadowWriteRequest{
		Source:    "test",
		WriteSeq:  9,
		WriteKind: "summary",
		Summary:   true,
		Cards: []map[string]interface{}{
			{"cardId": "c1", "title": "demo", "summaryOnly": true},
		},
	}
	raw, _ := json.Marshal(reqBody)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, PaletteStateShadowPath, bytes.NewReader(raw))
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("POST status=%d body=%s", rec.Code, rec.Body.String())
	}
	st := store.Status()
	if st.WriteKind != "summary" || !st.SummaryOnly || st.Mode != paletteShadowModeSummary {
		t.Fatalf("unexpected summary status: %+v", st)
	}
}

func TestPaletteStateShadowStore_SummaryReadCapsAt20(t *testing.T) {
	t.Setenv("NMER_SCRIPT_DIR", t.TempDir())
	store := NewPaletteStateShadowStore()
	mux := http.NewServeMux()
	store.RegisterRoutes(mux)

	cards := make([]map[string]interface{}, 0, 25)
	for i := 0; i < 25; i++ {
		cards = append(cards, map[string]interface{}{
			"cardId":      fmt.Sprintf("c%d", i),
			"summaryOnly": true,
		})
	}
	reqBody := PaletteShadowWriteRequest{
		Source:    "test",
		WriteSeq:  10,
		WriteKind: "summary",
		Summary:   true,
		Cards:     cards,
	}
	raw, _ := json.Marshal(reqBody)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, PaletteStateShadowPath, bytes.NewReader(raw))
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("POST status=%d body=%s", rec.Code, rec.Body.String())
	}

	sumRec := httptest.NewRecorder()
	sumReq := httptest.NewRequest(http.MethodGet, PaletteStateSummaryPath, nil)
	mux.ServeHTTP(sumRec, sumReq)
	if sumRec.Code != http.StatusOK {
		t.Fatalf("GET summary status=%d", sumRec.Code)
	}
	var summary PaletteSummaryResponse
	if err := json.Unmarshal(sumRec.Body.Bytes(), &summary); err != nil {
		t.Fatal(err)
	}
	if !summary.Ready || !summary.Summary || summary.Limit != paletteSummaryMaxCards {
		t.Fatalf("unexpected summary envelope: %+v", summary)
	}
	if summary.CardCount != paletteSummaryMaxCards || len(summary.Cards) != paletteSummaryMaxCards {
		t.Fatalf("expected %d cards got count=%d len=%d", paletteSummaryMaxCards, summary.CardCount, len(summary.Cards))
	}
}

func TestPaletteStateShadowStore_DetailWriteAndRead(t *testing.T) {
	t.Setenv("NMER_SCRIPT_DIR", t.TempDir())
	store := NewPaletteStateShadowStore()
	mux := http.NewServeMux()
	store.RegisterRoutes(mux)

	card := map[string]interface{}{
		"cardId":      "cp3d_probe",
		"title":       "detail probe",
		"summaryOnly": false,
		"blockStore": map[string]interface{}{
			"blocks": []interface{}{
				map[string]interface{}{"id": "b1", "kind": "reply", "text": "hello"},
			},
			"blockVersion": 1,
		},
	}
	reqBody := PaletteDetailWriteRequest{Source: "test", CardID: "cp3d_probe", Card: card}
	raw, _ := json.Marshal(reqBody)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, PaletteStateDetailPath, bytes.NewReader(raw))
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("POST detail status=%d body=%s", rec.Code, rec.Body.String())
	}

	getRec := httptest.NewRecorder()
	getReq := httptest.NewRequest(http.MethodGet, PaletteStateDetailPath+"?cardId=cp3d_probe", nil)
	mux.ServeHTTP(getRec, getReq)
	if getRec.Code != http.StatusOK {
		t.Fatalf("GET detail status=%d", getRec.Code)
	}
	var detail PaletteDetailResponse
	if err := json.Unmarshal(getRec.Body.Bytes(), &detail); err != nil {
		t.Fatal(err)
	}
	if !detail.Ready || !detail.HasBlocks || detail.CardID != "cp3d_probe" {
		t.Fatalf("unexpected detail: %+v", detail)
	}
}

func TestPaletteStateShadowStore_DetailRejectsSummaryOnly(t *testing.T) {
	t.Setenv("NMER_SCRIPT_DIR", t.TempDir())
	store := NewPaletteStateShadowStore()
	mux := http.NewServeMux()
	store.RegisterRoutes(mux)

	reqBody := PaletteDetailWriteRequest{
		Source: "test",
		CardID: "bad",
		Card: map[string]interface{}{
			"cardId":      "bad",
			"summaryOnly": true,
			"rawAnswer":   "short",
		},
	}
	raw, _ := json.Marshal(reqBody)
	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodPost, PaletteStateDetailPath, bytes.NewReader(raw))
	mux.ServeHTTP(rec, req)
	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected 400 got %d body=%s", rec.Code, rec.Body.String())
	}
}
