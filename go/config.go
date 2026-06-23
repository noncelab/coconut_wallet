package bridge

import (
	"encoding/hex"
	"encoding/json"
	"fmt"
	"sync"

	"github.com/BitBoxSwiss/bitbox02-api-go/api/firmware"
	"github.com/flynn/noise"
)

// configJSON is the serialized form of the noise config.
type configJSON struct {
	AppStaticPrivkey    string   `json:"app_static_privkey"`
	DeviceStaticPubkeys []string `json:"device_static_pubkeys"`
}

// inMemoryConfig implements firmware.ConfigInterface.
// All state is kept in-memory. JSON serialization via
// MarshalJSON/UnmarshalJSON bypasses gomobile's inability to bind *noise.DHKey.
type inMemoryConfig struct {
	mu                  sync.RWMutex
	appNoiseStaticKey   *noise.DHKey
	deviceStaticPubkeys [][]byte
}

func newInMemoryConfig() *inMemoryConfig {
	return &inMemoryConfig{}
}

func (c *inMemoryConfig) ContainsDeviceStaticPubkey(pubkey []byte) bool {
	c.mu.RLock()
	defer c.mu.RUnlock()
	for _, pk := range c.deviceStaticPubkeys {
		if len(pk) == len(pubkey) {
			match := true
			for i := range pk {
				if pk[i] != pubkey[i] {
					match = false
					break
				}
			}
			if match {
				return true
			}
		}
	}
	return false
}

func (c *inMemoryConfig) AddDeviceStaticPubkey(pubkey []byte) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	if !c.containsDeviceStaticPubkeyLocked(pubkey) {
		c.deviceStaticPubkeys = append(c.deviceStaticPubkeys, pubkey)
	}
	return nil
}

func (c *inMemoryConfig) containsDeviceStaticPubkeyLocked(pubkey []byte) bool {
	for _, pk := range c.deviceStaticPubkeys {
		if len(pk) == len(pubkey) {
			match := true
			for i := range pk {
				if pk[i] != pubkey[i] {
					match = false
					break
				}
			}
			if match {
				return true
			}
		}
	}
	return false
}

func (c *inMemoryConfig) GetAppNoiseStaticKeypair() *noise.DHKey {
	c.mu.RLock()
	defer c.mu.RUnlock()
	return c.appNoiseStaticKey
}

func (c *inMemoryConfig) SetAppNoiseStaticKeypair(key *noise.DHKey) error {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.appNoiseStaticKey = key
	return nil
}

func (c *inMemoryConfig) MarshalJSON() ([]byte, error) {
	c.mu.RLock()
	defer c.mu.RUnlock()

	cfg := configJSON{
		DeviceStaticPubkeys: make([]string, 0, len(c.deviceStaticPubkeys)),
	}
	if c.appNoiseStaticKey != nil {
		cfg.AppStaticPrivkey = hex.EncodeToString(c.appNoiseStaticKey.Private)
	}
	for _, pk := range c.deviceStaticPubkeys {
		cfg.DeviceStaticPubkeys = append(cfg.DeviceStaticPubkeys, hex.EncodeToString(pk))
	}
	return json.Marshal(cfg)
}

func (c *inMemoryConfig) UnmarshalJSON(data []byte) error {
	var cfg configJSON
	if err := json.Unmarshal(data, &cfg); err != nil {
		return err
	}

	c.mu.Lock()
	defer c.mu.Unlock()

	if cfg.AppStaticPrivkey != "" {
		privBytes, err := hex.DecodeString(cfg.AppStaticPrivkey)
		if err != nil {
			return fmt.Errorf("decode app_static_privkey: %w", err)
		}
		if len(privBytes) != 32 {
			return fmt.Errorf("app_static_privkey must be 32 bytes, got %d", len(privBytes))
		}
		var privKey [32]byte
		copy(privKey[:], privBytes)
		c.appNoiseStaticKey = &noise.DHKey{
			Private: privBytes,
			Public:  nil, // will be derived on use
		}
		_ = privKey
	}

	c.deviceStaticPubkeys = nil
	for _, hexPK := range cfg.DeviceStaticPubkeys {
		pk, err := hex.DecodeString(hexPK)
		if err != nil {
			return fmt.Errorf("decode device_static_pubkey: %w", err)
		}
		c.deviceStaticPubkeys = append(c.deviceStaticPubkeys, pk)
	}
	return nil
}

var _ firmware.ConfigInterface = (*inMemoryConfig)(nil)
