//go:build windows

package main

import (
	"context"
	"errors"
	"fmt"
	"runtime"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"
	"unsafe"

	"github.com/go-ole/go-ole"
	wailsruntime "github.com/wailsapp/wails/v2/pkg/runtime"
)

const (
	wsExLayered = 0x00080000

	wsOverlapped = 0x00000000

	hwndMessage = ^uintptr(2) // (HWND)-3

	wmQuit = 0x0012

	cfUnicodeText = 13
	cfHDrop       = 15

	dvaspectContent = 1
	tymedHGlobal    = 1

	dropEffectCopy          = 1
	coInitApartmentThreaded = 0x2

	sOk    = 0x00000000
	sFalse = 0x00000001

	eNotImpl     = 0x80004001
	eNoInterface = 0x80004002
)

type dropManager struct {
	ctx context.Context

	stopOnce sync.Once
	stopCh   chan struct{}
	errCh    chan error

	hwnd    uintptr
	thread  uint32
	target  *dropTarget
	started atomic.Bool
}

type nativeDropPayload struct {
	Kind      string   `json:"kind"`
	Text      string   `json:"text,omitempty"`
	Files     []string `json:"files,omitempty"`
	DropX     int32    `json:"dropX"`
	DropY     int32    `json:"dropY"`
	Source    string   `json:"source"`
	Succeeded bool     `json:"succeeded"`
}

type nativeDragIntentPayload struct {
	Kind   string `json:"kind"`
	DropX  int32  `json:"dropX"`
	DropY  int32  `json:"dropY"`
	Source string `json:"source"`
}

func newDropManager(ctx context.Context) *dropManager {
	return &dropManager{
		ctx:    ctx,
		stopCh: make(chan struct{}),
		errCh:  make(chan error, 1),
	}
}

func (m *dropManager) start() error {
	if !m.started.CompareAndSwap(false, true) {
		return nil
	}
	go m.run()
	// Never block Wails startup on native drop bootstrap.
	// If native OLE init hangs or crashes, UI must still come up.
	go func() {
		select {
		case err := <-m.errCh:
			if err != nil {
				m.started.Store(false)
				if m.ctx != nil {
					wailsruntime.LogErrorf(m.ctx, "native drop manager disabled: %v", err)
				}
			} else if m.ctx != nil {
				wailsruntime.LogInfo(m.ctx, "native drop manager initialized")
			}
		case <-time.After(2 * time.Second):
			if m.ctx != nil {
				wailsruntime.LogWarning(m.ctx, "native drop manager init timeout; continue without blocking UI")
			}
		}
	}()
	return nil
}

func (m *dropManager) stop() {
	m.stopOnce.Do(func() {
		close(m.stopCh)
		if m.thread != 0 {
			_, _, _ = procPostThreadMessageW.Call(uintptr(m.thread), wmQuit, 0, 0)
		}
	})
}

func (m *dropManager) run() {
	runtime.LockOSThread()
	defer runtime.UnlockOSThread()
	defer func() {
		if r := recover(); r != nil {
			select {
			case m.errCh <- fmt.Errorf("panic in native drop manager: %v", r):
			default:
			}
		}
	}()

	m.thread = getCurrentThreadID()

	if err := ole.CoInitializeEx(0, coInitApartmentThreaded); err != nil {
		m.errCh <- fmt.Errorf("CoInitializeEx failed: %w", err)
		return
	}
	defer ole.CoUninitialize()

	hwnd, err := createDropHostWindow()
	if err != nil {
		m.errCh <- err
		return
	}
	m.hwnd = hwnd
	defer func() {
		if m.hwnd != 0 {
			_, _, _ = procDestroyWindow.Call(m.hwnd)
		}
	}()

	target := newDropTarget(m)
	m.target = target

	hr := registerDragDrop(hwnd, target)
	if failed(hr) {
		m.errCh <- fmt.Errorf("RegisterDragDrop failed: 0x%08X", uint32(hr))
		return
	}
	defer revokeDragDrop(hwnd)

	m.errCh <- nil

	var msg msg
	for {
		select {
		case <-m.stopCh:
			return
		default:
		}

		r1, _, _ := procGetMessageW.Call(uintptr(unsafe.Pointer(&msg)), 0, 0, 0)
		if int32(r1) <= 0 {
			return
		}
		_, _, _ = procTranslateMessage.Call(uintptr(unsafe.Pointer(&msg)))
		_, _, _ = procDispatchMessageW.Call(uintptr(unsafe.Pointer(&msg)))
	}
}

