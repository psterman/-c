package poc

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"sync"
	"time"
)

const (
	A2UIActionVersion       = "nmer.a2ui.action.v1"
	A2UIActionResultVersion = "nmer.a2ui.action-result.v1"
	maxA2UIActionDepth      = 2
	minA2UIActionTimeoutMs  = 100
	maxA2UIActionTimeoutMs  = 30_000
	a2uiActionDedupWindow   = 10 * time.Second
)

type A2UIActionEnvelope struct {
	SchemaVersion string                 `json:"schemaVersion"`
	EventID       string                 `json:"eventId"`
	RequestID     string                 `json:"requestId"`
	CorrelationID string                 `json:"correlationId"`
	CardID        string                 `json:"cardId"`
	SurfaceID     string                 `json:"surfaceId"`
	ComponentID   string                 `json:"componentId"`
	ActionName    string                 `json:"actionName"`
	Depth         int                    `json:"depth"`
	TimeoutMs     int                    `json:"timeoutMs"`
	AbortID       string                 `json:"abortId"`
	Data          map[string]interface{} `json:"data"`
}

type A2UIActionResult struct {
	SchemaVersion string     `json:"schemaVersion"`
	RequestID     string     `json:"requestId"`
	CorrelationID string     `json:"correlationId"`
	CardID        string     `json:"cardId"`
	SurfaceID     string     `json:"surfaceId"`
	Status        string     `json:"status"`
	ErrorCode     string     `json:"errorCode,omitempty"`
	Error         string     `json:"error,omitempty"`
	ErrorDetail   *A2UIError `json:"errorDetail,omitempty"`
}

type A2UIAbortEnvelope struct {
	SchemaVersion string `json:"schemaVersion"`
	RequestID     string `json:"requestId"`
	AbortID       string `json:"abortId"`
}

type A2UIProvider interface {
	HandleAction(context.Context, A2UIActionEnvelope, func(A2UIEnvelope) error) error
}

type A2UIActionPolicy struct {
	mu           sync.Mutex
	seen         map[string]time.Time
	surfaceCards map[string]string
}

func NewA2UIActionPolicy() *A2UIActionPolicy {
	return &A2UIActionPolicy{
		seen:         make(map[string]time.Time),
		surfaceCards: make(map[string]string),
	}
}

func (p *A2UIActionPolicy) RegisterSurface(surfaceID, cardID string) {
	surfaceID = strings.TrimSpace(surfaceID)
	cardID = strings.TrimSpace(cardID)
	if surfaceID == "" || cardID == "" {
		return
	}
	p.mu.Lock()
	defer p.mu.Unlock()
	p.surfaceCards[surfaceID] = cardID
}

func (p *A2UIActionPolicy) Validate(action A2UIActionEnvelope) error {
	if action.SchemaVersion != A2UIActionVersion {
		return withActionContext(
			a2uiErr(
				"ACTION_VERSION_UNSUPPORTED",
				fmt.Sprintf("unsupported A2UI action version: %s", action.SchemaVersion),
				"policy",
				false,
			),
			&action,
		)
	}
	for name, value := range map[string]string{
		"eventId":       action.EventID,
		"requestId":     action.RequestID,
		"correlationId": action.CorrelationID,
		"cardId":        action.CardID,
		"surfaceId":     action.SurfaceID,
		"componentId":   action.ComponentID,
		"abortId":       action.AbortID,
	} {
		if strings.TrimSpace(value) == "" {
			return withActionContext(
				withA2UIContext(
					a2uiErr("TPA_FIELD_REQUIRED", fmt.Sprintf("%s is required", name), "policy", false),
					map[string]interface{}{"field": name},
				),
				&action,
			)
		}
		if len(value) > maxA2UIIdentifierLength {
			return withActionContext(
				withA2UIContext(
					a2uiErr(
						"TPA_FIELD_TOO_LONG",
						fmt.Sprintf("%s exceeds %d characters", name, maxA2UIIdentifierLength),
						"policy",
						false,
					),
					map[string]interface{}{"field": name},
				),
				&action,
			)
		}
	}
	if action.ActionName != "safe.follow-up" {
		return withActionContext(
			withA2UIContext(
				a2uiErr(
					"ACTION_NOT_ALLOWED",
					fmt.Sprintf("A2UI action is not allowed: %s", action.ActionName),
					"policy",
					false,
				),
				map[string]interface{}{"actionName": action.ActionName},
			),
			&action,
		)
	}
	if action.Depth < 0 || action.Depth > maxA2UIActionDepth {
		return withActionContext(
			a2uiErr(
				"ACTION_DEPTH_EXCEEDED",
				fmt.Sprintf("A2UI action depth exceeded: %d/%d", action.Depth, maxA2UIActionDepth),
				"policy",
				false,
			),
			&action,
		)
	}
	if action.TimeoutMs < minA2UIActionTimeoutMs || action.TimeoutMs > maxA2UIActionTimeoutMs {
		return withActionContext(
			a2uiErr(
				"ACTION_TIMEOUT_RANGE",
				fmt.Sprintf("A2UI action timeout out of range: %d", action.TimeoutMs),
				"policy",
				false,
			),
			&action,
		)
	}
	if action.Data == nil || action.Data["kind"] != "safe" {
		return withActionContext(
			a2uiErr("ACTION_KIND_UNSAFE", "A2UI action kind must be safe", "policy", false),
			&action,
		)
	}

	p.mu.Lock()
	if owner, exists := p.surfaceCards[action.SurfaceID]; exists && owner != action.CardID {
		p.mu.Unlock()
		return withActionContext(
			withA2UIContext(
				a2uiErr(
					"SEM_ACTION_CONTEXT_MISMATCH",
					fmt.Sprintf("surface %s is bound to card %s, not %s", action.SurfaceID, owner, action.CardID),
					"semantic",
					false,
				),
				map[string]interface{}{
					"surfaceId":      action.SurfaceID,
					"expectedCardId": owner,
					"actionCardId":   action.CardID,
				},
			),
			&action,
		)
	}
	p.mu.Unlock()

	now := time.Now()
	p.mu.Lock()
	defer p.mu.Unlock()
	for requestID, seenAt := range p.seen {
		if now.Sub(seenAt) >= a2uiActionDedupWindow {
			delete(p.seen, requestID)
		}
	}
	if seenAt, exists := p.seen[action.RequestID]; exists && now.Sub(seenAt) < a2uiActionDedupWindow {
		return withActionContext(
			a2uiErr(
				"ACTION_DUPLICATE",
				fmt.Sprintf("duplicate A2UI action request: %s", action.RequestID),
				"policy",
				true,
			),
			&action,
		)
	}
	p.seen[action.RequestID] = now
	return nil
}

