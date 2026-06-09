package poc

import (
	"regexp"
	"strings"
)

const (
	OpenClawNamespaceCP      = "niuma-cp"
	OpenClawNamespaceAdapter = "niuma-adp"
	maxOpenClawCardSlugLen   = 40
)

var (
	openClawCardPrefixRe = regexp.MustCompile(`(?i)^card[-_]?`)
	openClawSlugSanitize = regexp.MustCompile(`[^a-zA-Z0-9_-]+`)
	openClawSlugTrim     = regexp.MustCompile(`^-+|-+$`)
)

// OpenClawCanonicalSessionKey mirrors FTB ocCanonicalSessionKey.
func OpenClawCanonicalSessionKey(key string) string {
	s := strings.TrimSpace(key)
	if s == "" {
		return ""
	}
	if strings.HasPrefix(s, "agent:") {
		return s
	}
	if s == "main" {
		return "agent:main:main"
	}
	return "agent:main:" + s
}

func openClawCardIDSlug(cardID string) string {
	slug := openClawCardPrefixRe.ReplaceAllString(strings.TrimSpace(cardID), "")
	slug = openClawSlugSanitize.ReplaceAllString(slug, "-")
	slug = openClawSlugTrim.ReplaceAllString(slug, "")
	if len(slug) > maxOpenClawCardSlugLen {
		slug = slug[:maxOpenClawCardSlugLen]
	}
	slug = openClawSlugTrim.ReplaceAllString(slug, "")
	if slug == "" {
		return "task"
	}
	return slug
}

// OpenClawSessionKeyForCard builds agent:main:{namespace}-{slug}.
func OpenClawSessionKeyForCard(cardID, namespace string) string {
	ns := strings.TrimSpace(namespace)
	if ns == "" {
		ns = OpenClawNamespaceCP
	}
	raw := "agent:main:" + ns + "-" + openClawCardIDSlug(cardID)
	if canonical := OpenClawCanonicalSessionKey(raw); canonical != "" {
		return canonical
	}
	return raw
}

func IsOpenClawCPSessionKey(key string) bool {
	k := OpenClawCanonicalSessionKey(key)
	return strings.HasPrefix(strings.ToLower(k), "agent:main:niuma-cp-")
}

func IsOpenClawAdapterSessionKey(key string) bool {
	k := OpenClawCanonicalSessionKey(key)
	return strings.HasPrefix(strings.ToLower(k), "agent:main:niuma-adp-")
}
