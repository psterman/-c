package main

import (
	"bufio"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
)

type niumaDebugResponse struct {
	FilePath string            `json:"filePath"`
	Exists   bool              `json:"exists"`
	Size     int64             `json:"size"`
	Lines    []json.RawMessage `json:"lines"`
}

func handleNiumaDebug(w http.ResponseWriter, r *http.Request, absBase string) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.Header().Set("Access-Control-Allow-Origin", "*")

	fp := filepath.Join(absBase, "Cache", "debug", "openclaw_timeline.jsonl")
	resp := niumaDebugResponse{
		FilePath: fp,
		Exists:   false,
		Size:     0,
		Lines:    make([]json.RawMessage, 0, 80),
	}

	st, err := os.Stat(fp)
	if err != nil || st.IsDir() {
		_ = json.NewEncoder(w).Encode(resp)
		return
	}
	resp.Exists = true
	resp.Size = st.Size()

	f, err := os.Open(fp)
	if err != nil {
		_ = json.NewEncoder(w).Encode(resp)
		return
	}
	defer f.Close()

	sc := bufio.NewScanner(f)
	// Allow longer single-line JSON events.
	buf := make([]byte, 0, 64*1024)
	sc.Buffer(buf, 512*1024)
	tmp := make([]json.RawMessage, 0, 400)
	for sc.Scan() {
		line := sc.Bytes()
		if len(line) == 0 {
			continue
		}
		cp := make([]byte, len(line))
		copy(cp, line)
		tmp = append(tmp, json.RawMessage(cp))
	}
	if len(tmp) > 80 {
		tmp = tmp[len(tmp)-80:]
	}
	resp.Lines = tmp
	_ = json.NewEncoder(w).Encode(resp)
}

