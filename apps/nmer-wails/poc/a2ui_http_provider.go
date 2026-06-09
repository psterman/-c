package poc

import (
	"bufio"
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"net/http"
	"net/url"
	"os"
	"strings"
	"time"
)

const (
	defaultA2UIProviderMode = "fake"
	maxProviderErrorBytes   = 8 * 1024
)

type A2UIProviderConfig struct {
	Mode        string
	Endpoint    string
	Token       string
	Model       string
	AllowRemote bool
}

type HTTPA2UIProvider struct {
	endpoint string
	token    string
	client   *http.Client
}

func A2UIProviderConfigFromEnv() A2UIProviderConfig {
	return A2UIProviderConfig{
		Mode:        strings.ToLower(strings.TrimSpace(os.Getenv("NMER_A2UI_PROVIDER"))),
		Endpoint:    strings.TrimSpace(os.Getenv("NMER_A2UI_PROVIDER_URL")),
		Token:       strings.TrimSpace(os.Getenv("NMER_A2UI_PROVIDER_TOKEN")),
		Model:       strings.TrimSpace(os.Getenv("NMER_A2UI_PROVIDER_MODEL")),
		AllowRemote: strings.EqualFold(strings.TrimSpace(os.Getenv("NMER_A2UI_ALLOW_REMOTE_PROVIDER")), "true"),
	}
}

func NewA2UIProvider(config A2UIProviderConfig) (A2UIProvider, string, error) {
	mode := strings.ToLower(strings.TrimSpace(config.Mode))
	if mode == "" {
		mode = defaultA2UIProviderMode
	}
	switch mode {
	case "fake":
		return FakeA2UIProvider{}, "fake", nil
	case "http":
		provider, err := NewHTTPA2UIProvider(config)
		if err != nil {
			return nil, "", err
		}
		return provider, "http", nil
	case "openai-chat":
		provider, err := NewOpenAIChatA2UIProvider(config)
		if err != nil {
			return nil, "", err
		}
		return provider, "openai-chat", nil
	default:
		return nil, "", fmt.Errorf("unsupported A2UI provider mode: %s", mode)
	}
}

func NewHTTPA2UIProvider(config A2UIProviderConfig) (*HTTPA2UIProvider, error) {
	endpoint, err := validateProviderEndpoint(config.Endpoint, config.AllowRemote)
	if err != nil {
		return nil, err
	}
	return &HTTPA2UIProvider{
		endpoint: endpoint,
		token:    config.Token,
		client: &http.Client{
			Timeout: 35 * time.Second,
			Transport: &http.Transport{
				Proxy:                 http.ProxyFromEnvironment,
				ForceAttemptHTTP2:     false,
				MaxIdleConns:          4,
				MaxIdleConnsPerHost:   2,
				IdleConnTimeout:       30 * time.Second,
				ResponseHeaderTimeout: 10 * time.Second,
			},
		},
	}, nil
}

func validateProviderEndpoint(raw string, allowRemote bool) (string, error) {
	raw = strings.TrimSpace(raw)
	if raw == "" {
		return "", errors.New("NMER_A2UI_PROVIDER_URL is required for http provider")
	}
	parsed, err := url.Parse(raw)
	if err != nil {
		return "", fmt.Errorf("invalid A2UI provider URL: %w", err)
	}
	if parsed.Scheme != "http" && parsed.Scheme != "https" {
		return "", errors.New("A2UI provider URL must use http or https")
	}
	if parsed.Hostname() == "" {
		return "", errors.New("A2UI provider URL host is required")
	}
	if !allowRemote && !isLoopbackHost(parsed.Hostname()) {
		return "", errors.New("remote A2UI provider requires NMER_A2UI_ALLOW_REMOTE_PROVIDER=true")
	}
	return parsed.String(), nil
}

func isLoopbackHost(host string) bool {
	host = strings.Trim(strings.TrimSpace(host), "[]")
	if strings.EqualFold(host, "localhost") {
		return true
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}

func (p *HTTPA2UIProvider) HandleAction(
	ctx context.Context,
	action A2UIActionEnvelope,
	emit func(A2UIEnvelope) error,
) error {
	body, err := json.Marshal(action)
	if err != nil {
		return err
	}
	request, err := http.NewRequestWithContext(ctx, http.MethodPost, p.endpoint, bytes.NewReader(body))
	if err != nil {
		return err
	}
	request.Header.Set("Content-Type", "application/json")
	request.Header.Set("Accept", "application/x-ndjson, application/json")
	if p.token != "" {
		request.Header.Set("Authorization", "Bearer "+p.token)
	}
	response, err := p.client.Do(request)
	if err != nil {
		return fmt.Errorf("A2UI provider request failed: %w", err)
	}
	defer response.Body.Close()
	if response.StatusCode < 200 || response.StatusCode >= 300 {
		detail, _ := io.ReadAll(io.LimitReader(response.Body, maxProviderErrorBytes))
		return fmt.Errorf(
			"A2UI provider returned %s: %s",
			response.Status,
			strings.TrimSpace(string(detail)),
		)
	}

	scanner := bufio.NewScanner(io.LimitReader(response.Body, maxA2UIRequestBytes+1))
	scanner.Buffer(make([]byte, 64*1024), maxA2UILineBytes)
	emitted := 0
	for scanner.Scan() {
		line := bytes.TrimSpace(scanner.Bytes())
		if len(line) == 0 {
			continue
		}
		var envelope A2UIEnvelope
		decoder := json.NewDecoder(bytes.NewReader(line))
		decoder.DisallowUnknownFields()
		if err := decoder.Decode(&envelope); err != nil {
			return fmt.Errorf("invalid provider A2UI JSONL: %w", err)
		}
		if envelope.RequestID != action.RequestID ||
			envelope.CorrelationID != action.CorrelationID ||
			envelope.CardID != action.CardID {
			return errors.New("provider A2UI envelope does not match action context")
		}
		if err := emit(envelope); err != nil {
			return err
		}
		emitted++
	}
	if err := scanner.Err(); err != nil {
		return fmt.Errorf("read provider A2UI JSONL: %w", err)
	}
	if emitted == 0 {
		return errors.New("A2UI provider returned no messages")
	}
	return nil
}
