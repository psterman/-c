//go:build windows

package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"net/url"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

type dropPipeline struct {
	mu          sync.Mutex
	cancel      context.CancelFunc
	requestSeq  atomic.Uint64
	lastDropSig string
	lastDropAt  time.Time
}

var globalPipeline dropPipeline

type llmConfig struct {
	BaseURL string
	APIKey  string
	Model   string
	Provider string
}

func (p *dropPipeline) beginDrop(ev dropEvent) uint64 {
	p.mu.Lock()
	defer p.mu.Unlock()

	sig := dropSignature(ev)
	now := time.Now()
	if sig == p.lastDropSig && now.Sub(p.lastDropAt) < 400*time.Millisecond {
		return 0
	}
	p.lastDropSig = sig
	p.lastDropAt = now

	if p.cancel != nil {
		prev := p.requestSeq.Load()
		p.cancel()
		hubEmit("stream_abort", map[string]any{
			"requestId": prev,
			"reason":    "superseded",
		})
	}

	reqID := p.requestSeq.Add(1)
	ctx, cancel := context.WithCancel(context.Background())
	p.cancel = cancel

	go p.process(ctx, reqID, ev)
	return reqID
}

func (p *dropPipeline) beginManual(prompt string, cfg llmConfig) uint64 {
	p.mu.Lock()
	defer p.mu.Unlock()

	prompt = strings.TrimSpace(prompt)
	if prompt == "" {
		return 0
	}
	if p.cancel != nil {
		prev := p.requestSeq.Load()
		p.cancel()
		hubEmit("stream_abort", map[string]any{
			"requestId": prev,
			"reason":    "superseded",
		})
	}

	reqID := p.requestSeq.Add(1)
	ctx, cancel := context.WithCancel(context.Background())
	p.cancel = cancel
	go p.processManual(ctx, reqID, prompt, cfg)
	return reqID
}

func dropSignature(ev dropEvent) string {
	var b strings.Builder
	b.WriteString(ev.PayloadKind)
	b.WriteByte('|')
	b.WriteString(ev.Text)
	b.WriteByte('|')
	b.WriteString(strings.Join(ev.Files, ";"))
	return b.String()
}

func (p *dropPipeline) process(ctx context.Context, reqID uint64, ev dropEvent) {
	prompt, err := buildPrompt(ev)
	if err != nil || strings.TrimSpace(prompt) == "" {
		hubEmit("stream_error", map[string]any{
			"requestId": reqID,
			"error":     "empty_payload",
		})
		return
	}

	apiKey := strings.TrimSpace(os.Getenv("NMER_LLM_API_KEY"))
	if apiKey == "" {
		// 无密钥时仅推送摘要，便于 UI 联调
		summary := summarizePayload(ev)
		hubEmit("stream_chunk", map[string]any{
			"requestId": reqID,
			"session":   globalGate.Session(),
			"delta":     summary,
			"done":      false,
		})
		hubEmit("stream_done", map[string]any{"requestId": reqID, "session": globalGate.Session()})
		return
	}

	baseURL := strings.TrimSpace(os.Getenv("NMER_LLM_BASE_URL"))
	if baseURL == "" {
		baseURL = "https://api.deepseek.com"
	}
	model := strings.TrimSpace(os.Getenv("NMER_LLM_MODEL"))
	if model == "" {
		model = "deepseek-chat"
	}

	if err := p.streamChat(ctx, reqID, "deepseek", baseURL, apiKey, model, prompt); err != nil {
		if ctx.Err() != nil {
			return
		}
		hubEmit("stream_error", map[string]any{
			"requestId": reqID,
			"error":     err.Error(),
		})
	}
}

func (p *dropPipeline) processManual(ctx context.Context, reqID uint64, prompt string, cfg llmConfig) {
	apiKey := strings.TrimSpace(cfg.APIKey)
	baseURL := strings.TrimSpace(cfg.BaseURL)
	model := strings.TrimSpace(cfg.Model)
	provider := strings.ToLower(strings.TrimSpace(cfg.Provider))
	if baseURL == "" {
		baseURL = strings.TrimSpace(os.Getenv("NMER_LLM_BASE_URL"))
	}
	if model == "" {
		model = strings.TrimSpace(os.Getenv("NMER_LLM_MODEL"))
	}
	if baseURL == "" {
		baseURL = "https://api.deepseek.com"
	}
	if model == "" {
		model = "deepseek-chat"
	}
	if apiKey == "" {
		apiKey = strings.TrimSpace(os.Getenv("NMER_LLM_API_KEY"))
	}
	if apiKey == "" {
		hubEmit("stream_error", map[string]any{
			"requestId": reqID,
			"error":     "missing_api_key",
		})
		return
	}
	if err := p.streamChat(ctx, reqID, provider, baseURL, apiKey, model, prompt); err != nil {
		if ctx.Err() != nil {
			return
		}
		hubEmit("stream_error", map[string]any{
			"requestId": reqID,
			"error":     err.Error(),
		})
	}
}

