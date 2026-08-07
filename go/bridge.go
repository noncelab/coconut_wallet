package bridge

import (
	"bytes"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"io"
	"strings"
	"sync"

	"github.com/BitBoxSwiss/bitbox02-api-go/api/common"
	"github.com/BitBoxSwiss/bitbox02-api-go/api/firmware"
	"github.com/BitBoxSwiss/bitbox02-api-go/api/firmware/messages"
	"github.com/BitBoxSwiss/bitbox02-api-go/communication/u2fhid"
	"github.com/BitBoxSwiss/bitbox02-api-go/util/semver"
	"github.com/btcsuite/btcd/btcutil/psbt"
	"github.com/btcsuite/btcd/wire"
)

var (
	manager      = newDeviceManager()
	logger       = newBridgeLogger()
	prevTxStore  = make(map[string]map[int]string) // deviceID -> inputIndex -> rawTxHex
	prevTxStoreMu sync.RWMutex
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
		logger.Info(fmt.Sprintf("Init failed for device %s: %v", deviceID, err))
		return "", fmt.Errorf("init failed: %w", err)
	}
	logger.Info(fmt.Sprintf("Init succeeded for device %s", deviceID))

	// Best-effort: fetch device name after Noise handshake is established.
	deviceName := ""
	if info, err := entry.Device.DeviceInfo(); err == nil {
		deviceName = info.Name
		logger.Info(fmt.Sprintf("DeviceInfo: name=%q, version=%q, initialized=%v", info.Name, info.Version, info.Initialized))
	} else {
		logger.Info(fmt.Sprintf("DeviceInfo error: %v", err))
	}

	result := map[string]interface{}{
		"pairing_code": nil,
		"name":         deviceName,
	}
	b, err := json.Marshal(result)
	if err != nil {
		return "", err
	}
	return string(b), nil
}

// RootFingerprint returns the keystore's root fingerprint as a hex string.
func RootFingerprint(deviceID string) (string, error) {
	entry, err := manager.get(deviceID)
	if err != nil {
		return "", err
	}

	fp, err := entry.Device.RootFingerprint()
	if err != nil {
		return "", fmt.Errorf("root fingerprint failed: %w", err)
	}

	return hex.EncodeToString(fp), nil
}

// RestoreFromMnemonic restores the device from the built-in simulator mnemonic.
func RestoreFromMnemonic(deviceID string) error {
	entry, err := manager.get(deviceID)
	if err != nil {
		return err
	}
	logger.Info("RestoreFromMnemonic: calling device.RestoreFromMnemonic()")
	err = entry.Device.RestoreFromMnemonic()
	if err != nil {
		logger.Info(fmt.Sprintf("RestoreFromMnemonic: error: %v", err))
	} else {
		logger.Info("RestoreFromMnemonic: success")
	}
	return err
}

// SetPassword creates a new random wallet with the given seed length (16 or 32 bytes).
func SetPassword(deviceID string, seedLen int64) error {
	entry, err := manager.get(deviceID)
	if err != nil {
		return err
	}
	return entry.Device.SetPassword(int(seedLen))
}

// ChannelHashVerify confirms the pairing channel hash from the host side.
// Must be called after Init() before any other device operations.
func ChannelHashVerify(deviceID string, ok bool) error {
	entry, err := manager.get(deviceID)
	if err != nil {
		return err
	}
	entry.Device.ChannelHashVerify(ok)
	return nil
}

// DeviceInitialized returns true if the device has a seed loaded.
func DeviceInitialized(deviceID string) (bool, error) {
	entry, err := manager.get(deviceID)
	if err != nil {
		return false, err
	}
	info, err := entry.Device.DeviceInfo()
	if err != nil {
		return false, err
	}
	return info.Initialized, nil
}

// BTCXPub returns the extended public key at the given derivation path.
func BTCXPub(deviceID string, coin int64, keypath string, xpubType int64, display bool) (string, error) {
	entry, err := manager.get(deviceID)
	if err != nil {
		return "", err
	}

	btcCoin, err := parseCoin(coin)
	if err != nil {
		return "", err
	}

	kp, err := parseKeypath(keypath)
	if err != nil {
		return "", err
	}

	pubType, err := parseXPubType(xpubType)
	if err != nil {
		return "", err
	}

	xpub, err := entry.Device.BTCXPub(btcCoin, kp, pubType, display)
	if err != nil {
		return "", err
	}

	result := map[string]string{"xpub": xpub}
	b, _ := json.Marshal(result)
	return string(b), nil
}

// BTCAddress returns a Bitcoin address for the given keypath and script type.
func BTCAddress(deviceID string, coin int64, keypath string, scriptType string, display bool) (string, error) {
	entry, err := manager.get(deviceID)
	if err != nil {
		return "", err
	}

	btcCoin, err := parseCoin(coin)
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

	addr, err := entry.Device.BTCAddress(btcCoin, kp, sc, display)
	if err != nil {
		return "", err
	}

	result := map[string]string{"address": addr}
	b, _ := json.Marshal(result)
	return string(b), nil
}

