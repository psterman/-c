package poc

import (
	"context"
	"encoding/json"
	"errors"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	DefaultWSAddr   = "127.0.0.1:18791"
	DefaultWSPath   = "/agent/ws"
	eventBufferSize = 64
	pingInterval    = 15 * time.Second
	pongWait        = 25 * time.Second
	writeWait       = 8 * time.Second
)

var wsUpgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

// HubStatus is exposed to the Wails frontend.
type HubStatus struct {
	Addr                string             `json:"addr"`
	Path                string             `json:"path"`
	A2UIProvider        string             `json:"a2uiProvider"`
	ProviderCapability  ProviderCapability `json:"providerCapability"`
	Running             bool               `json:"running"`
	ClientCount         int                `json:"clientCount"`
	PumpRunning         bool               `json:"pumpRunning"`
	EventsEmitted       int                `json:"eventsEmitted"`
	LastEventSeq        int                `json:"lastEventSeq"`
}

type clientConn struct {
	id   string
	conn *websocket.Conn
	mu   sync.Mutex
}

type a2uiActionCancel struct {
	abortID string
	cancel  context.CancelFunc
}

// Hub manages WebSocket clients, replay buffer, and optional fake pump.
type Hub struct {
	addr   string
	path   string
	server   *http.Server
	listening bool

	mu                sync.RWMutex
	clients           map[string]*clientConn
	eventBuf          []AgentEvent
	a2uiBuf           []A2UIEnvelope
	lastSeq           int
	eventsEmitted     int
	pump              *FakePump
	emitFn            func(AgentEvent)
	statusFn          func(HubStatus)
	a2uiValidator     *A2UIValidator
	a2uiActions       *A2UIActionPolicy
	a2uiProvider      A2UIProvider
	a2uiProviderName  string
	a2uiActionCancels map[string]a2uiActionCancel
	shellFtb          *ShellFtbController
}

// NewHub creates a hub; emitFn receives each broadcast event (e.g. Wails EventsEmit).
func NewHub(addr, path string, emitFn func(AgentEvent), statusFn func(HubStatus)) *Hub {
	if addr == "" {
		addr = DefaultWSAddr
	}
	if path == "" {
		path = DefaultWSPath
	}
	return &Hub{
		addr:              addr,
		path:              path,
		clients:           make(map[string]*clientConn),
		emitFn:            emitFn,
		statusFn:          statusFn,
		a2uiValidator:     NewA2UIValidator(),
		a2uiActions:       NewA2UIActionPolicy(),
		a2uiProvider:      FakeA2UIProvider{},
		a2uiProviderName:  "fake",
		a2uiActionCancels: make(map[string]a2uiActionCancel),
		shellFtb:          NewShellFtbController(strings.TrimSpace(os.Getenv("NMER_SCRIPT_DIR"))),
	}
}

func (h *Hub) SetShellFtbEmit(fn func(string, interface{})) {
	if h == nil || h.shellFtb == nil || fn == nil {
		return
	}
	h.shellFtb.SetEmit(fn)
}

func (h *Hub) ShellFtbStatus() ShellFtbStatus {
	if h == nil || h.shellFtb == nil {
		return ShellFtbStatus{Phase: 2}
	}
	return h.shellFtb.Status()
}

func (h *Hub) SetA2UIProvider(name string, provider A2UIProvider) {
	if provider == nil {
		return
	}
	h.mu.Lock()
	h.a2uiProvider = provider
	h.a2uiProviderName = strings.TrimSpace(name)
	h.mu.Unlock()
	h.notifyStatus()
}

func (h *Hub) URL() string {
	return "ws://" + h.addr + h.path
}

func (h *Hub) A2UIIngestURL() string {
	return "http://" + h.addr + A2UIIngestPath
}

