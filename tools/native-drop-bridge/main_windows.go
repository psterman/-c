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
)

type dropEvent struct {
	At          string   `json:"at"`
	Kind        string   `json:"kind"`
	PayloadKind string   `json:"payloadKind,omitempty"` // text|link|file|folder|mixed|none
	Text        string   `json:"text,omitempty"`
	Link        string   `json:"link,omitempty"`
	Files       []string `json:"files,omitempty"`
	Folders     []string `json:"folders,omitempty"`
	X           int32    `json:"x"`
	Y           int32    `json:"y"`
	W           int32    `json:"w,omitempty"`
	H           int32    `json:"h,omitempty"`
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
	lpVtbl *iDropTargetVtbl
	refs   int32
	onDrop func(dropEvent)
	onEnter func(dropEvent)
}

var (
	modUser32  = syscall.NewLazyDLL("user32.dll")
	modOle32   = syscall.NewLazyDLL("ole32.dll")
	modShell32 = syscall.NewLazyDLL("shell32.dll")
	modKernel  = syscall.NewLazyDLL("kernel32.dll")

	procRegisterClassExW = modUser32.NewProc("RegisterClassExW")
	procCreateWindowExW  = modUser32.NewProc("CreateWindowExW")
	procDefWindowProcW   = modUser32.NewProc("DefWindowProcW")
	procDestroyWindow    = modUser32.NewProc("DestroyWindow")
	procGetMessageW      = modUser32.NewProc("GetMessageW")
	procGetCursorPos     = modUser32.NewProc("GetCursorPos")
	procTranslateMessage = modUser32.NewProc("TranslateMessage")
	procDispatchMessageW = modUser32.NewProc("DispatchMessageW")
	procShowWindow       = modUser32.NewProc("ShowWindow")
	procSetLayeredWindowAttributes = modUser32.NewProc("SetLayeredWindowAttributes")
	procGetAsyncKeyState = modUser32.NewProc("GetAsyncKeyState")
	procSetWinEventHook = modUser32.NewProc("SetWinEventHook")
	procUnhookWinEvent  = modUser32.NewProc("UnhookWinEvent")

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
	iidIUnknown    = ole.IID_IUnknown
	iidIDropTarget = ole.NewGUID("00000122-0000-0000-C000-000000000046")
	activeWriter   *bufio.Writer
	activeWriterF  *os.File
)

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

