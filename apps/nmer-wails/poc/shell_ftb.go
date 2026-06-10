package poc

import (
	"encoding/json"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

const (
	ShellFtbControlPath      = "/shell/ftb"
	ShellFtbStatusPath       = "/shell/ftb/status"
	ShellFtbInjectPath       = "/shell/ftb/inject"
	ShellFtbInjectDrainPath  = "/shell/ftb/inject/drain"
	ShellFtbEgressPath       = "/shell/ftb/egress"
	ShellFtbHtmlPrefix       = "/shell/ftb/html/"
	ShellFtbEventName        = "shell:ftb"
	shellFtbEgressCap        = 512
	shellFtbExternalInjectCap = 512
)

// ShellFtbStatus is exposed to Wails bindings and GET /shell/ftb/status.
type ShellFtbStatus struct {
	Visible           bool   `json:"visible"`
	Mounted           bool   `json:"mounted"`
	Ready             bool   `json:"ready"`
	Entry             string `json:"entry"`
	HtmlURL           string `json:"htmlUrl"`
	ScriptRoot        string `json:"scriptRoot"`
	UpdatedAt         string `json:"updatedAt"`
	Phase             int    `json:"phase"`
	PresentationMode  string `json:"presentationMode"`
}

type shellFtbEmitFn func(event string, payload interface{})

// ShellFtbController serves FTB strip HTML and coordinates lazy shell mount in Wails UI.
type ShellFtbController struct {
	mu                    sync.RWMutex
	scriptRoot            string
	addr                  string
	visible               bool
	mounted               bool
	ready                 bool
	entry                 string
	presentationMode      string
	emitFn                shellFtbEmitFn
	egress                []json.RawMessage
	pendingInject         []json.RawMessage
	pendingExternalInject []json.RawMessage
}

func resolveScriptRoot(initial string) string {
	candidates := []string{strings.TrimSpace(initial)}
	if extra := strings.TrimSpace(os.Getenv("NMER_SCRIPT_DIR")); extra != "" {
		candidates = append(candidates, extra)
	}
	if fp := strings.TrimSpace(os.Getenv("NMER_SCRIPT_DIR_UTF8_FILE")); fp != "" {
		if b, err := os.ReadFile(fp); err == nil {
			if utf8Root := strings.TrimSpace(string(b)); utf8Root != "" {
				candidates = append(candidates, utf8Root)
			}
		}
	}
	probe := "html" + string(os.PathSeparator) + "FloatingToolbarStrip.html"
	for _, root := range candidates {
		if root == "" {
			continue
		}
		if _, err := os.Stat(filepath.Join(root, probe)); err == nil {
			return root
		}
	}
	if len(candidates) > 0 && candidates[0] != "" {
		return candidates[0]
	}
	return "."
}

func resolvePresentationMode() string {
	mode := strings.ToLower(strings.TrimSpace(os.Getenv("NMER_FTB_PRESENTATION")))
	if mode == "external" {
		return "external"
	}
	return "embedded"
}

func NewShellFtbController(scriptRoot string) *ShellFtbController {
	return &ShellFtbController{
		scriptRoot:       resolveScriptRoot(scriptRoot),
		entry:            "",
		presentationMode: resolvePresentationMode(),
	}
}

func (c *ShellFtbController) SetAddr(addr string) {
	c.mu.Lock()
	c.addr = strings.TrimSpace(addr)
	c.mu.Unlock()
}

func (c *ShellFtbController) SetEmit(fn shellFtbEmitFn) {
	c.mu.Lock()
	c.emitFn = fn
	c.mu.Unlock()
}

func (c *ShellFtbController) RegisterRoutes(mux *http.ServeMux) {
	if mux == nil {
		return
	}
	mux.HandleFunc(ShellFtbControlPath, c.handleControl)
	mux.HandleFunc(ShellFtbStatusPath, c.handleStatus)
	mux.HandleFunc(ShellFtbInjectPath, c.handleInject)
	mux.HandleFunc(ShellFtbInjectDrainPath, c.handleInjectDrain)
	mux.HandleFunc(ShellFtbEgressPath, c.handleEgress)
	mux.HandleFunc(ShellFtbHtmlPrefix, c.handleHtml)
}

func (c *ShellFtbController) isExternalLocked() bool {
	return c.presentationMode == "external"
}

func (c *ShellFtbController) pushEgress(raw json.RawMessage) {
	if len(raw) == 0 {
		return
	}
	c.mu.Lock()
	c.egress = append(c.egress, raw)
	if len(c.egress) > shellFtbEgressCap {
		c.egress = c.egress[len(c.egress)-shellFtbEgressCap:]
	}
	c.mu.Unlock()
}

func (c *ShellFtbController) drainEgress() []json.RawMessage {
	c.mu.Lock()
	out := c.egress
	c.egress = nil
	c.mu.Unlock()
	return out
}

func (c *ShellFtbController) drainExternalInject() []json.RawMessage {
	c.mu.Lock()
	out := c.pendingExternalInject
	c.pendingExternalInject = nil
	c.mu.Unlock()
	return out
}

func (c *ShellFtbController) Status() ShellFtbStatus {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.snapshotLocked()
}

func (c *ShellFtbController) snapshotLocked() ShellFtbStatus {
	htmlURL := ""
	if c.addr != "" {
		htmlURL = "http://" + c.addr + ShellFtbHtmlPrefix + "FloatingToolbarStrip.html"
	}
	return ShellFtbStatus{
		Visible:          c.visible,
		Mounted:          c.mounted,
		Ready:            c.ready,
		Entry:            c.entry,
		HtmlURL:          htmlURL,
		ScriptRoot:       c.scriptRoot,
		UpdatedAt:        time.Now().Format(time.RFC3339),
		Phase:            2,
		PresentationMode: c.presentationMode,
	}
}

func (c *ShellFtbController) flushPendingInjectLocked() {
	if c.isExternalLocked() {
		return
	}
	for _, raw := range c.pendingInject {
		var payload interface{}
		if err := json.Unmarshal(raw, &payload); err != nil {
			continue
		}
		c.emitLocked("inject", map[string]interface{}{"injectPayload": payload})
	}
	c.pendingInject = nil
}

func (c *ShellFtbController) emitLocked(action string, extra map[string]interface{}) {
	fn := c.emitFn
	st := c.snapshotLocked()
	if fn == nil {
		return
	}
	payload := map[string]interface{}{
		"action":           action,
		"visible":          st.Visible,
		"mounted":          st.Mounted,
		"ready":            st.Ready,
		"entry":            st.Entry,
		"htmlUrl":          st.HtmlURL,
		"phase":            st.Phase,
		"presentationMode": st.PresentationMode,
	}
	for k, v := range extra {
		payload[k] = v
	}
	fn(ShellFtbEventName, payload)
}

func (c *ShellFtbController) emit(action string, extra map[string]interface{}) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.emitLocked(action, extra)
}

