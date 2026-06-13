package poc

import (
	"context"
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"time"
)

const (
	OpenClawAdapterActionPath = "/a2ui/openclaw/action"
	maxOpenClawActionBody     = 256 * 1024
	openClawAdapterTimeout    = 120 * time.Second
)

// OpenClawActionRequest is the ADP-1 ingress before OpenClaw WS orchestration.
type OpenClawActionRequest struct {
	CardID       string `json:"cardId"`
	RequestID    string `json:"requestId"`
	Query        string `json:"query"`
	SessionRef   string `json:"sessionRef"`
	SystemPrompt string `json:"systemPrompt,omitempty"`
	TransportNS  string `json:"transportNamespace,omitempty"`
}

type openClawActionResponse struct {
	OK        bool            `json:"ok"`
	Code      string          `json:"code"`
	Message   string          `json:"message,omitempty"`
	Accepted  int             `json:"accepted,omitempty"`
	SurfaceID string          `json:"surfaceId,omitempty"`
	RequestID string          `json:"requestId,omitempty"`
	Answer    string          `json:"answer,omitempty"`
	Detail    json.RawMessage `json:"detail,omitempty"`
}

func composeOpenClawChatMessage(systemPrompt, query string) string {
	systemPrompt = strings.TrimSpace(systemPrompt)
	query = strings.TrimSpace(query)
	if systemPrompt == "" {
		return query
	}
	if query == "" {
		return systemPrompt
	}
	return systemPrompt + "\n\n" + query
}

func (h *Hub) handleOpenClawAdapterAction(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeOpenClawActionError(w, http.StatusMethodNotAllowed, "METHOD_NOT_ALLOWED", "POST required")
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, maxOpenClawActionBody))
	if err != nil {
		writeOpenClawActionError(w, http.StatusBadRequest, "BODY_READ_FAILED", err.Error())
		return
	}
	var req OpenClawActionRequest
	if err := json.Unmarshal(body, &req); err != nil {
		writeOpenClawActionError(w, http.StatusBadRequest, "JSON_INVALID", err.Error())
		return
	}
	req.CardID = strings.TrimSpace(req.CardID)
	req.Query = strings.TrimSpace(req.Query)
	req.RequestID = strings.TrimSpace(req.RequestID)
	if req.CardID == "" || req.Query == "" {
		writeOpenClawActionError(w, http.StatusBadRequest, "FIELD_REQUIRED", "cardId and query are required")
		return
	}
	ns := strings.TrimSpace(req.TransportNS)
	if ns == "" {
		ns = OpenClawNamespaceAdapter
	}
	wantRef := OpenClawSessionKeyForCard(req.CardID, ns)
	sessionRef := wantRef
	if sr := strings.TrimSpace(req.SessionRef); sr != "" {
		canonical := OpenClawCanonicalSessionKey(sr)
		if IsOpenClawCPSessionKey(canonical) {
			writeOpenClawActionError(w, http.StatusConflict, "SESSION_REF_CP_ON_ADAPTER",
				"adapter path cannot reuse niuma-cp sessionRef")
			return
		}
		if canonical != wantRef && !IsOpenClawAdapterSessionKey(canonical) {
			writeOpenClawActionError(w, http.StatusBadRequest, "SESSION_REF_INVALID",
				"sessionRef must use adapter namespace")
			return
		}
		sessionRef = canonical
	}
	if req.RequestID == "" {
		req.RequestID = "adp-" + openClawCardIDSlug(req.CardID)
	}

	cfg, err := OpenClawGatewayConfigFromEnv()
	if err != nil {
		writeOpenClawActionError(w, http.StatusServiceUnavailable, "OPENCLAW_CONFIG_MISSING", err.Error())
		return
	}

	ctx, cancel := context.WithTimeout(r.Context(), openClawAdapterTimeout)
	defer cancel()

	client := NewOpenClawGatewayClient(cfg)
	chatMessage := composeOpenClawChatMessage(req.SystemPrompt, req.Query)
	answer, err := client.SendChatStreaming(ctx, sessionRef, chatMessage, func(delta string) {
		d := strings.TrimSpace(delta)
		if d == "" {
			return
		}
		cardID := req.CardID
		reqID := req.RequestID
		go func(text, cardID, reqID string) {
			h.BroadcastEvent(AgentEvent{
				Kind:   EventReplyDelta,
				CardID: cardID,
				Payload: map[string]interface{}{
					"reqId":  reqID,
					"delta":  text,
					"cardId": cardID,
					"source": "openclaw_adapter",
				},
			})
		}(d, cardID, reqID)
	})
	if err != nil {
		writeOpenClawActionError(w, http.StatusBadGateway, "OPENCLAW_CHAT_FAILED", err.Error())
		return
	}
	h.BroadcastEvent(AgentEvent{
		Kind:   EventReplyFinal,
		CardID: req.CardID,
		Payload: map[string]interface{}{
			"reqId":  req.RequestID,
			"answer": answer,
			"cardId": req.CardID,
			"source": "openclaw_adapter",
		},
	})

	surfaceID := openClawAdapterSurfaceID(req.CardID)
	envelopes, err := BuildOpenClawTextSurfaceEnvelopes(
		req.CardID,
		req.RequestID,
		surfaceID,
		"OpenClaw · Adapter",
		answer,
	)
	if err != nil {
		writeOpenClawActionError(w, http.StatusInternalServerError, "A2UI_BUILD_FAILED", err.Error())
		return
	}
	accepted, err := h.ingestA2UIEnvelopes(envelopes)
	if err != nil {
		writeOpenClawActionError(w, http.StatusBadRequest, "A2UI_INGEST_FAILED", err.Error())
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(openClawActionResponse{
		OK:        true,
		Code:      "ADAPTER_OK",
		Message:   "openclaw answer ingested",
		Accepted:  accepted,
		SurfaceID: surfaceID,
		RequestID: req.RequestID,
		Answer:    answer,
	})
}

func (h *Hub) ingestA2UIEnvelopes(envelopes []A2UIEnvelope) (int, error) {
	accepted := 0
	for _, envelope := range envelopes {
		raw, err := json.Marshal(envelope)
		if err != nil {
			return accepted, err
		}
		validated, err := h.a2uiValidator.Validate(raw)
		if err != nil {
			return accepted, err
		}
		h.BroadcastA2UI(validated)
		accepted++
	}
	return accepted, nil
}

func writeOpenClawActionError(w http.ResponseWriter, status int, code, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(openClawActionResponse{
		OK:      false,
		Code:    code,
		Message: message,
	})
}
