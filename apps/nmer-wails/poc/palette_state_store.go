package poc

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
)

const (
	PaletteStateShadowPath       = "/v1/palette/state/shadow"
	PaletteStateShadowStatusPath = "/v1/palette/state/shadow/status"
	PaletteStateSummaryPath      = "/v1/palette/state/summary"
	PaletteStateDetailPath       = "/v1/palette/state/detail"
	paletteShadowModeFull        = "shadow_write_only"
	paletteShadowModeSummary     = "summary_shadow_write"
	paletteSummaryMaxCards       = 20
)

// PaletteShadowWriteRequest is the CP3a/CP3b mirror payload from AHK persist.
type PaletteShadowWriteRequest struct {
	Source    string                   `json:"source"`
	WriteSeq  int64                    `json:"writeSeq"`
	WriteKind string                   `json:"writeKind"`
	Summary   bool                     `json:"summary"`
	Cards     []map[string]interface{} `json:"cards"`
}

// PaletteDetailWriteRequest mirrors a single full card DTO from AHK (CP3d).
type PaletteDetailWriteRequest struct {
	Source string                 `json:"source"`
	CardID string                 `json:"cardId"`
	Card   map[string]interface{} `json:"card"`
}

// PaletteDetailResponse is the CP3d lazy-load read model.
type PaletteDetailResponse struct {
	Ready     bool                   `json:"ready"`
	CardID    string                 `json:"cardId"`
	HasBlocks bool                   `json:"hasBlocks"`
	Card      map[string]interface{} `json:"card,omitempty"`
}

// PaletteSummaryResponse is the CP3c read model for frontend first-pull.
type PaletteSummaryResponse struct {
	Ready       bool                     `json:"ready"`
	Summary     bool                     `json:"summary"`
	WriteKind   string                   `json:"writeKind"`
	Limit       int                      `json:"limit"`
	CardCount   int                      `json:"cardCount"`
	WriteSeq    int64                    `json:"writeSeq"`
	LastWriteAt string                   `json:"lastWriteAt"`
	Cards       []map[string]interface{} `json:"cards"`
}

// PaletteShadowStatus exposes diagnostics for shadow-write gate scripts.
type PaletteShadowStatus struct {
	Ready       bool   `json:"ready"`
	Mode        string `json:"mode"`
	WriteKind   string `json:"writeKind"`
	SummaryOnly bool   `json:"summaryOnly"`
	CardCount   int    `json:"cardCount"`
	WriteSeq    int64  `json:"writeSeq"`
	LastWriteAt string `json:"lastWriteAt"`
	ShadowFile  string `json:"shadowFile"`
}

// PaletteStateShadowStore keeps CP3 shadow snapshots (write-only for consumers).
type PaletteStateShadowStore struct {
	mu                 sync.RWMutex
	shadowFile         string
	cardCount          int
	writeSeq           int64
	lastWriteAt        string
	writeKind          string
	summaryOnly        bool
	hasSummarySnapshot bool
	latestSummaryCards []map[string]interface{}
	detailCards        map[string]map[string]interface{}
}

func paletteShadowRootDir() string {
	root := strings.TrimSpace(os.Getenv("NMER_SCRIPT_DIR"))
	if root == "" {
		root = "."
	}
	return root
}

// NewPaletteStateShadowStore creates the shadow store under Cache/debug.
func NewPaletteStateShadowStore() *PaletteStateShadowStore {
	dir := filepath.Join(paletteShadowRootDir(), "Cache", "debug")
	_ = os.MkdirAll(dir, 0o755)
	return &PaletteStateShadowStore{
		shadowFile:  filepath.Join(dir, "palette_state_shadow.jsonl"),
		writeKind:   "full",
		detailCards: make(map[string]map[string]interface{}),
	}
}

