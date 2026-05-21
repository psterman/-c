//go:build windows

package main

import "sync"

const (
	bridgeSize   = 16
	parkX        = -32000
	parkY        = -32000
	swpNoActivate = 0x0010
	swpNoOwnerZOrder = 0x0200
)

type gateState int

const (
	gateParked gateState = iota
	gateDragArmed
	gateFollowing
)

type bridgeGate struct {
	mu      sync.Mutex
	state   gateState
	session uint64
	hwnd    uintptr
}

var globalGate bridgeGate

func (g *bridgeGate) setHWND(hwnd uintptr) {
	g.mu.Lock()
	g.hwnd = hwnd
	g.mu.Unlock()
}

func (g *bridgeGate) Session() uint64 {
	g.mu.Lock()
	defer g.mu.Unlock()
	return g.session
}

func (g *bridgeGate) Arm(reason string) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.state == gateFollowing {
		return
	}
	g.session++
	g.state = gateDragArmed
	_ = reason
}

func (g *bridgeGate) OnDragEnter(ptX, ptY int32) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.hwnd == 0 {
		return
	}
	g.state = gateFollowing
	showBridgeNoActivate(g.hwnd)
	moveBridgeCenter(g.hwnd, ptX, ptY)
}

func (g *bridgeGate) OnDragLeave() {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.state != gateFollowing {
		return
	}
	g.parkLocked()
}

func (g *bridgeGate) Park() {
	g.mu.Lock()
	defer g.mu.Unlock()
	g.parkLocked()
}

func (g *bridgeGate) parkLocked() {
	g.state = gateParked
	if g.hwnd != 0 {
		hideBridge(g.hwnd)
		moveBridgeCenter(g.hwnd, parkX, parkY)
	}
}

func (g *bridgeGate) IsFollowing() bool {
	g.mu.Lock()
	defer g.mu.Unlock()
	return g.state == gateFollowing
}

func (g *bridgeGate) FollowOLEPoint(x, y int32) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.state == gateFollowing && g.hwnd != 0 {
		moveBridgeCenter(g.hwnd, x, y)
	}
}

func (g *bridgeGate) MoveCursor(x, y int32, session uint64) {
	g.mu.Lock()
	defer g.mu.Unlock()
	if g.state != gateFollowing || g.hwnd == 0 {
		return
	}
	if session != 0 && session != g.session {
		return
	}
	moveBridgeCenter(g.hwnd, x, y)
}

func moveBridgeCenter(hwnd uintptr, x, y int32) {
	procSetWindowPos.Call(
		hwnd,
		uintptr(hwndTopmost),
		uintptr(int64(x)-8),
		uintptr(int64(y)-8),
		bridgeSize,
		bridgeSize,
		swpNoActivate|swpNoOwnerZOrder,
	)
}

func showBridgeNoActivate(hwnd uintptr) {
	procShowWindow.Call(hwnd, swShowNoActivate)
}

func hideBridge(hwnd uintptr) {
	const swHide = 0
	procShowWindow.Call(hwnd, swHide)
}
