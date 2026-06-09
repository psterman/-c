package poc

import (
	"bufio"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
)

const (
	A2UIHealthPath          = "/agent/health"
	A2UIIngestPath          = "/a2ui/ingest"
	A2UITransportVersion    = "nmer.a2ui.transport.v1"
	A2UIProtocolVersion     = "v0.9"
	A2UIBasicCatalogID      = "https://a2ui.org/specification/v0_9/basic_catalog.json"
	maxA2UILineBytes        = 256 * 1024
	maxA2UIRequestBytes     = 1024 * 1024
	maxA2UIComponents       = 200
	a2uiReplayBufferSize    = 128
	maxA2UIIdentifierLength = 160
)

var allowedA2UIComponents = map[string]struct{}{
	"Text":      {},
	"Row":       {},
	"Column":    {},
	"Card":      {},
	"Button":    {},
	"TextField": {},
}

// A2UIEnvelope is the authoritative Go transport contract around one A2UI v0.9 message.
type A2UIEnvelope struct {
	SchemaVersion string          `json:"schemaVersion"`
	EventID       string          `json:"eventId"`
	RequestID     string          `json:"requestId"`
	CorrelationID string          `json:"correlationId"`
	CardID        string          `json:"cardId"`
	SurfaceID     string          `json:"surfaceId"`
	Seq           int             `json:"seq"`
	Final         bool            `json:"final,omitempty"`
	Message       json.RawMessage `json:"message"`
}

type a2uiOperation struct {
	Version          string                `json:"version"`
	CreateSurface    *a2uiCreateSurface    `json:"createSurface,omitempty"`
	UpdateComponents *a2uiUpdateComponents `json:"updateComponents,omitempty"`
	UpdateDataModel  *a2uiSurfaceOperation `json:"updateDataModel,omitempty"`
	DeleteSurface    *a2uiSurfaceOperation `json:"deleteSurface,omitempty"`
}

type a2uiCreateSurface struct {
	SurfaceID string `json:"surfaceId"`
	CatalogID string `json:"catalogId"`
}

type a2uiSurfaceOperation struct {
	SurfaceID string `json:"surfaceId"`
}

type a2uiUpdateComponents struct {
	SurfaceID  string          `json:"surfaceId"`
	Components []a2uiComponent `json:"components"`
}

type a2uiComponent struct {
	ID        string `json:"id"`
	Component string `json:"component"`
}

// A2UIValidator owns sequence state and authoritative transport validation.
type A2UIValidator struct {
	mu      sync.Mutex
	lastSeq map[string]int
}

func NewA2UIValidator() *A2UIValidator {
	return &A2UIValidator{lastSeq: make(map[string]int)}
}

func (v *A2UIValidator) Validate(raw []byte) (A2UIEnvelope, error) {
	envelope, err := validateA2UIEnvelopeStructure(raw)
	if err != nil {
		return A2UIEnvelope{}, err
	}
	v.mu.Lock()
	defer v.mu.Unlock()
	if err := validateA2UISequence(v.lastSeq, envelope); err != nil {
		return A2UIEnvelope{}, err
	}
	commitA2UISequence(v.lastSeq, envelope)
	return envelope, nil
}

