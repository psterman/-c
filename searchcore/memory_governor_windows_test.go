//go:build windows

package main

import "testing"

func TestMemoryRecoveryAllowedBlocksIndexing(t *testing.T) {
	st := FullTextStatus{
		Running:      true,
		PendingTasks: 2,
		ScanPhase:    "indexing",
	}
	if memoryRecoveryAllowed(st) {
		t.Fatal("indexing with pending tasks should block recovery")
	}
}

func TestMemoryRecoveryAllowedWhenIdleStopped(t *testing.T) {
	setIndexActivity(false)
	st := FullTextStatus{
		Running:      false,
		PendingTasks: 0,
		ScanPhase:    "idle",
	}
	if !memoryRecoveryAllowed(st) {
		t.Fatal("idle stopped indexer should allow recovery")
	}
}
