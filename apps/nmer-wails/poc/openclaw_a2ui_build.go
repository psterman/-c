package poc

import (
	"encoding/json"
	"fmt"
	"strings"
)

// BuildOpenClawTextSurfaceEnvelopes maps OpenClaw prose into a minimal official A2UI surface.
func BuildOpenClawTextSurfaceEnvelopes(cardID, requestID, surfaceID, title, answer string) ([]A2UIEnvelope, error) {
	cardID = strings.TrimSpace(cardID)
	requestID = strings.TrimSpace(requestID)
	surfaceID = strings.TrimSpace(surfaceID)
	if cardID == "" || requestID == "" || surfaceID == "" {
		return nil, fmt.Errorf("cardId, requestId and surfaceId are required")
	}
	title = strings.TrimSpace(title)
	if title == "" {
		title = "OpenClaw"
	}
	answer = strings.TrimSpace(answer)
	if answer == "" {
		answer = "(empty reply)"
	}
	if len(answer) > 4000 {
		answer = answer[:4000] + "…"
	}
	correlationID := "corr-" + requestID
	messages := []map[string]interface{}{
		{
			"version": A2UIProtocolVersion,
			"createSurface": map[string]interface{}{
				"surfaceId":     surfaceID,
				"catalogId":     A2UIBasicCatalogID,
				"sendDataModel": true,
			},
		},
		{
			"version": A2UIProtocolVersion,
			"updateComponents": map[string]interface{}{
				"surfaceId": surfaceID,
				"components": []map[string]interface{}{
					{"id": "root", "component": "Column", "children": []string{"title", "body"}, "align": "stretch"},
					{"id": "title", "component": "Text", "text": map[string]string{"path": "/title"}, "variant": "h3"},
					{"id": "body", "component": "Text", "text": map[string]string{"path": "/answer"}, "variant": "body"},
				},
			},
		},
		{
			"version": A2UIProtocolVersion,
			"updateDataModel": map[string]interface{}{
				"surfaceId": surfaceID,
				"path":      "/",
				"value": map[string]interface{}{
					"title":  title,
					"answer": answer,
				},
			},
		},
	}
	out := make([]A2UIEnvelope, 0, len(messages))
	for index, message := range messages {
		rawMessage, err := json.Marshal(message)
		if err != nil {
			return nil, err
		}
		out = append(out, A2UIEnvelope{
			SchemaVersion: A2UITransportVersion,
			EventID:       fmt.Sprintf("evt-adp-%s-%d", requestID, index+1),
			RequestID:     requestID,
			CorrelationID: correlationID,
			CardID:        cardID,
			SurfaceID:     surfaceID,
			Seq:           index + 1,
			Final:         index == len(messages)-1,
			Message:       rawMessage,
		})
	}
	return out, nil
}

func openClawAdapterSurfaceID(cardID string) string {
	slug := openClawCardIDSlug(cardID)
	return "surface-adp-" + slug
}