type shellFtbControlRequest struct {
	Action string `json:"action"`
	Entry  string `json:"entry"`
	Ready  *bool  `json:"ready"`
}

func (c *ShellFtbController) handleControl(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 64*1024))
	if err != nil {
		http.Error(w, "read error", http.StatusBadRequest)
		return
	}
	var req shellFtbControlRequest
	if len(body) > 0 {
		if err := json.Unmarshal(body, &req); err != nil {
			http.Error(w, "invalid json", http.StatusBadRequest)
			return
		}
	}
	action := strings.ToLower(strings.TrimSpace(req.Action))
	if action == "" {
		http.Error(w, "missing action", http.StatusBadRequest)
		return
	}
	entry := strings.TrimSpace(req.Entry)
	switch action {
	case "register_external":
		c.mu.Lock()
		c.presentationMode = "external"
		c.mounted = true
		c.visible = true
		if entry != "" {
			c.entry = entry
		}
		st := c.snapshotLocked()
		c.mu.Unlock()
		c.emit("register_external", map[string]interface{}{"entry": st.Entry})
	case "show", "mount":
		c.mu.Lock()
		already := c.visible && c.mounted
		prevEntry := c.entry
		c.visible = true
		c.mounted = true
		if entry != "" {
			c.entry = entry
		}
		st := c.snapshotLocked()
		external := c.isExternalLocked()
		c.mu.Unlock()
		if external {
			break
		}
		if already && (entry == "" || entry == prevEntry) {
			break
		}
		c.emit("show", map[string]interface{}{"entry": st.Entry})
	case "hide":
		c.mu.Lock()
		alreadyHidden := !c.visible
		c.visible = false
		c.ready = false
		st := c.snapshotLocked()
		external := c.isExternalLocked()
		c.mu.Unlock()
		if external {
			break
		}
		if alreadyHidden {
			break
		}
		c.emit("hide", map[string]interface{}{"entry": st.Entry})
	case "dispose":
		c.mu.Lock()
		c.visible = false
		c.mounted = false
		c.ready = false
		c.entry = ""
		c.pendingExternalInject = nil
		st := c.snapshotLocked()
		external := c.isExternalLocked()
		c.mu.Unlock()
		if external {
			break
		}
		c.emit("dispose", map[string]interface{}{"entry": st.Entry})
	case "ready":
		c.mu.Lock()
		c.mounted = true
		c.ready = true
		if req.Ready != nil {
			c.ready = *req.Ready
		}
		st := c.snapshotLocked()
		if c.ready {
			c.flushPendingInjectLocked()
		}
		c.mu.Unlock()
		c.emit("ready", map[string]interface{}{"entry": st.Entry})
	default:
		http.Error(w, "unknown action", http.StatusBadRequest)
		return
	}
	c.writeStatus(w)
}

