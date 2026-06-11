package main

import (
	"crypto/sha256"
	"encoding/hex"
	"sort"
	"strings"
)

func hashStrings(items []string) string {
	if len(items) == 0 {
		return ""
	}
	cp := append([]string{}, items...)
	sort.Strings(cp)
	h := sha256.Sum256([]byte(strings.Join(cp, "\n")))
	return "sha256:" + hex.EncodeToString(h[:])
}

func computeConfigFingerprint(baseDir string, cfg fullTextConfig) string {
	res := cfg.RootResolution
	if len(res.Roots) == 0 {
		res = ResolveRoots(baseDir)
	}
	parts := []string{
		rootsFingerprint(res.Roots),
		hashStrings(cfg.FilterConfig.ExcludePrefixes),
		cfg.ScanSpeed,
		cfg.PrivacyMode,
	}
	if cfg.PipelineV2 {
		parts = append(parts, "pipeline_v2")
	}
	return hashStrings(parts)
}
