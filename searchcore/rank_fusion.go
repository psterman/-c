package main

import (
	"sort"
	"strings"
)

const rrfK = 5.0

type rankedItem struct {
	item      map[string]any
	source    string
	sourceIdx int
	sourceRk  int
	rrf       float64
	anchor    float64
	total     float64
}

func anchorScoreForItem(keyword string, source string, it map[string]any) float64 {
	kw := strings.ToLower(strings.TrimSpace(keyword))
	title := strings.ToLower(strVal(it["Title"]))
	content := strings.ToLower(strVal(it["Content"]))
	switch source {
	case "file":
		if kw != "" && title == kw {
			return 1000
		}
		if kw != "" && strings.HasPrefix(title, kw) {
			return 920
		}
		if kw != "" && strings.Contains(content, kw) {
			return 860
		}
		return 820
	case "fulltext":
		if kw != "" && strings.Contains(content, kw) {
			return 560
		}
		return 520
	case "clipboard":
		if strVal(it["ClipLayer"]) == "recent_buffer" && clipWeakMatch(keyword, it) {
			return 640
		}
		if kw != "" && strings.Contains(title, kw) {
			return 590
		}
		return 540
	default:
		return 420
	}
}

func scoreRankedItem(keyword string, source string, it map[string]any, rk int, idx int) rankedItem {
	rrf := 1.0 / (rrfK + float64(rk))
	anchor := anchorScoreForItem(keyword, source, it)
	total := anchor + (rrf * 400.0)
	if source == "clipboard" && strVal(it["ClipLayer"]) == "recent_buffer" && clipWeakMatch(keyword, it) {
		total += 25
	}
	it["SourceRank"] = source
	it["RankReason"] = "rrf_blend"
	it["AnchorClass"] = source
	it["UnifiedScore"] = total
	return rankedItem{
		item:      it,
		source:    source,
		sourceIdx: idx,
		sourceRk:  rk,
		rrf:       rrf,
		anchor:    anchor,
		total:     total,
	}
}

func sortByTotalDesc(items []rankedItem) {
	sort.SliceStable(items, func(i, j int) bool {
		if items[i].total == items[j].total {
			return items[i].sourceRk < items[j].sourceRk
		}
		return items[i].total > items[j].total
	})
}

func popBest(items []rankedItem, used map[string]struct{}) (rankedItem, bool) {
	for _, it := range items {
		key := strVal(it.item["originalDataType"]) + "|" + strVal(it.item["ID"]) + "|" + strVal(it.item["Title"])
		if _, ok := used[key]; ok {
			continue
		}
		used[key] = struct{}{}
		return it, true
	}
	return rankedItem{}, false
}

func rankAllUnified(merged []map[string]any, keyword string) []map[string]any {
	files := make([]map[string]any, 0)
	fulltexts := make([]map[string]any, 0)
	clips := make([]map[string]any, 0)
	others := make([]map[string]any, 0)
	for _, it := range merged {
		if isClipboardItem(it) {
			enrichClipboardItemStrategy(it, keyword)
			clips = append(clips, it)
			continue
		}
		if isFulltextItem(it) {
			fulltexts = append(fulltexts, it)
			continue
		}
		if isFileItem(it) {
			files = append(files, it)
			continue
		}
		others = append(others, it)
	}

	if len(files) > 0 && strings.TrimSpace(keyword) != "" {
		finalizeFilePathsResults(files, keyword)
		applyExeNameBonus(files, keyword)
		sortFileMaps(files, keyword)
	}
	applyParentDirectoryCollapse(files)
	applyTop9CategoryQuota(files)
	sortOtherMaps(others)
	sortOtherMaps(fulltexts)

	fileRanks := make([]rankedItem, 0, len(files))
	for i, it := range files {
		fileRanks = append(fileRanks, scoreRankedItem(keyword, "file", it, i+1, i))
	}
	fullRanks := make([]rankedItem, 0, len(fulltexts))
	for i, it := range fulltexts {
		fullRanks = append(fullRanks, scoreRankedItem(keyword, "fulltext", it, i+1, i))
	}
	clipRanks := make([]rankedItem, 0, len(clips))
	recentItems := make([]map[string]any, 0, len(clips))
	historyItems := make([]map[string]any, 0, len(clips))
	for _, it := range clips {
		if strVal(it["ClipLayer"]) == "recent_buffer" {
			recentItems = append(recentItems, it)
			continue
		}
		historyItems = append(historyItems, it)
	}
	rk := 1
	idx := 0
	for _, it := range recentItems {
		clipRanks = append(clipRanks, scoreRankedItem(keyword, "clipboard", it, rk, idx))
		rk++
		idx++
	}
	for _, it := range historyItems {
		clipRanks = append(clipRanks, scoreRankedItem(keyword, "clipboard", it, rk, idx))
		rk++
		idx++
	}
	otherRanks := make([]rankedItem, 0, len(others))
	for i, it := range others {
		otherRanks = append(otherRanks, scoreRankedItem(keyword, "other", it, i+1, i))
	}
	sortByTotalDesc(fileRanks)
	sortByTotalDesc(fullRanks)
	sortByTotalDesc(clipRanks)
	sortByTotalDesc(otherRanks)

	allStrong := append(append(append([]rankedItem{}, fileRanks...), clipRanks...), fullRanks...)
	allStrong = append(allStrong, otherRanks...)
	sortByTotalDesc(allStrong)

	used := map[string]struct{}{}
	outRanked := make([]rankedItem, 0, len(merged))

	// 1-3 强意图区
	for i := 0; i < 3; i++ {
		if p, ok := popBest(allStrong, used); ok {
			p.item["RankReason"] = "strong_intent"
			outRanked = append(outRanked, p)
		}
	}
	// 4-5 文件区
	for i := 0; i < 2; i++ {
		if p, ok := popBest(fileRanks, used); ok {
			p.item["RankReason"] = "file_lane"
			outRanked = append(outRanked, p)
		}
	}
	// 6-8 剪贴板/全文区（剪贴板 recent 优先）
	clipFull := append([]rankedItem{}, clipRanks...)
	clipFull = append(clipFull, fullRanks...)
	sortByTotalDesc(clipFull)
	for i := 0; i < 3; i++ {
		if p, ok := popBest(clipFull, used); ok {
			p.item["RankReason"] = "clip_fulltext_lane"
			outRanked = append(outRanked, p)
		}
	}
	// 其余补齐
	rest := append([]rankedItem{}, allStrong...)
	sortByTotalDesc(rest)
	for {
		p, ok := popBest(rest, used)
		if !ok {
			break
		}
		p.item["RankReason"] = "tail_fill"
		outRanked = append(outRanked, p)
	}

	out := make([]map[string]any, 0, len(outRanked))
	for i, it := range outRanked {
		it.item["UnifiedRank"] = i + 1
		out = append(out, it.item)
	}
	return out
}
