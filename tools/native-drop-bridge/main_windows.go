//go:build windows

package main

import (
	"bufio"
	"encoding/json"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync/atomic"
	"syscall"
	"time"
	"unsafe"

	"github.com/go-ole/go-ole"
)

const (
	wsExLayered              = 0x00080000
	wsExToolWindow           = 0x00000080
	wsExTopmost              = 0x00000008
	wsExNoActivate           = 0x08000000
	wsPopup                  = 0x80000000
	cfUnicodeText            = 13
	cfHDrop                  = 15
	dvaspectContent          = 1
	tymedHGlobal             = 1
	dropEffectCopy           = 1
	sOk                      = 0
	eNoInterface             = 0x80004002
	lwaAlpha                 = 0x2
	swShowNoActivate         = 4
	wineventOutOfContext     = 0x0000
	eventSystemDragDropStart = 0x000E
	eventSystemDragDropEnd   = 0x000F
	wmCopyData               = 0x004A
	dpiAwarenessContextPMv2  = ^uintptr(3) + 1 // (DPI_AWARENESS_CONTEXT)-4
	maxPathUTF16             = 260
	smCxScreen               = 0
	smCyScreen               = 1
	smXVirtualScreen         = 76
	smYVirtualScreen         = 77
	smCxVirtualScreen        = 78
	smCyVirtualScreen        = 79
)

type dropEvent struct {
	At           string   `json:"at"`
	Kind         string   `json:"kind"`
	PayloadKind  string   `json:"payloadKind,omitempty"`
	SourceFormat string   `json:"sourceFormat,omitempty"`
	Text         string   `json:"text,omitempty"`
	Link         string   `json:"link,omitempty"`
	Files        []string `json:"files,omitempty"`
	Folders      []string `json:"folders,omitempty"`
	Count        int      `json:"count,omitempty"`
	X            int32    `json:"x"`
	Y            int32    `json:"y"`
	W            int32    `json:"w,omitempty"`
	H            int32    `json:"h,omitempty"`
}

type pointl struct{ X, Y int32 }
type point struct{ X, Y int32 }

type msg struct {
	Hwnd     uintptr
	Message  uint32
	WParam   uintptr
	LParam   uintptr
	Time     uint32
	Pt       point
	LPrivate uint32
}

type formatEtc struct {
	CfFormat uint16
	Ptd      uintptr
	DwAspect uint32
	Lindex   int32
	Tymed    uint32
}

type stgMedium struct {
	Tymed          uint32
	_              uint32
	Handle         uintptr
	PUnkForRelease uintptr
}

type copyDataStruct struct {
	DwData uintptr
	CbData uint32
	LpData uintptr
}

type iDataObject struct{ LpVtbl *iDataObjectVtbl }
type iDataObjectVtbl struct {
	QueryInterface uintptr
	AddRef         uintptr
	Release        uintptr
	GetData        uintptr
}

type iDropTargetVtbl struct {
	QueryInterface uintptr
	AddRef         uintptr
	Release        uintptr
	DragEnter      uintptr
	DragOver       uintptr
	DragLeave      uintptr
	Drop           uintptr
}

type dropTarget struct {
	lpVtbl  *iDropTargetVtbl
	refs    int32
	onDrop  func(dropEvent)
	onEnter func(dropEvent)
}

type wndClassEx struct {
	CbSize        uint32
	Style         uint32
	LpfnWndProc   uintptr
	CbClsExtra    int32
	CbWndExtra    int32
	HInstance     uintptr
	HIcon         uintptr
	HCursor       uintptr
	HbrBackground uintptr
	LpszMenuName  uintptr
	LpszClassName uintptr
	HIconSm       uintptr
}

type fileDescriptorW struct {
	DwFlags          uint32
	ClsID            [16]byte
	SizelCx          int32
	SizelCy          int32
	PointlX          int32
	PointlY          int32
	DwFileAttributes uint32
	FtCreationTime   uint64
	FtLastAccessTime uint64
	FtLastWriteTime  uint64
	NFileSizeHigh    uint32
	NFileSizeLow     uint32
	CFileName        [maxPathUTF16]uint16
}

