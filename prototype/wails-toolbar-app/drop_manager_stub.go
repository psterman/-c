//go:build !windows

package main

import "context"

type dropManager struct{}

func newDropManager(ctx context.Context) *dropManager {
	_ = ctx
	return &dropManager{}
}

func (m *dropManager) start() error {
	return nil
}

func (m *dropManager) stop() {}
