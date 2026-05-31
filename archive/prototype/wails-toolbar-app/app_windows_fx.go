//go:build windows

package main

import (
	"bytes"
	"encoding/base64"
	"errors"
	"image/png"
	"strings"
	"syscall"
	"time"
	"unsafe"

	"github.com/kbinani/screenshot"
)

const (
	wsExTransparent  = 0x00000020
	wsExLayeredLocal = 0x00080000
	lwaAlphaLocal    = 0x00000002
)

var (
	modUser32Fx                      = syscall.NewLazyDLL("user32.dll")
	procFindWindowW                  = modUser32Fx.NewProc("FindWindowW")
	procGetWindowLongPtrW            = modUser32Fx.NewProc("GetWindowLongPtrW")
	procSetWindowLongPtrW            = modUser32Fx.NewProc("SetWindowLongPtrW")
	procSetLayeredWindowAttributesFx = modUser32Fx.NewProc("SetLayeredWindowAttributes")
	modDwmapiFx                      = syscall.NewLazyDLL("dwmapi.dll")
	procDwmSetWindowAttributeFx      = modDwmapiFx.NewProc("DwmSetWindowAttribute")
)

const dwmwaSystemBackdropType = 38

func (a *App) enableWindowResidentMode() {
	for i := 0; i < 120; i++ {
		hwnd := findMainWindowHwnd()
		if hwnd != 0 {
			_ = ensureWindowInteractive(hwnd)
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
}

// ensureWindowInteractive — 透明 WebView 悬浮窗：仅取消穿透，保留透明底
func ensureWindowInteractive(hwnd uintptr) error {
	if hwnd == 0 {
		return errors.New("window not found")
	}
	gwlExstyle := uintptr(^uintptr(19)) // -20
	ex, _, _ := procGetWindowLongPtrW.Call(hwnd, gwlExstyle)
	exStyle := uintptr(ex) &^ wsExTransparent
	procSetWindowLongPtrW.Call(hwnd, gwlExstyle, exStyle)
	backdropNone := uint32(3)
	procDwmSetWindowAttributeFx.Call(hwnd, dwmwaSystemBackdropType, uintptr(unsafe.Pointer(&backdropNone)), 4)
	return nil
}

func forceOpaqueWindow(hwnd uintptr) error {
	return ensureWindowInteractive(hwnd)
}

// SetInputImeReady — 聚焦时保证可点击、可输入（不恢复整窗不透明黑底）
func (a *App) SetInputImeReady() ProcessResult {
	hwnd := findMainWindowHwnd()
	if hwnd == 0 {
		return ProcessResult{OK: false, Message: "window not found"}
	}
	if err := ensureWindowInteractive(hwnd); err != nil {
		return ProcessResult{OK: false, Message: err.Error()}
	}
	return ProcessResult{OK: true, Message: "ok"}
}

func findMainWindowHwnd() uintptr {
	titles := []string{"NMER Wails Input", "nmer-wails-input", "NMER"}
	for _, t := range titles {
		p, _ := syscall.UTF16PtrFromString(t)
		h, _, _ := procFindWindowW.Call(0, uintptr(unsafe.Pointer(p)))
		if h != 0 {
			return h
		}
	}
	return 0
}

func setWindowAlphaTransparent(hwnd uintptr, alpha byte, clickThrough bool) error {
	if hwnd == 0 {
		return errors.New("window not found")
	}
	gwlExstyle := uintptr(^uintptr(19)) // -20
	ex, _, _ := procGetWindowLongPtrW.Call(hwnd, gwlExstyle)
	exStyle := uintptr(ex)
	exStyle |= wsExLayeredLocal
	if clickThrough {
		exStyle |= wsExTransparent
	} else {
		exStyle &^= wsExTransparent
	}
	procSetWindowLongPtrW.Call(hwnd, gwlExstyle, exStyle)
	r, _, _ := procSetLayeredWindowAttributesFx.Call(hwnd, 0, uintptr(alpha), lwaAlphaLocal)
	if r == 0 {
		return errors.New("SetLayeredWindowAttributes failed")
	}
	return nil
}

func fadeInWailsWindow(durationMs int) error {
	hwnd := findMainWindowHwnd()
	if hwnd == 0 {
		return errors.New("window not found")
	}
	steps := 16
	if durationMs < 60 {
		durationMs = 60
	}
	interval := time.Duration(durationMs/steps) * time.Millisecond
	clickThrough := true
	for i := 0; i <= steps; i++ {
		alpha := byte((255 * i) / steps)
		if i == steps {
			clickThrough = false
		}
		if err := setWindowAlphaTransparent(hwnd, alpha, clickThrough); err != nil {
			return err
		}
		time.Sleep(interval)
	}
	return ensureWindowInteractive(hwnd)
}

func captureAreaBase64(x, y, w, h int) SnapshotResult {
	if w <= 0 || h <= 0 {
		w, h = 220, 220
	}
	img, err := screenshot.Capture(x, y, w, h)
	if err != nil {
		return SnapshotResult{OK: false, Error: err.Error()}
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return SnapshotResult{OK: false, Error: err.Error()}
	}
	enc := base64.StdEncoding.EncodeToString(buf.Bytes())
	if strings.TrimSpace(enc) == "" {
		return SnapshotResult{OK: false, Error: "empty snapshot"}
	}
	return SnapshotResult{OK: true, Base64: "data:image/png;base64," + enc, Width: w, Height: h}
}