var (
	modUser32  = syscall.NewLazyDLL("user32.dll")
	modOle32   = syscall.NewLazyDLL("ole32.dll")
	modShell32 = syscall.NewLazyDLL("shell32.dll")
	modKernel  = syscall.NewLazyDLL("kernel32.dll")

	procRegisterClassExW           = modUser32.NewProc("RegisterClassExW")
	procCreateWindowExW            = modUser32.NewProc("CreateWindowExW")
	procDefWindowProcW             = modUser32.NewProc("DefWindowProcW")
	procDestroyWindow              = modUser32.NewProc("DestroyWindow")
	procGetMessageW                = modUser32.NewProc("GetMessageW")
	procGetCursorPos               = modUser32.NewProc("GetCursorPos")
	procTranslateMessage           = modUser32.NewProc("TranslateMessage")
	procDispatchMessageW           = modUser32.NewProc("DispatchMessageW")
	procShowWindow                 = modUser32.NewProc("ShowWindow")
	procSetLayeredWindowAttributes = modUser32.NewProc("SetLayeredWindowAttributes")
	procSetWindowPos               = modUser32.NewProc("SetWindowPos")
	procGetAsyncKeyState           = modUser32.NewProc("GetAsyncKeyState")
	procSetWinEventHook            = modUser32.NewProc("SetWinEventHook")
	procUnhookWinEvent             = modUser32.NewProc("UnhookWinEvent")
	procRegisterClipboardFormatW   = modUser32.NewProc("RegisterClipboardFormatW")
	procFindWindowW                = modUser32.NewProc("FindWindowW")
	procSendMessageW               = modUser32.NewProc("SendMessageW")
	procSetProcessDpiAwarenessCtx  = modUser32.NewProc("SetProcessDpiAwarenessContext")
	procSetProcessDPIAware         = modUser32.NewProc("SetProcessDPIAware")
	procGetSystemMetrics           = modUser32.NewProc("GetSystemMetrics")

	procRegisterDragDrop = modOle32.NewProc("RegisterDragDrop")
	procRevokeDragDrop   = modOle32.NewProc("RevokeDragDrop")
	procReleaseStgMedium = modOle32.NewProc("ReleaseStgMedium")
	procOleInitialize    = modOle32.NewProc("OleInitialize")
	procOleUninitialize  = modOle32.NewProc("OleUninitialize")

	procDragQueryFileW = modShell32.NewProc("DragQueryFileW")
	procGlobalLock     = modKernel.NewProc("GlobalLock")
	procGlobalUnlock   = modKernel.NewProc("GlobalUnlock")

	callbackDropQueryInterface = syscall.NewCallback(dropQueryInterface)
	callbackDropAddRef         = syscall.NewCallback(dropAddRef)
	callbackDropRelease        = syscall.NewCallback(dropRelease)
	callbackDropDragEnter      = syscall.NewCallback(dropDragEnter)
	callbackDropDragOver       = syscall.NewCallback(dropDragOver)
	callbackDropDragLeave      = syscall.NewCallback(dropDragLeave)
	callbackDropDrop           = syscall.NewCallback(dropDrop)
	callbackWinEvent           = syscall.NewCallback(winEventProc)

	dropTargetVTable = iDropTargetVtbl{
		QueryInterface: callbackDropQueryInterface,
		AddRef:         callbackDropAddRef,
		Release:        callbackDropRelease,
		DragEnter:      callbackDropDragEnter,
		DragOver:       callbackDropDragOver,
		DragLeave:      callbackDropDragLeave,
		Drop:           callbackDropDrop,
	}
	iidIUnknown            = ole.IID_IUnknown
	iidIDropTarget         = ole.NewGUID("00000122-0000-0000-C000-000000000046")
	activeWriter           *bufio.Writer
	activeWriterF          *os.File
	ahkReceiver            uintptr
	enableCopyData         bool
	cfFileGroupDescriptorW uint16
	cfHTML                 uint16
	cfURILIST              uint16

	gateFollow bool
	wsListen   string
)