func (c *ShellFtbController) handleInject(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	body, err := io.ReadAll(io.LimitReader(r.Body, 512*1024))
	if err != nil {
		http.Error(w, "read error", http.StatusBadRequest)
		return
	}
	if len(body) == 0 {
		http.Error(w, "empty body", http.StatusBadRequest)
		return
	}
	var payload interface{}
	if err := json.Unmarshal(body, &payload); err != nil {
		http.Error(w, "invalid json", http.StatusBadRequest)
		return
	}
	queued := false
	c.mu.Lock()
	if c.isExternalLocked() {
		c.pendingExternalInject = append(c.pendingExternalInject, append(json.RawMessage(nil), body...))
		if len(c.pendingExternalInject) > shellFtbExternalInjectCap {
			c.pendingExternalInject = c.pendingExternalInject[len(c.pendingExternalInject)-shellFtbExternalInjectCap:]
		}
		queued = true
	} else if c.ready && c.mounted {
		c.emitLocked("inject", map[string]interface{}{"injectPayload": payload})
	} else {
		c.pendingInject = append(c.pendingInject, append(json.RawMessage(nil), body...))
		queued = true
	}
	c.mu.Unlock()
	w.Header().Set("Content-Type", "application/json")
	if queued {
		_, _ = w.Write([]byte(`{"ok":true,"code":"SHELL_FTB_INJECT_QUEUED"}`))
		return
	}
	_, _ = w.Write([]byte(`{"ok":true,"code":"SHELL_FTB_INJECT_OK"}`))
}

func (c *ShellFtbController) handleInjectDrain(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	items := c.drainExternalInject()
	w.Header().Set("Content-Type", "application/json")
	enc, err := json.Marshal(map[string]interface{}{
		"ok":       true,
		"code":     "SHELL_FTB_INJECT_DRAIN",
		"messages": items,
		"count":    len(items),
	})
	if err != nil {
		http.Error(w, "encode error", http.StatusInternalServerError)
		return
	}
	_, _ = w.Write(enc)
}

func (c *ShellFtbController) handleEgress(w http.ResponseWriter, r *http.Request) {
	switch r.Method {
	case http.MethodPost:
		body, err := io.ReadAll(io.LimitReader(r.Body, 512*1024))
		if err != nil {
			http.Error(w, "read error", http.StatusBadRequest)
			return
		}
		if len(body) == 0 {
			http.Error(w, "empty body", http.StatusBadRequest)
			return
		}
		if !json.Valid(body) {
			http.Error(w, "invalid json", http.StatusBadRequest)
			return
		}
		c.pushEgress(json.RawMessage(body))
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"ok":true,"code":"SHELL_FTB_EGRESS_OK"}`))
	case http.MethodGet:
		items := c.drainEgress()
		w.Header().Set("Content-Type", "application/json")
		enc, err := json.Marshal(map[string]interface{}{
			"ok":       true,
			"code":     "SHELL_FTB_EGRESS_DRAIN",
			"messages": items,
			"count":    len(items),
		})
		if err != nil {
			http.Error(w, "encode error", http.StatusInternalServerError)
			return
		}
		_, _ = w.Write(enc)
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func (c *ShellFtbController) handleStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	if r.Method == http.MethodHead {
		w.WriteHeader(http.StatusOK)
		return
	}
	c.writeStatus(w)
}

func (c *ShellFtbController) writeStatus(w http.ResponseWriter) {
	st := c.Status()
	w.Header().Set("Content-Type", "application/json")
	payload, err := json.Marshal(map[string]interface{}{
		"ok":     true,
		"status": st,
	})
	if err != nil {
		http.Error(w, "encode error", http.StatusInternalServerError)
		return
	}
	_, _ = w.Write(payload)
}

func (c *ShellFtbController) handleHtml(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	rel := strings.TrimPrefix(r.URL.Path, ShellFtbHtmlPrefix)
	rel = strings.TrimPrefix(rel, "/")
	rel = filepath.Clean(strings.ReplaceAll(rel, "\\", "/"))
	if rel == "." || rel == ".." || strings.HasPrefix(rel, "..") {
		http.Error(w, "invalid path", http.StatusBadRequest)
		return
	}
	c.mu.RLock()
	root := c.scriptRoot
	c.mu.RUnlock()
	full := filepath.Join(root, "html", rel)
	if _, err := os.Stat(full); err != nil {
		log.Printf("[shell-ftb] html missing: %s (%v)", full, err)
		http.NotFound(w, r)
		return
	}
	http.ServeFile(w, r, full)
}
