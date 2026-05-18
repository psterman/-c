package main

import "strings"

func shouldRunHeavyFullText(keyword string) bool {
	return len([]rune(strings.TrimSpace(keyword))) >= 3
}

func isClipboardItem(it map[string]any) bool {
	return strVal(it["originalDataType"]) == "clipboard"
}

func isFulltextItem(it map[string]any) bool {
	return strVal(it["originalDataType"]) == "fulltext"
}

func isFileItem(it map[string]any) bool {
	od := strVal(it["originalDataType"])
	dt := strVal(it["DataType"])
	return od == "file" || dt == "file" || dt == "folder" || strVal(it["Source"]) == "文件" || strVal(it["Source"]) == "文件夹" || strVal(it["Source"]) == "文件路径"
}

