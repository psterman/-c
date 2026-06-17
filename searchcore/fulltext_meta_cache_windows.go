//go:build windows

package main

import (
	"sync"
	"time"
)

const defaultFileMetaCacheSize = 8192

type fileMetaCache struct {
	mu    sync.Mutex
	max   int
	order []string
	items map[string]fileFingerprint
}

func newFileMetaCache(max int) *fileMetaCache {
	if max <= 0 {
		max = defaultFileMetaCacheSize
	}
	return &fileMetaCache{
		max:   max,
		items: make(map[string]fileFingerprint, max/4),
	}
}

func (c *fileMetaCache) Get(id string) (fileFingerprint, bool) {
	if c == nil || id == "" {
		return fileFingerprint{}, false
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	fp, ok := c.items[id]
	if !ok {
		return fileFingerprint{}, false
	}
	c.touchLocked(id)
	return fp, true
}

func (c *fileMetaCache) Put(id string, fp fileFingerprint) {
	if c == nil || id == "" {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	if _, exists := c.items[id]; !exists {
		for len(c.items) >= c.max && len(c.order) > 0 {
			evict := c.order[0]
			c.order = c.order[1:]
			delete(c.items, evict)
		}
	}
	c.items[id] = fp
	c.touchLocked(id)
}

func (c *fileMetaCache) Delete(id string) {
	if c == nil || id == "" {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	delete(c.items, id)
	for i, k := range c.order {
		if k == id {
			c.order = append(c.order[:i], c.order[i+1:]...)
			break
		}
	}
}

func (c *fileMetaCache) Clear() {
	if c == nil {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	c.order = nil
	c.items = make(map[string]fileFingerprint, c.max/4)
}

func (c *fileMetaCache) TrimTo(target int) {
	if c == nil || target < 0 {
		return
	}
	c.mu.Lock()
	defer c.mu.Unlock()
	for len(c.items) > target && len(c.order) > 0 {
		evict := c.order[0]
		c.order = c.order[1:]
		delete(c.items, evict)
	}
}

func (c *fileMetaCache) touchLocked(id string) {
	for i, k := range c.order {
		if k == id {
			c.order = append(c.order[:i], c.order[i+1:]...)
			break
		}
	}
	c.order = append(c.order, id)
}

func (b *blugeIndexer) lookupFingerprint(path, id string) (fileFingerprint, bool) {
	if id == "" {
		id = docIDForPath(path)
	}
	if fp, ok := b.metaCache.Get(id); ok {
		return fp, true
	}
	if b.meta != nil {
		fp, ok, err := b.meta.Get(path)
		if err == nil && ok {
			b.metaCache.Put(id, fp)
			return fp, true
		}
	}
	return fileFingerprint{}, false
}

func (b *blugeIndexer) rememberFingerprint(path, id string, fp fileFingerprint) {
	if id == "" {
		id = docIDForPath(path)
	}
	b.metaCache.Put(id, fp)
	if b.meta != nil {
		_ = b.meta.Upsert(path, fp)
	}
}

func (b *blugeIndexer) forgetFingerprint(path, id string) {
	if id == "" {
		id = docIDForPath(path)
	}
	b.metaCache.Delete(id)
	if b.meta != nil {
		_ = b.meta.Delete(path)
	}
}

func (b *blugeIndexer) bumpIndexedFilesIfNew(path string) {
	if b.meta != nil {
		if _, ok, err := b.meta.Get(path); err == nil && ok {
			return
		}
	}
	// IndexedFiles 以 refreshIndexedCount（Bluge 实际文档数）为准，不在此递增避免虚高。
	b.mu.Lock()
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.mu.Unlock()
}
