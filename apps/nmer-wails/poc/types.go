package poc

import "time"

// AgentEventKind mirrors the frontend POC contract (not production OpenClaw).
type AgentEventKind string

const (
	EventTaskStart  AgentEventKind = "task_start"
	EventStatus     AgentEventKind = "status"
	EventReplyDelta AgentEventKind = "reply_delta"
	EventReplyFinal AgentEventKind = "reply_final"
	EventA2UI       AgentEventKind = "a2ui"
	EventTaskEnd    AgentEventKind = "task_end"
	EventError      AgentEventKind = "error"
)

// AgentEvent is the wire envelope for POC event pump.
type AgentEvent struct {
	Seq     int                    `json:"seq"`
	Ts      string                 `json:"ts"`
	Kind    AgentEventKind         `json:"kind"`
	CardID  string                 `json:"cardId,omitempty"`
	TurnID  int                    `json:"turnId,omitempty"`
	Payload map[string]interface{} `json:"payload,omitempty"`
}

// WireMessage is the JSON frame on /agent/ws.
type WireMessage struct {
	Type             string              `json:"type"`
	ClientID         string              `json:"clientId,omitempty"`
	Seq              int                 `json:"seq,omitempty"`
	Event            *AgentEvent         `json:"event,omitempty"`
	Replay           []AgentEvent        `json:"replay,omitempty"`
	A2UI             *A2UIEnvelope       `json:"a2ui,omitempty"`
	A2UIReplay       []A2UIEnvelope      `json:"a2uiReplay,omitempty"`
	A2UIAction       *A2UIActionEnvelope `json:"a2uiAction,omitempty"`
	A2UIActionResult *A2UIActionResult   `json:"a2uiActionResult,omitempty"`
	A2UIAbort        *A2UIAbortEnvelope  `json:"a2uiAbort,omitempty"`
	Reason           string              `json:"reason,omitempty"`
	Error            *A2UIError          `json:"error,omitempty"`
	Clients          int                 `json:"clients,omitempty"`
}

func NowISO() string {
	return time.Now().UTC().Format(time.RFC3339Nano)
}
