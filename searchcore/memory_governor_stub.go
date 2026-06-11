//go:build !windows

package main

func startMemoryGovernorLoop(baseDir string) {}

func memoryRecoveryAllowed(st FullTextStatus) bool {
	return true
}
