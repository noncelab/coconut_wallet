# BitBox02 PSBT Signing Fix

> NonWitnessUtxo 주입으로 P2WPKH 서명 panic 해결

## 문제

BitBox02 시뮬레이터로 P2WPKH PSBT 서명 시 nil pointer panic 발생:

```
panic: runtime error: invalid memory address or nil pointer dereference
```

## 원인 분석

### Panic 위치

stack trace로 추적 → `bitbox02-api-go/api/firmware/btc.go:481`:

```go
case messages.BTCSignNextResponse_PREVTX_INIT:
    prevtx := tx.Inputs[next.Index].PrevTx       // ← nil
    next, err = device.nonAtomicNestedQueryBtcSign(
        &messages.BTCRequest{
            Request: &messages.BTCRequest_PrevtxInit{
                PrevtxInit: &messages.BTCPrevTxInitRequest{
                    Version:    prevtx.Version,   // ← PANIC
```

### 근본 원인: NonWitnessUtxo 누락

BitBox02 펌웨어는 P2WPKH 서명 시 이전 트랜잭션 검증을 수행한다:

```
WitnessUtxo(amount + script) vs 이전 트랜잭션 원본
→ outputs[outpoint.index].amount == WitnessUtxo.amount ? ✓
```

Taproot는 서명 자체에 금액이 커밋되어 있어 불필요하지만, P2WPKH는 공격자가 WitnessUtxo 금액을 조작할 수 있기 때문에 기기가 직접 원본을 확인하는 보안 설계다.

coconut_lib의 `Psbt.fromTransaction()`은 `WitnessUtxo`(amount + scriptPubKey)만 추가하고 `NonWitnessUtxo`(이전 트랜잭션 전체)는 추가하지 않는다. 이로 인해 `BTCTxInput.PrevTx`가 nil이 되고, 펌웨어가 이전 트랜잭션을 요청할 때 panic 발생.

## 해결

### 1. bitbox02-api-go 패치

`fix/nil-guard-psbt` 브랜치에 방어 코드 추가:

| 위치 | 변경 |
|------|------|
| `psbt.go:findOurKey` | `Bip32Derivation` / `TaprootBip32Derivation` 슬라이스 순회 시 nil 요소 skip |
| `psbt.go:newBTCTxFromPSBT` | `Inputs`/`Outputs` 길이 bounds check |
| `psbt.go:scriptConfigFromUTXO` | `utxo == nil` 체크 |
| `btc.go:nonAtomicBTCSign` | `PREVTX_INIT/INPUT/OUTPUT`에서 `PrevTx == nil` 시 명확한 에러 반환 |

> NonWitnessUtxo가 정상 주입되면 이 방어 코드는 실행되지 않는다. 외부 PSBT에 대한 안전장치.

### 2. Go bridge: NonWitnessUtxo 주입

`go/bridge.go`에 추가:

```go
var prevTxStore = make(map[string]map[int]string)

func SetPrevTxHex(deviceID string, inputIndex int, rawTxHex string)
func injectPrevTxsIntoPsbt(deviceID string, p *psbt.Packet) error
```

`BTCSignPSBT`에서 `device.BTCSignPSBT()` 호출 전에 `injectPrevTxsIntoPsbt()`를 호출하여 저장된 prevtx hex들을 PSBT의 각 input에 `NonWitnessUtxo`로 주입한다.

### 3. Kotlin / Swift MethodChannel 핸들러

`setPrevTxHex` 메서드 추가 — Dart에서 전달받은 raw transaction hex를 Go bridge로 전달:

```
Dart → MethodChannel("bitbox02") → Kotlin/Swift → Bridge.setPrevTxHex()
```

### 4. Dart: prevtx 조회 및 전달

`bitbox02_sign_viewmodel.dart`에서 서명 전:

1. `Psbt.parse(psbtBase64)` → input txid 추출
2. `ElectrumService`로 각 txid의 raw transaction hex 조회
3. `_device.setPrevTxHex(i, rawTxHex)` 호출
4. 이후 `_device.btcSignPSBT()` 호출 → Go bridge가 NonWitnessUtxo 주입 후 서명

## 파일 변경

| 레이어 | 파일 | 변경 |
|--------|------|------|
| bitbox02-api-go | `api/firmware/psbt.go` | nil 가드, stack trace recover |
| bitbox02-api-go | `api/firmware/btc.go` | PrevTx nil 체크 |
| Go bridge | `go/bridge.go` | `SetPrevTxHex()`, `injectPrevTxsIntoPsbt()` |
| Kotlin | `.../Bitbox02MethodHandler.kt` | `setPrevTxHex` handler |
| Swift | `.../Bitbox02MethodHandler.swift` | `setPrevTxHex` handler |
| Dart | `lib/services/.../bitbox02_device.dart` | `setPrevTxHex()` 메서드 |
| Dart | `lib/.../bitbox02_sign_viewmodel.dart` | prevtx 조회 및 주입 로직 |
