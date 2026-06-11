//go:build windows

package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const currentRootPolicyVersion = 1

type RootLifecycleState string

const (
	RootSetupRequired  RootLifecycleState = "setup_required"
	RootConfigured     RootLifecycleState = "configured"
	RootAutoDiscovered RootLifecycleState = "auto_discovered"
)

type RootResolution struct {
	Roots            []string           `json:"roots"`
	State            RootLifecycleState `json:"rootLifecycleState"`
	Source           string             `json:"source"`
	RootsConfirmedAt string             `json:"rootsConfirmedAt,omitempty"`
	PolicyVersion    int                `json:"rootPolicyVersion"`
}

func NeedsSetupWizard(res RootResolution) bool {
	return res.State == RootSetupRequired
}

func IsNarrowRoot(path string) bool {
	return !isVolumeRootPath(path)
}

func ResolveRoots(baseDir string) RootResolution {
	cfg := loadFullTextFilterConfig(baseDir)
	raw := cfg.Raw

	res := RootResolution{
		PolicyVersion: raw.RootPolicyVersion,
	}
	if res.PolicyVersion <= 0 {
		res.PolicyVersion = currentRootPolicyVersion
	}
	if strings.TrimSpace(raw.RootsConfirmedAt) != "" {
		res.RootsConfirmedAt = strings.TrimSpace(raw.RootsConfirmedAt)
	}

	if roots := validatedKnowledgeRoots(baseDir, raw.KnowledgeRoots); len(roots) > 0 {
		res.Roots = roots
		res.State = RootConfigured
		res.Source = "knowledgeRoots"
		migrateLegacyRootsConfirmation(baseDir, &raw, roots)
		return res
	}

	if envRoots := resolveEnvRoots(baseDir); len(envRoots) > 0 {
		res.Roots = envRoots
		res.State = RootConfigured
		res.Source = "env"
		return res
	}

	autoDiscover := raw.AutoDiscoverRoots != nil && *raw.AutoDiscoverRoots
	if autoDiscover && res.RootsConfirmedAt != "" {
		if roots := discoverSearchRoots(); len(roots) > 0 {
			res.Roots = roots
			res.State = RootAutoDiscovered
			res.Source = "autoDiscover"
			return res
		}
	}

	res.State = RootSetupRequired
	res.Source = "none"
	res.Roots = nil
	return res
}

func validatedKnowledgeRoots(baseDir string, knowledgeRoots []string) []string {
	out := make([]string, 0, len(knowledgeRoots))
	for _, r := range knowledgeRoots {
		s := strings.TrimSpace(r)
		if s == "" {
			continue
		}
		if !filepath.IsAbs(s) {
			s = filepath.Join(baseDir, s)
		}
		s = filepath.Clean(s)
		if st, err := os.Stat(s); err == nil && st.IsDir() {
			out = append(out, s)
		}
	}
	return out
}

func resolveEnvRoots(baseDir string) []string {
	env := strings.TrimSpace(os.Getenv("SEARCHCENTER_FULLTEXT_ROOTS"))
	if env == "" {
		return nil
	}
	parts := strings.Split(env, ";")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		s := strings.TrimSpace(p)
		if s == "" {
			continue
		}
		if !filepath.IsAbs(s) {
			s = filepath.Join(baseDir, s)
		}
		if st, err := os.Stat(s); err == nil && st.IsDir() {
			out = append(out, filepath.Clean(s))
		}
	}
	return out
}

