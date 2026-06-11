//go:build !windows

package main

func (b *blugeIndexer) readBudgetForPath(path string) int64 {
	if b == nil {
		return 0
	}
	if b.cfg.HardReadLimit > 0 {
		return b.cfg.HardReadLimit
	}
	return b.cfg.MaxFileSizeBytes
}
