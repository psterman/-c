//go:build windows

package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestIndexLifecycleWriterAndQueryDirs(t *testing.T) {
	base := t.TempDir()
	mgr := &indexLifecycleManager{
		baseIndexDir: base,
		manifestPath: filepath.Join(base, "manifest.json"),
		manifest: indexManifest{
			SchemaVersion:     fullTextSchemaVersion,
			ConfigFingerprint: "fp",
			ActiveDir:         "active",
			CutoverState:      CutoverIdle,
		},
	}
	if got := mgr.writerIndexDir(); got != filepath.Join(base, "active") {
		t.Fatalf("idle writer dir = %q, want active", got)
	}
	if got := mgr.queryIndexDir(); got != filepath.Join(base, "active") {
		t.Fatalf("idle query dir = %q, want active", got)
	}

	mgr.manifest.CutoverState = CutoverBuilding
	mgr.manifest.BuildingDir = "building"
	if got := mgr.writerIndexDir(); got != filepath.Join(base, "building") {
		t.Fatalf("building writer dir = %q", got)
	}
	if got := mgr.queryIndexDir(); got != filepath.Join(base, "active") {
		t.Fatalf("building query dir without legacy = %q, want active", got)
	}

	mgr.manifest.LegacyDir = "legacy_readonly"
	if got := mgr.queryIndexDir(); got != filepath.Join(base, "legacy_readonly") {
		t.Fatalf("building query dir with legacy = %q", got)
	}
}

func TestIndexLifecycleCutoverIfReady(t *testing.T) {
	base := t.TempDir()
	active := filepath.Join(base, "active")
	building := filepath.Join(base, "building")
	if err := os.MkdirAll(active, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(active, "old.idx"), []byte("old"), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(building, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(building, "new.idx"), []byte("new"), 0o644); err != nil {
		t.Fatal(err)
	}

	mgr := &indexLifecycleManager{
		baseIndexDir: base,
		manifestPath: filepath.Join(base, "manifest.json"),
		manifest: indexManifest{
			SchemaVersion:     fullTextSchemaVersion,
			ConfigFingerprint: "fp",
			ActiveDir:         "active",
			BuildingDir:       "building",
			CutoverState:      CutoverReady,
		},
	}
	if err := mgr.cutoverIfReady(0); err != nil {
		t.Fatalf("cutoverIfReady: %v", err)
	}
	if mgr.manifest.CutoverState != CutoverDone {
		t.Fatalf("cutover state = %q, want cutover_done", mgr.manifest.CutoverState)
	}
	if _, err := os.Stat(filepath.Join(base, "legacy_readonly", "old.idx")); err != nil {
		t.Fatalf("legacy index missing: %v", err)
	}
	if _, err := os.Stat(filepath.Join(base, "active", "new.idx")); err != nil {
		t.Fatalf("active index missing after cutover: %v", err)
	}
	if _, err := os.Stat(building); err == nil {
		t.Fatalf("building dir should be removed after rename")
	}
}
