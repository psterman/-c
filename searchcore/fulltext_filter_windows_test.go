//go:build windows

package main

import (
	"testing"
)

func TestMergeFullTextFilterConfigAutoDiscoverFalse(t *testing.T) {
	base := defaultFullTextFilterConfig(t.TempDir())
	falseVal := false
	merged := mergeFullTextFilterConfig(base, fullTextFilterConfig{
		AutoDiscoverRoots: &falseVal,
	})
	if merged.AutoDiscoverRoots == nil || *merged.AutoDiscoverRoots {
		t.Fatalf("autoDiscoverRoots=%v want false", merged.AutoDiscoverRoots)
	}
	if effectiveAutoDiscoverRoots(merged) {
		t.Fatal("effective autoDiscover should be false")
	}
}

func TestMergeFullTextFilterConfigAutoDiscoverUnsetPreservesDefault(t *testing.T) {
	base := defaultFullTextFilterConfig(t.TempDir())
	merged := mergeFullTextFilterConfig(base, fullTextFilterConfig{})
	if merged.AutoDiscoverRoots == nil || !*merged.AutoDiscoverRoots {
		t.Fatalf("autoDiscoverRoots=%v want default true", merged.AutoDiscoverRoots)
	}
}
