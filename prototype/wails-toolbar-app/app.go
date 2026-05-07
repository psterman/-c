package main

import (
	"context"
	"path/filepath"
	"sort"
	"strings"

	"github.com/wailsapp/wails/v2/pkg/runtime"
)

type QuickAction struct {
	ID       string   `json:"id"`
	Label    string   `json:"label"`
	Desc     string   `json:"desc"`
	Keywords []string `json:"keywords"`
	Matched  bool     `json:"matched"`
	Score    int      `json:"score"`
}

type ProcessResult struct {
	OK      bool   `json:"ok"`
	Message string `json:"message"`
	Data    string `json:"data,omitempty"`
}

type App struct {
	ctx      context.Context
	commands []QuickAction
}

func NewApp() *App {
	return &App{
		commands: []QuickAction{
			{ID: "ocr", Label: "文字识别", Desc: "提取图片/PDF中的文字", Keywords: []string{"ocr", "识别", "提取", "图片文字"}},
			{ID: "summarize", Label: "归类总结", Desc: "按主题整理并总结内容", Keywords: []string{"总结", "归类", "摘要", "整理"}},
			{ID: "ask-ai", Label: "发送给AI", Desc: "把内容发送到 AI 进行问答", Keywords: []string{"ai", "提问", "问答", "解释"}},
			{ID: "translate", Label: "翻译", Desc: "中英互译或多语翻译", Keywords: []string{"翻译", "translate", "中译英", "英译中"}},
			{ID: "search", Label: "快速搜索", Desc: "在本地或网络执行搜索", Keywords: []string{"搜索", "search", "查找", "检索"}},
			{ID: "script", Label: "生成脚本", Desc: "根据描述生成脚本模板", Keywords: []string{"脚本", "代码", "生成", "自动化"}},
			{ID: "clipboard", Label: "剪贴板历史", Desc: "打开剪贴板管理面板", Keywords: []string{"剪贴板", "clipboard", "历史"}},
			{ID: "screenshot", Label: "智能截图", Desc: "截图并进入智能处理流程", Keywords: []string{"截图", "screen", "capture", "ocr"}},
		},
	}
}

func (a *App) startup(ctx context.Context) {
	a.ctx = ctx
}

func scoreAction(action QuickAction, q string) int {
	if q == "" {
		return 1
	}
	label := strings.ToLower(action.Label)
	if strings.HasPrefix(label, q) {
		return 120
	}
	if strings.Contains(label, q) {
		return 90
	}

	score := 0
	for _, k := range action.Keywords {
		kl := strings.ToLower(k)
		if strings.HasPrefix(kl, q) {
			if score < 80 {
				score = 80
			}
			continue
		}
		if strings.Contains(kl, q) {
			if score < 60 {
				score = 60
			}
		}
	}

	if score == 0 {
		for _, part := range strings.Fields(q) {
			if strings.Contains(label, part) {
				score += 20
			}
		}
	}
	return score
}

func (a *App) GetQuickActions(input string) []QuickAction {
	q := strings.ToLower(strings.TrimSpace(input))
	result := make([]QuickAction, 0, len(a.commands))

	for _, cmd := range a.commands {
		s := scoreAction(cmd, q)
		if q == "" {
			cmd.Score = 1
			cmd.Matched = false
			result = append(result, cmd)
			continue
		}
		if s > 0 {
			cmd.Score = s
			cmd.Matched = true
			result = append(result, cmd)
		}
	}

	sort.SliceStable(result, func(i, j int) bool {
		if result[i].Score == result[j].Score {
			return result[i].Label < result[j].Label
		}
		return result[i].Score > result[j].Score
	})

	if len(result) > 8 {
		result = result[:8]
	}
	if len(result) == 0 {
		for i := 0; i < len(a.commands) && i < 6; i++ {
			cmd := a.commands[i]
			cmd.Matched = false
			cmd.Score = 0
			result = append(result, cmd)
		}
	}
	return result
}

func (a *App) ExecuteAction(actionID string, input string) ProcessResult {
	id := strings.TrimSpace(actionID)
	if id == "" {
		return ProcessResult{OK: false, Message: "empty action id"}
	}
	return ProcessResult{
		OK:      true,
		Message: "action executed",
		Data:    "action=" + id + ", query=" + strings.TrimSpace(input),
	}
}

func (a *App) ProcessFile(path string, actionType string) ProcessResult {
	if strings.TrimSpace(path) == "" {
		return ProcessResult{OK: false, Message: "empty file path"}
	}
	name := filepath.Base(path)
	if strings.TrimSpace(actionType) == "" {
		actionType = "ocr"
	}
	return ProcessResult{
		OK:      true,
		Message: "stub processed",
		Data:    "action=" + actionType + ", file=" + name,
	}
}

func (a *App) MinimizeWindow() {
	if a.ctx != nil {
		runtime.WindowMinimise(a.ctx)
	}
}

func (a *App) FocusWindow() {
	if a.ctx != nil {
		runtime.WindowUnminimise(a.ctx)
		runtime.WindowShow(a.ctx)
		runtime.WindowCenter(a.ctx)
	}
}

func (a *App) SetPaletteExpanded(expanded bool, itemCount int) {
	if a.ctx == nil {
		return
	}

	width := 900
	height := 64
	if expanded {
		if itemCount < 1 {
			itemCount = 1
		}
		if itemCount > 8 {
			itemCount = 8
		}
		// Input area + result list rows + vertical paddings.
		height = 64 + itemCount*44 + 14
		if height > 420 {
			height = 420
		}
	}

	runtime.WindowSetSize(a.ctx, width, height)
}