func (m *dropManager) emitDrop(payload nativeDropPayload) {
	if m.ctx == nil {
		return
	}
	wailsruntime.EventsEmit(m.ctx, "native_drop_detected", payload)
}

func (m *dropManager) emitDragIntent(payload nativeDragIntentPayload) {
	if m.ctx == nil {
		return
	}
	wailsruntime.EventsEmit(m.ctx, "native_drag_intent", payload)
}

type msg struct {
	Hwnd     uintptr
	Message  uint32
	WParam   uintptr
	LParam   uintptr
	Time     uint32
	Pt       point
	LPrivate uint32
}

type point struct {
	X int32
	Y int32
}

type pointl struct {
	X int32
	Y int32
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

type iDataObject struct {
	LpVtbl *iDataObjectVtbl
}

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
	mgr    *dropManager
}

var (
	modUser32  = syscall.NewLazyDLL("user32.dll")
	modOle32   = syscall.NewLazyDLL("ole32.dll")
	modShell32 = syscall.NewLazyDLL("shell32.dll")
	modKernel  = syscall.NewLazyDLL("kernel32.dll")

	procRegisterClassExW   = modUser32.NewProc("RegisterClassExW")
	procCreateWindowExW    = modUser32.NewProc("CreateWindowExW")
	procDefWindowProcW     = modUser32.NewProc("DefWindowProcW")
	procDestroyWindow      = modUser32.NewProc("DestroyWindow")
	procGetMessageW        = modUser32.NewProc("GetMessageW")
	procTranslateMessage   = modUser32.NewProc("TranslateMessage")
	procDispatchMessageW   = modUser32.NewProc("DispatchMessageW")
	procPostThreadMessageW = modUser32.NewProc("PostThreadMessageW")

	procRegisterDragDrop = modOle32.NewProc("RegisterDragDrop")
	procRevokeDragDrop   = modOle32.NewProc("RevokeDragDrop")
	procReleaseStgMedium = modOle32.NewProc("ReleaseStgMedium")

	procDragQueryFileW = modShell32.NewProc("DragQueryFileW")

	procGlobalLock         = modKernel.NewProc("GlobalLock")
	procGlobalUnlock       = modKernel.NewProc("GlobalUnlock")
	procGetCurrentThreadID = modKernel.NewProc("GetCurrentThreadId")

	callbackDropQueryInterface = syscall.NewCallback(dropQueryInterface)
	callbackDropAddRef         = syscall.NewCallback(dropAddRef)
	callbackDropRelease        = syscall.NewCallback(dropRelease)
	callbackDropDragEnter      = syscall.NewCallback(dropDragEnter)
	callbackDropDragOver       = syscall.NewCallback(dropDragOver)
	callbackDropDragLeave      = syscall.NewCallback(dropDragLeave)
	callbackDropDrop           = syscall.NewCallback(dropDrop)

	dropTargetVTable = iDropTargetVtbl{
		QueryInterface: callbackDropQueryInterface,
		AddRef:         callbackDropAddRef,
		Release:        callbackDropRelease,
		DragEnter:      callbackDropDragEnter,
		DragOver:       callbackDropDragOver,
		DragLeave:      callbackDropDragLeave,
		Drop:           callbackDropDrop,
	}
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

func createDropHostWindow() (uintptr, error) {
	className, _ := syscall.UTF16PtrFromString("NMERNativeDropTargetHost")
	windowName, _ := syscall.UTF16PtrFromString("NMERNativeDropTargetHostWnd")

	wc := wndClassEx{
		CbSize:        uint32(unsafe.Sizeof(wndClassEx{})),
		LpfnWndProc:   procDefWindowProcW.Addr(),
		LpszClassName: uintptr(unsafe.Pointer(className)),
	}

	_, _, _ = procRegisterClassExW.Call(uintptr(unsafe.Pointer(&wc)))

	hwnd, _, callErr := procCreateWindowExW.Call(
		wsExLayered,
		uintptr(unsafe.Pointer(className)),
		uintptr(unsafe.Pointer(windowName)),
		wsOverlapped,
		0,
		0,
		0,
		0,
		hwndMessage,
		0,
		0,
		0,
	)
	if hwnd == 0 {
		if callErr != nil && !errors.Is(callErr, syscall.Errno(0)) {
			return 0, fmt.Errorf("CreateWindowExW failed: %w", callErr)
		}
		return 0, fmt.Errorf("CreateWindowExW failed")
	}
	return hwnd, nil
}

func registerDragDrop(hwnd uintptr, target *dropTarget) uintptr {
	hr, _, _ := procRegisterDragDrop.Call(hwnd, uintptr(unsafe.Pointer(target)))
	return hr
}

func revokeDragDrop(hwnd uintptr) {
	_, _, _ = procRevokeDragDrop.Call(hwnd)
}

func releaseStgMedium(m *stgMedium) {
	_, _, _ = procReleaseStgMedium.Call(uintptr(unsafe.Pointer(m)))
}

func getCurrentThreadID() uint32 {
	r1, _, _ := procGetCurrentThreadID.Call()
	return uint32(r1)
}

func newDropTarget(mgr *dropManager) *dropTarget {
	return &dropTarget{
		lpVtbl: &dropTargetVTable,
		refs:   1,
		mgr:    mgr,
	}
}

func (d *dropTarget) dragEnter(dataObj *iDataObject, keyState uint32, pt pointl, effect *uint32) uintptr {
	_ = dataObj
	_ = keyState
	if effect != nil {
		*effect = dropEffectCopy
	}
	if d.mgr != nil {
		d.mgr.emitDragIntent(nativeDragIntentPayload{
			Kind:   "drag_enter",
			DropX:  pt.X,
			DropY:  pt.Y,
			Source: "native_ole",
		})
	}
	return sOk
}

func (d *dropTarget) dragOver(keyState uint32, pt pointl, effect *uint32) uintptr {
	_ = keyState
	_ = pt
	if effect != nil {
		*effect = dropEffectCopy
	}
	return sOk
}

func (d *dropTarget) dragLeave() uintptr {
	return sOk
}

func (d *dropTarget) drop(dataObj *iDataObject, keyState uint32, pt pointl, effect *uint32) uintptr {
	_ = keyState
	if effect != nil {
		*effect = dropEffectCopy
	}

	payload := nativeDropPayload{
		Kind:      "none",
		DropX:     pt.X,
		DropY:     pt.Y,
		Source:    "native_ole",
		Succeeded: false,
	}

	if dataObj != nil {
		if files, ok := readHDropPaths(dataObj); ok && len(files) > 0 {
			payload.Kind = "file"
			payload.Files = files
			payload.Succeeded = true
		} else if text, ok := readUnicodeText(dataObj); ok && strings.TrimSpace(text) != "" {
			payload.Kind = "text"
			payload.Text = strings.TrimSpace(text)
			payload.Succeeded = true
		}
	}

	if d.mgr != nil && payload.Succeeded {
		d.mgr.emitDrop(payload)
	}

	return sOk
}

func readHDropPaths(dataObj *iDataObject) ([]string, bool) {
	fe := formatEtc{CfFormat: cfHDrop, DwAspect: dvaspectContent, Lindex: -1, Tymed: tymedHGlobal}
	var med stgMedium
	hr := getDataFromObject(dataObj, &fe, &med)
	if failed(hr) || med.Handle == 0 {
		return nil, false
	}
	defer releaseStgMedium(&med)

	count := dragQueryFileCount(med.Handle)
	if count == 0 {
		return nil, false
	}

	files := make([]string, 0, count)
	for i := uint32(0); i < count; i++ {
		name := dragQueryFileName(med.Handle, i)
		if strings.TrimSpace(name) != "" {
			files = append(files, name)
		}
	}
	return files, len(files) > 0
}

func readUnicodeText(dataObj *iDataObject) (string, bool) {
	fe := formatEtc{CfFormat: cfUnicodeText, DwAspect: dvaspectContent, Lindex: -1, Tymed: tymedHGlobal}
	var med stgMedium
	hr := getDataFromObject(dataObj, &fe, &med)
	if failed(hr) || med.Handle == 0 {
		return "", false
	}
	defer releaseStgMedium(&med)

	ptr, _, _ := procGlobalLock.Call(med.Handle)
	if ptr == 0 {
		return "", false
	}
	defer procGlobalUnlock.Call(med.Handle)

	text := utf16PtrToString((*uint16)(unsafe.Pointer(ptr)))
	if text == "" {
		return "", false
	}
	return text, true
}

func getDataFromObject(dataObj *iDataObject, fe *formatEtc, med *stgMedium) uintptr {
	if dataObj == nil || dataObj.LpVtbl == nil || dataObj.LpVtbl.GetData == 0 {
		return eNotImpl
	}
	hr, _, _ := syscall.SyscallN(dataObj.LpVtbl.GetData,
		uintptr(unsafe.Pointer(dataObj)),
		uintptr(unsafe.Pointer(fe)),
		uintptr(unsafe.Pointer(med)),
	)
	return hr
}

func dragQueryFileCount(hdrop uintptr) uint32 {
	r1, _, _ := procDragQueryFileW.Call(hdrop, 0xFFFFFFFF, 0, 0)
	return uint32(r1)
}

func dragQueryFileName(hdrop uintptr, index uint32) string {
	r1, _, _ := procDragQueryFileW.Call(hdrop, uintptr(index), 0, 0)
	lenChars := uint32(r1)
	if lenChars == 0 {
		return ""
	}
	buf := make([]uint16, lenChars+1)
	_, _, _ = procDragQueryFileW.Call(hdrop, uintptr(index), uintptr(unsafe.Pointer(&buf[0])), uintptr(len(buf)))
	return syscall.UTF16ToString(buf)
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

func failed(hr uintptr) bool {
	return int32(hr) < 0
}

func dropQueryInterface(self, riid, ppvObject uintptr) uintptr {
	if ppvObject == 0 {
		return eNoInterface
	}
	*(*uintptr)(unsafe.Pointer(ppvObject)) = 0

	if isIIDIUnknownOrDropTarget((*ole.GUID)(unsafe.Pointer(riid))) {
		*(*uintptr)(unsafe.Pointer(ppvObject)) = self
		dropAddRef(self)
		return sOk
	}
	return eNoInterface
}

func dropAddRef(self uintptr) uintptr {
	obj := (*dropTarget)(unsafe.Pointer(self))
	return uintptr(atomic.AddInt32(&obj.refs, 1))
}

func dropRelease(self uintptr) uintptr {
	obj := (*dropTarget)(unsafe.Pointer(self))
	return uintptr(atomic.AddInt32(&obj.refs, -1))
}

func dropDragEnter(self uintptr, dataObj, keyState, pt, effect uintptr) uintptr {
	obj := (*dropTarget)(unsafe.Pointer(self))
	var e *uint32
	if effect != 0 {
		e = (*uint32)(unsafe.Pointer(effect))
	}
	return obj.dragEnter((*iDataObject)(unsafe.Pointer(dataObj)), uint32(keyState), *(*pointl)(unsafe.Pointer(pt)), e)
}

func dropDragOver(self uintptr, keyState, pt, effect uintptr) uintptr {
	obj := (*dropTarget)(unsafe.Pointer(self))
	var e *uint32
	if effect != 0 {
		e = (*uint32)(unsafe.Pointer(effect))
	}
	return obj.dragOver(uint32(keyState), *(*pointl)(unsafe.Pointer(pt)), e)
}

func dropDragLeave(self uintptr) uintptr {
	obj := (*dropTarget)(unsafe.Pointer(self))
	return obj.dragLeave()
}

func dropDrop(self uintptr, dataObj, keyState, pt, effect uintptr) uintptr {
	obj := (*dropTarget)(unsafe.Pointer(self))
	var e *uint32
	if effect != 0 {
		e = (*uint32)(unsafe.Pointer(effect))
	}
	return obj.drop((*iDataObject)(unsafe.Pointer(dataObj)), uint32(keyState), *(*pointl)(unsafe.Pointer(pt)), e)
}

var (
	iidIUnknown    = ole.IID_IUnknown
	iidIDropTarget = ole.NewGUID("00000122-0000-0000-C000-000000000046")
)

func isIIDIUnknownOrDropTarget(g *ole.GUID) bool {
	if g == nil {
		return false
	}
	return equalGUID(g, iidIUnknown) || equalGUID(g, iidIDropTarget)
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
