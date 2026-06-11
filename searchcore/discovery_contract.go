//go:build windows

package main

import (
	"strings"
	"sync"
)

type DiscoveryMode string

const (
	DiscoveryEverything    DiscoveryMode = "everything"
	DiscoveryWalkFallback  DiscoveryMode = "walk_fallback"
	DiscoveryDegraded      DiscoveryMode = "degraded"
	DiscoverySetupRequired DiscoveryMode = "setup_required"
)

type DiscoveryOutcome struct {
	Mode           DiscoveryMode `json:"mode"`
	Reason         string        `json:"reason,omitempty"`
	Skipped        bool          `json:"skipped,omitempty"`
	ActionableHint string        `json:"actionableHint,omitempty"`
}

type RootDiscoveryStatus struct {
	Path       string           `json:"path"`
	Discovery  DiscoveryOutcome `json:"discovery"`
	IsVolume   bool             `json:"isVolumeRoot"`
}

type DiscoverySummary struct {
	Mode           string `json:"mode"`
	DegradedCount  int    `json:"degradedCount"`
	WalkCount      int    `json:"walkFallbackCount"`
	SetupRequired  bool   `json:"setupRequired"`
	ActionableHint string `json:"actionableHint,omitempty"`
}

var (
	discoveryStatusMu sync.RWMutex
	discoveryByRoot   = map[string]DiscoveryOutcome{}
)

func resetDiscoveryStatus() {
	discoveryStatusMu.Lock()
	discoveryByRoot = map[string]DiscoveryOutcome{}
	discoveryStatusMu.Unlock()
}

func recordDiscoveryOutcome(root string, outcome DiscoveryOutcome) {
	key := normalizePathKey(root)
	discoveryStatusMu.Lock()
	discoveryByRoot[key] = outcome
	discoveryStatusMu.Unlock()
}

func getDiscoveryOutcome(root string) DiscoveryOutcome {
	key := normalizePathKey(root)
	discoveryStatusMu.RLock()
	out, ok := discoveryByRoot[key]
	discoveryStatusMu.RUnlock()
	if ok {
		return out
	}
	return DiscoveryOutcome{Mode: DiscoveryEverything, Reason: "OK"}
}

func planDiscoveryForRoot(res RootResolution, root string, everythingOK bool, everythingReason string) DiscoveryOutcome {
	if res.State == RootSetupRequired {
		return DiscoveryOutcome{
			Mode:           DiscoverySetupRequired,
			Reason:         "ROOT_SETUP_REQUIRED",
			ActionableHint: "请选择要索引的文件夹",
		}
	}
	if everythingOK {
		return DiscoveryOutcome{Mode: DiscoveryEverything, Reason: "OK"}
	}
	if isVolumeRootPath(root) {
		return DiscoveryOutcome{
			Mode:           DiscoveryDegraded,
			Reason:         "EVERYTHING_IPC_FAIL_VOLUME_ROOT",
			Skipped:        true,
			ActionableHint: root + " 无法安全索引，请缩小目录或启动 Everything",
		}
	}
	reason := strings.TrimSpace(everythingReason)
	if reason == "" {
		reason = "EVERYTHING_IPC_FAIL"
	}
	return DiscoveryOutcome{
		Mode:           DiscoveryWalkFallback,
		Reason:         reason,
		ActionableHint: "Everything 不可用，已对 " + root + " 使用目录遍历",
	}
}

func buildRootDiscoveryStatuses(res RootResolution, everythingOK bool, everythingReason string) []RootDiscoveryStatus {
	if res.State == RootSetupRequired {
		return []RootDiscoveryStatus{{
			Path: "",
			Discovery: DiscoveryOutcome{
				Mode:           DiscoverySetupRequired,
				Reason:         "ROOT_SETUP_REQUIRED",
				ActionableHint: "请选择要索引的文件夹",
			},
		}}
	}
	out := make([]RootDiscoveryStatus, 0, len(res.Roots))
	for _, root := range res.Roots {
		stored := getDiscoveryOutcome(root)
		planned := planDiscoveryForRoot(res, root, everythingOK, everythingReason)
		mode := planned.Mode
		if stored.Mode != DiscoveryEverything || stored.Reason != "OK" {
			mode = stored.Mode
			planned = stored
		}
		out = append(out, RootDiscoveryStatus{
			Path:      root,
			IsVolume:  isVolumeRootPath(root),
			Discovery: DiscoveryOutcome{Mode: mode, Reason: planned.Reason, Skipped: planned.Skipped, ActionableHint: planned.ActionableHint},
		})
	}
	return out
}

func summarizeDiscovery(statuses []RootDiscoveryStatus) DiscoverySummary {
	sum := DiscoverySummary{Mode: "ok"}
	if len(statuses) == 0 {
		return sum
	}
	for _, st := range statuses {
		switch st.Discovery.Mode {
		case DiscoverySetupRequired:
			sum.SetupRequired = true
			sum.Mode = "setup_required"
			sum.ActionableHint = st.Discovery.ActionableHint
		case DiscoveryDegraded:
			sum.DegradedCount++
		case DiscoveryWalkFallback:
			sum.WalkCount++
		}
	}
	if sum.SetupRequired {
		return sum
	}
	if sum.DegradedCount > 0 && sum.WalkCount > 0 {
		sum.Mode = "mixed"
	} else if sum.DegradedCount > 0 {
		sum.Mode = "degraded"
		sum.ActionableHint = "部分盘符根无法索引，请缩小目录或启动 Everything"
	} else if sum.WalkCount > 0 {
		sum.Mode = "walk_fallback"
	}
	return sum
}

func shouldWalkOnEverythingFailure(root string, res RootResolution) bool {
	if res.State == RootSetupRequired {
		return false
	}
	if isVolumeRootPath(root) {
		return false
	}
	return IsNarrowRoot(root)
}

func shouldSkipRootOnEverythingFailure(root string, res RootResolution) bool {
	if res.State == RootSetupRequired {
		return true
	}
	return isVolumeRootPath(root)
}
