//go:build !windows

package main

type indexLifecycleSnapshot struct {
	Role              string `json:"role"`
	CutoverState      string `json:"cutoverState"`
	ConfigFingerprint string `json:"configFingerprint"`
	SchemaVersion     int    `json:"schemaVersion"`
}

func loadIndexLifecycleSnapshot(baseDir string) (indexLifecycleSnapshot, error) {
	return indexLifecycleSnapshot{Role: "active", CutoverState: "idle", SchemaVersion: 1}, nil
}

func ensureIndexDirsForLifecycle(indexDir string, cfg fullTextConfig) (writerDir, queryDir string, mgr any, forceRebuild bool, err error) {
	changed, err := ensureIndexVersion(indexDir, fullTextIndexVersion)
	return indexDir, indexDir, nil, changed, err
}