func summarizePayload(ev dropEvent) string {
	switch ev.PayloadKind {
	case "text", "link":
		t := ev.Text
		if ev.Link != "" {
			t = ev.Link
		}
		if len(t) > 200 {
			return t[:200] + "…"
		}
		return t
	case "file", "mixed", "folder":
		if len(ev.Files) > 0 {
			return "已接收文件: " + strings.Join(ev.Files, ", ")
		}
		return "已接收拖放载荷"
	default:
		return "拖放完成"
	}
}

func buildPrompt(ev dropEvent) (string, error) {
	switch ev.PayloadKind {
	case "text", "link":
		t := ev.Text
		if ev.Link != "" {
			t = ev.Link
		}
		return strings.TrimSpace(t), nil
	case "file", "mixed":
		var parts []string
		for _, f := range ev.Files {
			ext := strings.ToLower(filepath.Ext(f))
			switch ext {
			case ".png", ".jpg", ".jpeg", ".webp", ".gif":
				b, err := os.ReadFile(f)
				if err != nil {
					continue
				}
				parts = append(parts, "[image:"+filepath.Base(f)+"] base64:"+base64.StdEncoding.EncodeToString(b)[:min(256, len(b))]+"...")
			case ".txt", ".md", ".py", ".go", ".js", ".ts", ".json", ".ahk", ".html", ".css":
				b, err := os.ReadFile(f)
				if err != nil {
					continue
				}
				body := string(b)
				if len(body) > 120000 {
					body = body[:120000] + "\n...(truncated)"
				}
				parts = append(parts, "--- "+filepath.Base(f)+" ---\n"+body)
			default:
				parts = append(parts, "文件: "+f)
			}
		}
		return strings.Join(parts, "\n\n"), nil
	default:
		return "", fmt.Errorf("unsupported payload")
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func openAICompatURL(baseURL string) string {
	u := strings.TrimSpace(baseURL)
	u = strings.TrimRight(u, "/")
	if u == "" {
		return "https://api.deepseek.com/v1/chat/completions"
	}
	lu := strings.ToLower(u)
	if strings.HasSuffix(lu, "/chat/completions") {
		return u
	}
	// If already on version root (e.g. .../v1 or .../v1beta), append only /chat/completions.
	if strings.HasSuffix(lu, "/v1") || strings.HasSuffix(lu, "/v1beta") || strings.HasSuffix(lu, "/v4") {
		return u + "/chat/completions"
	}
	return u + "/v1/chat/completions"
}

func normalizeMiniMaxBaseURL(baseURL string) string {
	u := strings.TrimSpace(baseURL)
	if u == "" {
		return u
	}
	parsed, err := url.Parse(u)
	if err != nil || parsed.Host == "" {
		// Fallback string-level patch.
		v := strings.ReplaceAll(u, "api.minimax.com", "api.minimax.io")
		v = strings.ReplaceAll(v, "/anthrop/", "/anthropic/")
		if strings.HasSuffix(v, "/anthrop") {
			v = strings.TrimSuffix(v, "/anthrop") + "/anthropic"
		}
		return v
	}
	host := strings.ToLower(strings.TrimSpace(parsed.Host))
	if host == "api.minimax.com" {
		parsed.Host = "api.minimax.io"
	}
	path := strings.ReplaceAll(parsed.Path, "/anthrop/", "/anthropic/")
	if strings.HasSuffix(path, "/anthrop") {
		path = strings.TrimSuffix(path, "/anthrop") + "/anthropic"
	}
	parsed.Path = path
	return parsed.String()
}

func shouldUseAnthropic(provider, baseURL string) bool {
	p := strings.ToLower(strings.TrimSpace(provider))
	u := strings.ToLower(strings.TrimSpace(baseURL))
	if p == "claude" {
		return true
	}
	if p == "minimax" && strings.Contains(u, "/anthropic") {
		return true
	}
	return false
}

func anthropicCompatURL(baseURL string) string {
	u := strings.TrimSpace(baseURL)
	u = strings.TrimRight(u, "/")
	if u == "" {
		return "https://api.anthropic.com/v1/messages"
	}
	lu := strings.ToLower(u)
	if strings.HasSuffix(lu, "/v1/messages") || strings.HasSuffix(lu, "/messages") {
		return u
	}
	if strings.HasSuffix(lu, "/v1") {
		return u + "/messages"
	}
	return u + "/v1/messages"
}

func (p *dropPipeline) streamAnthropic(ctx context.Context, reqID uint64, baseURL, apiKey, model, prompt string) error {
	url := anthropicCompatURL(normalizeMiniMaxBaseURL(baseURL))
	body, _ := json.Marshal(map[string]any{
		"model": model,
		"max_tokens": 1024,
		"messages": []map[string]string{
			{"role": "user", "content": prompt},
		},
	})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("x-api-key", apiKey)
	req.Header.Set("anthropic-version", "2023-06-01")
	req.Header.Set("Content-Type", "application/json")
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	raw, _ := io.ReadAll(io.LimitReader(resp.Body, 16384))
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return fmt.Errorf("llm http %d: %s", resp.StatusCode, string(raw))
	}
	var out struct {
		Content []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
	}
	if err := json.Unmarshal(raw, &out); err != nil {
		return fmt.Errorf("llm parse error: %v", err)
	}
	var acc strings.Builder
	for _, c := range out.Content {
		if strings.ToLower(strings.TrimSpace(c.Type)) == "text" && strings.TrimSpace(c.Text) != "" {
			acc.WriteString(c.Text)
		}
	}
	txt := strings.TrimSpace(acc.String())
	if txt == "" {
		txt = "（空响应）"
	}
	hubEmit("stream_chunk", map[string]any{
		"requestId": reqID,
		"session": globalGate.Session(),
		"delta": txt,
		"done": false,
	})
	hubEmit("stream_done", map[string]any{
		"requestId": reqID,
		"session": globalGate.Session(),
	})
	return nil
}

func (p *dropPipeline) streamChat(ctx context.Context, reqID uint64, provider, baseURL, apiKey, model, prompt string) error {
	if strings.ToLower(strings.TrimSpace(provider)) == "minimax" {
		baseURL = normalizeMiniMaxBaseURL(baseURL)
	}
	if shouldUseAnthropic(provider, baseURL) {
		return p.streamAnthropic(ctx, reqID, baseURL, apiKey, model, prompt)
	}
	url := openAICompatURL(baseURL)
	body, _ := json.Marshal(map[string]any{
		"model":  model,
		"stream": true,
		"messages": []map[string]string{
			{"role": "system", "content": "你是 AI 黑洞助手。用简洁中文回答用户拖入的内容。"},
			{"role": "user", "content": prompt},
		},
	})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, url, bytes.NewReader(body))
	if err != nil {
		return err
	}
	req.Header.Set("Authorization", "Bearer "+apiKey)
	req.Header.Set("Content-Type", "application/json")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
		return fmt.Errorf("llm http %d: %s", resp.StatusCode, string(b))
	}

	sc := bufio.NewScanner(resp.Body)
	for sc.Scan() {
		if ctx.Err() != nil {
			return ctx.Err()
		}
		line := strings.TrimSpace(sc.Text())
		if line == "" || line == "data: [DONE]" {
			continue
		}
		if !strings.HasPrefix(line, "data: ") {
			continue
		}
		var chunk struct {
			Choices []struct {
				Delta struct {
					Content string `json:"content"`
				} `json:"delta"`
			} `json:"choices"`
		}
		if err := json.Unmarshal([]byte(line[6:]), &chunk); err != nil {
			continue
		}
		if len(chunk.Choices) == 0 {
			continue
		}
		delta := chunk.Choices[0].Delta.Content
		if delta == "" {
			continue
		}
		hubEmit("stream_chunk", map[string]any{
			"requestId": reqID,
			"session":   globalGate.Session(),
			"delta":     delta,
			"done":      false,
		})
	}
	hubEmit("stream_done", map[string]any{
		"requestId": reqID,
		"session":   globalGate.Session(),
	})
	return sc.Err()
}
