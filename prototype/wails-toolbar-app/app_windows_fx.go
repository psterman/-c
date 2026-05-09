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
)

func (a *App) enableWindowResidentMode() {
	for i := 0; i < 80; i++ {
		hwnd := findMainWindowHwnd()
		if hwnd != 0 {
			_ = setWindowAlphaTransparent(hwnd, 0, true)
			return
		}
		time.Sleep(50 * time.Millisecond)
	}
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
	for i := 0; i <= steps; i++ {
		alpha := byte((255 * i) / steps)
		if err := setWindowAlphaTransparent(hwnd, alpha, true); err != nil {
			return err
		}
		time.Sleep(interval)
	}
	return nil
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
