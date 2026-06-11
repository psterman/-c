//go:build !windows

package main

import "net/http"

func initActivityTracker()                             {}
func bumpClientActivity()                             {}
func cancelIdleExitCountdown()                        {}
func acquireActivityLease()                           {}
func releaseActivityLease()                           {}
func bumpQueryActivity()                              {}
func setIndexActivity(active bool)                    {}
func activityTrackerSnapshot(st FullTextStatus) map[string]any {
	return map[string]any{"isIdle": true, "activityLeases": int32(0)}
}
func idleLifecycleSnapshot(st FullTextStatus) map[string]any {
	return map[string]any{"enabled": false}
}
func startIdleLifecycleLoop(string)                   {}
func memoryGovernorSnapshot(baseDir string, st FullTextStatus) map[string]any {
	return map[string]any{"action": "none"}
}

func handleFullTextMemory(w http.ResponseWriter, r *http.Request) {
	http.Error(w, "not supported", http.StatusNotImplemented)
}
