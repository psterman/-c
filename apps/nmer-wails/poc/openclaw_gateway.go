package poc

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	openClawGatewayMinProtocol = 3
	openClawGatewayMaxProtocol = 5
	openClawDefaultChatTimeout = 90 * time.Second
)

type OpenClawGatewayConfig struct {
	Host  string
	Port  string
	Token string
}

func OpenClawGatewayConfigFromEnv() (OpenClawGatewayConfig, error) {
	token := strings.TrimSpace(os.Getenv("OPENCLAW_GATEWAY_TOKEN"))
	if token == "" {
		token = strings.TrimSpace(os.Getenv("OPENCLAW_TOKEN"))
	}
	base := strings.TrimSpace(os.Getenv("OPENCLAW_BASE_URL"))
	host := strings.TrimSpace(os.Getenv("OPENCLAW_GATEWAY_HOST"))
	port := strings.TrimSpace(os.Getenv("OPENCLAW_GATEWAY_PORT"))
	if base != "" {
		parsed, err := url.Parse(base)
		if err != nil {
			return OpenClawGatewayConfig{}, fmt.Errorf("invalid OPENCLAW_BASE_URL: %w", err)
		}
		if host == "" {
			host = parsed.Hostname()
		}
		if port == "" {
			port = parsed.Port()
		}
	}
	if host == "" {
		host = "127.0.0.1"
	}
	if port == "" {
		port = "18789"
	}
	if token == "" {
		return OpenClawGatewayConfig{}, errors.New("OPENCLAW_GATEWAY_TOKEN is required for OpenClaw adapter")
	}
	return OpenClawGatewayConfig{Host: host, Port: port, Token: token}, nil
}

type OpenClawGatewayClient struct {
	cfg OpenClawGatewayConfig
}

func NewOpenClawGatewayClient(cfg OpenClawGatewayConfig) *OpenClawGatewayClient {
	return &OpenClawGatewayClient{cfg: cfg}
}

func (c *OpenClawGatewayClient) wsURL() string {
	return fmt.Sprintf(
		"ws://%s/?token=%s",
		net.JoinHostPort(c.cfg.Host, c.cfg.Port),
		url.QueryEscape(c.cfg.Token),
	)
}

func (c *OpenClawGatewayClient) SendChat(ctx context.Context, sessionKey, message string) (string, error) {
	sessionKey = OpenClawCanonicalSessionKey(sessionKey)
	message = strings.TrimSpace(message)
	if sessionKey == "" || message == "" {
		return "", errors.New("sessionKey and message are required")
	}
	if ctx == nil {
		ctx = context.Background()
	}
	dialer := websocket.Dialer{HandshakeTimeout: 10 * time.Second}
	conn, _, err := dialer.DialContext(ctx, c.wsURL(), nil)
	if err != nil {
		return "", fmt.Errorf("openclaw websocket dial: %w", err)
	}
	defer conn.Close()

	var (
		mu          sync.Mutex
		seq         int
		connected   bool
		connectSent bool
		chatSent    bool
		chatMsgID   string
		pending     strings.Builder
		done        = make(chan struct{})
		closeOnce   sync.Once
		finalErr    error
	)
	finish := func(err error) {
		if err != nil {
			finalErr = err
		}
		closeOnce.Do(func() { close(done) })
	}

	writeJSON := func(payload interface{}) error {
		data, err := json.Marshal(payload)
		if err != nil {
			return err
		}
		return conn.WriteMessage(websocket.TextMessage, data)
	}

	sendConnect := func() error {
		if connectSent {
			return nil
		}
		connectSent = true
		seq++
		params := map[string]interface{}{
			"minProtocol": openClawGatewayMinProtocol,
			"maxProtocol": openClawGatewayMaxProtocol,
			"client": map[string]interface{}{
				"id":         "openclaw-control-ui",
				"version":    "niuma-go",
				"platform":   "go",
				"mode":       "webchat",
				"instanceId": fmt.Sprintf("niuma-adp-%d", time.Now().UnixNano()),
			},
			"role":   "operator",
			"scopes": []string{"operator.admin", "operator.approvals", "operator.pairing", "operator.read", "operator.write"},
			"caps":   []interface{}{},
			"auth":   map[string]interface{}{"token": c.cfg.Token},
		}
		return writeJSON(map[string]interface{}{
			"type":   "req",
			"id":     fmt.Sprintf("connect-%d", seq),
			"method": "connect",
			"params": params,
		})
	}

	sendChat := func() error {
		if chatSent {
			return nil
		}
		chatSent = true
		seq++
		chatMsgID = fmt.Sprintf("msg-%d", seq)
		return writeJSON(map[string]interface{}{
			"type":   "req",
			"id":     chatMsgID,
			"method": "chat.send",
			"params": map[string]interface{}{
				"message":        message,
				"idempotencyKey": chatMsgID,
				"sessionKey":     sessionKey,
			},
		})
	}

	handleFrame := func(raw []byte) {
		var msg map[string]interface{}
		if err := json.Unmarshal(raw, &msg); err != nil {
			return
		}
		ev := strings.ToLower(stringFromAny(msg["event"], msg["type"], msg["method"]))
		if ev == "connect.challenge" {
			connectSent = false
			_ = sendConnect()
			return
		}
		if id, ok := msg["id"].(string); ok && strings.HasPrefix(id, "connect-") {
			if msg["error"] != nil || msg["ok"] == false {
				finish(fmt.Errorf("openclaw connect failed: %v", msg["error"]))
				return
			}
			connected = true
			_ = sendChat()
			return
		}
		if ev == "hello-ok" {
			connected = true
			_ = sendChat()
			return
		}
		if !connected {
			return
		}
		if id, ok := msg["id"].(string); ok && id == chatMsgID {
			if msg["error"] != nil || msg["ok"] == false {
				finish(fmt.Errorf("openclaw chat.send failed: %v", msg["error"]))
				return
			}
		}
		if pl := openClawGetChatBroadcastPayload(msg); pl != nil {
			if chunk := openClawExtractAssistantText(pl); chunk != "" {
				mu.Lock()
				pending.WriteString(chunk)
				mu.Unlock()
			}
			if openClawIsChatFinalState(pl) && !openClawPayloadIsIntermediatePhase(pl) {
				finish(nil)
			}
		}
	}

	go func() {
		defer finish(nil)
		_ = sendConnect()
		for {
			select {
			case <-ctx.Done():
				finish(ctx.Err())
				return
			case <-done:
				return
			default:
			}
			if err := conn.SetReadDeadline(time.Now().Add(3 * time.Second)); err != nil {
				finish(err)
				return
			}
			_, data, err := conn.ReadMessage()
			if err != nil {
				mu.Lock()
				hasText := pending.Len() > 0
				mu.Unlock()
				if hasText && strings.Contains(strings.ToLower(err.Error()), "timeout") {
					return
				}
				if !strings.Contains(strings.ToLower(err.Error()), "timeout") {
					finish(err)
				}
				return
			}
			handleFrame(data)
		}
	}()

	select {
	case <-ctx.Done():
		return "", ctx.Err()
	case <-done:
		mu.Lock()
		text := strings.TrimSpace(pending.String())
		mu.Unlock()
		if finalErr != nil {
			return text, finalErr
		}
		if text == "" {
			return "", errors.New("openclaw returned empty assistant text")
		}
		return text, nil
	case <-time.After(openClawDefaultChatTimeout):
		mu.Lock()
		text := strings.TrimSpace(pending.String())
		mu.Unlock()
		if text != "" {
			return text, nil
		}
		return "", errors.New("openclaw chat timeout")
	}
}