// BTCSignPSBT signs a PSBT. Returns the signed PSBT bytes.
func BTCSignPSBT(deviceID string, coin int64, psbtBytes []byte, formatUnit int64) ([]byte, error) {
	entry, err := manager.get(deviceID)
	if err != nil {
		return nil, err
	}

	btcCoin, err := parseCoin(coin)
	if err != nil {
		return nil, err
	}

	logger.Info(fmt.Sprintf("BTCSignPSBT: parsing %d bytes", len(psbtBytes)))
	psbtPacket, err := psbt.NewFromRawBytes(bytes.NewReader(psbtBytes), false)
	if err != nil {
		logger.Info("BTCSignPSBT: parse failed, normalizing PSBT")
		normalized := normalizePsbtKeys(psbtBytes)
		if normalized != nil {
			logger.Info(fmt.Sprintf("BTCSignPSBT: normalized to %d bytes", len(normalized)))
			psbtPacket, err = psbt.NewFromRawBytes(bytes.NewReader(normalized), false)
		}
		if err != nil {
			return nil, fmt.Errorf("psbt decode: %w", err)
		}
	}
	logger.Info("BTCSignPSBT: parsed ok, calling device API")

	var fu messages.BTCSignInitRequest_FormatUnit
	switch formatUnit {
	case 1:
		fu = messages.BTCSignInitRequest_SAT
	default:
		fu = messages.BTCSignInitRequest_DEFAULT
	}

	opts := &firmware.PSBTSignOptions{
		FormatUnit: fu,
	}

	if psbtPacket.UnsignedTx == nil {
		return nil, fmt.Errorf("psbt has nil UnsignedTx")
	}
	logger.Info(fmt.Sprintf("BTCSignPSBT: UnsignedTx ok, inputs=%d outputs=%d psbtInputs=%d psbtOutputs=%d",
		len(psbtPacket.UnsignedTx.TxIn), len(psbtPacket.UnsignedTx.TxOut),
		len(psbtPacket.Inputs), len(psbtPacket.Outputs)))

	// Check input details
	for i, in := range psbtPacket.Inputs {
		hasWitness := in.WitnessUtxo != nil
		var pkScriptLen int
		if hasWitness {
			pkScriptLen = len(in.WitnessUtxo.PkScript)
		}
		hasBip32 := len(in.Bip32Derivation) > 0
		var fp uint32
		if hasBip32 && in.Bip32Derivation[0] != nil {
			fp = in.Bip32Derivation[0].MasterKeyFingerprint
		}
		logger.Info(fmt.Sprintf("BTCSignPSBT: input[%d] witnessUtxo=%v pkScript=%db bip32Deriv=%d fp=%08x",
			i, hasWitness, pkScriptLen, len(in.Bip32Derivation), fp))
	}

	// Inject NonWitnessUtxo from stored prevtx hexes
	if err := injectPrevTxsIntoPsbt(deviceID, psbtPacket); err != nil {
		return nil, err
	}

	logger.Info(fmt.Sprintf("BTCSignPSBT: calling device.BTCSignPSBT coin=%v", btcCoin))

	var sigErr error
	func() {
		defer func() {
			if r := recover(); r != nil {
				sigErr = fmt.Errorf("panic in BTCSignPSBT: %v", r)
				logger.Error("BTCSignPSBT: recovered from panic", sigErr)
			}
		}()
		sigErr = entry.Device.BTCSignPSBT(btcCoin, psbtPacket, opts)
	}()
	if sigErr != nil {
		return nil, fmt.Errorf("psbt sign: %w", sigErr)
	}
	logger.Info("BTCSignPSBT: device signed ok")

	var buf bytes.Buffer
	if err := psbtPacket.Serialize(&buf); err != nil {
		return nil, fmt.Errorf("psbt serialize: %w", err)
	}
	return buf.Bytes(), nil
}