func main() {
	out := flag.String("out", "..\\..\\Cache\\native_drop_events.jsonl", "output jsonl path")
	x := flag.Int("x", 300, "drop window x")
	y := flag.Int("y", 300, "drop window y")
	w := flag.Int("w", 170, "drop window width")
	h := flag.Int("h", 210, "drop window height")
	flag.Parse()
	if err := run(*out, *x, *y, *w, *h); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func run(outPath string, x int, y int, w int, h int) error {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	hr, _, _ := procOleInitialize.Call(0)
	if int32(hr) < 0 {
		return fmt.Errorf("OleInitialize failed: 0x%08X", uint32(hr))
	}
	defer procOleUninitialize.Call()

	f, err := os.OpenFile(outPath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
	if err != nil { return err }
	defer f.Close()
	bw := bufio.NewWriter(f)
	defer bw.Flush()
	activeWriter = bw
	activeWriterF = f
	defer func() {
		activeWriter = nil
		activeWriterF = nil
	}()

	hwnd, err := createHostWindow(x, y, w, h)
	if err != nil { return err }
	defer procDestroyWindow.Call(hwnd)
	dragHook := installDragDropWinEventHook()
	if dragHook != 0 {
		defer procUnhookWinEvent.Call(dragHook)
	}
	stopMouseFallback := startMouseDragFallback()
	defer stopMouseFallback()

	target := &dropTarget{lpVtbl: &dropTargetVTable, refs: 1, onDrop: writeDropEvent, onEnter: writeDropEvent}

	ready, _ := json.Marshal(dropEvent{
		At:   time.Now().Format(time.RFC3339),
		Kind: "bridge_ready",
		X:    int32(x),
		Y:    int32(y),
		W:    int32(w),
		H:    int32(h),
	})
	_, _ = bw.Write(append(ready, '\n'))
	_ = bw.Flush()

	hr, _, _ = procRegisterDragDrop.Call(hwnd, uintptr(unsafe.Pointer(target)))
	if int32(hr) < 0 { return fmt.Errorf("RegisterDragDrop failed: 0x%08X", uint32(hr)) }
	defer procRevokeDragDrop.Call(hwnd)

	var m msg
	for {
		r1, _, _ := procGetMessageW.Call(uintptr(unsafe.Pointer(&m)), 0, 0, 0)
		if int32(r1) <= 0 { break }
		procTranslateMessage.Call(uintptr(unsafe.Pointer(&m)))
		procDispatchMessageW.Call(uintptr(unsafe.Pointer(&m)))
	}
	return nil
}

func writeDropEvent(ev dropEvent) {
	if activeWriter == nil {
		return
	}
	b, _ := json.Marshal(ev)
	_, _ = activeWriter.Write(append(b, '\n'))
	_ = activeWriter.Flush()
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
	kind := ""
	switch uint32(event) {
	case eventSystemDragDropStart:
		kind = "drag_start"
	case eventSystemDragDropEnd:
		kind = "drag_end"
	default:
		return 0
	}
	writeDropEvent(dropEvent{
		At:          time.Now().Format(time.RFC3339),
		Kind:        kind,
		PayloadKind: "none",
	})
	return 0
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
					writeDropEvent(dropEvent{At: time.Now().Format(time.RFC3339), Kind: "drag_start", PayloadKind: "none", X: x, Y: y})
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
	cn, _ := syscall.UTF16PtrFromString("NMERNativeDropBridge")
	wn, _ := syscall.UTF16PtrFromString("NMERNativeDropBridgeWnd")
	wc := wndClassEx{CbSize: uint32(unsafe.Sizeof(wndClassEx{})), LpfnWndProc: procDefWindowProcW.Addr(), LpszClassName: uintptr(unsafe.Pointer(cn))}
	procRegisterClassExW.Call(uintptr(unsafe.Pointer(&wc)))
	if w < 40 {
		w = 40
	}
	if h < 40 {
		h = 40
	}
	hwnd, _, e := procCreateWindowExW.Call(
		wsExLayered|wsExToolWindow|wsExTopmost,
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
	if effect != nil { *effect = dropEffectCopy }
	ev := dropEvent{At: time.Now().Format(time.RFC3339), Kind: "drop", PayloadKind: "none", X: pt.X, Y: pt.Y}
	if files, folders, ok := readHDropPaths(dataObj); ok && (len(files) > 0 || len(folders) > 0) {
		ev.Files = files
		ev.Folders = folders
		switch {
		case len(files) > 0 && len(folders) > 0:
			ev.PayloadKind = "mixed"
		case len(folders) > 0:
			ev.PayloadKind = "folder"
		default:
			ev.PayloadKind = "file"
		}
	} else if t, ok := readUnicodeText(dataObj); ok && strings.TrimSpace(t) != "" {
		t = strings.TrimSpace(t)
		ev.Text = t
		if looksLikeURL(t) {
			ev.PayloadKind = "link"
			ev.Link = t
		} else {
			ev.PayloadKind = "text"
		}
	}
	if ev.PayloadKind != "none" && d.onDrop != nil {
		d.onDrop(ev)
	}
	// Physical release signal must be emitted regardless of IDataObject parse success.
	if d.onDrop != nil {
		d.onDrop(dropEvent{
			At:          time.Now().Format(time.RFC3339),
			Kind:        "DRAG_END_PHYSICAL",
			PayloadKind: "none",
			X:           pt.X,
			Y:           pt.Y,
		})
	}
	return sOk
}

func (d *dropTarget) dragEnterLog(pt pointl, effect *uint32) uintptr {
	if effect != nil {
		*effect = dropEffectCopy
	}
	if d.onEnter != nil {
		d.onEnter(dropEvent{
			At:   time.Now().Format(time.RFC3339),
			Kind: "drag_enter",
			PayloadKind: "none",
			X:    pt.X,
			Y:    pt.Y,
		})
	}
	return sOk
}

func readHDropPaths(dataObj *iDataObject) ([]string, []string, bool) {
	fe := formatEtc{CfFormat: cfHDrop, DwAspect: dvaspectContent, Lindex: -1, Tymed: tymedHGlobal}
	var med stgMedium
	if int32(getData(dataObj, &fe, &med)) < 0 || med.Handle == 0 { return nil, nil, false }
	defer procReleaseStgMedium.Call(uintptr(unsafe.Pointer(&med)))
	cnt, _, _ := procDragQueryFileW.Call(med.Handle, 0xFFFFFFFF, 0, 0)
	if cnt == 0 { return nil, nil, false }
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

func readUnicodeText(dataObj *iDataObject) (string, bool) {
	fe := formatEtc{CfFormat: cfUnicodeText, DwAspect: dvaspectContent, Lindex: -1, Tymed: tymedHGlobal}
	var med stgMedium
	if int32(getData(dataObj, &fe, &med)) < 0 || med.Handle == 0 { return "", false }
	defer procReleaseStgMedium.Call(uintptr(unsafe.Pointer(&med)))
	ptr, _, _ := procGlobalLock.Call(med.Handle)
	if ptr == 0 { return "", false }
	defer procGlobalUnlock.Call(med.Handle)
	return utf16PtrToString((*uint16)(unsafe.Pointer(ptr))), true
}

func getData(dataObj *iDataObject, fe *formatEtc, med *stgMedium) uintptr {
	hr, _, _ := syscall.SyscallN(dataObj.LpVtbl.GetData, uintptr(unsafe.Pointer(dataObj)), uintptr(unsafe.Pointer(fe)), uintptr(unsafe.Pointer(med)))
	return hr
}

func utf16PtrToString(ptr *uint16) string {
	if ptr == nil { return "" }
	buf := make([]uint16, 0, 256)
	for p := uintptr(unsafe.Pointer(ptr)); ; p += 2 {
		v := *(*uint16)(unsafe.Pointer(p)); if v == 0 { break }; buf = append(buf, v)
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
		return strings.HasSuffix(p, `\`) || strings.HasSuffix(p, `/`)
	}
	return fi.IsDir()
}

func dropQueryInterface(self, riid, ppv uintptr) uintptr {
	if ppv == 0 { return eNoInterface }
	*(*uintptr)(unsafe.Pointer(ppv)) = 0
	g := (*ole.GUID)(unsafe.Pointer(riid))
	if equalGUID(g, iidIUnknown) || equalGUID(g, iidIDropTarget) {
		*(*uintptr)(unsafe.Pointer(ppv)) = self
		dropAddRef(self)
		return sOk
	}
	return eNoInterface
}
func dropAddRef(self uintptr) uintptr { return uintptr(atomic.AddInt32(&(*dropTarget)(unsafe.Pointer(self)).refs, 1)) }
func dropRelease(self uintptr) uintptr { return uintptr(atomic.AddInt32(&(*dropTarget)(unsafe.Pointer(self)).refs, -1)) }
func dropDragEnter(self, dataObj, keyState, pt, effect uintptr) uintptr {
	obj := (*dropTarget)(unsafe.Pointer(self))
	var eff *uint32
	if effect != 0 {
		eff = (*uint32)(unsafe.Pointer(effect))
	}
	return obj.dragEnterLog(*(*pointl)(unsafe.Pointer(pt)), eff)
}
func dropDragOver(self, keyState, pt, effect uintptr) uintptr { if effect != 0 { *(*uint32)(unsafe.Pointer(effect)) = dropEffectCopy }; return sOk }
func dropDragLeave(self uintptr) uintptr { return sOk }
func dropDrop(self, dataObj, keyState, pt, effect uintptr) uintptr {
	obj := (*dropTarget)(unsafe.Pointer(self))
	var eff *uint32
	if effect != 0 { eff = (*uint32)(unsafe.Pointer(effect)) }
	return obj.drop((*iDataObject)(unsafe.Pointer(dataObj)), *(*pointl)(unsafe.Pointer(pt)), eff)
}

func equalGUID(a, b *ole.GUID) bool {
	if a == nil || b == nil { return false }
	if a.Data1 != b.Data1 || a.Data2 != b.Data2 || a.Data3 != b.Data3 { return false }
	for i := 0; i < 8; i++ { if a.Data4[i] != b.Data4[i] { return false } }
	return true
}
