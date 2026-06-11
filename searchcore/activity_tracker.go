//go:build windows

package main

import (
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

type activityTracker struct {
	queryCount      atomic.Int64
	indexActive     atomic.Bool
	lastBump        atomic.Int64
	activityLeases  atomic.Int32
}

var globalActivityTracker activityTracker

func initActivityTracker() {
	if globalActivityTracker.lastBump.Load() == 0 {
		globalActivityTracker.lastBump.Store(time.Now().UnixNano())
	}
}

func bumpClientActivity() {
	globalActivityTracker.lastBump.Store(time.Now().UnixNano())
}

func cancelIdleExitCountdown() {
	resetIdleIndexerStoppedMark()
}

func acquireActivityLease() {
	globalActivityTracker.activityLeases.Add(1)
	bumpClientActivity()
	cancelIdleExitCountdown()
}

func releaseActivityLease() {
	globalActivityTracker.activityLeases.Add(-1)
}

func bumpQueryActivity() {
	globalActivityTracker.queryCount.Add(1)
	bumpClientActivity()
	cancelIdleExitCountdown()
}

func setIndexActivity(active bool) {
	globalActivityTracker.indexActive.Store(active)
	if active {
		globalActivityTracker.lastBump.Store(time.Now().UnixNano())
	}
}

func activityTrackerSnapshot(st FullTextStatus) map[string]any {
	queries := globalActivityTracker.queryCount.Load()
	indexing := globalActivityTracker.indexActive.Load()
	phase := strings.ToLower(strings.TrimSpace(st.ScanPhase))
	if phase == "walking" || phase == "indexing" || phase == "incremental_sync" {
		indexing = true
	}
	if st.PendingTasks > 0 {
		indexing = true
	}
	leases := globalActivityTracker.activityLeases.Load()
	if leases > 0 {
		indexing = true
	}
	idleSec := int64(0)
	if ts := globalActivityTracker.lastBump.Load(); ts > 0 {
		idleSec = int64(time.Since(time.Unix(0, ts)).Seconds())
	}
	return map[string]any{
		"queryCount":      queries,
		"indexActivity":   indexing,
		"idleSeconds":     idleSec,
		"isIdle":          queries == 0 && !indexing && leases == 0,
		"activityLeases":  leases,
	}
}

type memoryGovernor struct {
	mu               sync.Mutex
	softThresholdMB  int64
	hardThresholdMB  int64
	lastAction       string
	hardHitStreak    int
	softRecoveryAt   time.Time
	lastSoftRecovery map[string]any
}

var globalMemoryGovernor = memoryGovernor{
	softThresholdMB: 600,
	hardThresholdMB: 900,
}

func memoryGovernorSnapshot(baseDir string, st FullTextStatus) map[string]any {
	var m runtimeMemStats
	readRuntimeMemStats(&m)
	privateMiB := float64(m.privateBytes) / (1024 * 1024)
	workingSetMiB := float64(m.workingSetBytes) / (1024 * 1024)
	heapAllocMiB := float64(m.heapAlloc) / (1024 * 1024)
	heapSysMiB := float64(m.heapSys) / (1024 * 1024)
	heapInuseMiB := float64(m.heapInuse) / (1024 * 1024)
	heapIdleMiB := float64(m.heapIdle) / (1024 * 1024)
	heapReleasedMiB := float64(m.heapReleased) / (1024 * 1024)
	softHit := privateMiB >= float64(globalMemoryGovernor.softThresholdMB)
	hardHit := privateMiB >= float64(globalMemoryGovernor.hardThresholdMB)
	recoveryOK := memoryRecoveryAllowed(st)
	globalMemoryGovernor.mu.Lock()
	action := globalMemoryGovernor.lastAction
	if action == "" {
		action = "none"
	}
	hardStreak := globalMemoryGovernor.hardHitStreak
	lastSoft := globalMemoryGovernor.lastSoftRecovery
	globalMemoryGovernor.mu.Unlock()
	if hardHit && recoveryOK && !st.Running && hardStreak >= memHardHitsNeeded {
		action = "hard_exit_pending"
	} else if hardHit {
		if recoveryOK && !st.Running {
			action = "hard_watch"
		} else {
			action = "hard_blocked"
		}
	} else if softHit && recoveryOK {
		action = "soft_eligible"
	}
	fp := computeConfigFingerprint(baseDir, loadFullTextConfig(baseDir))
	indexMappedMiB := measureIndexMappedMiB(baseDir)
	return map[string]any{
		"privateMiB":        round2(privateMiB),
		"workingSetMiB":     round2(workingSetMiB),
		"heapAllocMiB":      round2(heapAllocMiB),
		"heapSysMiB":        round2(heapSysMiB),
		"indexMappedMiB":    indexMappedMiB,
		"heapInuseMiB":      round2(heapInuseMiB),
		"heapIdleMiB":       round2(heapIdleMiB),
		"heapReleasedMiB":   round2(heapReleasedMiB),
		"numGC":             m.numGC,
		"softThresholdMiB":  globalMemoryGovernor.softThresholdMB,
		"hardThresholdMiB":  globalMemoryGovernor.hardThresholdMB,
		"action":            action,
		"hardHitStreak":     hardStreak,
		"recoveryAllowed":   recoveryOK,
		"lastSoftRecovery":  lastSoft,
		"activity":          activityTrackerSnapshot(st),
		"configFingerprint": fp,
		"indexedFiles":      st.IndexedFiles,
		"pendingTasks":      st.PendingTasks,
		"idleLifecycle":     idleLifecycleSnapshot(st),
	}
}

func round2(v float64) float64 {
	return float64(int64(v*100+0.5)) / 100
}

type runtimeMemStats struct {
	privateBytes    uint64
	workingSetBytes uint64
	heapAlloc       uint64
	heapSys         uint64
	heapInuse       uint64
	heapIdle        uint64
	heapReleased    uint64
	numGC           uint32
}
