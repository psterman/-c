//go:build windows

package main

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
)

func handleFullTextRoots(w http.ResponseWriter, r *http.Request) {
	baseDir := fullTextBaseDir()
	if baseDir == "" {
		http.Error(w, "base dir not initialized", http.StatusInternalServerError)
		return
	}

	switch r.Method {
	case http.MethodGet:
		res := ResolveRoots(baseDir)
		everythingOK, everythingReason := probeEverythingIPC(baseDir)
		rootDiscovery := buildRootDiscoveryStatuses(res, everythingOK, everythingReason)
		writeFullTextJSON(w, http.StatusOK, map[string]any{
			"ok":                 true,
			"resolution":         res,
			"needsSetupWizard":   NeedsSetupWizard(res),
			"wizardCandidates":   DefaultWizardCandidates(baseDir),
			"rootDiscovery":      rootDiscovery,
			"discoverySummary":   summarizeDiscovery(rootDiscovery),
			"everythingOk":       everythingOK,
			"everythingReason":   everythingReason,
		})
	case http.MethodPost:
		handleFullTextRootsConfirm(w, r, baseDir)
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func handleFullTextRootsConfirm(w http.ResponseWriter, r *http.Request, baseDir string) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	body, err := io.ReadAll(r.Body)
	if err != nil {
		http.Error(w, "invalid body", http.StatusBadRequest)
		return
	}
	var req rootsConfirmRequest
	if len(strings.TrimSpace(string(body))) > 0 {
		if err := json.Unmarshal(body, &req); err != nil {
			http.Error(w, "invalid json body", http.StatusBadRequest)
			return
		}
	}
	if len(req.Roots) == 0 {
		http.Error(w, "roots required", http.StatusBadRequest)
		return
	}
	var autoDiscover *bool
	if req.AutoDiscover != nil {
		autoDiscover = req.AutoDiscover
	}
	res, err := PersistRoots(baseDir, req.Roots, autoDiscover)
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}
	invalidateFullTextFilterCache()

	if req.Remember || req.Remember == false && len(req.Roots) > 0 {
		// remember defaults true when roots provided
	}
	if !isFullTextStartSuppressed() {
		_ = StopIndexer()
		_ = StartIndexer(baseDir)
	}
	everythingOK, everythingReason := probeEverythingIPC(baseDir)
	rootDiscovery := buildRootDiscoveryStatuses(res, everythingOK, everythingReason)
	writeFullTextJSON(w, http.StatusOK, map[string]any{
		"ok":               true,
		"resolution":       res,
		"needsSetupWizard": NeedsSetupWizard(res),
		"rootDiscovery":    rootDiscovery,
		"discoverySummary": summarizeDiscovery(rootDiscovery),
		"status":           GetStatus(),
	})
}
