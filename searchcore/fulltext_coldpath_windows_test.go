//go:build windows

package main

import (
	"context"
	"testing"
)

func testBlugeIndexerForColdPath(t *testing.T) *blugeIndexer {
	t.Helper()
	return &blugeIndexer{
		cfg: fullTextConfig{
			MaxFileSizeBytes: 16 * 1024 * 1024,
			HardReadLimit:    32 * 1024 * 1024,
			FilterConfig: fullTextFilterResolved{
				HotExts:  map[string]struct{}{"txt": {}, "go": {}},
				ColdExts: map[string]struct{}{"pdf": {}, "docx": {}, "xlsx": {}},
			},
		},
	}
}

func TestShouldIndexByColdPathSizeBudgets(t *testing.T) {
	b := testBlugeIndexerForColdPath(t)

	if !b.shouldIndexByColdPath(`C:\docs\notes.txt`, 3*1024*1024) {
		t.Fatal("txt within plain budget should index")
	}
	if b.shouldIndexByColdPath(`C:\docs\huge.txt`, 17*1024*1024) {
		t.Fatal("txt over plain budget should skip")
	}
	if !b.shouldIndexByColdPath(`C:\docs\paper.pdf`, 20*1024*1024) {
		t.Fatal("pdf within pdf budget should index")
	}
	if b.shouldIndexByColdPath(`C:\docs\huge.pdf`, 40*1024*1024) {
		t.Fatal("pdf over pdf budget should skip")
	}
	if !b.shouldIndexByColdPath(`C:\docs\sheet.xlsx`, 10*1024*1024) {
		t.Fatal("xlsx within office budget should index")
	}
}

func TestShouldIndexByColdPathExtensionWhitelist(t *testing.T) {
	b := testBlugeIndexerForColdPath(t)
	if b.shouldIndexByColdPath(`C:\docs\image.jpg`, 1024) {
		t.Fatal("non-whitelisted ext should skip")
	}
}

func TestShouldDeferColdTaskRouting(t *testing.T) {
	b := testBlugeIndexerForColdPath(t)
	b.cfg.ColdIdleDefer = true
	b.coldTasks = make(chan indexTask, 4)
	b.ctx, b.cancel = context.WithCancel(context.Background())

	hot := indexTask{Path: `C:\docs\main.go`, Initial: true}
	cold := indexTask{Path: `C:\docs\report.pdf`, Initial: true}
	if b.shouldDeferColdTask(hot) {
		t.Fatal("hot ext should not defer")
	}
	if !b.shouldDeferColdTask(cold) {
		t.Fatal("cold ext should defer when cold idle enabled")
	}
	if b.shouldDeferColdTask(indexTask{Path: `C:\docs\report.pdf`, Delete: true}) {
		t.Fatal("delete tasks must not defer")
	}
	b.cancel()
}
