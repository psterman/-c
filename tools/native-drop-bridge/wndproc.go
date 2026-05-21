//go:build windows

package main

import (
	"encoding/json"
	"syscall"
	"unsafe"
)

const (
	wmCopyDataInCursor = 2
	hwndTopmost        = ^uintptr(0) // HWND_TOPMOST
)

var (
	procCallWindowProcW = modUser32.NewProc("CallWindowProcW")

	callbackBridgeWndProc = syscall.NewCallback(bridgeWndProc)
)

type cursorCopyData struct {
	Op      string `json:"op"`
	X       int32  `json:"x"`
	Y       int32  `json:"y"`
	Session uint64 `json:"session"`
}

func bridgeWndProc(hwnd, msg, wParam, lParam uintptr) uintptr {
	switch uint32(msg) {
	case wmCopyData:
		if handleCopyDataCursor(lParam) {
			return 1
		}
	}
	r, _, _ := procCallWindowProcW.Call(procDefWindowProcW.Addr(), hwnd, msg, wParam, lParam)
	return r
}

func handleCopyDataCursor(lParam uintptr) bool {
	cds := (*copyDataStruct)(unsafe.Pointer(lParam))
	if cds == nil || cds.CbData == 0 || cds.LpData == 0 {
		return false
	}
	if cds.DwData != wmCopyDataInCursor {
		return false
	}
	n := cds.CbData
	if n > 4096 {
		n = 4096
	}
	buf := make([]byte, n)
	copy(buf, unsafe.Slice((*byte)(unsafe.Pointer(cds.LpData)), n))
	line := string(buf)
	line = trimNull(line)
	var cur cursorCopyData
	if err := json.Unmarshal([]byte(line), &cur); err != nil {
		return false
	}
	if cur.Op != "cursor" {
		return false
	}
	globalGate.MoveCursor(cur.X, cur.Y, cur.Session)
	return true
}

func trimNull(s string) string {
	if i := indexByteString(s, 0); i >= 0 {
		return s[:i]
	}
	return s
}

func indexByteString(s string, c byte) int {
	for i := 0; i < len(s); i++ {
		if s[i] == c {
			return i
		}
	}
	return -1
}

func subclassBridgeWindow(hwnd uintptr) {
	_ = hwnd
}
