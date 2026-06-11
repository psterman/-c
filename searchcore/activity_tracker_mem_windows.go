//go:build windows

package main

import (
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"runtime/debug"
	"strings"
	"unsafe"

	"golang.org/x/sys/windows"
)

var (
	modPsapi                 = windows.NewLazySystemDLL("psapi.dll")
	procGetProcessMemoryInfo = modPsapi.NewProc("GetProcessMemoryInfo")
)

type processMemoryCounters struct {
	CB                         uint32
	PageFaultCount             uint32
	PeakWorkingSetSize         uintptr
	WorkingSetSize             uintptr
	QuotaPeakPagedPoolUsage    uintptr
	QuotaPagedPoolUsage        uintptr
	QuotaPeakNonPagedPoolUsage uintptr
	QuotaNonPagedPoolUsage     uintptr
	PagefileUsage              uintptr
	PeakPagefileUsage          uintptr
}

func readRuntimeMemStats(out *runtimeMemStats) {
	if out == nil {
		return
	}
	var mc processMemoryCounters
	mc.CB = uint32(unsafe.Sizeof(mc))
	h := windows.CurrentProcess()
	_, _, _ = procGetProcessMemoryInfo.Call(uintptr(h), uintptr(unsafe.Pointer(&mc)), uintptr(mc.CB))
	out.privateBytes = uint64(mc.PagefileUsage)
	out.workingSetBytes = uint64(mc.WorkingSetSize)
	var ms runtime.MemStats
	runtime.ReadMemStats(&ms)
	out.heapAlloc = ms.HeapAlloc
	out.heapSys = ms.HeapSys
	out.heapInuse = ms.HeapInuse
	out.heapIdle = ms.HeapIdle
	out.heapReleased = ms.HeapReleased
	out.numGC = ms.NumGC
}

// releaseProcessHeapAfterIndexerStop runs a one-shot Go GC + OS heap release after indexer stop.
// Must not be called periodically — only on explicit stop/idle transitions.
func releaseProcessHeapAfterIndexerStop() {
	runtime.GC()
	debug.FreeOSMemory()
}

func measureIndexMappedMiB(baseDir string) float64 {
	idxDir, _ := resolveIndexDir(baseDir)
	if idxDir == "" {
		return 0
	}
	activeDir := filepath.Join(idxDir, "active")
	if st, err := os.Stat(activeDir); err != nil || !st.IsDir() {
		activeDir = idxDir
	}
	var total int64
	_ = filepath.Walk(activeDir, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		name := strings.ToLower(info.Name())
		if strings.HasSuffix(name, ".seg") || strings.HasSuffix(name, ".db") {
			total += info.Size()
		}
		return nil
	})
	return round2(float64(total) / (1024 * 1024))
}

func handleFullTextMemory(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	baseDir := fullTextBaseDir()
	st := GetStatus()
	writeFullTextJSON(w, http.StatusOK, map[string]any{
		"ok":     true,
		"memory": memoryGovernorSnapshot(baseDir, st),
		"status": st,
	})
}
