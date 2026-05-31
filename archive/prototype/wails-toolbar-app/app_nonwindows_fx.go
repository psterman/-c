//go:build !windows

package main

func (a *App) enableWindowResidentMode() {}

func fadeInWailsWindow(durationMs int) error { return nil }

func captureAreaBase64(x, y, w, h int) SnapshotResult {
	return SnapshotResult{OK: false, Error: "not supported on this platform"}
}