func validateA2UIEnvelopeStructure(raw []byte) (A2UIEnvelope, error) {
	if len(raw) == 0 {
		return A2UIEnvelope{}, a2uiErr("TPA_ENVELOPE_EMPTY", "empty A2UI envelope", "transport", false)
	}
	if len(raw) > maxA2UILineBytes {
		return A2UIEnvelope{}, a2uiErr(
			"TPA_ENVELOPE_TOO_LARGE",
			fmt.Sprintf("A2UI line exceeds %d bytes", maxA2UILineBytes),
			"transport",
			false,
		)
	}

	var envelope A2UIEnvelope
	decoder := json.NewDecoder(bytes.NewReader(raw))
	decoder.DisallowUnknownFields()
	if err := decoder.Decode(&envelope); err != nil {
		return A2UIEnvelope{}, a2uiErr(
			"TPA_ENVELOPE_INVALID",
			fmt.Sprintf("invalid A2UI envelope: %v", err),
			"transport",
			false,
		)
	}
	if envelope.SchemaVersion != A2UITransportVersion {
		return A2UIEnvelope{}, withEnvelopeContext(
			a2uiErr(
				"TPA_TRANSPORT_VERSION_UNSUPPORTED",
				fmt.Sprintf("unsupported transport version: %s", envelope.SchemaVersion),
				"transport",
				false,
			),
			&envelope,
		)
	}
	for name, value := range map[string]string{
		"eventId":       envelope.EventID,
		"requestId":     envelope.RequestID,
		"correlationId": envelope.CorrelationID,
		"cardId":        envelope.CardID,
		"surfaceId":     envelope.SurfaceID,
	} {
		if strings.TrimSpace(value) == "" {
			return A2UIEnvelope{}, withEnvelopeContext(
				withA2UIContext(
					a2uiErr("TPA_FIELD_REQUIRED", fmt.Sprintf("%s is required", name), "transport", false),
					map[string]interface{}{"field": name},
				),
				&envelope,
			)
		}
		if len(value) > maxA2UIIdentifierLength {
			return A2UIEnvelope{}, withEnvelopeContext(
				withA2UIContext(
					a2uiErr(
						"TPA_FIELD_TOO_LONG",
						fmt.Sprintf("%s exceeds %d characters", name, maxA2UIIdentifierLength),
						"transport",
						false,
					),
					map[string]interface{}{"field": name},
				),
				&envelope,
			)
		}
	}
	if envelope.Seq <= 0 {
		return A2UIEnvelope{}, withEnvelopeContext(
			a2uiErr("TPA_SEQ_INVALID", "seq must be positive", "transport", false),
			&envelope,
		)
	}
	if err := validateA2UIMessage(envelope); err != nil {
		return A2UIEnvelope{}, err
	}
	return envelope, nil
}

func validateA2UISequence(lastSeq map[string]int, envelope A2UIEnvelope) error {
	if envelope.Seq <= lastSeq[envelope.SurfaceID] {
		return withEnvelopeContext(
			a2uiErr(
				"TPA_SEQ_STALE",
				fmt.Sprintf(
					"stale A2UI sequence for %s: %d <= %d",
					envelope.SurfaceID,
					envelope.Seq,
					lastSeq[envelope.SurfaceID],
				),
				"transport",
				true,
			),
			&envelope,
		)
	}
	return nil
}

func commitA2UISequence(lastSeq map[string]int, envelope A2UIEnvelope) {
	lastSeq[envelope.SurfaceID] = envelope.Seq
	if envelope.Final {
		delete(lastSeq, envelope.SurfaceID)
	}
}

