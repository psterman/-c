//go:build windows

package main

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
)

func readLauncherModeFromINI() string {
	exe, err := os.Executable()
	if err != nil {
		return "starry"
	}
	dir := filepath.Dir(exe)
	candidates := []string{
		filepath.Clean(filepath.Join(dir, "..", "..", "CursorShortcut.ini")),
		filepath.Clean(filepath.Join(dir, "..", "..", "..", "CursorShortcut.ini")),
	}
	for _, p := range candidates {
		if mode := parseLauncherModeINI(p); mode != "" {
			return mode
		}
	}
	return "starry"
}

func parseLauncherModeINI(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()
	inSection := false
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := strings.TrimSpace(sc.Text())
		if line == "" || strings.HasPrefix(line, ";") || strings.HasPrefix(line, "#") {
			continue
		}
		if strings.HasPrefix(line, "[") && strings.HasSuffix(line, "]") {
			sec := strings.ToLower(strings.Trim(line, "[]"))
			inSection = sec == "texthole"
			continue
		}
		if !inSection {
			continue
		}
		if !strings.HasPrefix(strings.ToLower(line), "launcher_mode") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		return normalizeLauncherMode(strings.TrimSpace(parts[1]))
	}
	return ""
}
