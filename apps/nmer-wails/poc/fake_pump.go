package poc

import (
	"sync"
	"time"
)

// FakePump emits a scripted AgentEvent sequence for POC 2.
type FakePump struct {
	mu      sync.Mutex
	running bool
	stopCh  chan struct{}
	emit    func(AgentEvent)
}

func NewFakePump(emit func(AgentEvent)) *FakePump {
	return &FakePump{emit: emit, stopCh: make(chan struct{})}
}

func (p *FakePump) Running() bool {
	p.mu.Lock()
	defer p.mu.Unlock()
	return p.running
}

func (p *FakePump) Start() {
	p.mu.Lock()
	if p.running {
		p.mu.Unlock()
		return
	}
	p.running = true
	p.stopCh = make(chan struct{})
	stop := p.stopCh
	emit := p.emit
	p.mu.Unlock()

	go func() {
		script := buildFakeScript()
		for _, ev := range script {
			select {
			case <-stop:
				return
			default:
			}
			if emit != nil {
				emit(ev)
			}
			time.Sleep(280 * time.Millisecond)
		}
		p.mu.Lock()
		p.running = false
		p.mu.Unlock()
	}()
}

func (p *FakePump) Stop() {
	p.mu.Lock()
	defer p.mu.Unlock()
	if !p.running {
		return
	}
	close(p.stopCh)
	p.running = false
}

func buildFakeScript() []AgentEvent {
	cardID := "poc-card-compare"
	turnID := 1
	seq := 0
	next := func(kind AgentEventKind, payload map[string]interface{}) AgentEvent {
		seq++
		return AgentEvent{
			Seq:    seq,
			Ts:     NowISO(),
			Kind:   kind,
			CardID: cardID,
			TurnID: turnID,
			Payload: payload,
		}
	}

	table := map[string]interface{}{
		"id":        "blk_cmp",
		"type":      "a2ui",
		"component": "ComparisonTable",
		"state":     "final",
		"source":    "heuristic",
		"turnId":    turnID,
		"props": map[string]interface{}{
			"columns": []interface{}{"项目", "Pocket 3", "Pocket 4"},
			"rows": []interface{}{
				[]interface{}{"传感器", "1 英寸", "1 英寸"},
				[]interface{}{"视频", "4K/120fps", "4K/240fps"},
				[]interface{}{"动态范围", "10 档", "14 档"},
			},
		},
	}

	chips := map[string]interface{}{
		"id":        "blk_chips",
		"type":      "a2ui",
		"component": "ActionChips",
		"state":     "final",
		"source":    "system",
		"turnId":    turnID,
		"props": map[string]interface{}{
			"actions": []interface{}{
				map[string]interface{}{
					"id": "chip1", "label": "补充对比维度", "intent": "prefill",
					"payload": map[string]interface{}{"text": "补充续航和配件生态"},
				},
				map[string]interface{}{
					"id": "chip2", "label": "缩短结论", "intent": "prefill",
					"payload": map[string]interface{}{"text": "用三句话总结怎么选"},
				},
			},
		},
	}

	return []AgentEvent{
		next(EventTaskStart, map[string]interface{}{"query": "比较 pocket4 和 3"}),
		next(EventStatus, map[string]interface{}{"text": "规划中…", "level": "info"}),
		next(EventReplyDelta, map[string]interface{}{"text": "## Pocket 4 vs Pocket 3\n\n"}),
		next(EventReplyDelta, map[string]interface{}{"text": "正在整理规格对比…\n"}),
		next(EventA2UI, map[string]interface{}{"block": table}),
		next(EventReplyFinal, map[string]interface{}{
			"markdown": "## Pocket 4 vs Pocket 3\n\n对比表见上方 A2UI；差价约 700 元，视频规格提升明显。",
		}),
		next(EventA2UI, map[string]interface{}{"block": chips}),
		next(EventStatus, map[string]interface{}{"text": "完成", "level": "info"}),
		next(EventTaskEnd, map[string]interface{}{"ok": true}),
	}
}
