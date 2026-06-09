package poc

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
)

type OpenAIChatA2UIProvider struct {
	endpoint string
	token    string
	model    string
	client   *http.Client
}

type openAIChatResponse struct {
	Choices []struct {
		Message struct {
			Content string `json:"content"`
		} `json:"message"`
	} `json:"choices"`
}

func NewOpenAIChatA2UIProvider(config A2UIProviderConfig) (*OpenAIChatA2UIProvider, error) {
	endpoint := strings.TrimRight(strings.TrimSpace(config.Endpoint), "/")
	if endpoint == "" {
		return nil, errors.New("NMER_A2UI_PROVIDER_URL is required for openai-chat provider")
	}
	if !strings.HasSuffix(strings.ToLower(endpoint), "/chat/completions") {
		endpoint += "/chat/completions"
	}
	validated, err := validateProviderEndpoint(endpoint, config.AllowRemote)
	if err != nil {
		return nil, err
	}
	model := strings.TrimSpace(config.Model)
	if model == "" {
		return nil, errors.New("NMER_A2UI_PROVIDER_MODEL is required for openai-chat provider")
	}
	httpProvider, err := NewHTTPA2UIProvider(A2UIProviderConfig{
		Endpoint:    validated,
		Token:       config.Token,
		AllowRemote: config.AllowRemote,
	})
	if err != nil {
		return nil, err
	}
	return &OpenAIChatA2UIProvider{
		endpoint: validated,
		token:    config.Token,
		model:    model,
		client:   httpProvider.client,
	}, nil
}

func (p *OpenAIChatA2UIProvider) HandleAction(
	ctx context.Context,
	action A2UIActionEnvelope,
	emit func(A2UIEnvelope) error,
) error {
	surfaceID := providerSurfaceID(action)
	requestBody := map[string]interface{}{
		"model": p.model,
		"messages": []map[string]string{
			{
				"role": "system",
				"content": "You emit only A2UI v0.9 JSONL. One compact JSON object per line. " +
					"Allowed components: Text, Row, Column, Card, Button, TextField. " +
					"Use exactly one operation per line. Never emit markdown fences or prose.",
			},
			{
				"role":    "user",
				"content": buildOpenAIChatA2UIPrompt(action, surfaceID),
			},
		},
		"stream":      false,
		"temperature": 0,
		"max_tokens":  4096,
	}
	body, err := json.Marshal(requestBody)
	if err != nil {
		return err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, p.endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Accept", "application/json")
	if p.token != "" {
		request.Header.Set("Authorization", "Bearer "+p.token)
	}
	response, err := p.client.Do(request)
	if err != nil {
		return fmt.Errorf("openai-chat A2UI request failed: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		detail, _ := io.ReadAll(io.LimitReader(response.Body, maxProviderErrorBytes))
		return fmt.Errorf(
			"openai-chat A2UI provider returned %s: %s",
			response.Status,
			strings.TrimSpace(string(detail)),
		)
	}
	var completion openAIChatResponse
	decoder := json.NewDecoder(io.LimitReader(response.Body, maxA2UIRequestBytes))
	if err := decoder.Decode(&completion); err != nil {
		return fmt.Errorf("invalid openai-chat response: %w", err)
	}
	if len(completion.Choices) == 0 {
		return errors.New("openai-chat response has no choices")
	}
	return emitA2UIMessagesFromText(action, surfaceID, completion.Choices[0].Message.Content, emit)
}

func providerSurfaceID(action A2UIActionEnvelope) string {
	suffix := action.RequestID
	if len(suffix) > 40 {
		suffix = suffix[len(suffix)-40:]
	}
	prefix := action.SurfaceID
	maxPrefixLength := maxA2UIIdentifierLength - len("-llm-") - len(suffix)
	if maxPrefixLength < 1 {
		maxPrefixLength = 1
	}
	if len(prefix) > maxPrefixLength {
		prefix = prefix[:maxPrefixLength]
	}
	return prefix + "-llm-" + suffix
}

func buildOpenAIChatA2UIPrompt(action A2UIActionEnvelope, surfaceID string) string {
	question := strings.TrimSpace(fmt.Sprint(action.Data["question"]))
	if question == "" {
		question = "Continue the requested task."
	}
	return fmt.Sprintf(
		"Create an A2UI response for this user request: %q\n"+
			"Required surfaceId: %q\n"+
			"First line must createSurface with catalogId %q.\n"+
			"Then updateComponents and updateDataModel. Keep the UI concise and safe.",
		question,
		surfaceID,
		A2UIBasicCatalogID,
	)
}

func emitA2UIMessagesFromText(
	action A2UIActionEnvelope,
	surfaceID string,
	content string,
	emit func(A2UIEnvelope) error,
) error {
	content = strings.TrimSpace(content)
	content = strings.TrimPrefix(content, "```jsonl")
	content = strings.TrimPrefix(content, "```json")
	content = strings.TrimPrefix(content, "```")
	content = strings.TrimSuffix(content, "```")
	content = strings.TrimSpace(content)
	scanner := bufio.NewScanner(strings.NewReader(content))
	scanner.Buffer(make([]byte, 64*1024), maxA2UILineBytes)
	messages := make([]json.RawMessage, 0, 8)
	for scanner.Scan() {
		line := bytes.TrimSpace(scanner.Bytes())
		if len(line) == 0 {
			continue
		}
		var message json.RawMessage
		if err := json.Unmarshal(line, &message); err != nil {
			return fmt.Errorf("invalid A2UI JSONL from openai-chat: %w", err)
		}
		messages = append(messages, append(json.RawMessage(nil), message...))
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("read openai-chat A2UI JSONL: %w", err)
	}
	if len(messages) == 0 {
		return errors.New("openai-chat returned no A2UI messages")
	}
	for index, message := range messages {
		envelope := A2UIEnvelope{
			SchemaVersion: A2UITransportVersion,
			EventID:       fmt.Sprintf("%s-llm-%d", action.EventID, index+1),
			RequestID:     action.RequestID,
			CorrelationID: action.CorrelationID,
			CardID:        action.CardID,
			SurfaceID:     surfaceID,
			Seq:           index + 1,
			Final:         index == len(messages)-1,
			Message:       message,
		}
		if err := emit(envelope); err != nil {
			return err
		}
	}
	return nil
}
