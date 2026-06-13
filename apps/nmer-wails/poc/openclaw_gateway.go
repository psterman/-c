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
	openClawDefaultChatTimeout = 120 * time.Second
	openClawBackendClientID   = "gateway-client"
	openClawBackendClientMode = "backend"
)

func openClawBackendScopes() []string {
	return []string{
		"operator.admin",
		"operator.approvals",
		"operator.pairing",
		"operator.read",
		"operator.write",
	}
}

func openClawConnectErrorText(err interface{}) string {
	if err == nil {
		return ""
	}
	if m, ok := err.(map[string]interface{}); ok {
		return strings.ToLower(stringFromAny(m["message"], m["code"], m["error"]))
	}
	return strings.ToLower(fmt.Sprintf("%v", err))
}

func openClawIsAlreadyConnectedConnectError(err interface{}) bool {
	return strings.Contains(openClawConnectErrorText(err), "connect is only valid as the first request")
}

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
		host = parsed.Hostname()
		port = parsed.Port()
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

func openClawGatewayConnectClient() map[string]interface{} {
	id := strings.TrimSpace(os.Getenv("OPENCLAW_GATEWAY_CLIENT_ID"))
	if id == "" {
		id = openClawBackendClientID
	}
	mode := strings.TrimSpace(os.Getenv("OPENCLAW_GATEWAY_CLIENT_MODE"))
	if mode == "" {
		mode = openClawBackendClientMode
	}
	return map[string]interface{}{
		"id":         id,
		"version":    "niuma-hub",
		"platform":   "go",
		"mode":       mode,
		"instanceId": fmt.Sprintf("niuma-adp-%d", time.Now().UnixNano()),
	}
}

func (c *OpenClawGatewayClient) wsURL() string {
	return fmt.Sprintf(
		"ws://%s/?token=%s",
		net.JoinHostPort(c.cfg.Host, c.cfg.Port),
		url.QueryEscape(c.cfg.Token),
	)
}

func (c *OpenClawGatewayClient) SendChat(ctx context.Context, sessionKey, message string) (string, error) {
	return c.SendChatStreaming(ctx, sessionKey, message, nil)
}

func openClawChatTimeoutFromCtx(ctx context.Context) time.Duration {
	timeout := openClawDefaultChatTimeout
	if ctx == nil {
		return timeout
	}
	if deadline, ok := ctx.Deadline(); ok {
		remain := time.Until(deadline)
		if remain > 0 && remain < timeout {
			return remain
		}
	}
	return timeout
}