func validateA2UIMessage(envelope A2UIEnvelope) error {
	if len(envelope.Message) == 0 {
		return withEnvelopeContext(
			a2uiErr("TPA_MESSAGE_REQUIRED", "message is required", "transport", false),
			&envelope,
		)
	}
	var operation a2uiOperation
	if err := json.Unmarshal(envelope.Message, &operation); err != nil {
		return withEnvelopeContext(
			a2uiErr(
				"A2UI_MESSAGE_INVALID",
				fmt.Sprintf("invalid A2UI v0.9 message: %v", err),
				"schema",
				false,
			),
			&envelope,
		)
	}
	if operation.Version != A2UIProtocolVersion {
		return withEnvelopeContext(
			a2uiErr(
				"A2UI_PROTOCOL_VERSION_UNSUPPORTED",
				fmt.Sprintf("unsupported A2UI protocol version: %s", operation.Version),
				"schema",
				false,
			),
			&envelope,
		)
	}
	operationCount := 0
	messageSurfaceID := ""
	if operation.CreateSurface != nil {
		operationCount++
		messageSurfaceID = operation.CreateSurface.SurfaceID
		if operation.CreateSurface.CatalogID != A2UIBasicCatalogID {
			return withEnvelopeContext(
				a2uiErr(
					"A2UI_CATALOG_NOT_ALLOWED",
					fmt.Sprintf("catalog is not allowed: %s", operation.CreateSurface.CatalogID),
					"schema",
					false,
				),
				&envelope,
			)
		}
	}
	if operation.UpdateComponents != nil {
		operationCount++
		messageSurfaceID = operation.UpdateComponents.SurfaceID
		if len(operation.UpdateComponents.Components) > maxA2UIComponents {
			return withEnvelopeContext(
				a2uiErr(
					"A2UI_COMPONENT_LIMIT",
					fmt.Sprintf(
						"A2UI component limit exceeded (%d/%d)",
						len(operation.UpdateComponents.Components),
						maxA2UIComponents,
					),
					"schema",
					false,
				),
				&envelope,
			)
		}
		for _, component := range operation.UpdateComponents.Components {
			if strings.TrimSpace(component.ID) == "" {
				return withEnvelopeContext(
					a2uiErr("A2UI_COMPONENT_ID_REQUIRED", "A2UI component id is required", "schema", false),
					&envelope,
				)
			}
			if _, ok := allowedA2UIComponents[component.Component]; !ok {
				return withEnvelopeContext(
					withA2UIContext(
						a2uiErr(
							"A2UI_COMPONENT_UNSUPPORTED",
							fmt.Sprintf("unsupported A2UI component: %s", component.Component),
							"schema",
							false,
						),
						map[string]interface{}{"component": component.Component},
					),
					&envelope,
				)
			}
		}
	}
	if operation.UpdateDataModel != nil {
		operationCount++
		messageSurfaceID = operation.UpdateDataModel.SurfaceID
	}
	if operation.DeleteSurface != nil {
		operationCount++
		messageSurfaceID = operation.DeleteSurface.SurfaceID
	}
	if operationCount != 1 {
		return withEnvelopeContext(
			a2uiErr(
				"A2UI_OPERATION_AMBIGUOUS",
				"A2UI message must contain exactly one operation",
				"schema",
				false,
			),
			&envelope,
		)
	}
	if messageSurfaceID != envelope.SurfaceID {
		return withEnvelopeContext(
			a2uiErr(
				"A2UI_SURFACE_MISMATCH",
				fmt.Sprintf(
					"surface mismatch: envelope=%s message=%s",
					envelope.SurfaceID,
					messageSurfaceID,
				),
				"schema",
				false,
			),
			&envelope,
		)
	}
	return nil
}

func decodeA2UIJSONL(r io.Reader, validator *A2UIValidator) ([]A2UIEnvelope, error) {
	scanner := bufio.NewScanner(io.LimitReader(r, maxA2UIRequestBytes+1))
	scanner.Buffer(make([]byte, 64*1024), maxA2UILineBytes)
	envelopes := make([]A2UIEnvelope, 0, 8)
	for scanner.Scan() {
		line := bytes.TrimSpace(scanner.Bytes())
		if len(line) == 0 {
			continue
		}
		envelope, err := validateA2UIEnvelopeStructure(line)
		if err != nil {
			return nil, err
		}
		envelopes = append(envelopes, envelope)
	}
	if err := scanner.Err(); err != nil {
		return nil, a2uiErr(
			"TPA_ENVELOPE_INVALID",
			fmt.Sprintf("read A2UI JSONL: %v", err),
			"transport",
			false,
		)
	}
	if len(envelopes) == 0 {
		return nil, a2uiErr("TPA_ENVELOPE_EMPTY", "A2UI JSONL contains no messages", "transport", false)
	}
	validator.mu.Lock()
	defer validator.mu.Unlock()
	nextSeq := make(map[string]int, len(validator.lastSeq))
	for surfaceID, seq := range validator.lastSeq {
		nextSeq[surfaceID] = seq
	}
	for _, envelope := range envelopes {
		if err := validateA2UISequence(nextSeq, envelope); err != nil {
			return nil, err
		}
		commitA2UISequence(nextSeq, envelope)
	}
	validator.lastSeq = nextSeq
	return envelopes, nil
}

func (h *Hub) handleA2UIIngest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	r.Body = http.MaxBytesReader(w, r.Body, maxA2UIRequestBytes)
	envelopes, err := decodeA2UIJSONL(r.Body, h.a2uiValidator)
	if err != nil {
		writeA2UIHTTPError(w, http.StatusBadRequest, err)
		return
	}
	for _, envelope := range envelopes {
		h.BroadcastA2UI(envelope)
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"ok":       true,
		"accepted": len(envelopes),
	})
}