func main() {
	out := flag.String("out", "..\\..\\Cache\\native_drop_events.jsonl", "output jsonl path")
	x := flag.Int("x", 300, "drop window x")
	y := flag.Int("y", 300, "drop window y")
	w := flag.Int("w", 170, "drop window width")
	h := flag.Int("h", 210, "drop window height")
	ahkClass := flag.String("ahk-class", "AutoHotkey", "AHK target window class for WM_COPYDATA")
	ahkTitle := flag.String("ahk-title", "", "AHK target window title for WM_COPYDATA")
	sendCopyData := flag.Bool("copydata", false, "send JSON events via WM_COPYDATA to AHK hidden window")
	monitor := flag.String("monitor", "custom", "receiver area: custom|primary|all|rect")
	rect := flag.String("rect", "", "rect as x,y,w,h (used when --monitor rect)")
	wsAddr := flag.String("ws", "127.0.0.1:18790", "WebSocket listen address")
	gateFollowFlag := flag.Bool("gate-follow", true, "gate bridge window: only follow cursor during OLE drag")
	flag.Parse()
	gateFollow = *gateFollowFlag
	wsListen = *wsAddr
	rx, ry, _, _ := resolveReceiverRect(*monitor, *rect, *x, *y, *w, *h)
	if *gateFollowFlag {
		rx, ry = parkX, parkY
	}
	if err := run(*out, rx, ry, bridgeSize, bridgeSize, *ahkClass, *ahkTitle, *sendCopyData); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func resolveReceiverRect(mode string, rectArg string, x, y, w, h int) (int, int, int, int) {
	switch strings.ToLower(strings.TrimSpace(mode)) {
	case "all":
		return getMetric(smXVirtualScreen), getMetric(smYVirtualScreen), getMetric(smCxVirtualScreen), getMetric(smCyVirtualScreen)
	case "primary":
		return 0, 0, getMetric(smCxScreen), getMetric(smCyScreen)
	case "rect":
		if rx, ry, rw, rh, ok := parseRect(rectArg); ok {
			return rx, ry, rw, rh
		}
	}
	return x, y, w, h
}

func parseRect(s string) (int, int, int, int, bool) {
	parts := strings.Split(strings.TrimSpace(s), ",")
	if len(parts) != 4 {
		return 0, 0, 0, 0, false
	}
	vals := make([]int, 4)
	for i := 0; i < 4; i++ {
		n, err := strconv.Atoi(strings.TrimSpace(parts[i]))
		if err != nil {
			return 0, 0, 0, 0, false
		}
		vals[i] = n
	}
	if vals[2] <= 0 || vals[3] <= 0 {
		return 0, 0, 0, 0, false
	}
	return vals[0], vals[1], vals[2], vals[3], true
}

func getMetric(i int) int {
	r, _, _ := procGetSystemMetrics.Call(uintptr(i))
	return int(int32(r))
}

func run(outPath string, x int, y int, w int, h int, ahkClass string, ahkTitle string, sendCopyData bool) error {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	setDPIAwareness()
	registerFormats()
	resolveAHKReceiver(ahkClass, ahkTitle, sendCopyData)

	hr, _, _ := procOleInitialize.Call(0)
	if int32(hr) < 0 {
		return fmt.Errorf("OleInitialize failed: 0x%08X", uint32(hr))
	}
	defer procOleUninitialize.Call()

	f, err := os.OpenFile(outPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil {
		return err
	}
	defer f.Close()
	bw := bufio.NewWriter(f)
	defer bw.Flush()
	activeWriter = bw
	activeWriterF = f
	defer func() {
		activeWriter = nil
		activeWriterF = nil
	}()

	globalHub.start(wsListen)
	initInteractionManager(readLauncherModeFromINI())

	hwnd, err := createHostWindow(x, y, w, h)
	if err != nil {
		return err
	}
	globalGate.setHWND(hwnd)
	subclassBridgeWindow(hwnd)
	if gateFollow {
		hideBridge(hwnd)
	}
	defer procDestroyWindow.Call(hwnd)
	dragHook := installDragDropWinEventHook()
	if dragHook != 0 {
		defer procUnhookWinEvent.Call(dragHook)
	}
	stopMouseFallback := startMouseDragFallback()
	defer stopMouseFallback()

	target := &dropTarget{lpVtbl: &dropTargetVTable, refs: 1, onDrop: writeDropEvent, onEnter: writeDropEvent}

	ready := dropEvent{
		At:   time.Now().Format(time.RFC3339),
		Kind: "bridge_ready",
		X:    int32(x),
		Y:    int32(y),
		W:    int32(w),
		H:    int32(h),
	}
	writeDropEvent(ready)
	hubEmit("bridge_ready", map[string]any{"ws": wsListen, "gateFollow": gateFollow})

	hr, _, _ = procRegisterDragDrop.Call(hwnd, uintptr(unsafe.Pointer(target)))
	if int32(hr) < 0 {
		return fmt.Errorf("RegisterDragDrop failed: 0x%08X", uint32(hr))
	}
	defer procRevokeDragDrop.Call(hwnd)

	var m msg
	for {
		r1, _, _ := procGetMessageW.Call(uintptr(unsafe.Pointer(&m)), 0, 0, 0)
		if int32(r1) <= 0 {
			break
		}
		procTranslateMessage.Call(uintptr(unsafe.Pointer(&m)))
		procDispatchMessageW.Call(uintptr(unsafe.Pointer(&m)))
	}
	return nil
}

func setDPIAwareness() {
	r, _, _ := procSetProcessDpiAwarenessCtx.Call(dpiAwarenessContextPMv2)
	if r == 0 {
		procSetProcessDPIAware.Call()
	}
}

func registerFormats() {
	for _, n := range []string{"FileGroupDescriptorW", "text/html", "text/uri-list", "UniformResourceLocator"} {
		name, _ := syscall.UTF16PtrFromString(n)
		r, _, _ := procRegisterClipboardFormatW.Call(uintptr(unsafe.Pointer(name)))
		switch n {
		case "FileGroupDescriptorW":
			cfFileGroupDescriptorW = uint16(r)
		case "text/html":
			cfHTML = uint16(r)
		case "text/uri-list":
			cfURILIST = uint16(r)
		}
	}
}

func resolveAHKReceiver(className, title string, enabled bool) {
	enableCopyData = false
	ahkReceiver = 0
	if !enabled {
		return
	}
	var classPtr, titlePtr *uint16
	if strings.TrimSpace(className) != "" {
		classPtr, _ = syscall.UTF16PtrFromString(className)
	}
	if strings.TrimSpace(title) != "" {
		titlePtr, _ = syscall.UTF16PtrFromString(title)
	}
	h, _, _ := procFindWindowW.Call(uintptr(unsafe.Pointer(classPtr)), uintptr(unsafe.Pointer(titlePtr)))
	if h != 0 {
		ahkReceiver = h
		enableCopyData = true
	}
}

func writeDropEvent(ev dropEvent) {
	if ev.Count == 0 {
		ev.Count = len(ev.Files) + len(ev.Folders)
	}
	if activeWriter != nil {
		if b, err := json.Marshal(ev); err == nil {
			_, _ = activeWriter.Write(append(b, '\n'))
			_ = activeWriter.Flush()
		}
	}
	if enableCopyData && ahkReceiver != 0 {
		sendCopyDataJSON(ev)
	}
}

func sendCopyDataJSON(ev dropEvent) {
	b, err := json.Marshal(ev)
	if err != nil {
		return
	}
	payload := append(b, 0)
	cds := copyDataStruct{
		DwData: 1,
		CbData: uint32(len(payload)),
		LpData: uintptr(unsafe.Pointer(&payload[0])),
	}
	procSendMessageW.Call(ahkReceiver, wmCopyData, 0, uintptr(unsafe.Pointer(&cds)))
}

func installDragDropWinEventHook() uintptr {
	h, _, _ := procSetWinEventHook.Call(
		eventSystemDragDropStart,
		eventSystemDragDropEnd,
		0,
		callbackWinEvent,
		0,
		0,
		wineventOutOfContext,
	)
	return h
}

func winEventProc(hWinEventHook, event, hwnd, idObject, idChild, idEventThread, dwmsEventTime uintptr) uintptr {
	defer recoverCallback("winEventProc")
	kind := ""
	switch uint32(event) {
	case eventSystemDragDropStart:
		kind = "drag_start"
		globalGate.Arm("win_event")
	case eventSystemDragDropEnd:
		kind = "drag_end"
		globalGate.Park()
		hubEmit("dragleave", map[string]any{"reason": "win_event_end"})
	default:
		return 0
	}
	writeDropEvent(dropEvent{
		At:          time.Now().Format(time.RFC3339),
		Kind:        kind,
		PayloadKind: "none",
	})
	if kind == "drag_start" {
		hubEmit("dragenter", map[string]any{"source": "win_event", "payloadKind": "none"})
	}
	return 0
}

func recoverCallback(tag string) {
	if r := recover(); r != nil {
		fmt.Fprintf(os.Stderr, "callback panic (%s): %v\n", tag, r)
	}
}

func startMouseDragFallback() func() {
	stop := make(chan struct{})
	go func() {
		const vkLButton = 0x01
		const threshold = 12
		active := false
		seeded := false
		var sx, sy int32
		ticker := time.NewTicker(35 * time.Millisecond)
		defer ticker.Stop()
		for {
			select {
			case <-ticker.C:
				down := isLButtonDown(vkLButton)
				x, y, ok := getCursorPos()
				if !ok {
					continue
				}
				if !down {
					seeded = false
					if active {
						active = false
						globalGate.Park()
						hubEmit("dragleave", map[string]any{"reason": "mouse_release", "x": x, "y": y})
						writeDropEvent(dropEvent{At: time.Now().Format(time.RFC3339), Kind: "drag_end", PayloadKind: "none", X: x, Y: y})
					}
					continue
				}
				if !seeded {
					seeded = true
					sx, sy = x, y
					continue
				}
				dx := int(x - sx)
				dy := int(y - sy)
				if !active && (dx*dx+dy*dy >= threshold*threshold) {
					active = true
					globalGate.Arm("mouse_threshold")
					writeDropEvent(dropEvent{At: time.Now().Format(time.RFC3339), Kind: "drag_start", PayloadKind: "none", X: x, Y: y})
					hubEmit("dragenter", map[string]any{"source": "mouse_fallback", "payloadKind": "none", "x": x, "y": y})
				}
			case <-stop:
				return
			}
		}
	}()
	return func() { close(stop) }
}

func isLButtonDown(vk int) bool {
	r, _, _ := procGetAsyncKeyState.Call(uintptr(vk))
	return (uint16(r) & 0x8000) != 0
}

func getCursorPos() (int32, int32, bool) {
	var p point
	r, _, _ := procGetCursorPos.Call(uintptr(unsafe.Pointer(&p)))
	if r == 0 {
		return 0, 0, false
	}
	return p.X, p.Y, true
}

func createHostWindow(x int, y int, w int, h int) (uintptr, error) {
	cn, _ := syscall.UTF16PtrFromString("NMER_NativeDropBridge")
	wn, _ := syscall.UTF16PtrFromString("NMER_NativeDropBridgeWnd")
	wc := wndClassEx{CbSize: uint32(unsafe.Sizeof(wndClassEx{})), LpfnWndProc: callbackBridgeWndProc, LpszClassName: uintptr(unsafe.Pointer(cn))}
	procRegisterClassExW.Call(uintptr(unsafe.Pointer(&wc)))
	if w <= 0 {
		w = bridgeSize
	}
	if h <= 0 {
		h = bridgeSize
	}
	hwnd, _, e := procCreateWindowExW.Call(
		wsExLayered|wsExToolWindow|wsExTopmost|wsExNoActivate,
		uintptr(unsafe.Pointer(cn)),
		uintptr(unsafe.Pointer(wn)),
		wsPopup,
		uintptr(x),
		uintptr(y),
		uintptr(w),
		uintptr(h),
		0, 0, 0, 0,
	)
	if hwnd == 0 {
		return 0, e
	}
	procSetLayeredWindowAttributes.Call(hwnd, 0, 1, lwaAlpha)
	procShowWindow.Call(hwnd, swShowNoActivate)
	return hwnd, nil
}

func (d *dropTarget) drop(dataObj *iDataObject, pt pointl, effect *uint32) uintptr {
	if effect != nil {
		*effect = dropEffectCopy
	}
	ev := buildDropEvent("drop", dataObj, pt)
	if ev.PayloadKind != "none" {
		reqID := globalPipeline.beginDrop(ev)
		if reqID != 0 {
			hubEmit("drop", map[string]any{
				"requestId":   reqID,
				"session":     globalGate.Session(),
				"payloadKind": ev.PayloadKind,
				"x":           ev.X,
				"y":           ev.Y,
				"text":        ev.Text,
				"files":       ev.Files,
			})
		}
		if d.onDrop != nil {
			d.onDrop(ev)
		}
	}
	globalGate.Park()
	if d.onDrop != nil {
		d.onDrop(dropEvent{At: time.Now().Format(time.RFC3339), Kind: "DRAG_END_PHYSICAL", PayloadKind: "none", X: pt.X, Y: pt.Y})
	}
	return sOk
}

func (d *dropTarget) dragEnterLog(dataObj *iDataObject, pt pointl, effect *uint32) uintptr {
	if effect != nil {
		*effect = dropEffectCopy
	}
	ev := buildDropEvent("drag_enter", dataObj, pt)
	globalGate.OnDragEnter(pt.X, pt.Y)
	hubEmit("dragenter", map[string]any{
		"payloadKind": ev.PayloadKind,
		"x":           pt.X,
		"y":           pt.Y,
		"session":     globalGate.Session(),
	})
	if d.onEnter != nil {
		d.onEnter(ev)
	}
	return sOk
}

func buildDropEvent(kind string, dataObj *iDataObject, pt pointl) dropEvent {
	ev := dropEvent{At: time.Now().Format(time.RFC3339), Kind: kind, PayloadKind: "none", X: pt.X, Y: pt.Y}
	if files, folders, ok := readHDropPaths(dataObj); ok {
		ev.Files = files
		ev.Folders = folders
		ev.SourceFormat = "CF_HDROP"
		ev.PayloadKind = classifyPayload(files, folders)
		ev.Count = len(files) + len(folders)
		return ev
	}
	if files, ok := readFileGroupDescriptorW(dataObj); ok {
		ev.Files = files
		ev.SourceFormat = "FileGroupDescriptorW"
		ev.PayloadKind = "file"
		ev.Count = len(files)
		return ev
	}
	if t, ok := readUnicodeText(dataObj); ok && strings.TrimSpace(t) != "" {
		t = strings.TrimSpace(t)
		ev.Text = t
		ev.SourceFormat = "CF_UNICODETEXT"
		if looksLikeURL(t) {
			ev.PayloadKind = "link"
			ev.Link = t
		} else {
			ev.PayloadKind = "text"
		}
		return ev
	}
	if cfHTML != 0 {
		if t, ok := readFormatText(dataObj, cfHTML); ok && strings.TrimSpace(t) != "" {
			ev.Text = stripHTMLBasic(strings.TrimSpace(t))
			ev.SourceFormat = "text/html"
			ev.PayloadKind = "text"
			return ev
		}
	}
	if cfURILIST != 0 {
		if t, ok := readFormatText(dataObj, cfURILIST); ok {
			lines := strings.Split(strings.TrimSpace(t), "\n")
			for _, ln := range lines {
				ln = strings.TrimSpace(ln)
				if ln != "" && !strings.HasPrefix(ln, "#") {
					ev.Link = ln
					ev.Text = ln
					ev.SourceFormat = "text/uri-list"
					ev.PayloadKind = "link"
					return ev
				}
			}
		}
	}
	return ev
}

func readFormatText(dataObj *iDataObject, cf uint16) (string, bool) {
	fe := formatEtc{CfFormat: cf, DwAspect: dvaspectContent, Lindex: -1, Tymed: tymedHGlobal}
	var med stgMedium
	if int32(getData(dataObj, &fe, &med)) < 0 || med.Handle == 0 {
		return "", false
	}
	defer procReleaseStgMedium.Call(uintptr(unsafe.Pointer(&med)))
	ptr, _, _ := procGlobalLock.Call(med.Handle)
	if ptr == 0 {
		return "", false
	}
	defer procGlobalUnlock.Call(med.Handle)
	return utf16PtrToString((*uint16)(unsafe.Pointer(ptr))), true
}

func stripHTMLBasic(s string) string {
	s = strings.ReplaceAll(s, "<br>", "\n")
	s = strings.ReplaceAll(s, "<br/>", "\n")
	s = strings.ReplaceAll(s, "<br />", "\n")
	var out strings.Builder
	inTag := false
	for _, r := range s {
		switch {
		case r == '<':
			inTag = true
		case r == '>':
			inTag = false
		case !inTag:
			out.WriteRune(r)
		}
	}
	return strings.TrimSpace(out.String())
}

func classifyPayload(files []string, folders []string) string {
	switch {
	case len(files) > 0 && len(folders) > 0:
		return "mixed"
	case len(folders) > 0:
		return "folder"
	case len(files) > 0:
		return "file"
	default:
		return "none"
	}
}

func readHDropPaths(dataObj *iDataObject) ([]string, []string, bool) {
	fe := formatEtc{CfFormat: cfHDrop, DwAspect: dvaspectContent, Lindex: -1, Tymed: tymedHGlobal}
	var med stgMedium
	if int32(getData(dataObj, &fe, &med)) < 0 || med.Handle == 0 {
		return nil, nil, false
	}
	defer procReleaseStgMedium.Call(uintptr(unsafe.Pointer(&med)))
	cnt, _, _ := procDragQueryFileW.Call(med.Handle, 0xFFFFFFFF, 0, 0)
	if cnt == 0 {
		return nil, nil, false
	}
	files := make([]string, 0, cnt)
	folders := make([]string, 0, cnt)
	for i := uint32(0); i < uint32(cnt); i++ {
		ln, _, _ := procDragQueryFileW.Call(med.Handle, uintptr(i), 0, 0)
		buf := make([]uint16, ln+1)
		procDragQueryFileW.Call(med.Handle, uintptr(i), uintptr(unsafe.Pointer(&buf[0])), uintptr(len(buf)))
		s := syscall.UTF16ToString(buf)
		s = strings.TrimSpace(s)
		if s == "" {
			continue
		}
		if isDirectoryPath(s) {
			folders = append(folders, s)
		} else {
			files = append(files, s)
		}
	}
	return files, folders, (len(files)+len(folders) > 0)
}

func readFileGroupDescriptorW(dataObj *iDataObject) ([]string, bool) {
	if cfFileGroupDescriptorW == 0 {
		return nil, false
	}
	fe := formatEtc{CfFormat: cfFileGroupDescriptorW, DwAspect: dvaspectContent, Lindex: -1, Tymed: tymedHGlobal}
	var med stgMedium
	if int32(getData(dataObj, &fe, &med)) < 0 || med.Handle == 0 {
		return nil, false
	}
	defer procReleaseStgMedium.Call(uintptr(unsafe.Pointer(&med)))
	ptr, _, _ := procGlobalLock.Call(med.Handle)
	if ptr == 0 {
		return nil, false
	}
	defer procGlobalUnlock.Call(med.Handle)

	count := *(*uint32)(unsafe.Pointer(ptr))
	if count == 0 || count > 4096 {
		return nil, false
	}
	off := uintptr(4)
	sz := unsafe.Sizeof(fileDescriptorW{})
	files := make([]string, 0, count)
	for i := uint32(0); i < count; i++ {
		fd := (*fileDescriptorW)(unsafe.Pointer(ptr + off + uintptr(i)*sz))
		name := strings.TrimSpace(syscall.UTF16ToString(fd.CFileName[:]))
		if name != "" {
			files = append(files, name)
		}
	}
	return files, len(files) > 0
}

func readUnicodeText(dataObj *iDataObject) (string, bool) {
	fe := formatEtc{CfFormat: cfUnicodeText, DwAspect: dvaspectContent, Lindex: -1, Tymed: tymedHGlobal}
	var med stgMedium
	if int32(getData(dataObj, &fe, &med)) < 0 || med.Handle == 0 {
		return "", false
	}
	defer procReleaseStgMedium.Call(uintptr(unsafe.Pointer(&med)))
	ptr, _, _ := procGlobalLock.Call(med.Handle)
	if ptr == 0 {
		return "", false
	}
	defer procGlobalUnlock.Call(med.Handle)
	return utf16PtrToString((*uint16)(unsafe.Pointer(ptr))), true
}

func getData(dataObj *iDataObject, fe *formatEtc, med *stgMedium) uintptr {
	hr, _, _ := syscall.SyscallN(dataObj.LpVtbl.GetData, uintptr(unsafe.Pointer(dataObj)), uintptr(unsafe.Pointer(fe)), uintptr(unsafe.Pointer(med)))
	return hr
}

func utf16PtrToString(ptr *uint16) string {
	if ptr == nil {
		return ""
	}
	buf := make([]uint16, 0, 256)
	for p := uintptr(unsafe.Pointer(ptr)); ; p += 2 {
		v := *(*uint16)(unsafe.Pointer(p))
		if v == 0 {
			break
		}
		buf = append(buf, v)
	}
	return syscall.UTF16ToString(buf)
}

func looksLikeURL(s string) bool {
	u := strings.ToLower(strings.TrimSpace(s))
	return strings.HasPrefix(u, "http://") || strings.HasPrefix(u, "https://") || strings.HasPrefix(u, "ftp://") || strings.HasPrefix(u, "file://")
}

func isDirectoryPath(p string) bool {
	fi, err := os.Stat(filepath.Clean(p))
	if err != nil {
		return strings.HasSuffix(p, `\\`) || strings.HasSuffix(p, `/`)
	}
	return fi.IsDir()
}

func dropQueryInterface(self, riid, ppv uintptr) uintptr {
	defer recoverCallback("dropQueryInterface")
	if ppv == 0 {
		return eNoInterface
	}
	*(*uintptr)(unsafe.Pointer(ppv)) = 0
	g := (*ole.GUID)(unsafe.Pointer(riid))
	if equalGUID(g, iidIUnknown) || equalGUID(g, iidIDropTarget) {
		*(*uintptr)(unsafe.Pointer(ppv)) = self
		dropAddRef(self)
		return sOk
	}
	return eNoInterface
}

func dropAddRef(self uintptr) uintptr {
	defer recoverCallback("dropAddRef")
	return uintptr(atomic.AddInt32(&(*dropTarget)(unsafe.Pointer(self)).refs, 1))
}

func dropRelease(self uintptr) uintptr {
	defer recoverCallback("dropRelease")
	return uintptr(atomic.AddInt32(&(*dropTarget)(unsafe.Pointer(self)).refs, -1))
}

func dropDragEnter(self, dataObj, keyState, pt, effect uintptr) uintptr {
	defer recoverCallback("dropDragEnter")
	obj := (*dropTarget)(unsafe.Pointer(self))
	var eff *uint32
	if effect != 0 {
		eff = (*uint32)(unsafe.Pointer(effect))
	}
	return obj.dragEnterLog((*iDataObject)(unsafe.Pointer(dataObj)), *(*pointl)(unsafe.Pointer(pt)), eff)
}

func dropDragOver(self, keyState, pt, effect uintptr) uintptr {
	defer recoverCallback("dropDragOver")
	if effect != 0 {
		*(*uint32)(unsafe.Pointer(effect)) = dropEffectCopy
	}
	if pt != 0 {
		p := *(*pointl)(unsafe.Pointer(pt))
		globalGate.FollowOLEPoint(p.X, p.Y)
	}
	return sOk
}

func dropDragLeave(self uintptr) uintptr {
	defer recoverCallback("dropDragLeave")
	globalGate.OnDragLeave()
	hubEmit("dragleave", map[string]any{"reason": "ole_drag_leave"})
	return sOk
}

func dropDrop(self, dataObj, keyState, pt, effect uintptr) uintptr {
	defer recoverCallback("dropDrop")
	obj := (*dropTarget)(unsafe.Pointer(self))
	var eff *uint32
	if effect != 0 {
		eff = (*uint32)(unsafe.Pointer(effect))
	}
	return obj.drop((*iDataObject)(unsafe.Pointer(dataObj)), *(*pointl)(unsafe.Pointer(pt)), eff)
}

func equalGUID(a, b *ole.GUID) bool {
	if a == nil || b == nil {
		return false
	}
	if a.Data1 != b.Data1 || a.Data2 != b.Data2 || a.Data3 != b.Data3 {
		return false
	}
	for i := 0; i < 8; i++ {
		if a.Data4[i] != b.Data4[i] {
			return false
		}
	}
	return true
}
