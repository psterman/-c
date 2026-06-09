package poc

import "strings"

// ProviderCapability declares what an A2UI action provider can do (Wave 3 P3).
type ProviderCapability struct {
	Provider     string   `json:"provider"`
	Stream       bool     `json:"stream"`
	Action       bool     `json:"action"`
	Abort        bool     `json:"abort"`
	Routes       []string `json:"routes"`
	Experimental bool     `json:"experimental"`
	Description  string   `json:"description,omitempty"`
}

var providerCapabilities = map[string]ProviderCapability{
	"fake": {
		Provider:     "fake",
		Stream:       true,
		Action:       true,
		Abort:        true,
		Routes:       []string{"r3"},
		Experimental: false,
		Description:  "in-process fake follow-up surface",
	},
	"http": {
		Provider:     "http",
		Stream:       true,
		Action:       true,
		Abort:        true,
		Routes:       []string{"r3"},
		Experimental: false,
		Description:  "HTTP adapter returning nmer.a2ui.transport.v1 NDJSON",
	},
	"openai-chat": {
		Provider:     "openai-chat",
		Stream:       true,
		Action:       true,
		Abort:        true,
		Routes:       []string{"r3"},
		Experimental: true,
		Description:  "OpenAI-compatible chat completions (Hermes experiments)",
	},
}

// CapabilityForProvider returns the declared capability for a provider name.
func CapabilityForProvider(name string) ProviderCapability {
	name = strings.ToLower(strings.TrimSpace(name))
	if cap, ok := providerCapabilities[name]; ok {
		return cap
	}
	return ProviderCapability{
		Provider:     name,
		Stream:       false,
		Action:       false,
		Abort:        false,
		Routes:       []string{},
		Experimental: true,
		Description:  "unknown provider",
	}
}

// CapabilityForConfig resolves capability from provider config before instantiation.
func CapabilityForConfig(config A2UIProviderConfig) ProviderCapability {
	mode := strings.ToLower(strings.TrimSpace(config.Mode))
	if mode == "" {
		mode = defaultA2UIProviderMode
	}
	return CapabilityForProvider(mode)
}