func (s *PaletteStateShadowStore) RegisterRoutes(mux *http.ServeMux) {
	if mux == nil || s == nil {
		return
	}
	mux.HandleFunc(PaletteStateShadowPath, s.handleShadowWrite)
	mux.HandleFunc(PaletteStateShadowStatusPath, s.handleShadowStatus)
	mux.HandleFunc(PaletteStateSummaryPath, s.handleSummaryRead)
	mux.HandleFunc(PaletteStateDetailPath, s.handleDetail)
}

func (s *PaletteStateShadowStore) Status() PaletteShadowStatus {
	s.mu.RLock()
	defer s.mu.RUnlock()
	mode := paletteShadowModeFull
	if s.summaryOnly || s.writeKind == "summary" {
		mode = paletteShadowModeSummary
	}
	return PaletteShadowStatus{
		Ready:       true,
		Mode:        mode,
		WriteKind:   s.writeKind,
		SummaryOnly: s.summaryOnly,
		CardCount:   s.cardCount,
		WriteSeq:    s.writeSeq,
		LastWriteAt: s.lastWriteAt,
		ShadowFile:  s.shadowFile,
	}
}

func (s *PaletteStateShadowStore) handleShadowStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	writeJSON(w, http.StatusOK, s.Status())
}

func (s *PaletteStateShadowStore) handleDetail(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodGet:
		s.handleDetailRead(w, r)
	case http.MethodPost:
		s.handleDetailWrite(w, r)
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func detailCardID(card map[string]interface{}) string {
	if card == nil {
		return ""
	}
	if v, ok := card["cardId"].(string); ok {
		return strings.TrimSpace(v)
	}
	if v, ok := card["id"].(string); ok {
		return strings.TrimSpace(v)
	}
	return ""
}

func cardHasBlockStore(card map[string]interface{}) bool {
	if card == nil {
		return false
	}
	bs, ok := card["blockStore"].(map[string]interface{})
	if !ok || bs == nil {
		return false
	}
	blocks, ok := bs["blocks"].([]interface{})
	return ok && len(blocks) > 0
}

func validateDetailCard(card map[string]interface{}) error {
	cid := detailCardID(card)
	if cid == "" {
		return fmt.Errorf("cardId required")
	}
	if summaryOnly, ok := card["summaryOnly"].(bool); ok && summaryOnly && !cardHasBlockStore(card) {
		return fmt.Errorf("summaryOnly card must not be stored as detail without blockStore")
	}
	if !cardHasBlockStore(card) {
		return fmt.Errorf("detail card must include blockStore.blocks")
	}
	return nil
}

func (s *PaletteStateShadowStore) handleDetailRead(w http.ResponseWriter, r *http.Request) {
	cid := strings.TrimSpace(r.URL.Query().Get("cardId"))
	if cid == "" {
		http.Error(w, "cardId required", http.StatusBadRequest)
		return
	}
	s.mu.RLock()
	card := s.detailCards[cid]
	var resp PaletteDetailResponse
	if card != nil {
		resp = PaletteDetailResponse{
			Ready:     true,
			CardID:    cid,
			HasBlocks: cardHasBlockStore(card),
			Card:      card,
		}
	} else {
		resp = PaletteDetailResponse{Ready: false, CardID: cid, HasBlocks: false}
	}
	s.mu.RUnlock()
	writeJSON(w, http.StatusOK, resp)
}

func (s *PaletteStateShadowStore) handleDetailWrite(w http.ResponseWriter, r *http.Request) {
	body, err := io.ReadAll(io.LimitReader(r.Body, 8<<20))
	if err != nil {
		http.Error(w, "read body failed", http.StatusBadRequest)
		return
	}
	var req PaletteDetailWriteRequest
	if err := json.Unmarshal(body, &req); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	card := req.Card
	if card == nil {
		http.Error(w, "card required", http.StatusBadRequest)
		return
	}
	cid := strings.TrimSpace(req.CardID)
	if cid == "" {
		cid = detailCardID(card)
	}
	if cid == "" {
		http.Error(w, "cardId required", http.StatusBadRequest)
		return
	}
	if err := validateDetailCard(card); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	s.mu.Lock()
	if s.detailCards == nil {
		s.detailCards = make(map[string]map[string]interface{})
	}
	s.detailCards[cid] = card
	s.mu.Unlock()
	writeJSON(w, http.StatusOK, PaletteDetailResponse{
		Ready:     true,
		CardID:    cid,
		HasBlocks: cardHasBlockStore(card),
		Card:      card,
	})
}

func (s *PaletteStateShadowStore) handleSummaryRead(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	s.mu.RLock()
	cards := make([]map[string]interface{}, 0, len(s.latestSummaryCards))
	for _, card := range s.latestSummaryCards {
		if card != nil {
			cards = append(cards, card)
		}
	}
	resp := PaletteSummaryResponse{
		Ready:       s.hasSummarySnapshot,
		Summary:     true,
		WriteKind:   s.writeKind,
		Limit:       paletteSummaryMaxCards,
		CardCount:   len(cards),
		WriteSeq:    s.writeSeq,
		LastWriteAt: s.lastWriteAt,
		Cards:       cards,
	}
	s.mu.RUnlock()
	writeJSON(w, http.StatusOK, resp)
}

func (s *PaletteStateShadowStore) handleShadowWrite(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 8<<20))
	if err != nil {
		http.Error(w, "read body failed", http.StatusBadRequest)
		return
	}
	var req PaletteShadowWriteRequest
	if err := json.Unmarshal(body, &req); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	if err := s.applyShadowWrite(req); err != nil {
		log.Printf("[palette-shadow] write failed: %v", err)
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	writeJSON(w, http.StatusOK, s.Status())
}

