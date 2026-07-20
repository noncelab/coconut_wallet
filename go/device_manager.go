package bridge

import (
	"fmt"
	"io"
	"sync"

	"github.com/BitBoxSwiss/bitbox02-api-go/api/firmware"
)

type deviceEntry struct {
	Device   *firmware.Device
	Config   *inMemoryConfig
	Comm     *deviceComm
}

type deviceComm struct {
	adapter io.Closer
}

type deviceManager struct {
	mu      sync.RWMutex
	devices map[string]*deviceEntry
	counter uint64
}

func newDeviceManager() *deviceManager {
	return &deviceManager{
		devices: make(map[string]*deviceEntry),
	}
}

func (dm *deviceManager) add(device *firmware.Device, config *inMemoryConfig, comm *deviceComm) string {
	dm.mu.Lock()
	defer dm.mu.Unlock()
	dm.counter++
	id := fmt.Sprintf("bb02_%d", dm.counter)
	dm.devices[id] = &deviceEntry{
		Device: device,
		Config: config,
		Comm:   comm,
	}
	return id
}

func (dm *deviceManager) get(id string) (*deviceEntry, error) {
	dm.mu.RLock()
	defer dm.mu.RUnlock()
	entry, ok := dm.devices[id]
	if !ok {
		return nil, fmt.Errorf("device %s not found", id)
	}
	return entry, nil
}

func (dm *deviceManager) remove(id string) error {
	dm.mu.Lock()
	defer dm.mu.Unlock()
	entry, ok := dm.devices[id]
	if !ok {
		return fmt.Errorf("device %s not found", id)
	}
	if entry.Comm != nil && entry.Comm.adapter != nil {
		entry.Comm.adapter.Close()
	}
	delete(dm.devices, id)
	return nil
}
