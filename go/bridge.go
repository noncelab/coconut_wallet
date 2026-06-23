package bridge

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"strings"

	"github.com/BitBoxSwiss/bitbox02-api-go/api/common"
	"github.com/BitBoxSwiss/bitbox02-api-go/api/firmware"
	"github.com/BitBoxSwiss/bitbox02-api-go/api/firmware/messages"
	"github.com/BitBoxSwiss/bitbox02-api-go/communication/u2fhid"
	"github.com/BitBoxSwiss/bitbox02-api-go/util/semver"
	"github.com/btcsuite/btcd/btcutil/psbt"
)

var (
	manager = newDeviceManager()
	logger  = newBridgeLogger()
)

// SetLoggerEnabled toggles logging.
func SetLoggerEnabled(v bool) {
	logger.SetEnabled(v)
}

// Connect opens a connection to a BitBox02 device.
// Uses nil version/product — device info is queried via OP_INFO.
func Connect(transport Transport) (string, error) {
	return connectDevice(transport, nil, nil)
}

// ConnectWithInfo opens a connection with explicit product and version info.
// Use this for simulators or transports that don't provide USB HID descriptors.
// product: "btc-only" or "multi"
// version: e.g. "9.26.1"
func ConnectWithInfo(transport Transport, product string, version string) (string, error) {
	var p common.Product
	switch product {
	case "btc-only":
		p = common.ProductBitBox02BTCOnly
	default:
		p = common.ProductBitBox02Multi
	}

	v, err := semver.NewSemVerFromString(version)
	if err != nil {
		return "", fmt.Errorf("invalid version: %w", err)
	}

	return connectDevice(transport, v, &p)
}

func connectDevice(transport Transport, version *semver.SemVer, product *common.Product) (string, error) {
	adapter := newTransportAdapter(transport)
	comm := u2fhid.NewCommunication(adapter, 0xC1)

	config := newInMemoryConfig()

	device := firmware.NewDevice(
		version,
		product,
		config,
		comm,
		logger,
	)

	commWrapper := &deviceComm{
		adapter: adapter,
	}

	id := manager.add(device, config, commWrapper)
	return id, nil
}