func migrateLegacyRootPolicyConfig(baseDir string, raw *fullTextFilterConfig) bool {
	if raw == nil {
		return false
	}
	if raw.RootPolicyVersion >= currentRootPolicyVersion && strings.TrimSpace(raw.RootsConfirmedAt) != "" {
		return false
	}
	autoDiscover := raw.AutoDiscoverRoots != nil && *raw.AutoDiscoverRoots
	hasKnowledge := len(validatedKnowledgeRoots(baseDir, raw.KnowledgeRoots)) > 0
	changed := false
	// 旧版：autoDiscoverRoots:true + 空 knowledgeRoots → 禁止静默 C–Z 全盘
	if !hasKnowledge && autoDiscover && strings.TrimSpace(raw.RootsConfirmedAt) == "" {
		falseVal := false
		raw.AutoDiscoverRoots = &falseVal
		raw.KnowledgeRoots = []string{}
		raw.RootPolicyVersion = currentRootPolicyVersion
		changed = true
	}
	if changed {
		_ = saveFullTextFilterConfig(baseDir, *raw)
	}
	return changed
}

func migrateLegacyRootsConfirmation(baseDir string, raw *fullTextFilterConfig, roots []string) {
	if strings.TrimSpace(raw.RootsConfirmedAt) != "" {
		return
	}
	raw.KnowledgeRoots = roots
	raw.RootsConfirmedAt = time.Now().Format(time.RFC3339)
	if raw.RootPolicyVersion <= 0 {
		raw.RootPolicyVersion = currentRootPolicyVersion
	}
	_ = saveFullTextFilterConfig(baseDir, *raw)
	invalidateFullTextFilterCache()
}

func DefaultWizardCandidates(baseDir string) []string {
	out := make([]string, 0, 4)
	home := strings.TrimSpace(os.Getenv("USERPROFILE"))
	if home != "" {
		for _, sub := range []string{"Documents", "Desktop"} {
			p := filepath.Join(home, sub)
			if st, err := os.Stat(p); err == nil && st.IsDir() {
				out = append(out, p)
			}
		}
	}
	cleanBase := filepath.Clean(strings.TrimSpace(baseDir))
	if cleanBase != "" {
		if st, err := os.Stat(cleanBase); err == nil && st.IsDir() {
			found := false
			for _, existing := range out {
				if strings.EqualFold(existing, cleanBase) {
					found = true
					break
				}
			}
			if !found {
				out = append(out, cleanBase)
			}
		}
	}
	return out
}

type rootsConfirmRequest struct {
	Roots          []string `json:"roots"`
	Remember       bool     `json:"remember"`
	AutoDiscover   *bool    `json:"autoDiscoverRoots"`
}

func invalidateFullTextFilterCache() {
	fullTextFilterCacheMu.Lock()
	fullTextFilterCacheBase = ""
	fullTextFilterCacheMu.Unlock()
}

func saveFullTextFilterConfig(baseDir string, raw fullTextFilterConfig) error {
	path := fullTextFilterConfigPath(baseDir)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	out, err := json.MarshalIndent(raw, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, out, 0o644)
}

func PersistRoots(baseDir string, roots []string, autoDiscover *bool) (RootResolution, error) {
	valid := validatedKnowledgeRoots(baseDir, roots)
	if len(valid) == 0 {
		return RootResolution{}, errInvalidRoots
	}

	cfg := loadFullTextFilterConfig(baseDir).Raw
	cfg.KnowledgeRoots = valid
	cfg.RootsConfirmedAt = time.Now().Format(time.RFC3339)
	if cfg.RootPolicyVersion <= 0 {
		cfg.RootPolicyVersion = currentRootPolicyVersion
	}
	if autoDiscover != nil {
		cfg.AutoDiscoverRoots = autoDiscover
	}
	cfg.WizardDismissed = false

	if err := saveFullTextFilterConfig(baseDir, cfg); err != nil {
		return RootResolution{}, err
	}
	invalidateFullTextFilterCache()
	return ResolveRoots(baseDir), nil
}

var errInvalidRoots = &rootPolicyError{msg: "at least one valid directory root is required"}

type rootPolicyError struct{ msg string }

func (e *rootPolicyError) Error() string { return e.msg }

func rootsFingerprint(roots []string) string {
	if len(roots) == 0 {
		return ""
	}
	normalized := make([]string, 0, len(roots))
	for _, r := range roots {
		normalized = append(normalized, normalizePathKey(r))
	}
	return hashStrings(normalized)
}
