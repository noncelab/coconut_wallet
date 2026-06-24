# BitBox02 Simulator Integration

> Coconut Wallet + BitBox02 hardware wallet integration via simulator (regtest)

## Overview

The BitBox02 integration spans four layers:

```
Dart (Flutter UI / ViewModel / Service)
  ↕ MethodChannel("bitbox02")
Native (Kotlin / Swift)
  ↕ gomobile (Bridge class)
Go Bridge (bridge.go)
  ↕ u2fhid + bitbox02-api-go
BitBox02 Simulator (Docker, TCP:15423)
```

Key dependencies:
- `go/go.mod`: `replace github.com/BitBoxSwiss/bitbox02-api-go => ../../bitbox02-api-go` (local clone)
- `go/go.mod`: `github.com/btcsuite/btcd/btcutil/psbt v1.1.10`
- gomobile bind output: `android/app/libs/bitboxbridge.aar` / `ios/Runner/bitboxbridge.xcframework`

---

## Files Changed

### Go Bridge (`go/`)

| File | Changes |
|------|---------|
| `bridge.go` | Coin parameter added to `BTCXPub`, `BTCAddress`, `BTCSignPSBT`, `BTCSignMessage`. Added `RootFingerprint()`, `RestoreFromMnemonic()`, `SetPassword()`, `ChannelHashVerify()`, `DeviceInitialized()`, `normalizePsbtKeys()`, panic recovery with `defer/recover`. |
| `logger.go` | Logging via `android.util.Log` (GoLog tag). |

### Native Handlers

| File | Changes |
|------|---------|
| `android/.../Bitbox02MethodHandler.kt` | Added `rootFingerprint`, `restoreFromMnemonic`, `setPassword`, `channelHashVerify`, `deviceInitialized` handlers. All existing handlers now pass coin value (Long) to Go bridge. `btcSignMessage` passes message as `ByteArray`. `btcSignPSBT` passes `formatUnit` as Long. |
| `ios/.../Bitbox02MethodHandler.swift` | Added `rootFingerprint` handler. Coin parameters already in place from original code. |

### Simulator (`simulator/`)

| File | Changes |
|------|---------|
| `Dockerfile` | Added `--platform=linux/amd64` for Apple Silicon compatibility. |

### Dart Layer

#### Service (`lib/services/hardware_wallet/`)

