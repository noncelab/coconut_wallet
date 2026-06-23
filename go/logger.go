package bridge

import (
	"log"
	"sync/atomic"
)

type bridgeLogger struct {
	enabled atomic.Bool
}

func newBridgeLogger() *bridgeLogger {
	return &bridgeLogger{}
}

func (l *bridgeLogger) SetEnabled(v bool) {
	l.enabled.Store(v)
}

func (l *bridgeLogger) Error(msg string, err error) {
	if l.enabled.Load() {
		log.Printf("[bitbox02] ERROR: %s: %v", msg, err)
	}
}

func (l *bridgeLogger) Info(msg string) {
	if l.enabled.Load() {
		log.Printf("[bitbox02] INFO: %s", msg)
	}
}

func (l *bridgeLogger) Debug(msg string) {
	if l.enabled.Load() {
		log.Printf("[bitbox02] DEBUG: %s", msg)
	}
}