func normalizeShadowWriteKind(req PaletteShadowWriteRequest) string {
	kind := strings.ToLower(strings.TrimSpace(req.WriteKind))
	if kind == "summary" || req.Summary {
		return "summary"
	}
	return "full"
}

func validateSummaryShadowCards(cards []map[string]interface{}) error {
	for i, card := range cards {
		if card == nil {
			continue
		}
		for _, key := range []string{"blockStore", "officialA2ui", "protocolClosure"} {
			if _, ok := card[key]; ok {
				return fmt.Errorf("summary card[%d] must not include %s", i, key)
			}
		}
	}
	return nil
}

func (s *PaletteStateShadowStore) applyShadowWrite(req PaletteShadowWriteRequest) error {
	kind := normalizeShadowWriteKind(req)
	if kind == "summary" {
		if err := validateSummaryShadowCards(req.Cards); err != nil {
			return err
		}
	}
	line, err := json.Marshal(req)
	if err != nil {
		return err
	}
	f, err := os.OpenFile(s.shadowFile, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return err
	}
	if _, err := f.Write(append(line, '\n')); err != nil {
		_ = f.Close()
		return err
	}
	if err := f.Close(); err != nil {
		return err
	}
	s.mu.Lock()
	s.cardCount = len(req.Cards)
	if req.WriteSeq > 0 {
		s.writeSeq = req.WriteSeq
	} else {
		s.writeSeq++
	}
	s.writeKind = kind
	s.summaryOnly = kind == "summary"
	s.lastWriteAt = NowISO()
	if kind == "summary" {
		n := len(req.Cards)
		if n > paletteSummaryMaxCards {
			n = paletteSummaryMaxCards
		}
		snap := make([]map[string]interface{}, 0, n)
		for i := 0; i < n; i++ {
			if req.Cards[i] != nil {
				snap = append(snap, req.Cards[i])
			}
		}
		s.latestSummaryCards = snap
		s.hasSummarySnapshot = true
	}
	s.mu.Unlock()
	return nil
}

func writeJSON(w http.ResponseWriter, code int, payload interface{}) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(payload)
}
