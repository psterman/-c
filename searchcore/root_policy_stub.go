//go:build !windows

package main

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

func NeedsSetupWizard(res RootResolution) bool { return res.State == RootSetupRequired }
func IsNarrowRoot(path string) bool            { return false }
func ResolveRoots(baseDir string) RootResolution {
	return RootResolution{Roots: []string{baseDir}, State: RootConfigured, Source: "workspaceFallback", PolicyVersion: 1}
}
func DefaultWizardCandidates(baseDir string) []string { return []string{baseDir} }
func PersistRoots(baseDir string, roots []string, autoDiscover *bool) (RootResolution, error) {
	return ResolveRoots(baseDir), nil
}
func rootsFingerprint(roots []string) string { return "" }
