//go:build !windows

package main

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
	Path      string           `json:"path"`
	Discovery DiscoveryOutcome `json:"discovery"`
	IsVolume  bool             `json:"isVolumeRoot"`
}

type DiscoverySummary struct {
	Mode           string `json:"mode"`
	DegradedCount  int    `json:"degradedCount"`
	WalkCount      int    `json:"walkFallbackCount"`
	SetupRequired  bool   `json:"setupRequired"`
	ActionableHint string `json:"actionableHint,omitempty"`
}

func resetDiscoveryStatus()                          {}
func recordDiscoveryOutcome(root string, o DiscoveryOutcome) {}
func planDiscoveryForRoot(res RootResolution, root string, everythingOK bool, everythingReason string) DiscoveryOutcome {
	return DiscoveryOutcome{Mode: DiscoveryEverything}
}
func buildRootDiscoveryStatuses(res RootResolution, everythingOK bool, everythingReason string) []RootDiscoveryStatus {
	return nil
}
func summarizeDiscovery(statuses []RootDiscoveryStatus) DiscoverySummary { return DiscoverySummary{Mode: "ok"} }
func shouldWalkOnEverythingFailure(root string, res RootResolution) bool { return true }
func shouldSkipRootOnEverythingFailure(root string, res RootResolution) bool { return false }