func (c *OpenClawGatewayClient) SendChatStreaming(
	ctx context.Context,
	sessionKey, message string,
	onDelta func(delta string),
) (string, error) {
	sessionKey = OpenClawCanonicalSessionKey(sessionKey)
	message = strings.TrimSpace(message)
	if sessionKey == "" || message == "" {
		return "", errors.New("sessionKey and message are required")
	}
	if ctx == nil {
		ctx = context.Background()
	}
	chatTimeout := openClawChatTimeoutFromCtx(ctx)
	dialer := websocket.Dialer{HandshakeTimeout: 10 * time.Second}
	conn, _, err := dialer.DialContext(ctx, c.wsURL(), nil)
	if err != nil {
		return "", fmt.Errorf("openclaw websocket dial: %w", err)
	}
	defer conn.Close()

	var (
		mu              sync.Mutex
		writeMu         sync.Mutex
		seq             int
		connected       bool
		connectSent     bool
		connectEverSent bool
		chatSent        bool
		chatMsgID       string
		pending         strings.Builder
		done            = make(chan struct{})
		closeOnce       sync.Once
		finalErr        error
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
		writeMu.Lock()
		defer writeMu.Unlock()
		return conn.WriteMessage(websocket.TextMessage, data)
	}

	applyHistoryAnswer := func(result interface{}) {
		hist := openClawPickAssistantFromHistoryForQuery(result, message)
		if hist == "" {
			return
		}
		if onDelta != nil {
			onDelta(hist)
		}
		mu.Lock()
		pending.Reset()
		pending.WriteString(hist)
		mu.Unlock()
		finish(nil)
	}

	sendHistory := func() error {
		if !connected {
			return errors.New("not connected")
		}
		seq++
		histID := fmt.Sprintf("hist-%d", seq)
		return writeJSON(map[string]interface{}{
			"type":   "req",
			"id":     histID,
			"method": "chat.history",
			"params": map[string]interface{}{
				"sessionKey": sessionKey,
				"limit":      40,
			},
		})
	}

	sendConnect := func() error {
		if connectSent {
			return nil
		}
		connectSent = true
		connectEverSent = true
		seq++
		params := map[string]interface{}{
			"minProtocol": openClawGatewayMinProtocol,
			"maxProtocol": openClawGatewayMaxProtocol,
			"client":      openClawGatewayConnectClient(),
			"role":        "operator",
			"scopes":      openClawBackendScopes(),
			"caps":        []interface{}{},
			"auth":        map[string]interface{}{"token": c.cfg.Token},
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

	startHistoryPoll := func() {
		go func() {
			pollOnce := func() {
				mu.Lock()
				hasText := pending.Len() > 0
				mu.Unlock()
				if hasText {
					return
				}
				_ = sendHistory()
			}
			select {
			case <-ctx.Done():
				return
			case <-done:
				return
			case <-time.After(2 * time.Second):
				pollOnce()
			}
			ticker := time.NewTicker(4 * time.Second)
			defer ticker.Stop()
			for {
				select {
				case <-ctx.Done():
					return
				case <-done:
					return
				case <-ticker.C:
					mu.Lock()
					hasText := pending.Len() > 0
					mu.Unlock()
					if hasText {
						return
					}
					_ = sendHistory()
				}
			}
		}()
	}

	handleFrame := func(raw []byte) {
		var msg map[string]interface{}
		if err := json.Unmarshal(raw, &msg); err != nil {
			return
		}
		ev := strings.ToLower(stringFromAny(msg["event"], msg["type"], msg["method"]))
		if ev == "connect.challenge" {
			if connectEverSent && (connected || chatSent) {
				return
			}
			connectSent = false
			_ = sendConnect()
			return
		}
		if id, ok := msg["id"].(string); ok && strings.HasPrefix(id, "connect-") {
			if msg["error"] != nil || msg["ok"] == false {
				if connectEverSent && openClawIsAlreadyConnectedConnectError(msg["error"]) {
					connected = true
					_ = sendChat()
					startHistoryPoll()
					return
				}
				finish(fmt.Errorf("openclaw connect failed: %v", msg["error"]))
				return
			}
			connected = true
			_ = sendChat()
			startHistoryPoll()
			return
		}
		if ev == "hello-ok" {
			connected = true
			_ = sendChat()
			startHistoryPoll()
			return
		}
		if !connected {
			return
		}
		if id, ok := msg["id"].(string); ok && strings.HasPrefix(id, "hist-") {
			if msg["error"] != nil || msg["ok"] == false {
				return
			}
			var result interface{}
			if msg["result"] != nil {
				result = msg["result"]
			} else {
				result = msg["payload"]
			}
			applyHistoryAnswer(result)
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
				if onDelta != nil {
					onDelta(chunk)
				}
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
		_ = sendConnect()
		deadline := time.Now().Add(chatTimeout)
		for {
			select {
			case <-ctx.Done():
				finish(ctx.Err())
				return
			case <-done:
				return
			default:
			}
			if err := conn.SetReadDeadline(deadline); err != nil {
				finish(err)
				return
			}
			_, data, err := conn.ReadMessage()
			if err != nil {
				mu.Lock()
				hasText := pending.Len() > 0
				mu.Unlock()
				if hasText {
					return
				}
				finish(err)
				return
			}
			handleFrame(data)
			select {
			case <-done:
				return
			default:
			}
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
			if hist, histErr := c.fetchAssistantViaHistory(ctx, sessionKey); histErr == nil && hist != "" {
				return hist, nil
			}
			return "", errors.New("openclaw returned empty assistant text")
		}
		return text, nil
	case <-time.After(chatTimeout):
		mu.Lock()
		text := strings.TrimSpace(pending.String())
		mu.Unlock()
		if text != "" {
			return text, nil
		}
		if hist, histErr := c.fetchAssistantViaHistory(ctx, sessionKey); histErr == nil && hist != "" {
			return hist, nil
		}
		return "", errors.New("openclaw chat timeout")
	}
}

func (c *OpenClawGatewayClient) fetchAssistantViaHistory(ctx context.Context, sessionKey string) (string, error) {
	if ctx == nil {
		ctx = context.Background()
	}
	histCtx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	result, err := c.rpcCall(histCtx, "chat.history", map[string]interface{}{
		"sessionKey": sessionKey,
		"limit":      40,
	})
	if err != nil {
		return "", err
	}
	return openClawPickAssistantFromHistory(result), nil
}

func (c *OpenClawGatewayClient) rpcCall(ctx context.Context, method string, params map[string]interface{}) (interface{}, error) {
	method = strings.TrimSpace(method)
	if method == "" {
		return nil, errors.New("rpc method required")
	}
	dialer := websocket.Dialer{HandshakeTimeout: 10 * time.Second}
	conn, _, err := dialer.DialContext(ctx, c.wsURL(), nil)
	if err != nil {
		return nil, fmt.Errorf("openclaw websocket dial: %w", err)
	}
	defer conn.Close()

	var (
		seq             int
		connectSent     bool
		connectEverSent bool
		connected       bool
		rpcID           string
		result      interface{}
		rpcErr      error
		done        = make(chan struct{})
		closeOnce   sync.Once
	)
	finish := func(res interface{}, err error) {
		result = res
		rpcErr = err
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
		connectEverSent = true
		seq++
		return writeJSON(map[string]interface{}{
			"type":   "req",
			"id":     fmt.Sprintf("connect-%d", seq),
			"method": "connect",
			"params": map[string]interface{}{
				"minProtocol": openClawGatewayMinProtocol,
				"maxProtocol": openClawGatewayMaxProtocol,
				"client":      openClawGatewayConnectClient(),
				"role":        "operator",
				"scopes":      openClawBackendScopes(),
				"caps":        []interface{}{},
				"auth":        map[string]interface{}{"token": c.cfg.Token},
			},
		})
	}
	sendRPC := func() error {
		seq++
		rpcID = fmt.Sprintf("rpc-%d", seq)
		return writeJSON(map[string]interface{}{
			"type":   "req",
			"id":     rpcID,
			"method": method,
			"params": params,
		})
	}

	go func() {
		deadline := time.Now().Add(25 * time.Second)
		_ = sendConnect()
		for {
			select {
			case <-ctx.Done():
				finish(nil, ctx.Err())
				return
			case <-done:
				return
			default:
			}
			if err := conn.SetReadDeadline(deadline); err != nil {
				finish(nil, err)
				return
			}
			_, data, err := conn.ReadMessage()
			if err != nil {
				finish(nil, err)
				return
			}
			var msg map[string]interface{}
			if err := json.Unmarshal(data, &msg); err != nil {
				continue
			}
			ev := strings.ToLower(stringFromAny(msg["event"], msg["type"], msg["method"]))
			if ev == "connect.challenge" {
				if connectEverSent && (connected || rpcID != "") {
					continue
				}
				connectSent = false
				_ = sendConnect()
				continue
			}
			if id, ok := msg["id"].(string); ok && strings.HasPrefix(id, "connect-") {
				if msg["error"] != nil || msg["ok"] == false {
					if connectEverSent && openClawIsAlreadyConnectedConnectError(msg["error"]) {
						connected = true
						_ = sendRPC()
						continue
					}
					finish(nil, fmt.Errorf("openclaw connect failed: %v", msg["error"]))
					return
				}
				connected = true
				_ = sendRPC()
				continue
			}
			if ev == "hello-ok" {
				connected = true
				_ = sendRPC()
				continue
			}
			if id, ok := msg["id"].(string); ok && id == rpcID {
				if msg["error"] != nil || msg["ok"] == false {
					finish(nil, fmt.Errorf("openclaw %s failed: %v", method, msg["error"]))
					return
				}
				if msg["result"] != nil {
					finish(msg["result"], nil)
				} else {
					finish(msg["payload"], nil)
				}
				return
			}
		}
	}()

	select {
	case <-ctx.Done():
		return nil, ctx.Err()
	case <-done:
		return result, rpcErr
	case <-time.After(25 * time.Second):
		return nil, errors.New("openclaw rpc timeout")
	}
}

func openClawPickAssistantFromHistory(result interface{}) string {
	return openClawPickAssistantFromHistoryForQuery(result, "")
}

func openClawNormForMatch(s string) string {
	return strings.ToLower(strings.Join(strings.Fields(strings.TrimSpace(s)), " "))
}

func openClawHistoryRole(m map[string]interface{}) string {
	return strings.ToLower(stringFromAny(m["role"], m["author"], m["speaker"]))
}

func openClawPickAssistantFromHistoryForQuery(result interface{}, query string) string {
	msgs := openClawFlattenHistoryMessages(result)
	if len(msgs) == 0 {
		return ""
	}
	queryNorm := openClawNormForMatch(query)
	bestAfterUser := func(userIdx int) string {
		best := ""
		for j := userIdx + 1; j < len(msgs); j++ {
			m := msgs[j]
			if m == nil {
				continue
			}
			role := openClawHistoryRole(m)
			if role == "user" {
				break
			}
			if role != "" && role != "assistant" {
				continue
			}
			txt := strings.TrimSpace(openClawExtractAssistantText(m))
			if txt == "" {
				for _, key := range []string{"text", "content", "message", "output"} {
					if raw, ok := m[key].(string); ok && strings.TrimSpace(raw) != "" {
						txt = strings.TrimSpace(raw)
						break
					}
				}
			}
			if txt == "" || openClawIsIgnorableHistoryText(txt) {
				continue
			}
			if len(txt) > len(best) {
				best = txt
			}
		}
		return best
	}
	if queryNorm != "" {
		for i := len(msgs) - 1; i >= 0; i-- {
			m := msgs[i]
			if m == nil || openClawHistoryRole(m) != "user" {
				continue
			}
			userText := strings.TrimSpace(openClawExtractAssistantText(m))
			if userText == "" {
				for _, key := range []string{"text", "content", "message"} {
					if raw, ok := m[key].(string); ok && strings.TrimSpace(raw) != "" {
						userText = strings.TrimSpace(raw)
						break
					}
				}
			}
			if openClawNormForMatch(userText) == queryNorm || strings.Contains(openClawNormForMatch(userText), queryNorm) {
				if best := bestAfterUser(i); best != "" {
					return best
				}
			}
		}
	}
	for i := len(msgs) - 1; i >= 0; i-- {
		m := msgs[i]
		if m == nil {
			continue
		}
		role := openClawHistoryRole(m)
		if role != "" && role != "assistant" {
			continue
		}
		txt := strings.TrimSpace(openClawExtractAssistantText(m))
		if txt == "" {
			for _, key := range []string{"text", "content", "message", "output"} {
				if raw, ok := m[key].(string); ok && strings.TrimSpace(raw) != "" {
					txt = strings.TrimSpace(raw)
					break
				}
			}
		}
		if txt != "" && !openClawIsIgnorableHistoryText(txt) {
			return txt
		}
	}
	return ""
}

func openClawIsIgnorableHistoryText(s string) bool {
	t := strings.TrimSpace(s)
	if t == "" {
		return true
	}
	lower := strings.ToLower(t)
	if lower == "heartbeat_ok" {
		return true
	}
	if strings.HasPrefix(t, "HEARTBEAT_") {
		return true
	}
	return false
}

func openClawFlattenHistoryMessages(result interface{}) []map[string]interface{} {
	out := []map[string]interface{}{}
	switch typed := result.(type) {
	case []interface{}:
		for _, item := range typed {
			if m, ok := item.(map[string]interface{}); ok {
				out = append(out, m)
			}
		}
	case map[string]interface{}:
		for _, key := range []string{"messages", "items", "history", "entries"} {
			if arr, ok := typed[key].([]interface{}); ok {
				for _, item := range arr {
					if m, ok := item.(map[string]interface{}); ok {
						out = append(out, m)
					}
				}
			}
		}
		if len(out) == 0 {
			out = append(out, typed)
		}
	}
	return out
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
	if ev != "event" && ev != "chat" && ev != "chat.stream" && ev != "chat.delta" && ev != "chat.event" && ev != "broadcast" && ev != "agent" && ev != "agent.stream" {
		return nil
	}
	wrapper, _ := msg["payload"].(map[string]interface{})
	if wrapper == nil {
		wrapper, _ = msg["params"].(map[string]interface{})
	}
	if wrapper == nil {
		if ev == "chat" || ev == "chat.stream" || ev == "chat.delta" || ev == "chat.event" {
			return msg
		}
		return nil
	}
	inner := strings.ToLower(stringFromAny(wrapper["event"], wrapper["type"]))
	if inner != "chat" && inner != "chat.stream" && inner != "chat.delta" && inner != "chat.event" && inner != "chat.result" && inner != "agent" && inner != "agent.stream" && inner != "message" {
		if ev == "chat" || ev == "chat.stream" || ev == "chat.delta" || ev == "chat.event" {
			return wrapper
		}
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