// BTCSignMessage signs a message.
func BTCSignMessage(deviceID string, coin int64, keypath string, scriptType string, message []byte) (string, error) {
	entry, err := manager.get(deviceID)
	if err != nil {
		return "", err
	}

	btcCoin, err := parseCoin(coin)
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

	result, err := entry.Device.BTCSignMessage(btcCoin, sc, message)
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

func parseCoin(coin int64) (messages.BTCCoin, error) {
	switch coin {
	case 0:
		return messages.BTCCoin_BTC, nil
	case 1:
		return messages.BTCCoin_TBTC, nil
	case 2:
		return messages.BTCCoin_LTC, nil
	case 3:
		return messages.BTCCoin_TLTC, nil
	case 4:
		return messages.BTCCoin_RBTC, nil
	default:
		return messages.BTCCoin_BTC, fmt.Errorf("unknown coin: %d", coin)
	}
}

func parseXPubType(t int64) (messages.BTCPubRequest_XPubType, error) {
	switch t {
	case 0:
		return messages.BTCPubRequest_TPUB, nil
	case 1:
		return messages.BTCPubRequest_XPUB, nil
	case 2:
		return messages.BTCPubRequest_YPUB, nil
	case 3:
		return messages.BTCPubRequest_ZPUB, nil
	case 4:
		return messages.BTCPubRequest_VPUB, nil
	case 5:
		return messages.BTCPubRequest_UPUB, nil
	case 6:
		return messages.BTCPubRequest_CAPITAL_VPUB, nil
	case 7:
		return messages.BTCPubRequest_CAPITAL_ZPUB, nil
	case 8:
		return messages.BTCPubRequest_CAPITAL_UPUB, nil
	case 9:
		return messages.BTCPubRequest_CAPITAL_YPUB, nil
	default:
		return messages.BTCPubRequest_XPUB, fmt.Errorf("unknown xpub type: %d", t)
	}
}

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

// normalizePsbtKeys strips proprietary keys (0xFC) from PSBT global map
// so that btcd/btcutil parser accepts the PSBT.
func normalizePsbtKeys(data []byte) []byte {
	if len(data) < 6 || data[0] != 0x70 || data[1] != 0x73 || data[2] != 0x62 || data[3] != 0x74 || data[4] != 0xff {
		return nil
	}

	// split: magic (5 bytes) | global keypairs | 0x00 separator | inputs | outputs
	pos := 5

	var safeRead func(int) (uint64, int)
	safeRead = func(p int) (uint64, int) {
		if p >= len(data) {
			return 0, p
		}
		b := data[p]
		if b < 0xfd {
			return uint64(b), p + 1
		}
		if b == 0xfd && p+2 < len(data) {
			return uint64(data[p+1]) | uint64(data[p+2])<<8, p + 3
		}
		if b == 0xfe && p+4 < len(data) {
			return uint64(data[p+1]) | uint64(data[p+2])<<8 | uint64(data[p+3])<<16 | uint64(data[p+4])<<24, p + 5
		}
		return 0, p
	}

	var kept bytes.Buffer

	for pos < len(data) && data[pos] != 0x00 {
		start := pos

		keyLen, newPos := safeRead(pos)
		pos = newPos
		if keyLen == 0 || pos+int(keyLen) > len(data) {
			return nil
		}
		keyType := data[pos]
		pos += int(keyLen)

		valLen, newPos := safeRead(pos)
		pos = newPos
		if pos+int(valLen) > len(data) {
			return nil
		}
		pos += int(valLen)

		if keyType != 0xfc {
			kept.Write(data[start:pos])
		}
	}

	if pos >= len(data) || data[pos] != 0x00 {
		return nil
	}

	var out bytes.Buffer
	out.Write(data[:5]) // magic
	out.Write(kept.Bytes())
	out.Write(data[pos:]) // separator + rest
	return out.Bytes()
}

// SetPrevTxHex stores a previous transaction raw hex for a given device and input index.
// These will be injected as NonWitnessUtxo into the PSBT before signing.
func SetPrevTxHex(deviceID string, inputIndex int, rawTxHex string) {
	prevTxStoreMu.Lock()
	defer prevTxStoreMu.Unlock()
	if prevTxStore[deviceID] == nil {
		prevTxStore[deviceID] = make(map[int]string)
	}
	prevTxStore[deviceID][inputIndex] = rawTxHex
}

// ClearPrevTxHexes clears stored prevtx hexes for a device.
func ClearPrevTxHexes(deviceID string) {
	prevTxStoreMu.Lock()
	defer prevTxStoreMu.Unlock()
	delete(prevTxStore, deviceID)
}

// injectPrevTxsIntoPsbt adds NonWitnessUtxo to PSBT inputs using stored prevtx hexes.
func injectPrevTxsIntoPsbt(deviceID string, p *psbt.Packet) error {
	prevTxStoreMu.RLock()
	devicePrevTxs := prevTxStore[deviceID]
	prevTxStoreMu.RUnlock()

	if devicePrevTxs == nil {
		return nil
	}

	for inputIndex, rawTxHex := range devicePrevTxs {
		if inputIndex >= len(p.Inputs) {
			return fmt.Errorf("prevtx input index %d out of range (PSBT has %d inputs)", inputIndex, len(p.Inputs))
		}
		if p.Inputs[inputIndex].NonWitnessUtxo != nil {
			continue // already has NonWitnessUtxo
		}
		rawTxBytes, err := hex.DecodeString(rawTxHex)
		if err != nil {
			return fmt.Errorf("prevtx[%d]: invalid hex: %w", inputIndex, err)
		}
		msgTx := wire.NewMsgTx(2)
		if err := msgTx.Deserialize(bytes.NewReader(rawTxBytes)); err != nil {
			return fmt.Errorf("prevtx[%d]: deserialize: %w", inputIndex, err)
		}
		p.Inputs[inputIndex].NonWitnessUtxo = msgTx
		logger.Info(fmt.Sprintf("BTCSignPSBT: injected NonWitnessUtxo for input[%d]", inputIndex))
	}
	return nil
}

// Ensure unused imports don't cause errors
var _ = common.ProductBitBox02PlusMulti
var _ = io.Discard
