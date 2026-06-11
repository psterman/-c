//go:build windows

package main

import (
	"log"
	"os"
	"time"
)

const (
	defaultMemSoftMiB   = 600
	defaultMemHardMiB   = 900
	memGovernorPeriod   = 30 * time.Second
	memHardHitsNeeded   = 3
	memSoftCooldown     = 90 * time.Second
)

func initMemoryGovernorThresholds() {
	globalMemoryGovernor.mu.Lock()
	defer globalMemoryGovernor.mu.Unlock()
	soft := parseInt64Env("SEARCHCENTER_MEM_SOFT_MIB", defaultMemSoftMiB)
	hard := parseInt64Env("SEARCHCENTER_MEM_HARD_MIB", defaultMemHardMiB)
	if soft < 100 {
		soft = defaultMemSoftMiB
	}
	if hard < soft+50 {
		hard = soft + 300
	}
	globalMemoryGovernor.softThresholdMB = soft
	globalMemoryGovernor.hardThresholdMB = hard
}

func startMemoryGovernorLoop(baseDir string) {
	_ = baseDir
	if !parseBoolEnv("SEARCHCENTER_MEM_GOVERNOR", true) {
		log.Printf("[mem] governor disabled (SEARCHCENTER_MEM_GOVERNOR=0)")
		return
	}
	initMemoryGovernorThresholds()
	globalMemoryGovernor.mu.Lock()
	log.Printf("[mem] governor enabled soft=%d MiB hard=%d MiB period=%s",
		globalMemoryGovernor.softThresholdMB, globalMemoryGovernor.hardThresholdMB, memGovernorPeriod)
	globalMemoryGovernor.mu.Unlock()
	go memoryGovernorLoop()
}

func memoryGovernorLoop() {
	ticker := time.NewTicker(memGovernorPeriod)
	defer ticker.Stop()
	for range ticker.C {
		memoryGovernorTick()
	}
}

func memoryRecoveryAllowed(st FullTextStatus) bool {
	act := activityTrackerSnapshot(st)
	if indexing, _ := act["indexActivity"].(bool); indexing {
		return false
	}
	if leases, _ := act["activityLeases"].(int32); leases > 0 {
		return false
	}
	if st.Running && st.PendingTasks > 0 {
		return false
	}
	fullTextGlobalMu.RLock()
	idx := fullTextGlobal
	fullTextGlobalMu.RUnlock()
	if idx != nil && idx.hasPendingBatch() {
		return false
	}
	return true
}

func memoryGovernorTick() {
	st := GetStatus()
	var m runtimeMemStats
	readRuntimeMemStats(&m)
	privateMiB := float64(m.privateBytes) / (1024 * 1024)

	globalMemoryGovernor.mu.Lock()
	soft := float64(globalMemoryGovernor.softThresholdMB)
	hard := float64(globalMemoryGovernor.hardThresholdMB)
	globalMemoryGovernor.mu.Unlock()

	allowed := memoryRecoveryAllowed(st)

	if privateMiB >= hard {
		globalMemoryGovernor.mu.Lock()
		globalMemoryGovernor.hardHitStreak++
		streak := globalMemoryGovernor.hardHitStreak
		globalMemoryGovernor.mu.Unlock()

		if streak >= memHardHitsNeeded && allowed && !st.Running {
			log.Printf("[mem] hard limit %.1f MiB >= %.0f for %d samples; exiting process", privateMiB, hard, streak)
			globalMemoryGovernor.mu.Lock()
			globalMemoryGovernor.lastAction = "hard_exit"
			globalMemoryGovernor.mu.Unlock()
			os.Exit(0)
			return
		}
		globalMemoryGovernor.mu.Lock()
		globalMemoryGovernor.lastAction = "hard_watch"
		globalMemoryGovernor.mu.Unlock()
		return
	}

	globalMemoryGovernor.mu.Lock()
	globalMemoryGovernor.hardHitStreak = 0
	globalMemoryGovernor.mu.Unlock()

	if privateMiB < soft || !allowed {
		return
	}

	globalMemoryGovernor.mu.Lock()
	if time.Since(globalMemoryGovernor.softRecoveryAt) < memSoftCooldown {
		globalMemoryGovernor.mu.Unlock()
		return
	}
	globalMemoryGovernor.mu.Unlock()

	beforePrivate := privateMiB
	beforeHeap := float64(m.heapAlloc) / (1024 * 1024)
	runSoftMemoryRecovery()
	time.Sleep(200 * time.Millisecond)

	var m2 runtimeMemStats
	readRuntimeMemStats(&m2)
	afterPrivate := float64(m2.privateBytes) / (1024 * 1024)
	afterHeap := float64(m2.heapAlloc) / (1024 * 1024)
	rec := map[string]any{
		"at":                 time.Now().UTC().Format(time.RFC3339),
		"privateBeforeMiB":   round2(beforePrivate),
		"privateAfterMiB":    round2(afterPrivate),
		"heapAllocBeforeMiB": round2(beforeHeap),
		"heapAllocAfterMiB":  round2(afterHeap),
	}
	globalMemoryGovernor.mu.Lock()
	globalMemoryGovernor.lastAction = "soft_recovery"
	globalMemoryGovernor.lastSoftRecovery = rec
	globalMemoryGovernor.softRecoveryAt = time.Now()
	globalMemoryGovernor.mu.Unlock()
	log.Printf("[mem] soft recovery private %.1f→%.1f MiB heap %.1f→%.1f MiB",
		rec["privateBeforeMiB"], rec["privateAfterMiB"], rec["heapAllocBeforeMiB"], rec["heapAllocAfterMiB"])
}

func runSoftMemoryRecovery() {
	fullTextGlobalMu.RLock()
	idx := fullTextGlobal
	fullTextGlobalMu.RUnlock()
	if idx != nil {
		idx.closeCachedReaderOnStop()
		if idx.metaCache != nil {
			idx.metaCache.TrimTo(defaultFileMetaCacheSize / 2)
		}
	}
	bumpFullTextQueryCacheEpoch()
	releaseProcessHeapAfterIndexerStop()
}