func (h *Hub) Start(ctx context.Context) error {
	mux := http.NewServeMux()
	mux.HandleFunc(A2UIHealthPath, h.handleHealth)
	mux.HandleFunc(h.path, h.handleWS)
	mux.HandleFunc(A2UIIngestPath, h.handleA2UIIngest)
	mux.HandleFunc(OpenClawAdapterActionPath, h.handleOpenClawAdapterAction)
	if h.shellFtb != nil {
		h.shellFtb.SetAddr(h.addr)
		h.shellFtb.RegisterRoutes(mux)
	}
	h.pump = NewFakePump(h.BroadcastEvent)

	listener, err := net.Listen("tcp", h.addr)
	if err != nil {
		log.Printf("[poc-hub] listen error: %v", err)
		return err
	}
	h.mu.Lock()
	h.listening = true
	if la := listener.Addr(); la != nil {
		h.addr = la.String()
	}
	h.server = &http.Server{Handler: mux}
	h.mu.Unlock()
	h.notifyStatus()

	go func() {
		<-ctx.Done()
		_ = h.server.Close()
		_ = listener.Close()
	}()

	go func() {
		log.Printf("[poc-hub] listening %s%s", h.addr, h.path)
		if err := h.server.Serve(listener); err != nil && err != http.ErrServerClosed {
			log.Printf("[poc-hub] server error: %v", err)
		}
		h.mu.Lock()
		h.listening = false
		h.mu.Unlock()
		h.notifyStatus()
	}()
	return nil
}