func stringFromAny(values ...interface{}) string {
	for _, value := range values {
		if value == nil {
			continue
		}
		switch typed := value.(type) {
		case string:
			if strings.TrimSpace(typed) != "" {
				return strings.TrimSpace(typed)
			}
		}
	}
	return ""
}

func openClawGetChatBroadcastPayload(msg map[string]interface{}) map[string]interface{} {
	ev := strings.ToLower(stringFromAny(msg["event"], msg["type"], msg["method"]))
	if ev != "event" && ev != "chat" && ev != "chat.stream" && ev != "chat.delta" && ev != "chat.event" && ev != "broadcast" {
		return nil
	}
	wrapper, _ := msg["payload"].(map[string]interface{})
	if wrapper == nil {
		wrapper, _ = msg["params"].(map[string]interface{})
	}
	if wrapper == nil {
		return nil
	}
	inner := strings.ToLower(stringFromAny(wrapper["event"], wrapper["type"]))
	if inner != "chat" && inner != "chat.stream" && inner != "chat.delta" && inner != "chat.event" && inner != "chat.result" {
		return nil
	}
	if nested, ok := wrapper["payload"].(map[string]interface{}); ok {
		return nested
	}
	return wrapper
}

func openClawExtractAssistantText(pl map[string]interface{}) string {
	if pl == nil {
		return ""
	}
	if state, _ := pl["state"].(string); strings.EqualFold(state, "error") {
		return ""
	}
	parts := openClawContentParts(pl)
	for _, part := range parts {
		typ := strings.ToLower(stringFromAny(part["type"]))
		text, _ := part["text"].(string)
		if (typ == "text" || typ == "output_text" || typ == "markdown" || typ == "assistant") && strings.TrimSpace(text) != "" {
			return text
		}
	}
	for _, key := range []string{"text", "content", "message", "output"} {
		if text, ok := pl[key].(string); ok && strings.TrimSpace(text) != "" {
			return text
		}
	}
	return ""
}

func openClawContentParts(pl map[string]interface{}) []map[string]interface{} {
	candidates := []interface{}{pl["content"]}
	if nested, ok := pl["message"].(map[string]interface{}); ok {
		candidates = append(candidates, nested["content"])
	}
	for _, candidate := range candidates {
		if arr, ok := candidate.([]interface{}); ok {
			out := make([]map[string]interface{}, 0, len(arr))
			for _, item := range arr {
				if m, ok := item.(map[string]interface{}); ok {
					out = append(out, m)
				}
			}
			if len(out) > 0 {
				return out
			}
		}
	}
	return nil
}

func openClawIsChatFinalState(pl map[string]interface{}) bool {
	if pl == nil {
		return false
	}
	if state, ok := pl["state"].(string); ok {
		switch strings.ToLower(state) {
		case "final", "done", "completed", "finished":
			return true
		}
	}
	if done, ok := pl["done"].(bool); ok && done {
		return true
	}
	if finished, ok := pl["finished"].(bool); ok && finished {
		return true
	}
	return false
}

func openClawPayloadIsIntermediatePhase(pl map[string]interface{}) bool {
	if openClawExtractAssistantText(pl) != "" {
		return false
	}
	for _, part := range openClawContentParts(pl) {
		typ := strings.ToLower(stringFromAny(part["type"]))
		switch typ {
		case "thinking", "toolcall", "tool_call", "function_call", "tool_result", "toolresult", "tool_output":
			return true
		}
	}
	return false
}
