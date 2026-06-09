package poc

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
)

const A2UIErrorSchemaVersion = "nmer.a2ui.error.v1"

// A2UIError is the stable nmer.a2ui.error.v1 contract (see docs/nmer-a2ui-error-v1.md).
type A2UIError struct {
	SchemaVersion string                 `json:"schemaVersion"`
	Code          string                 `json:"code"`
	Message       string                 `json:"message"`
	Retryable     bool                   `json:"retryable"`
	Layer         string                 `json:"layer"`
	Context       map[string]interface{} `json:"context,omitempty"`
	Fallback      *A2UIErrorFallback     `json:"fallback,omitempty"`
}

type A2UIErrorFallback struct {
	Hint        string `json:"hint,omitempty"`
	UserMessage string `json:"userMessage,omitempty"`
}

func (e *A2UIError) Error() string {
	if e == nil {
		return ""
	}
	return e.Message
}

func NewA2UIError(code, message, layer string, retryable bool) *A2UIError {
	return &A2UIError{
		SchemaVersion: A2UIErrorSchemaVersion,
		Code:          code,
		Message:       message,
		Retryable:     retryable,
		Layer:         layer,
	}
}

func a2uiErr(code, message, layer string, retryable bool) *A2UIError {
	return NewA2UIError(code, message, layer, retryable)
}

func withA2UIContext(err *A2UIError, ctx map[string]interface{}) *A2UIError {
	if err == nil {
		return nil
	}
	if len(ctx) == 0 {
		return err
	}
	if err.Context == nil {
		err.Context = map[string]interface{}{}
	}
	for key, value := range ctx {
		err.Context[key] = value
	}
	return err
}

func withEnvelopeContext(err *A2UIError, envelope *A2UIEnvelope) *A2UIError {
	if err == nil || envelope == nil {
		return err
	}
	return withA2UIContext(err, map[string]interface{}{
		"cardId":        envelope.CardID,
		"surfaceId":     envelope.SurfaceID,
		"correlationId": envelope.CorrelationID,
		"requestId":     envelope.RequestID,
		"seq":           envelope.Seq,
	})
}

func withActionContext(err *A2UIError, action *A2UIActionEnvelope) *A2UIError {
	if err == nil || action == nil {
		return err
	}
	return withA2UIContext(err, map[string]interface{}{
		"cardId":        action.CardID,
		"surfaceId":     action.SurfaceID,
		"correlationId": action.CorrelationID,
		"requestId":     action.RequestID,
		"component":     action.ComponentID,
	})
}

// AsA2UIError unwraps nmer.a2ui.error.v1 or maps a legacy Go error string.
func AsA2UIError(err error) *A2UIError {
	if err == nil {
		return nil
	}
	var a2uiErr *A2UIError
	if errors.As(err, &a2uiErr) && a2uiErr != nil {
		return a2uiErr
	}
	return mapLegacyA2UIError(err.Error())
}

func mapLegacyA2UIError(message string) *A2UIError {
	msg := strings.TrimSpace(message)
	switch {
	case msg == "":
		return a2uiErr("TPA_ENVELOPE_INVALID", "invalid A2UI envelope", "transport", false)
	case strings.Contains(msg, "empty A2UI envelope"):
		return a2uiErr("TPA_ENVELOPE_EMPTY", msg, "transport", false)
	case strings.Contains(msg, "A2UI line exceeds"):
		return a2uiErr("TPA_ENVELOPE_TOO_LARGE", msg, "transport", false)
	case strings.Contains(msg, "unsupported transport version"):
		return a2uiErr("TPA_TRANSPORT_VERSION_UNSUPPORTED", msg, "transport", false)
	case strings.Contains(msg, "is required"):
		return a2uiErr("TPA_FIELD_REQUIRED", msg, "transport", false)
	case strings.Contains(msg, "exceeds") && strings.Contains(msg, "characters"):
		return a2uiErr("TPA_FIELD_TOO_LONG", msg, "transport", false)
	case strings.Contains(msg, "seq must be positive"):
		return a2uiErr("TPA_SEQ_INVALID", msg, "transport", false)
	case strings.Contains(msg, "stale A2UI sequence"):
		return a2uiErr("TPA_SEQ_STALE", msg, "transport", true)
	case strings.Contains(msg, "message is required"):
		return a2uiErr("TPA_MESSAGE_REQUIRED", msg, "transport", false)
	case strings.Contains(msg, "invalid A2UI v0.9 message"):
		return a2uiErr("A2UI_MESSAGE_INVALID", msg, "schema", false)
	case strings.Contains(msg, "unsupported A2UI protocol version"):
		return a2uiErr("A2UI_PROTOCOL_VERSION_UNSUPPORTED", msg, "schema", false)
	case strings.Contains(msg, "catalog is not allowed"):
		return a2uiErr("A2UI_CATALOG_NOT_ALLOWED", msg, "schema", false)
	case strings.Contains(msg, "component limit exceeded"):
		return a2uiErr("A2UI_COMPONENT_LIMIT", msg, "schema", false)
	case strings.Contains(msg, "component id is required"):
		return a2uiErr("A2UI_COMPONENT_ID_REQUIRED", msg, "schema", false)
	case strings.Contains(msg, "unsupported A2UI component"):
		return a2uiErr("A2UI_COMPONENT_UNSUPPORTED", msg, "schema", false)
	case strings.Contains(msg, "must contain exactly one operation"):
		return a2uiErr("A2UI_OPERATION_AMBIGUOUS", msg, "schema", false)
	case strings.Contains(msg, "surface mismatch"):
		return a2uiErr("A2UI_SURFACE_MISMATCH", msg, "schema", false)
	case strings.Contains(msg, "unsupported A2UI action version"):
		return a2uiErr("ACTION_VERSION_UNSUPPORTED", msg, "policy", false)
	case strings.Contains(msg, "action is not allowed"):
		return a2uiErr("ACTION_NOT_ALLOWED", msg, "policy", false)
	case strings.Contains(msg, "action depth exceeded"):
		return a2uiErr("ACTION_DEPTH_EXCEEDED", msg, "policy", false)
	case strings.Contains(msg, "action timeout out of range"):
		return a2uiErr("ACTION_TIMEOUT_RANGE", msg, "policy", false)
	case strings.Contains(msg, "action kind must be safe"):
		return a2uiErr("ACTION_KIND_UNSAFE", msg, "policy", false)
	case strings.Contains(msg, "duplicate A2UI action request"):
		return a2uiErr("ACTION_DUPLICATE", msg, "policy", true)
	default:
		return a2uiErr("TPA_ENVELOPE_INVALID", msg, "transport", false)
	}
}

func wireA2UIRejectMessage(err error) WireMessage {
	a2uiErr := AsA2UIError(err)
	return WireMessage{
		Type:   "official_a2ui_rejected",
		Reason: a2uiErr.Message,
		Error:  a2uiErr,
	}
}

func writeA2UIHTTPError(w http.ResponseWriter, status int, err error) {
	if status <= 0 {
		status = http.StatusBadRequest
	}
	a2uiErr := AsA2UIError(err)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(map[string]interface{}{
		"ok":    false,
		"error": a2uiErr,
	})
}