func (h *Hub) handleHealth(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodHead {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	if r.Method == http.MethodHead {
		w.WriteHeader(http.StatusOK)
		return
	}
	st := h.Status()
	payload, err := json.Marshal(map[string]interface{}{
		"ok":         true,
		"provider":   st.A2UIProvider,
		"capability": st.ProviderCapability,
	})
	if err != nil {
		http.Error(w, "encode error", http.StatusInternalServerError)
		return
	}
	_, _ = w.Write(payload)
}

func (h *Hub) Status() HubStatus {
	h.mu.RLock()
	defer h.mu.RUnlock()
	pumpRunning := h.pump != nil && h.pump.Running()
	return HubStatus{
		Addr:               h.addr,
		Path:               h.path,
		A2UIProvider:       h.a2uiProviderName,
		ProviderCapability: CapabilityForProvider(h.a2uiProviderName),
		Running:            h.listening,
		ClientCount:        len(h.clients),
		PumpRunning:        pumpRunning,
		EventsEmitted:      h.eventsEmitted,
		LastEventSeq:       h.lastSeq,
	}
}

func (h *Hub) notifyStatus() {
	if h.statusFn != nil {
		h.statusFn(h.Status())
	}
}

func (h *Hub) StartFakePump() {
	if h.pump != nil {
		h.pump.Start()
		h.notifyStatus()
	}
}

func (h *Hub) StopFakePump() {
	if h.pump != nil {
		h.pump.Stop()
		h.notifyStatus()
	}
}

func (h *Hub) pushEvent(ev AgentEvent) {
	h.mu.Lock()
	if ev.Seq <= 0 {
		h.lastSeq++
		ev.Seq = h.lastSeq
	} else {
		h.lastSeq = ev.Seq
	}
	if ev.Ts == "" {
		ev.Ts = NowISO()
	}
	h.eventsEmitted++
	h.eventBuf = append(h.eventBuf, ev)
	if len(h.eventBuf) > eventBufferSize {
		h.eventBuf = h.eventBuf[len(h.eventBuf)-eventBufferSize:]
	}
	h.mu.Unlock()
}

func (h *Hub) replaySnapshot() []AgentEvent {
	h.mu.RLock()
	defer h.mu.RUnlock()
	out := make([]AgentEvent, len(h.eventBuf))
	copy(out, h.eventBuf)
	return out
}

// BroadcastEvent sends an agent event to all WS clients and optional Wails emit hook.
func (h *Hub) BroadcastEvent(ev AgentEvent) {
	h.pushEvent(ev)
	if h.emitFn != nil {
		h.emitFn(ev)
	}
	msg := WireMessage{Type: "agent_event", Event: &ev}
	h.broadcast(msg)
	h.notifyStatus()
}

// BroadcastA2UI forwards an already validated official A2UI envelope.
func (h *Hub) BroadcastA2UI(envelope A2UIEnvelope) {
	if h.a2uiActions != nil {
		h.a2uiActions.RegisterSurface(envelope.SurfaceID, envelope.CardID)
	}
	h.mu.Lock()
	h.a2uiBuf = append(h.a2uiBuf, envelope)
	if len(h.a2uiBuf) > a2uiReplayBufferSize {
		h.a2uiBuf = h.a2uiBuf[len(h.a2uiBuf)-a2uiReplayBufferSize:]
	}
	h.mu.Unlock()
	msg := WireMessage{Type: "official_a2ui_event", A2UI: &envelope}
	h.broadcast(msg)
}

func (h *Hub) a2uiReplaySnapshot() []A2UIEnvelope {
	h.mu.RLock()
	defer h.mu.RUnlock()
	out := make([]A2UIEnvelope, len(h.a2uiBuf))
	copy(out, h.a2uiBuf)
	return out
}

func (h *Hub) handleA2UIAction(action A2UIActionEnvelope) {
	if err := h.a2uiActions.Validate(action); err != nil {
		result := actionResultFromError(action, "rejected", err)
		h.broadcast(WireMessage{
			Type:             "official_a2ui_action_result",
			A2UIActionResult:   &result,
		})
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(action.TimeoutMs)*time.Millisecond)
	h.mu.Lock()
	h.a2uiActionCancels[action.RequestID] = a2uiActionCancel{
		abortID: action.AbortID,
		cancel:  cancel,
	}
	h.mu.Unlock()
	h.broadcast(WireMessage{
		Type: "official_a2ui_action_result",
		A2UIActionResult: &A2UIActionResult{
			SchemaVersion: A2UIActionResultVersion,
			RequestID:     action.RequestID,
			CorrelationID: action.CorrelationID,
			CardID:        action.CardID,
			SurfaceID:     action.SurfaceID,
			Status:        "accepted",
		},
	})
	go func() {
		defer cancel()
		defer func() {
			h.mu.Lock()
			delete(h.a2uiActionCancels, action.RequestID)
			h.mu.Unlock()
		}()
		h.mu.RLock()
		provider := h.a2uiProvider
		h.mu.RUnlock()
		err := provider.HandleAction(ctx, action, func(envelope A2UIEnvelope) error {
			raw, marshalErr := json.Marshal(envelope)
			if marshalErr != nil {
				return marshalErr
			}
			validated, validateErr := h.a2uiValidator.Validate(raw)
			if validateErr != nil {
				return validateErr
			}
			h.BroadcastA2UI(validated)
			return nil
		})
		result := A2UIActionResult{
			SchemaVersion: A2UIActionResultVersion,
			RequestID:     action.RequestID,
			CorrelationID: action.CorrelationID,
			CardID:        action.CardID,
			SurfaceID:     action.SurfaceID,
			Status:        "completed",
		}
		if err != nil {
			result.Status = "rejected"
			if errors.Is(err, context.DeadlineExceeded) {
				result.Status = "timeout"
				err = a2uiErr("ACTION_TIMED_OUT", err.Error(), "policy", true)
			} else if errors.Is(err, context.Canceled) {
				result.Status = "cancelled"
				err = a2uiErr("ACTION_CANCELLED", err.Error(), "policy", false)
			}
			detail := actionResultFromError(action, result.Status, err)
			result.Error = detail.Error
			result.ErrorCode = detail.ErrorCode
			result.ErrorDetail = detail.ErrorDetail
		}
		h.broadcast(WireMessage{Type: "official_a2ui_action_result", A2UIActionResult: &result})
	}()
}

func (h *Hub) handleA2UIAbort(abort A2UIAbortEnvelope) {
	if err := validateA2UIAbort(abort); err != nil {
		h.broadcast(WireMessage{Type: "official_a2ui_action_result", A2UIActionResult: &A2UIActionResult{
			SchemaVersion: A2UIActionResultVersion,
			RequestID:     abort.RequestID,
			Status:        "rejected",
			Error:         err.Error(),
		}})
		return
	}
	h.mu.RLock()
	active, exists := h.a2uiActionCancels[abort.RequestID]
	h.mu.RUnlock()
	if !exists || active.abortID != abort.AbortID {
		h.broadcast(WireMessage{Type: "official_a2ui_action_result", A2UIActionResult: &A2UIActionResult{
			SchemaVersion: A2UIActionResultVersion,
			RequestID:     abort.RequestID,
			Status:        "rejected",
			Error:         "A2UI action is not active or abortId does not match",
		}})
		return
	}
	active.cancel()
}

func (h *Hub) broadcast(msg WireMessage) {
	raw, err := json.Marshal(msg)
	if err != nil {
		return
	}
	h.mu.RLock()
	clients := make([]*clientConn, 0, len(h.clients))
	for _, c := range h.clients {
		clients = append(clients, c)
	}
	h.mu.RUnlock()
	for _, c := range clients {
		c.mu.Lock()
		_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
		err := c.conn.WriteMessage(websocket.TextMessage, raw)
		c.mu.Unlock()
		if err != nil {
			h.removeClient(c.id)
		}
	}
}

func (h *Hub) registerClient(id string, conn *websocket.Conn) *clientConn {
	c := &clientConn{id: id, conn: conn}
	h.mu.Lock()
	h.clients[id] = c
	h.mu.Unlock()
	h.notifyStatus()
	return c
}

func (h *Hub) removeClient(id string) {
	h.mu.Lock()
	if c, ok := h.clients[id]; ok {
		_ = c.conn.Close()
		delete(h.clients, id)
	}
	h.mu.Unlock()
	h.notifyStatus()
}

func (h *Hub) handleWS(w http.ResponseWriter, r *http.Request) {
	conn, err := wsUpgrader.Upgrade(w, r, nil)
	if err != nil {
		return
	}
	clientID := r.URL.Query().Get("clientId")
	if clientID == "" {
		clientID = "c_" + time.Now().Format("150405.000")
	}
	_ = conn.SetReadDeadline(time.Now().Add(pongWait))
	conn.SetPongHandler(func(string) error {
		return conn.SetReadDeadline(time.Now().Add(pongWait))
	})

	c := h.registerClient(clientID, conn)
	defer h.removeClient(clientID)

	replay := h.replaySnapshot()
	a2uiReplay := h.a2uiReplaySnapshot()
	ack, _ := json.Marshal(WireMessage{
		Type:       "hello_ack",
		ClientID:   clientID,
		Replay:     replay,
		A2UIReplay: a2uiReplay,
		Clients:    h.Status().ClientCount,
	})
	c.mu.Lock()
	_ = conn.SetWriteDeadline(time.Now().Add(writeWait))
	_ = conn.WriteMessage(websocket.TextMessage, ack)
	c.mu.Unlock()

	ticker := time.NewTicker(pingInterval)
	defer ticker.Stop()

	readDone := make(chan struct{})
	go func() {
		defer close(readDone)
		for {
			_, data, err := conn.ReadMessage()
			if err != nil {
				return
			}
			var msg WireMessage
			if json.Unmarshal(data, &msg) != nil {
				continue
			}
			switch msg.Type {
			case "ping":
				pong, _ := json.Marshal(WireMessage{Type: "pong", Seq: msg.Seq})
				c.mu.Lock()
				_ = conn.SetWriteDeadline(time.Now().Add(writeWait))
				_ = conn.WriteMessage(websocket.TextMessage, pong)
				c.mu.Unlock()
			case "hello":
				// no-op; hello_ack already sent
			case "official_a2ui_ingest":
				if msg.A2UI == nil {
					continue
				}
				raw, marshalErr := json.Marshal(msg.A2UI)
				if marshalErr != nil {
					continue
				}
				envelope, validateErr := h.a2uiValidator.Validate(raw)
				if validateErr != nil {
					reject, _ := json.Marshal(wireA2UIRejectMessage(validateErr))
					c.mu.Lock()
					_ = conn.SetWriteDeadline(time.Now().Add(writeWait))
					_ = conn.WriteMessage(websocket.TextMessage, reject)
					c.mu.Unlock()
					continue
				}
				h.BroadcastA2UI(envelope)
			case "official_a2ui_action":
				if msg.A2UIAction != nil {
					h.handleA2UIAction(*msg.A2UIAction)
				}
			case "official_a2ui_abort":
				if msg.A2UIAbort != nil {
					h.handleA2UIAbort(*msg.A2UIAbort)
				}
			}
		}
	}()

	for {
		select {
		case <-readDone:
			return
		case <-ticker.C:
			c.mu.Lock()
			_ = conn.SetWriteDeadline(time.Now().Add(writeWait))
			err := conn.WriteMessage(websocket.PingMessage, nil)
			c.mu.Unlock()
			if err != nil {
				return
			}
		}
	}
}