func actionResultFromError(action A2UIActionEnvelope, status string, err error) A2UIActionResult {
	a2uiErrObj := AsA2UIError(err)
	return A2UIActionResult{
		SchemaVersion: A2UIActionResultVersion,
		RequestID:     action.RequestID,
		CorrelationID: action.CorrelationID,
		CardID:        action.CardID,
		SurfaceID:     action.SurfaceID,
		Status:        status,
		ErrorCode:     a2uiErrObj.Code,
		Error:         a2uiErrObj.Message,
		ErrorDetail:   a2uiErrObj,
	}
}

func validateA2UIAbort(abort A2UIAbortEnvelope) error {
	if abort.SchemaVersion != A2UIActionVersion {
		return fmt.Errorf("unsupported A2UI abort version: %s", abort.SchemaVersion)
	}
	if strings.TrimSpace(abort.RequestID) == "" || strings.TrimSpace(abort.AbortID) == "" {
		return errors.New("A2UI abort requestId and abortId are required")
	}
	if len(abort.RequestID) > maxA2UIIdentifierLength || len(abort.AbortID) > maxA2UIIdentifierLength {
		return errors.New("A2UI abort identifier is too long")
	}
	return nil
}

type FakeA2UIProvider struct{}

func (FakeA2UIProvider) HandleAction(
	ctx context.Context,
	action A2UIActionEnvelope,
	emit func(A2UIEnvelope) error,
) error {
	suffix := strings.NewReplacer(" ", "-", "/", "-", "\\", "-").Replace(action.RequestID)
	if len(suffix) > 40 {
		suffix = suffix[len(suffix)-40:]
	}
	prefix := action.SurfaceID
	maxPrefixLength := maxA2UIIdentifierLength - len("-followup-") - len(suffix)
	if maxPrefixLength < 1 {
		maxPrefixLength = 1
	}
	if len(prefix) > maxPrefixLength {
		prefix = prefix[:maxPrefixLength]
	}
	surfaceID := prefix + "-followup-" + suffix
	question := strings.TrimSpace(fmt.Sprint(action.Data["question"]))
	if question == "" {
		question = "继续完善 CommandPalette"
	}
	messages := []map[string]interface{}{
		{
			"version": A2UIProtocolVersion,
			"createSurface": map[string]interface{}{
				"surfaceId": surfaceID,
				"catalogId": A2UIBasicCatalogID,
			},
		},
		{
			"version": A2UIProtocolVersion,
			"updateComponents": map[string]interface{}{
				"surfaceId": surfaceID,
				"components": []map[string]interface{}{
					{"id": "root", "component": "Card", "child": "content"},
					{"id": "content", "component": "Column", "children": []string{"title", "answer"}},
					{"id": "title", "component": "Text", "text": map[string]string{"path": "/title"}, "variant": "h3"},
					{"id": "answer", "component": "Text", "text": map[string]string{"path": "/answer"}, "variant": "body"},
				},
			},
		},
		{
			"version": A2UIProtocolVersion,
			"updateDataModel": map[string]interface{}{
				"surfaceId": surfaceID,
				"path":      "/",
				"value": map[string]interface{}{
					"title":  "Fake Provider 回调完成",
					"answer": "已收到安全追问：" + question,
				},
			},
		},
	}
	for index, message := range messages {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(35 * time.Millisecond):
		}
		rawMessage, err := json.Marshal(message)
		if err != nil {
			return err
		}
		envelope := A2UIEnvelope{
			SchemaVersion: A2UITransportVersion,
			EventID:       fmt.Sprintf("%s-provider-%d", action.EventID, index+1),
			RequestID:     action.RequestID,
			CorrelationID: action.CorrelationID,
			CardID:        action.CardID,
			SurfaceID:     surfaceID,
			Seq:           index + 1,
			Final:         index == len(messages)-1,
			Message:       rawMessage,
		}
		if err := emit(envelope); err != nil {
			return err
		}
	}
	return nil
}
