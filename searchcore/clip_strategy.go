package main

import (
	"net/url"
	"regexp"
	"strings"
	"time"
)

const (
	clipRecentWindow = 3 * time.Minute
	clipIndexMaxRunes = 200
)

var (
	reTokenLike  = regexp.MustCompile(`(?i)^[A-Za-z0-9_\-]{24,}$`)
	reBase64Like = regexp.MustCompile(`(?i)^[A-Za-z0-9+/=]{48,}$`)
)

func clipNormalizeForIndex(s string) string {
	r := []rune(strings.TrimSpace(s))
	if len(r) > clipIndexMaxRunes {
		return string(r[:clipIndexMaxRunes])
	}
	return string(r)
}

func clipStrategyTag(content string) string {
	c := strings.TrimSpace(content)
	if c == "" {
		return "plain_text"
	}
	if isURLLike(c) {
		return "url"
	}
	if isPathLikeLoose(c) {
		return "path"
	}
	if reTokenLike.MatchString(c) {
		return "token"
	}
	if reBase64Like.MatchString(c) {
		return "base64"
	}
	if len([]rune(c)) > clipIndexMaxRunes {
		return "large_text"
	}
	cl := strings.ToLower(c)
	if strings.Contains(cl, "func ") || strings.Contains(cl, "class ") || strings.Contains(cl, "import ") || strings.Contains(cl, "=>") || strings.Contains(cl, "{") {
		return "code"
	}
	return "plain_text"
}

func isURLLike(s string) bool {
	trimmed := strings.TrimSpace(s)
	if trimmed == "" {
		return false
	}
	prefixProbe := strings.ToLower(trimmed)
	if !strings.HasPrefix(prefixProbe, "http://") && !strings.HasPrefix(prefixProbe, "https://") {
		return false
	}
	u, err := url.Parse(trimmed)
	return err == nil && (u.Scheme == "http" || u.Scheme == "https") && u.Host != ""
}

func isPathLikeLoose(s string) bool {
	x := strings.TrimSpace(s)
	if x == "" {
		return false
	}
	if strings.HasPrefix(x, `\\`) {
		return true
	}
	if len(x) >= 3 && ((x[1] == ':' && (x[2] == '\\' || x[2] == '/'))) {
		return true
	}
	return false
}

func parseClipTime(item map[string]any) time.Time {
	candidates := []string{
		strVal(item["Timestamp"]),
	}
	if m, ok := item["Metadata"].(map[string]any); ok && m != nil {
		candidates = append(candidates, strVal(m["Timestamp"]))
	}
	layouts := []string{
		"2006-01-02 15:04:05",
		"2006-01-02T15:04:05",
		time.RFC3339,
		"2006/01/02 15:04:05",
	}
	for _, raw := range candidates {
		s := strings.TrimSpace(raw)
		if s == "" {
			continue
		}
		for _, layout := range layouts {
			if t, err := time.ParseInLocation(layout, s, time.Local); err == nil {
				return t
			}
		}
	}
	return time.Time{}
}

func clipWeakMatch(keyword string, item map[string]any) bool {
	kw := strings.ToLower(strings.TrimSpace(keyword))
	if kw == "" {
		return true
	}
	title := strings.ToLower(strVal(item["Title"]))
	content := strings.ToLower(strVal(item["Content"]))
	if strings.Contains(title, kw) || strings.Contains(content, kw) {
		return true
	}
	return len([]rune(kw)) <= 2
}

func enrichClipboardItemStrategy(item map[string]any, keyword string) {
	content := strVal(item["Content"])
	tag := clipStrategyTag(content)
	item["StrategyTag"] = tag
	item["AnchorClass"] = "clip_history"
	item["RankReason"] = "clip_history_match"
	item["SourceRank"] = "clipboard"

	if tag == "large_text" {
		r := []rune(strings.TrimSpace(content))
		if len(r) > clipIndexMaxRunes {
			item["Preview"] = string(r[:clipIndexMaxRunes]) + "..."
		} else {
			item["Preview"] = string(r)
		}
	} else {
		item["Preview"] = content
	}
	if tag == "url" {
		if u, err := url.Parse(strings.TrimSpace(content)); err == nil && u.Host != "" {
			if m, ok := item["Metadata"].(map[string]any); ok && m != nil {
				m["UrlDomain"] = strings.ToLower(u.Host)
				m["UrlPath"] = u.Path
			}
		}
	}

	if tag == "token" || tag == "base64" {
		item["ClipLayer"] = "history"
		return
	}

	ts := parseClipTime(item)
	if !ts.IsZero() && time.Since(ts) <= clipRecentWindow {
		item["ClipLayer"] = "recent_buffer"
		item["AnchorClass"] = "clip_recent"
		if clipWeakMatch(keyword, item) {
			item["RankReason"] = "clip_recent_guard"
		} else {
			item["RankReason"] = "clip_recent"
		}
		return
	}
	item["ClipLayer"] = "history"
}
