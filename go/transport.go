package bridge

import (
	"fmt"
	"io"
)

// Transport is the interface that gomobile binds to native platforms.
// Uses the bitbox-wallet-app pattern: Read returns a new byte slice instead of
// filling a provided buffer (gomobile does not copy back modified []byte params).
type Transport interface {
	Read(n int) ([]byte, error)
	Write(p []byte) (int, error)
	Close() error
}

// transportAdapter wraps a Transport to implement io.ReadWriteCloser.
type transportAdapter struct {
	t Transport
}

func newTransportAdapter(t Transport) io.ReadWriteCloser {
	return &transportAdapter{t: t}
}

func (a *transportAdapter) Read(p []byte) (int, error) {
	data, err := a.t.Read(len(p))
	if err != nil {
		return 0, err
	}
	n := copy(p, data)
	if n == 0 && len(p) > 0 {
		return 0, fmt.Errorf("transport read returned 0 bytes")
	}
	return n, nil
}

func (a *transportAdapter) Write(p []byte) (int, error) {
	n, err := a.t.Write(p)
	if err != nil {
		return n, err
	}
	if n != len(p) {
		return n, fmt.Errorf("transport write short: wrote %d of %d bytes", n, len(p))
	}
	return n, nil
}

func (a *transportAdapter) Close() error {
	return a.t.Close()
}
