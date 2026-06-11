//go:build windows

package main

import (
	"strings"
)

type ReadBudgetTier string

const (
	ReadBudgetPlain  ReadBudgetTier = "plain"
	ReadBudgetOffice ReadBudgetTier = "office"
	ReadBudgetPDF    ReadBudgetTier = "pdf"
	ReadBudgetOCR    ReadBudgetTier = "ocr"
)

func classifyReadBudgetTier(ext string) ReadBudgetTier {
	e := strings.ToLower(strings.TrimPrefix(strings.TrimSpace(ext), "."))
	switch e {
	case "pdf":
		return ReadBudgetPDF
	case "docx", "xlsx", "pptx", "doc", "xls", "ppt":
		return ReadBudgetOffice
	default:
		return ReadBudgetPlain
	}
}

func (b *blugeIndexer) readBudgetForPath(path string) int64 {
	tier := classifyReadBudgetTier(pathExtLower(path))
	switch tier {
	case ReadBudgetPDF:
		if b.cfg.HardReadLimit > 0 && b.cfg.HardReadLimit < 32*1024*1024 {
			return b.cfg.HardReadLimit
		}
		return 32 * 1024 * 1024
	case ReadBudgetOffice:
		if b.cfg.MaxFileSizeBytes > 0 && b.cfg.MaxFileSizeBytes < 16*1024*1024 {
			return b.cfg.MaxFileSizeBytes
		}
		return 16 * 1024 * 1024
	default:
		if b.cfg.MaxFileSizeBytes > 0 {
			return b.cfg.MaxFileSizeBytes
		}
		return 4 * 1024 * 1024
	}
}
