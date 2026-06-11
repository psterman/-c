//go:build windows

package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestResolveRootsConfiguredKnowledgeRoots(t *testing.T) {
	base := t.TempDir()
	cfgPath := fullTextFilterConfigPath(base)
	_ = os.MkdirAll(filepath.Dir(cfgPath), 0o755)
	docDir := filepath.Join(base, "docs")
	_ = os.MkdirAll(docDir, 0o755)
	raw := `{
  "knowledgeRoots": ["docs"],
  "autoDiscoverRoots": false,
  "rootsConfirmedAt": "2026-06-08T12:00:00Z",
  "rootPolicyVersion": 1
}`
	if err := os.WriteFile(cfgPath, []byte(raw), 0o644); err != nil {
		t.Fatal(err)
	}
	invalidateFullTextFilterCache()
	res := ResolveRoots(base)
	if res.State != RootConfigured {
		t.Fatalf("state=%s want configured", res.State)
	}
	if len(res.Roots) != 1 {
		t.Fatalf("roots=%v", res.Roots)
	}
	for _, r := range res.Roots {
		if pathHasRootPrefix("C:\\Windows", r) {
			t.Fatalf("unexpected drive expansion: %s", r)
		}
	}
}

func TestResolveRootsSetupRequiredWhenEmpty(t *testing.T) {
	base := t.TempDir()
	cfgPath := fullTextFilterConfigPath(base)
	_ = os.MkdirAll(filepath.Dir(cfgPath), 0o755)
	raw := `{"knowledgeRoots":[],"autoDiscoverRoots":false}`
	if err := os.WriteFile(cfgPath, []byte(raw), 0o644); err != nil {
		t.Fatal(err)
	}
	invalidateFullTextFilterCache()
	res := ResolveRoots(base)
	if res.State != RootSetupRequired {
		t.Fatalf("state=%s want setup_required", res.State)
	}
	if !NeedsSetupWizard(res) {
		t.Fatal("expected setup wizard")
	}
}

func TestDiscoveryContractThreeModes(t *testing.T) {
	narrow := "D:\\docs"
	volume := "C:\\"
	emptyRes := RootResolution{State: RootSetupRequired}

	a := planDiscoveryForRoot(RootResolution{State: RootConfigured}, narrow, false, "ipc fail")
	if a.Mode != DiscoveryWalkFallback {
		t.Fatalf("narrow mode=%s", a.Mode)
	}
	b := planDiscoveryForRoot(RootResolution{State: RootConfigured}, volume, false, "ipc fail")
	if b.Mode != DiscoveryDegraded || !b.Skipped {
		t.Fatalf("volume mode=%s skipped=%v", b.Mode, b.Skipped)
	}
	c := planDiscoveryForRoot(emptyRes, "", true, "")
	if c.Mode != DiscoverySetupRequired {
		t.Fatalf("empty config mode=%s", c.Mode)
	}
	if shouldWalkOnEverythingFailure(volume, RootResolution{State: RootConfigured}) {
		t.Fatal("volume root must not walk")
	}
	if !shouldWalkOnEverythingFailure(narrow, RootResolution{State: RootConfigured}) {
		t.Fatal("narrow root should walk")
	}
}