// Init performs the Noise handshake and pairing.
func Init(deviceID string) (string, error) {
	entry, err := manager.get(deviceID)
	if err != nil {
		return "", err
	}

	if err := entry.Device.Init(); err != nil {
		return "", fmt.Errorf("init failed: %w", err)
	}

	result := map[string]interface{}{
		"pairing_code": nil,
	}
	b, err := json.Marshal(result)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// BTCXPub returns the extended public key at the given derivation path.
func BTCXPub(deviceID, keypath string) (string, error) {
	entry, err := manager.get(deviceID)
	if err != nil {
		return "", err
	}

	kp, err := parseKeypath(keypath)
	if err != nil {
		return "", err
	}

	xpub, err := entry.Device.BTCXPub(messages.BTCCoin_BTC, kp, messages.BTCPubRequest_XPUB, false)
	if err != nil {
		return "", err
	}

	result := map[string]string{"xpub": xpub}
	b, _ := json.Marshal(result)
	return string(b), nil
}

// BTCAddress returns a Bitcoin address for the given keypath and script type.
func BTCAddress(deviceID, keypath, scriptType string, display bool) (string, error) {
	entry, err := manager.get(deviceID)
	if err != nil {
		return "", err
	}

	kp, err := parseKeypath(keypath)
	if err != nil {
		return "", err
	}

	sc, err := parseScriptConfig(scriptType)
	if err != nil {
		return "", err
	}

	addr, err := entry.Device.BTCAddress(messages.BTCCoin_BTC, kp, sc, display)
	if err != nil {
		return "", err
	}

	result := map[string]string{"address": addr}
	b, _ := json.Marshal(result)
	return string(b), nil
}

// BTCSignPSBT signs a PSBT. Returns the signed PSBT bytes.
func BTCSignPSBT(deviceID string, psbtBytes []byte, formatUnit string) ([]byte, error) {
	entry, err := manager.get(deviceID)
	if err != nil {
		return nil, err
	}

	psbtPacket, err := psbt.NewFromRawBytes(bytes.NewReader(psbtBytes), false)
	if err != nil {
		return nil, fmt.Errorf("psbt decode: %w", err)
	}

	var fu messages.BTCSignInitRequest_FormatUnit
	switch formatUnit {
	case "sat":
		fu = messages.BTCSignInitRequest_SAT
	default:
		fu = messages.BTCSignInitRequest_DEFAULT
	}

	opts := &firmware.PSBTSignOptions{
		FormatUnit: fu,
	}

	if err := entry.Device.BTCSignPSBT(messages.BTCCoin_BTC, psbtPacket, opts); err != nil {
		return nil, fmt.Errorf("psbt sign: %w", err)
	}

	var buf bytes.Buffer
	if err := psbtPacket.Serialize(&buf); err != nil {
		return nil, fmt.Errorf("psbt serialize: %w", err)
	}
	return buf.Bytes(), nil
}

// BTCSignMessage signs a message.
func BTCSignMessage(deviceID, keypath, scriptType, message string) (string, error) {
	entry, err := manager.get(deviceID)
	if err != nil {
		return "", err
	}

	kp, err := parseKeypath(keypath)
	if err != nil {
		return "", err
	}

	sc, err := parseScriptConfigWithKeypath(scriptType, kp)
	if err != nil {
		return "", err
	}

	result, err := entry.Device.BTCSignMessage(messages.BTCCoin_BTC, sc, []byte(message))
	if err != nil {
		return "", err
	}

	b, err := json.Marshal(result)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// SaveConfig serializes the device's noise config to JSON.
func SaveConfig(deviceID string) (string, error) {
	entry, err := manager.get(deviceID)
	if err != nil {
		return "", err
	}
	b, err := entry.Config.MarshalJSON()
	if err != nil {
		return "", fmt.Errorf("marshal config: %w", err)
	}
	return string(b), nil
}

// LoadConfig loads a previously saved noise config from JSON.
func LoadConfig(deviceID, configJSON string) error {
	entry, err := manager.get(deviceID)
	if err != nil {
		return err
	}
	return entry.Config.UnmarshalJSON([]byte(configJSON))
}

// Disconnect closes the connection to a device.
func Disconnect(deviceID string) error {
	return manager.remove(deviceID)
}

// ListDevices returns device IDs of currently connected devices.
func ListDevices() (string, error) {
	manager.mu.RLock()
	defer manager.mu.RUnlock()
	var ids []string
	for id := range manager.devices {
		ids = append(ids, id)
	}
	b, _ := json.Marshal(map[string]interface{}{"devices": ids})
	return string(b), nil
}

// --- internal helpers ---

func parseKeypath(path string) ([]uint32, error) {
	parts := strings.Split(path, "/")
	if len(parts) == 0 || parts[0] != "m" {
		return nil, fmt.Errorf("keypath must start with 'm'")
	}
	var result []uint32
	for _, p := range parts[1:] {
		if p == "" {
			continue
		}
		var val uint32
		hardened := strings.HasSuffix(p, "'") || strings.HasSuffix(p, "h")
		p = strings.TrimRight(p, "'h")
		if _, err := fmt.Sscanf(p, "%d", &val); err != nil {
			return nil, fmt.Errorf("invalid keypath component: %s", p)
		}
		if hardened {
			val += 0x80000000
		}
		result = append(result, val)
	}
	return result, nil
}

func parseScriptConfig(scriptType string) (*messages.BTCScriptConfig, error) {
	var simpleType messages.BTCScriptConfig_SimpleType
	switch scriptType {
	case "p2wpkh":
		simpleType = messages.BTCScriptConfig_P2WPKH
	case "p2wpkh-p2sh":
		simpleType = messages.BTCScriptConfig_P2WPKH_P2SH
	case "p2tr":
		simpleType = messages.BTCScriptConfig_P2TR
	default:
		return nil, fmt.Errorf("unknown script type: %s", scriptType)
	}

	return &messages.BTCScriptConfig{
		Config: &messages.BTCScriptConfig_SimpleType_{
			SimpleType: simpleType,
		},
	}, nil
}

func parseScriptConfigWithKeypath(scriptType string, keypath []uint32) (*messages.BTCScriptConfigWithKeypath, error) {
	sc, err := parseScriptConfig(scriptType)
	if err != nil {
		return nil, err
	}
	return &messages.BTCScriptConfigWithKeypath{
		ScriptConfig: sc,
		Keypath:      keypath,
	}, nil
}

// Ensure unused imports don't cause errors
var _ = common.ProductBitBox02PlusMulti
var _ = io.Discard
