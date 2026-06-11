//go:build windows

package main

import (
	"log"
	"os"
	"sync"
	"time"
)

const (
	defaultIdleStopIndexerSec = 300
	defaultIdleExitAfterStopSec = 600
)

type idleLifecycleState struct {
	mu               sync.Mutex
	indexerStoppedAt time.Time
	lastAction       string
}

var globalIdleLifecycle idleLifecycleState

func idleExitEnabled() bool {
	return parseBoolEnv("SEARCHCENTER_IDLE_EXIT", true)
}

func idleStopIndexerAfter() time.Duration {
	sec := parseInt64Env("SEARCHCENTER_IDLE_STOP_INDEXER_SEC", defaultIdleStopIndexerSec)
	if sec < 60 {
		sec = 60
	}
	return time.Duration(sec) * time.Second
}

func idleExitAfterStop() time.Duration {
	sec := parseInt64Env("SEARCHCENTER_IDLE_EXIT_SEC", defaultIdleExitAfterStopSec)
	if sec < 60 {
		sec = 60
	}
	return time.Duration(sec) * time.Second
}

func markIdleIndexerStopped() {
	globalIdleLifecycle.mu.Lock()
	defer globalIdleLifecycle.mu.Unlock()
	if globalIdleLifecycle.indexerStoppedAt.IsZero() {
		globalIdleLifecycle.indexerStoppedAt = time.Now()
	}
	globalIdleLifecycle.lastAction = "indexer_stopped_idle"
}

func resetIdleIndexerStoppedMark() {
	globalIdleLifecycle.mu.Lock()
	defer globalIdleLifecycle.mu.Unlock()
	globalIdleLifecycle.indexerStoppedAt = time.Time{}
	globalIdleLifecycle.lastAction = "active"
}

func idleLifecycleSnapshot(st FullTextStatus) map[string]any {
	enabled := idleExitEnabled()
	stopAfter := int64(idleStopIndexerAfter() / time.Second)
	exitAfter := int64(idleExitAfterStop() / time.Second)

	globalIdleLifecycle.mu.Lock()
	stoppedAt := globalIdleLifecycle.indexerStoppedAt
	lastAction := globalIdleLifecycle.lastAction
	globalIdleLifecycle.mu.Unlock()

	act := activityTrackerSnapshot(st)
	idleSec, _ := act["idleSeconds"].(int64)
	leases, _ := act["activityLeases"].(int32)

	phase := "disabled"
	if enabled {
		switch {
		case st.Running:
			phase = "active"
		case !stoppedAt.IsZero():
			phase = "exit_pending"
		default:
			phase = "indexer_idle"
		}
	}

	var stoppedAtRFC3339 any
	secondsUntilExit := int64(-1)
	if !stoppedAt.IsZero() {
		stoppedAtRFC3339 = stoppedAt.UTC().Format(time.RFC3339)
		remain := idleExitAfterStop() - time.Since(stoppedAt)
		if remain > 0 {
			secondsUntilExit = int64(remain / time.Second)
		} else {
			secondsUntilExit = 0
		}
	}

	return map[string]any{
		"enabled":              enabled,
		"phase":                phase,
		"stopIndexerAfterSec":  stopAfter,
		"exitAfterStopSec":     exitAfter,
		"idleSeconds":          idleSec,
		"activityLeases":       leases,
		"indexerStoppedAt":     stoppedAtRFC3339,
		"secondsUntilExit":     secondsUntilExit,
		"lastAction":           lastAction,
		"targetPrivateMiB":     150,
		"note":                 "P2: idle stop indexer then exit process; AHK/hub restart on next client request",
	}
}

func startIdleLifecycleLoop(baseDir string) {
	if !idleExitEnabled() {
		log.Printf("[idle] process exit on idle disabled (SEARCHCENTER_IDLE_EXIT=0)")
		return
	}
	go idleLifecycleLoop(baseDir)
}

func idleLifecycleLoop(baseDir string) {
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()
	for range ticker.C {
		if !idleExitEnabled() {
			continue
		}
		st := GetStatus()
		act := activityTrackerSnapshot(st)
		isIdle, _ := act["isIdle"].(bool)

		globalIdleLifecycle.mu.Lock()
		stoppedAt := globalIdleLifecycle.indexerStoppedAt
		globalIdleLifecycle.mu.Unlock()

		if !stoppedAt.IsZero() {
			if time.Since(stoppedAt) >= idleExitAfterStop() && isIdle {
				log.Printf("[idle] exiting SearchCenterCore after %v since indexer stop",
					time.Since(stoppedAt).Round(time.Second))
				globalIdleLifecycle.mu.Lock()
				globalIdleLifecycle.lastAction = "process_exit_idle"
				globalIdleLifecycle.mu.Unlock()
				os.Exit(0)
			}
			continue
		}

		if !isIdle {
			continue
		}

		idleSec, _ := act["idleSeconds"].(int64)
		stopAfter := idleStopIndexerAfter()

		if st.Running {
			if time.Duration(idleSec)*time.Second >= stopAfter {
				log.Printf("[idle] stopping indexer after %ds idle", idleSec)
				if err := StopIndexer(); err != nil {
					log.Printf("[idle] StopIndexer: %v", err)
				}
				markIdleIndexerStopped()
			}
			continue
		}

		if time.Duration(idleSec)*time.Second >= stopAfter {
			markIdleIndexerStopped()
		}
	}
}