| File | Changes |
|------|---------|
| `bitbox02_device.dart` | Added `rootFingerprint()`, `restoreFromMnemonic()`, `setPassword()`, `channelHashVerify()`, `deviceInitialized()`. Fixed `btcXPub()` and `btcAddress()` to `jsonDecode` the Go bridge's JSON-wrapped response. Added `static BitBox02Device? lastConnected` for device reuse. |
| `bitbox02_types.dart` | `BitBox02Coin.rbtc(4)` exists for regtest (not used — see caveat #6). |
| `bitbox02_exceptions.dart` | (No changes) |

#### ViewModel (`lib/providers/view_model/hardware_wallet/`)

| File | Changes |
|------|---------|
| `bitbox02_connect_viewmodel.dart` | `channelHashVerify(ok: true)` called after `Init()`. Added `restoreWallet()` and `createWallet()` methods. Stores `_transport` for retry. Fingerprint fetched from device (`rootFingerprint()`) instead of hardcoded. Regtest uses `TBTC(1)` coin. Sets `BitBox02Device.lastConnected` when paired. |
| `bitbox02_sign_viewmodel.dart` | Added `transport` parameter. Added `_cleanPsbt()` to strip proprietary 0xFC keys from PSBT. Determines coin from `NetworkType` (TBTC for testnet/regtest). Checks `deviceInitialized()` and conditionally calls `restoreFromMnemonic()`. Reuses `lastConnected` device if available. Calls `channelHashVerify(ok: true)` and `RootFingerprint` as pre-flight checks. |

#### Screens (`lib/screens/`)

| File | Changes |
|------|---------|
| `hardware_wallet/bitbox02_connect_screen.dart` | Added "Restore from Mnemonic" and "Create New Wallet" buttons after pairing. Retry button uses stored transport. "Sign Test Transaction" passes transport to sign screen. |
| `hardware_wallet/bitbox02_sign_screen.dart` | `_buildTransactionSummaryCard()` now parses actual PSBT to display real amount, address, fee. Added `isFromSendFlow` flag — hides Mock toggle in production send flow. Added `transport` parameter passed to ViewModel. Continue button sets signed PSBT in `SendInfoProvider` and navigates to `/broadcasting`. |

#### Send Flow

| File | Changes |
|------|---------|
| `send/send_confirm_view_model.dart` | Added `walletImportSource` and `txWaitingForSign` getters. |
| `send/send_confirm_screen.dart` | Routes BitBox02 wallets to `/bitbox02-sign` instead of `/unsigned-transaction-qr`. Passes `transport: 'tcp'`. |

#### Routing

| File | Changes |
|------|---------|
| `app.dart` | `/bitbox02-sign` route accepts `isFromSendFlow` and `transport` arguments. |

### Build

| File | Changes |
|------|---------|
| `android/app/libs/bitboxbridge.aar` | Rebuilt via `make gomobile-android` (requires `ANDROID_NDK_HOME` set). |

---

## Key Discoveries

### 1. Go Bridge JSON Wrapping (`BTCXPub` / `BTCAddress`)

The Go bridge wraps xpub/address responses in JSON:
```json
{"xpub":"vpub5YWD..."}
```
Dart must `jsonDecode` before use. Without this, `ExtendedPublicKey.parse()` fails with "not compatible with network type".

**Status:** ✅ Fixed — `btcXPub()` and `btcAddress()` now parse JSON response.

### 2. `ChannelHashVerify(true)` Required After `Init()`

The Noise handshake requires both device-side and app-side confirmation. After `Init()`, the device is in `StatusUnpaired`. `ChannelHashVerify(true)` must be called to confirm pairing from the app side. Without it, all subsequent queries return "handshake must come first".

**Status:** ✅ Fixed — called in both connect and sign ViewModels.

### 3. Coconut PSBT Proprietary Keys (0xFC)

`coconut_lib`'s `Psbt.serialize()` adds proprietary key-value pairs to the PSBT global map:
```
key:   0xFC | "coconut" | 0x01
value: SHA256(wallet.descriptor)
```
The btcd PSBT parser (`btcsuite/btcd/btcutil/psbt`) rejects PSBTs where proprietary keys precede the unsigned transaction key (0x00).

**Status:** ✅ Fixed — `_cleanPsbt()` in Dart strips 0xFC keypairs from the global map before sending to Go bridge.

### 4. Simulator Loses Seed Across TCP Reconnects

Each new TCP connection to the Docker simulator presents an unseeded device. Even if `RestoreFromMnemonic` was called in a previous connection, the next connection sees `DeviceInfo().Initialized = false`.

**Status:** ✅ Mitigated — `deviceInitialized()` check before signing. If false, `RestoreFromMnemonic` is called. Reconnect to same simulator also reused via `BitBox02Device.lastConnected`.

### 5. `BTCSignPSBT` Nil Pointer Panic

**The critical unresolved issue.** `device.BTCSignPSBT()` in `bitbox02-api-go` v9.26.1 panics with nil pointer dereference at a stable address (offset 0x10 from nil).

Log evidence:
```
BTCSignPSBT: input[0] witnessUtxo=true pkScript=22b bip32Deriv=1 fp=9d73004c
BTCSignPSBT: calling device.BTCSignPSBT coin=TBTC
ERROR: recovered from panic: runtime error: invalid memory address or nil pointer dereference
```

Isolated and reproduced in a standalone Go test binary running inside the Docker simulator container — same panic. This confirms the bug is in `bitbox02-api-go`'s `newBTCTxFromPSBT` function, not in our bridge or gomobile.

**Status:** ❌ Unresolved. Panic recovery prevents app crash but signing fails.

---

## End-to-End Flow

```
✓ Docker simulator running (TCP:15423)
✓ Connect → Init → ChannelHashVerify → RestoreFromMnemonic
✓ m/84'/1'/0' + TBTC coin → vpub fetched
✓ RootFingerprint → 4c00739d
✓ Wallet created and synced from extended public key
✓ bitcoind regtest → generatetoaddress → balance confirmed
✓ Send flow → PSBT created → BitBox02 sign screen opens
✓ PSBT tx summary displayed correctly (amount, fee, address)
✗ BTCSignPSBT → nil pointer panic in bitbox02-api-go
```

### Coin Mapping

| Network | Dart Coin | Go Coin | Protobuf |
|---------|-----------|---------|----------|
| Mainnet | `BitBox02Coin.btc(0)` | `BTCCoin_BTC` | 0 |
| Testnet | `BitBox02Coin.tbtc(1)` | `BTCCoin_TBTC` | 1 |
| Regtest | `BitBox02Coin.tbtc(1)` | `BTCCoin_TBTC` | 1 |

> ⚠️ `BitBox02Coin.rbtc(4)` maps to `BTCCoin_RBTC(4)` which causes the simulator firmware to panic. Use TBTC for regtest.

### Derivation

| Network | Coin | Keypath | XPub Type |
|---------|------|---------|-----------|
| Mainnet | BTC | `m/84'/0'/0'` | ZPUB |
| Testnet | TBTC | `m/84'/1'/0'` | VPUB |
| Regtest | TBTC | `m/84'/1'/0'` | VPUB |

### Built-in Simulator Mnemonic

```
boring mistake dish oyster truth pigeon viable emerge sort crash
wire portion cannon couple enact box walk height pull today solid
off enable tide
```

Root fingerprint: `4c00739d`

---

## Caveats

### 1. NDK Path for gomobile Build

```bash
ANDROID_NDK_HOME=/Users/jm/Library/Android/sdk/ndk/27.0.12077973 make gomobile-android
```

The `ANDROID_NDK_HOME` env var must point to an installed NDK directory (not `<version>` placeholder).

### 2. macOS: No `timeout` Command

Use `docker exec` for time-constrained operations inside the simulator container, or install `coreutils` (`brew install coreutils` → `gtimeout`).

### 3. Single TCP Connection

The simulator accepts only one TCP connection at a time. Stop the app or disconnect before running Go test binaries against the simulator. Restart with:
```bash
docker restart bitbox02-sim
```

### 4. `RestoreFromMnemonic` State Check

Calling `RestoreFromMnemonic` on an already-seeded device returns `"can't call this endpoint: wrong state"`. Always check `deviceInitialized()` first.

### 5. PSBT Must Be Cleaned Before Sending

Always pass PSBT through `_cleanPsbt()` before sending to Go bridge. Coconut's 0xFC proprietary keys cause btcd parse failure.

### 6. Don't Use `BitBox02Coin.rbtc(4)` for Regtest

The `BTCCoin_RBTC(4)` protobuf value causes the simulator firmware (v9.26.1) to crash. Use `BitBox02Coin.tbtc(1)` for regtest — the network type (testnet3 vs regtest) is determined by the Electrum server connection, not the hardware wallet coin type.

### 7. `bitbox02-api-go` is a Local Replace

```go
// go/go.mod
replace github.com/BitBoxSwiss/bitbox02-api-go => ../../bitbox02-api-go
```

Must clone `bitbox02-api-go` at `../../bitbox02-api-go` relative to `coconut_wallet/go/`.

### 8. Fingerprint Endianness

PSBT BIP32 derivation stores fingerprints in **little-endian**. `4c00739d` (hex) ↔ `9d73004c` (LE uint32). Both representations are the same value.

---

## Debugging Commands

```bash
# Android logcat for BitBox02
adb logcat -s BB02 BB02_TCP GoLog flutter | grep -E "BB02|GoLog"

# Simulator logs
docker logs -f bitbox02-sim

# TCP port forwarding (physical device)
adb reverse tcp:15423 tcp:15423

# Simulator connectivity check (emulator)
adb shell nc -zv 10.0.2.2 15423

# Build & run
flutter run --flavor regtest
```

---

## Bug Analysis: BTCSignPSBT Nil Pointer Panic

### Symptom

`device.BTCSignPSBT(coin, psbtPacket, opts)` panics in Go runtime:

```
panic: runtime error: invalid memory address or nil pointer dereference
signal SIGSEGV: segmentation violation code=0x1 addr=0x10
```

Panic occurs at stable address `pc=0x...4c4898` across all runs (same faulting instruction every time).

### Reproduction

| Method | Result |
|--------|--------|
| gomobile (Android) | Panic → `defer/recover` catches it, app doesn't crash |
| Standalone Go binary in Docker | Same panic (gomobile ruled out as cause) |
| bitbox-wallet-app test PSBT | Parse error — different mnemonic fingerprint |
| With `RestoreFromMnemonic` before signing | Same panic |
| Without `RestoreFromMnemonic` before signing | Same panic |
| With PSBT rebuild (`NewFromUnsignedTx` + `Updater`) | Same panic |
| With BTC coin instead of TBTC | Not tested (PSBT has testnet addresses) |

### Ruled-Out Causes

All verified as working correctly before the panic:

| Item | Verification |
|------|-------------|
| TCP communication | `RootFingerprint()` returns `4c00739d` successfully |
| Noise handshake | `channelHashVerify: true` passes |
| Device state | `DeviceInitialized: true` (seed present) |
| PSBT parsing | btcd `NewFromRawBytes` succeeds |
| UnsignedTx | `UnsignedTx ok, inputs=1 outputs=2` |
| PSBT input count match | `psbtInputs=1` matches `TxIn=1` |
| Witness UTXO | `witnessUtxo=true` |
| PkScript | `pkScript=22b` → valid P2WPKH (0x00 + 0x14 + 20 bytes) |
| BIP32 derivation | `bip32Deriv=1` present |
| Fingerprint match | `fp=9d73004c` → `4c00739d` in big-endian ✓ |
| PSBT size | 383 bytes cleaned (427 original minus 44 bytes proprietary) |

### Inferred Panic Location

`device.BTCSignPSBT()` internal call chain:

```
BTCSignPSBT()
  ├─ device.RootFingerprint()          [OK] queries firmware, returns 4 bytes
  ├─ newBTCTxFromPSBT()                [PANIC] — fully local, no firmware I/O
  │   ├─ psbt_.UnsignedTx.TxIn         [OK] len=1, non-nil
  │   ├─ psbt_.Inputs[0]               [OK] valid struct
  │   ├─ psbtInput.WitnessUtxo         [OK] non-nil, PkScript=22 bytes
  │   ├─ psbtInput.Bip32Derivation[0]  [OK] len=1, non-nil
  │   ├─ findOurKey()                  [OK] fingerprint matches → returns non-nil ourKey
  │   ├─ getScriptConfig()             [OK] P2WPKH recognized
  │   ├─ findOrAddInputScriptConfig()  [?] closure accessing inputScriptConfigs slice
  │   ├─ psbtInput.NonWitnessUtxo      [OK] nil, guarded by if-check
  │   └─ BTCTxInput construction       [?] field access on partially-initialized struct
  ├─ device.BTCSign()                  [NOT REACHED]
  └─ write signatures back to PSBT     [NOT REACHED]
```

### Offset 0x10 Analysis

Fault address `0x10` = 16 bytes from nil pointer. This is the third pointer-sized field of some struct:

| Candidate Struct | Field at +0x10 |
|-----------------|----------------|
| `psbt.Input` (from btcd) | `PartialSigs []*PartialSig` (slice: ptr+len+cap = 24 bytes) |
| `wire.TxOut` | `PkScript []byte` (offset 8, actually) |
| `btcTxResult` | Internal map or slice at offset 16 |
| `messages.BTCScriptConfigWithKeypath` | `Keypath []uint32` (slice) |

The most likely candidate is an uninitialized slice or map field within `psbt.Input` that `newBTCTxFromPSBT` accesses without nil-guard.

### Root Cause Hypothesis

`newBTCTxFromPSBT` iterates over btcd-parsed `psbt.Input` fields. When the PSBT originates externally (coconut_lib → btcd parser), the resulting `psbt.Input` struct may have some pointer fields set to nil in ways the bitbox02-api-go code doesn't expect. The bitbox-wallet-app never hits this because it always constructs PSBTs internally via `psbt.NewFromUnsignedTx` + `Updater`, producing consistently-populated structs.

The specific nil access likely involves:

1. An input field that btcd populates differently for externally-created PSBTs
2. Or the closure `findOrAddInputScriptConfig` accessing `cfg.Config.(*messages.BTCScriptConfig_SimpleType_)` where the type assertion receives an unexpected nil wrapper

### Mitigation

`defer/recover` in the Go bridge catches the panic and converts it to a normal error:

```go
var sigErr error
func() {
    defer func() {
        if r := recover(); r != nil {
            sigErr = fmt.Errorf("panic in BTCSignPSBT: %v", r)
        }
    }()
    sigErr = entry.Device.BTCSignPSBT(btcCoin, psbtPacket, opts)
}()
```

This prevents the app from crashing. The error is propagated to Dart and displayed in the UI.

### Resolution Paths

| Option | Approach | Effort |
|--------|----------|--------|
| **A. Patch bitbox02-api-go** | Add defensive nil checks to `newBTCTxFromPSBT` around field access. Since `bitbox02-api-go` is a local replace (`go.mod` replace directive), modifications take effect immediately. | Medium |
| **B. Bypass BTCSignPSBT** | Call `device.BTCSign()` directly with manually constructed `BTCTxInput`/`BTCTxOutput` structs. Requires extracting WitnessUtxo, Bip32Derivation, PrevOutPoint, Sequence from PSBT and building protobuf messages manually. | High |
| **C. Full PSBT Rebuild** | Parse external PSBT → extract UnsignedTx → `psbt.NewFromUnsignedTx` + `Updater` → add all fields back (WitnessUtxo, NonWitnessUtxo, Bip32Derivation, RedeemScript, SighashType, Taproot fields). Already attempted but 383→279 byte data loss meant incomplete reconstruction. | Medium |
| **D. Try Different Firmware** | Test with a newer/older simulator binary from [bitbox02-firmware releases](https://github.com/BitBoxSwiss/bitbox02-firmware/releases). | Low |

**Recommended: Option A** — it's the most targeted fix, leverages the existing local replace, and could be upstreamed as a PR to `bitbox02-api-go`.

---

## Next Steps (Other)

- **Fix `BTCSignPSBT` panic** — see Bug Analysis section above
- **iOS BLE support**: Untested, requires XCFramework build + physical iOS device
- **Noise key persistence**: `inMemoryConfig` loses keys on app restart. Wire `SaveConfig`/`LoadConfig` to Flutter persistent storage
- **USB support on physical Android**: Requires USB OTG cable + physical BitBox02 device
