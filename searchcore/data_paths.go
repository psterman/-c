package main

import (
	"os"
	"path/filepath"
)

// resolveDataFile 优先 Data/<subDir>/<name>，其次 Data/<name>（兼容旧布局）。
func resolveDataFile(baseDir, subDir, fileName string) string {
	if subDir != "" {
		preferred := filepath.Join(baseDir, "Data", subDir, fileName)
		if _, err := os.Stat(preferred); err == nil {
			return preferred
		}
	}
	legacy := filepath.Join(baseDir, "Data", fileName)
	if _, err := os.Stat(legacy); err == nil {
		return legacy
	}
	if subDir != "" {
		return filepath.Join(baseDir, "Data", subDir, fileName)
	}
	return legacy
}

// resolveDataDb 优先 Data/db/<name>，其次 Data/<name>。
func resolveDataDb(baseDir, fileName string) string {
	return resolveDataFile(baseDir, "db", fileName)
}
