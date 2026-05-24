package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
)

// VoiceStatus — 由 AHK 写入 Cache/wails_voice_status.json，前端轮询展示
type VoiceStatus struct {
	Status  string `json:"status"`
	Message string `json:"message"`
}

func (a *App) nmerCacheDir() string {
	if p := strings.TrimSpace(os.Getenv("NMER_SCRIPT_DIR")); p != "" {
		return filepath.Join(p, "Cache")
	}
	exe, err := os.Executable()
	if err != nil {
		return filepath.Join(".", "Cache")
	}
	// build/bin/nmer-wails-input.exe -> 仓库根目录
	root := filepath.Clean(filepath.Join(filepath.Dir(exe), "..", "..", "..", ".."))
	return filepath.Join(root, "Cache")
}

func (a *App) ToggleVoiceInput() ProcessResult {
	cache := a.nmerCacheDir()
	if err := os.MkdirAll(cache, 0755); err != nil {
		return ProcessResult{OK: false, Message: err.Error()}
	}
	path := filepath.Join(cache, "wails_voice_cmd.txt")
	if err := os.WriteFile(path, []byte("toggle"), 0644); err != nil {
		return ProcessResult{OK: false, Message: err.Error()}
	}
	return ProcessResult{OK: true, Message: "ok"}
}

func (a *App) GetVoiceStatus() VoiceStatus {
	path := filepath.Join(a.nmerCacheDir(), "wails_voice_status.json")
	b, err := os.ReadFile(path)
	if err != nil {
		return VoiceStatus{
			Status:  "idle",
			Message: "点击麦克风开始；识别中再按 CapsLock 结束",
		}
	}
	var st VoiceStatus
	if json.Unmarshal(b, &st) == nil && strings.TrimSpace(st.Status) != "" {
		if strings.TrimSpace(st.Message) == "" {
			st.Message = voiceDefaultHint(st.Status)
		}
		return st
	}
	return VoiceStatus{Status: "idle", Message: "点击麦克风开始语音输入"}
}

func voiceDefaultHint(status string) string {
	switch strings.ToLower(strings.TrimSpace(status)) {
	case "listening", "recording":
		return "正在聆听… 再按 CapsLock 或点麦克风结束"
	case "loading", "transcribing":
		return "正在识别语音…"
	case "error":
		return "语音识别失败"
	default:
		return "点击麦克风开始语音输入"
	}
}
