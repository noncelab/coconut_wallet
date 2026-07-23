# Trezor Integration — Developer Guide

Coconut Wallet ↔ Trezor 하드웨어 지갑 연동을 위한 개발자 가이드.

---

## 1. 지원 범위

### 기기 × 연결 방식 × 프로토콜

| 기기 | 연결 | 프로토콜 | iOS | Android |
|------|------|----------|-----|---------|
| Trezor Model One | USB | Protocol v1 | ❌ | ✅ |
| Trezor Model T | USB | Protocol v1 | ❌ | ✅ |
| Trezor Safe 3 | USB | Protocol v1 | ❌ | ✅ |
| Trezor Safe 5 | USB | Protocol v1 | ❌ | ✅ |
| Trezor Safe 7 | BLE | THP v2 (Noise XX) | ✅ | ✅ |
| Trezor Safe 7 | USB-C | THP v2 (Noise XX) | ❌ | ❌ |

> ✅ 지원 / ❌ 미지원

- **Trezor Safe 7**: iOS/Android 모두 **BLE 전용** 지원
- **Model One ~ Safe 5**: **Android USB 전용** 지원 (iOS는 MFi 인증 필요로 USB 불가)
- **Safe 7 USB-C**: iOS/Android 모두 미지원 (§6 의사결정 근거 참고)

---

## 2. BitBox02 vs Trezor Safe 7: 차이점 비교

| 항목 | BitBox02 | Trezor Safe 7 |
|------|----------|---------------|
| **통신 프로토콜** | 자체 Noise 기반 (bitbox02-api-go) | THP v2 (Trezor Host Protocol, Noise XX) |
| **BLE GATT Service UUID** | `e1511a45-f3db-44c0-82b8-6c880790d1f1` | `8c000001-a59b-4d58-a9ad-073df69fa1b1` |
| **RX Characteristic** | `799d485c-d354-4ed0-b577-f8ee79ec275a` | `8c000002-a59b-4d58-a9ad-073df69fa1b1` |
| **TX Characteristic** | `419572a5-9f53-4eb1-8db7-61bcab928867` | `8c000003-a59b-4d58-a9ad-073df69fa1b1` |
| **BLE 패킷 크기** | 64 bytes | 244 bytes |
| **연결 후 절차** | BridgeConnect → Init → channelHashVerify → xpub | ChannelAlloc → Noise XX Handshake 3단계 → Pairing → Credential → xpub |
| **사용자 확인 UI** | 채널 해시 표시 (현재 자동 OK) | Numeric Comparison (기기 화면 숫자 확인 필요) |
| **재연결** | config JSON 저장 | Credential(HMAC key) Keychain 저장으로 Pairing 생략 |
| **iOS 라이브러리** | Go → `Bitboxbridge.xcframework` | 없음 (직접 구현 필요) |

> **결론: 연동 과정이 100% 동일하지 않습니다.**  
> BitBox02는 컴파일된 Go 라이브러리가 프로토콜 전체를 처리하지만,  
> Trezor Safe 7은 THP v2를 직접 구현해야 합니다.

---

## 3. THP v2 연결 시퀀스 (Trezor Safe 7 BLE)

```
1. BLE 스캔 & GATT 연결 (CoreBluetooth)
2. ChannelAllocationRequest → ChannelAllocationResponse (채널 ID 획득)
3. HandshakeInitiationRequest (host ephemeral pubkey 전송)
4. HandshakeInitiationResponse (trezor ephemeral + masked static pubkey 수신)
5. HandshakeCompletionRequest (encrypted host static pubkey 전송)
6. HandshakeCompletionResponse → AES-GCM 세션키 파생 (HKDF)
7. [최초 연결] Pairing Phase (Numeric Comparison: 기기 화면 숫자 확인)
8. Credential 발급 및 iOS Keychain 저장 (재연결 시 Pairing 생략)
9. GetPublicKey 요청 (protobuf over THP 암호화 채널)
```

---

## 4. Safe 7 BLE 구현: Rust + UniFFI (iOS + Android 공통)

### 왜 Rust + UniFFI인가

- `trezor-connect-rs` 크레이트: Safe 7 BLE + THP v2 + xpub 파생을 지원하는 완성된 오픈소스 구현체
- UniFFI로 **Swift(iOS)와 Kotlin(Android) 바인딩을 동시에 자동 생성** → THP v2 구현 1벌로 양 플랫폼 공유
- BitBox02의 `Bitboxbridge.xcframework(Go)` 패턴과 동일한 접근

### trezor-connect-rs 지원 범위

| 기능 | 지원 |
|------|------|
| Safe 7 BLE (THP v2, Noise XX) | ✅ |
| USB (Protocol v1) | ✅ (단, libusb 기반이므로 Android 불가) |

### Feature Flags

```toml
# iOS: Bluetooth only
trezor-connect-rs = { version = "0.4", default-features = false, features = ["bluetooth", "os-keychain"] }

# Android: Bluetooth only (btleplug Android 빌드 필요)
trezor-connect-rs = { version = "0.4", default-features = false, features = ["bluetooth"] }
```

### 크로스 컴파일 타겟

```bash
# iOS
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
cargo build --target aarch64-apple-ios --release

# Android (btleplug .aar 빌드 별도 필요)
rustup target add aarch64-linux-android armv7-linux-androideabi
cargo ndk -t arm64-v8a -t armeabi-v7a build --release
```

### Android BLE 주의사항 (btleplug)

`trezor-connect-rs`의 BLE는 내부적으로 `btleplug`를 사용합니다.  
Android에서 btleplug는 **Rust + Java 하이브리드 빌드**가 필요합니다:

1. `btleplug` Java 부분(droidplug) `.aar` 빌드
2. `android/libs/` 에 `.aar` 배치
3. `build.gradle` 의존성 추가

### 예상 파일 구조

```
ios/Runner/
  TrezorMethodHandler.swift         # MethodChannel('trezor') 처리 (BLE)
  TrezorBluetoothTransport.swift    # CoreBluetooth GATT (UUID: 8c000001-...)

android/app/src/main/kotlin/.../
  TrezorMethodHandler.kt            # MethodChannel('trezor') 처리 (BLE)
  android/libs/btleplug.aar         # btleplug Android Java 부분

lib/services/hardware_wallet/
  trezor_device.dart                # MethodChannel 래퍼 (Dart)

lib/providers/view_model/wallet_add/connected/
  trezor_connect_viewmodel.dart     # 연결 상태 관리

lib/screens/home/wallet_add/connected/
  trezor_connect_screen.dart        # UI (현재 shell 상태)
```

---

## 4-A. Trezor Safe 7 BLE 실제 연결 흐름 (현재 구현)

> §4의 구조 설명을 보완하는 **실제 코드 흐름**입니다.  
> §5의 docs 다이어그램은 아직 구현되지 않은 Android USB(Model One~Safe 5) 방식을 설명합니다.

### 계층 구조

```
[Flutter UI]
  trezor_connect_screen.dart
        │ ChangeNotifier
        ▼
  trezor_connect_viewmodel.dart          # TrezorConnectStep 상태 관리
        │ TrezorDevice.connect()
        ▼
  trezor_device.dart                     # MethodChannel('trezor') 래퍼
        │ invokeMethod('connect')
        │
        │ ◀── 역방향: invokeMethod('showPairingCodeDialog')
        │         └─ onPairingCodeRequested() → 다이얼로그 표시 → 코드 반환
        ▼
[Native]
  iOS:     TrezorMethodHandler.swift
  Android: TrezorMethodHandler.kt
        │ trezorConnect(bleHandle, callback)
        ▼
[Rust — trezor-bridge / trezor-connect-rs]
  rust/trezor-bridge/src/lib.rs          # UniFFI 진입점
        │
        ▼
  trezor-connect-rs (로컬 패치)
  rust/trezor-connect-rs/src/transport/callback.rs
        │
        ├─ BLE 패킷 송수신: callback.write() / callback.read()
        │       └─ Swift/Kotlin이 CoreBluetooth / BluetoothGatt로 실제 전송
        │
        └─ THP 전체 수행 (내부 자동):
               ChannelAlloc → Noise XX Handshake → Pairing → Credential
```

### 단계별 흐름

```
1. vm.connect() 호출
   └─ TrezorDevice.connect()
        └─ MethodChannel: 'connect' → native

2. [Native] BLE 스캔 → Trezor Safe 7 발견 → GATT 연결
   └─ drainThenConnect(delay: 2s)  ← 스테일 BLE 패킷 제거

3. [Rust] trezorConnect() 실행
   └─ perform_thp_handshake()  (최대 3회 retry)
        ├─ ChannelAllocationRequest / Response
        ├─ Noise XX HandshakeInitiation / Response / Completion
        │
        ├─ [신규 기기] perform_pairing()
        │    ├─ Trezor 화면에 6자리 숫자 표시
        │    ├─ callback.getPairingCode() 호출  ← Rust → Native로 block
        │    │    └─ [Native] DispatchSemaphore.wait()
        │    │         └─ MethodChannel: 'showPairingCodeDialog' → Flutter
        │    │              └─ 사용자 입력 대기 → 코드 반환 → sema.signal()
        │    ├─ 코드 검증 실패 시: PairingCancelledByUser or retry loop
        │    │    └─ retry → getPairingCode() 재호출
        │    │         └─ Flutter: _waitForPairingCode()에서 isOpen 감지
        │    │              → _onPairingFailed() → 에러 메시지 표시
        │    └─ 성공 시: Credential 발급 → Keychain/Keystore 저장
        │
        └─ [재연결] Credential 로드 → Pairing 단계 생략

4. [Rust] 완료 → device_id + label JSON 반환 → native → Flutter

5. vm: TrezorConnectStep.paired
   └─ _retrieveXPub() → getXPub(keypath, network) → getFingerprint()
```

### 취소 처리

```
사용자가 취소 버튼 클릭
  └─ _pairingCodeCompleter.complete('')  ← 빈 문자열
       └─ [Rust] code.is_empty() → PairingFailed("PairingCancelledByUser")
            └─ is_retryable 체크에서 제외 → retry loop 즉시 중단
                 └─ Swift: PAIRING_CANCELLED FlutterError
                      └─ Dart: TrezorPairingException
                           └─ vm: TrezorConnectStep.error → _buildErrorCard
```

### 관련 파일

| 파일 | 역할 |
|------|------|
| `lib/screens/home/wallet_add/connected/trezor_connect_screen.dart` | UI, 페어링 다이얼로그, 로딩 오버레이 |
| `lib/providers/view_model/wallet_add/connected/trezor_connect_viewmodel.dart` | `TrezorConnectStep` 상태, `onPairingCodeRequested` / `onPairingFailed` 콜백 |
| `lib/services/hardware_wallet/trezor_device.dart` | MethodChannel 래퍼, `showPairingCodeDialog` 역방향 핸들러 |
| `ios/Runner/TrezorMethodHandler.swift` | BLE 관리, `getPairingCode()` semaphore, `PAIRING_CANCELLED` 에러 코드 |
| `android/app/src/main/kotlin/.../TrezorMethodHandler.kt` | 동일 역할 (Kotlin) |
| `rust/trezor-bridge/src/lib.rs` | UniFFI 진입점 |
| `rust/trezor-connect-rs/src/transport/callback.rs` | THP 핸드셰이크, 페어링, retry 로직 (로컬 패치) |

---

## 5. Android USB 구현 방법 (Model One ~ Safe 5)

### 왜 Rust 라이브러리를 재사용할 수 없는가

`trezor-connect-rs`의 USB 기능은 `libusb`를 사용합니다.  
`libusb`는 Linux의 `/dev/bus/usb`에 직접 접근하는데, Android는 앱에 이 경로를 허용하지 않습니다.  
Android USB는 반드시 **Java `UsbManager` API + 사용자 권한 승인** 경로를 통해야 합니다.

### BitBox02 Android 구조 (현재 코드)

```
Flutter (Dart)
    │  MethodChannel('bitbox02')
    ▼
Bitbox02MethodHandler.kt        ← Kotlin: USB 연결 관리, 스레드 처리
    │  Bridge.connect(transport)
    ▼
Bridge.java (Go AAR)             ← Go 라이브러리: BitBox 프로토콜 전체 처리
    │  (Noise 핸드쉐이크, xpub 요청 등)
    ▼
UsbTransport (Kotlin)            ← 실제 바이트 read/write
    │
    ▼
Android USB Host API
```

핵심: Kotlin은 USB 물리 연결만 처리하고, **프로토콜 로직(Noise 핸드쉐이크, xpub 파생 등)은 Go AAR이 담당**.

### Trezor Android 구조 (구현 예정)

```
Flutter (Dart)
    │  MethodChannel('trezor')
    ▼
TrezorMethodHandler.kt           ← 새로 작성 (Bitbox02MethodHandler.kt 패턴 참고)
    │  Protocol v1 직접 구현
    ▼
TrezorUsbManager.kt              ← 새로 작성 (Bitbox02UsbManager.kt 패턴 참고)
    │  VendorId: 0x1209, ProductId: Trezor 기종별 상이
    ▼
Android USB Host API
```

핵심 차이: Trezor에는 BitBox의 `Bridge.java(Go AAR)`에 해당하는 라이브러리가 없음.  
**Protocol v1 자체를 Kotlin으로 직접 구현** (Noise 없음, 훨씬 단순).

### Trezor USB Protocol v1 구조

```
패킷 크기: 64 bytes (HID)
헤더: '?' + 0x23 0x23 (##) + MessageType(2B) + payload_len(4B)
본문: protobuf 메시지
```

BitBox02 Noise 핸드쉐이크가 없어 구현 난이도가 낮습니다.

### Trezor USB VendorId / ProductId

| 기기 | VendorId | ProductId |
|------|----------|-----------|
| Model One (bootloader) | 0x534C | 0x0000 |
| Model One (firmware) | 0x534C | 0x0001 |
| Model T, Safe 3, Safe 5, Safe 7 (bootloader) | 0x1209 | 0x53C0 |
| Model T, Safe 3, Safe 5, Safe 7 (firmware) | 0x1209 | 0x53C1 |

### Safe 7 USB-C 주의사항

Safe 7은 USB-C로 연결해도 **Protocol v1이 아닌 THP v2**를 사용합니다.  
Android USB 지원을 Model One ~ Safe 5로 제한하면 Protocol v1만 구현하면 됩니다.

---

## 6. 의사결정 근거

### Safe 7: BLE 전용 (USB-C 미지원)

Safe 7은 USB-C로 연결해도 Protocol v1이 아닌 **THP v2**를 사용합니다.  
THP v2는 Noise XX 핸드쉐이크 + AES-GCM 암호화 + protobuf 전체를 구현해야 하는 복잡한 프로토콜입니다.

- iOS USB: MFi 인증 필요 → 원천 불가
- Android USB (Safe 7): THP v2를 Kotlin으로 직접 구현해야 함 → 난이도 매우 높음
- **BLE로도 동일 기능 제공 가능** → USB-C 지원 필요성이 낮음

→ **Safe 7은 iOS/Android 모두 BLE만 지원**하고, THP v2 구현(`trezor-connect-rs`)을 양 플랫폼이 공유합니다.

### Model One ~ Safe 5: Android USB 전용 (iOS 미지원)

Model One ~ Safe 5는 USB HID + Protocol v1을 사용합니다.  
Protocol v1은 Noise 핸드쉐이크 없이 단순 HID 패킷 + protobuf 구조라 **구현 난이도가 낮습니다.**

- iOS USB: MFi 인증 필요 → 원천 불가
- Android USB: Java `UsbManager` API로 구현 가능, BitBox02 패턴 재사용 가능
- `trezor-connect-rs`의 USB feature는 `libusb` 기반이라 Android에서 사용 불가  
  → **Protocol v1을 Kotlin으로 직접 구현**

→ **Model One ~ Safe 5는 Android USB만 지원**, iOS는 해당 기기를 미지원합니다.

### 결과: 두 가지 독립적인 구현 스택

```
[Safe 7 BLE]  iOS + Android
    Rust (trezor-connect-rs)
        ├── UniFFI → Swift 바인딩 (iOS)
        └── UniFFI → Kotlin 바인딩 + btleplug.aar (Android)

[Model One ~ Safe 5 USB]  Android only
    Kotlin 직접 구현
        ├── TrezorUsbManager.kt  (Android UsbManager API)
        └── TrezorMethodHandler.kt  (Protocol v1 + protobuf)
```

Flutter 레이어(`MethodChannel('trezor')`)는 단일 인터페이스로 유지되어 Dart 코드는 플랫폼을 구분하지 않습니다.

---

## 7. rust/trezor-bridge 크레이트

`rust/trezor-bridge/` 에 UniFFI 크레이트가 구현되어 있습니다.

### 파일 구조

```
rust/trezor-bridge/
  Cargo.toml           # uniffi 0.28, thiserror, serde_json, uuid, once_cell
  build.rs             # uniffi::generate_scaffolding("src/trezor.udl")
  src/
    trezor.udl         # UniFFI IDL: connect / get_xpub / get_fingerprint / disconnect
    lib.rs             # FFI 구현
  scripts/
    build_ios.sh       # → ios/Runner/TrezorBridge.xcframework + TrezorBridgeFFI.swift
    build_android.sh   # → android/app/src/main/jniLibs/<abi>/*.so + Kotlin 바인딩

rust/trezor-connect-rs/  # crates.io 0.4.0 로컬 패치 (Cargo.toml [patch.crates-io])
  src/transport/callback.rs  # PairingCancelledByUser non-retryable 패치 적용
```

### 빌드

```bash
# iOS XCFramework 생성
make trezor-ios

# Android JNI .so + Kotlin 바인딩 생성
make trezor-android

# 양쪽 동시
make trezor-bind
```

### 구현 상태

| 함수 | 상태 |
|------|------|
| `trezor_connect(ble_handle)` | ✅ BLE THP 핸드셰이크 + 페어링 + credential 저장 |
| `trezor_get_xpub(device_id, keypath, network)` | ✅ xpub 반환 |
| `trezor_get_fingerprint(device_id)` | ✅ 마스터 지문 반환 |
| `trezor_disconnect(device_id)` | ✅ 세션 정리 |

### 로컬 패치 (rust/trezor-connect-rs)

crates.io 0.4.0 소스를 `rust/trezor-connect-rs/`에 복사 후 `[patch.crates-io]`로 교체합니다.  
수정 파일: `src/transport/callback.rs`

#### 패치 1 — 취소·오입력 에러를 non-retryable로 처리 (line 846)

`ThpError::PairingFailed(msg)` 의 `Display`는 항상 `"Pairing failed: {msg}"` 형태이므로, 모든 `PairingFailed` 변종이 `contains("Pairing failed")` 에 매칭되어 retryable로 분류됩니다.  
취소(빈 문자열 반환)와 오입력(코드 틀림) 두 경우는 retry 없이 즉시 Flutter로 전파해야 하므로, 각 에러 메시지를 `&&` 조건으로 명시적으로 제외합니다.

```rust
// 원본 (0.4.0)
let is_retryable = error_str.contains("Not connected")
    || error_str.contains("Data transfer error")
    // ...
    || error_str.contains("Pairing failed")
    // ...
    || error_str.contains("Device disconnected");

// 패치 후
let is_retryable = !error_str.contains("Pairing cancelled by user")  // 사용자 취소
    && !error_str.contains("Code verification failed")               // 오입력
    && (error_str.contains("Not connected")
    || error_str.contains("Data transfer error")
    // ...
    || error_str.contains("Pairing failed")
    // ...
    || error_str.contains("Device disconnected"));
```

**이유**:
- `"Pairing failed: Pairing cancelled by user"` → `contains("Pairing cancelled by user")` = true → `!true` = false → non-retryable
- `"Pairing failed: Code verification failed"` → `contains("Code verification failed")` = true → `!true` = false → non-retryable
- 두 에러 메시지 모두 **원본 0.4.0 그대로** 사용하므로 에러 메시지 자체는 수정하지 않습니다.

#### 패치 2 — THP credential 파일 기반 영구 저장

기존에는 THP credential을 인메모리 `HashMap`(`THP_CREDS`)에만 저장했습니다. 앱 프로세스가 종료되면 credential이 사라지지만, Trezor 기기에는 credential이 남아 있어 재연결 시 `Decryption error: aead::Error`가 발생했습니다.

변경 후 `trezor_connect`에 `device_uuid`와 `credential_path` 파라미터가 추가되었고, `NativeAdapter`는 `credential_path`가 지정된 경우 파일에서 credential을 로드/저장합니다.

- **저장 위치**: iOS `Application Support/trezor/thp-credentials.json`, Android `filesDir/trezor/thp-credentials.json`
- **저장 형식**: JSON (`{ "ble:{device_uuid}": "{credential_json}" }`)
- **파일 권한**: Unix 0600 (소유자만 읽기/쓰기)
- **device_uuid**: iOS `peripheral.identifier.uuidString`, Android MAC address — 앱 재시작 후에도 동일한 키로 credential 매칭

**보안 고려사항**: 파일 저장은 앱 샌드박스(iOS)/앱 전용 영역(Android) 내에 저장되어 다른 앱이 접근할 수 없습니다. credential이 유출되더라도 BLE 물리적 근접(~10m), Trezor 기기 잠금 해제, 트랜잭션 서명 시 기기 화면 확인이 모두 필요하므로 실질적인 공격 위험은 낮습니다.

#### 패치 3 — Model One ~ Safe 7 전 모델 USB Connect 연결/서명 지원

Trezor 제품군의 USB 연결 및 서명 흐름이 모델별로 차이가 있어, Model One부터 Safe 7까지 모든 모델에서 USB를 통한 연결과 트랜잭션 서명이 정상 동작하도록 `rust/trezor-connect-rs`를 패치했습니다. 이 패치는 Trezor Bridge 기반 USB 통신에서 모델별 프로토콜/메시지 차이를 처리합니다.

### trezor-connect-rs 버전 업그레이드 방법

새 버전이 crates.io에 배포됐을 때 로컬 소스를 교체하고 패치를 재적용하는 절차입니다.

**1. 새 버전 소스 다운로드**

```bash
# X.Y.Z를 새 버전으로 교체
VER=X.Y.Z
mkdir -p /tmp/trezor-new
curl -sL "https://static.crates.io/crates/trezor-connect-rs/${VER}/download" \
  -o /tmp/trezor-new.tar.gz
tar xzf /tmp/trezor-new.tar.gz -C /tmp/trezor-new
```

**2. 로컬 소스 교체**

```bash
rm -rf rust/trezor-connect-rs
cp -R /tmp/trezor-new/trezor-connect-rs-${VER} rust/trezor-connect-rs
```

**3. 패치 적용**

`rust/trezor-connect-rs/src/transport/callback.rs` 를 열고 두 곳을 수정합니다.

> 라인 번호는 버전마다 달라질 수 있으므로 키워드로 검색해서 위치를 확인합니다.

**패치 1** — `// Check if the error is retryable` 주석 아래 `is_retryable` 변수 선언 검색:

```rust
// 변경 전
let is_retryable = error_str.contains("Not connected")
    || ...
    || error_str.contains("Device disconnected");

// 변경 후
let is_retryable = !error_str.contains("Pairing cancelled by user")
    && !error_str.contains("Code verification failed")
    && (error_str.contains("Not connected")
    || ...
    || error_str.contains("Device disconnected"));
```

**패치 2** — PSBT 트랜잭션 서명 처리 보완:

Trezor Bridge에서 PSBT 서명 API를 노출하고, 서명에 필요한 이전 트랜잭션 정보를 주입하며, Trezor가 반환하는 ECDSA DER 서명 형식을 처리하도록 보완합니다.

변경 대상 파일:

- `rust/trezor-bridge/src/lib.rs`
- `rust/trezor-bridge/src/trezor.udl`
- `rust/trezor-connect-rs/src/psbt.rs`

상세 변경 사항은 패치 적용 커밋을 기준으로 확인합니다.

- GitHub commit: `https://github.com/noncelab/coconut_wallet/commit/75aed8b062bcc62db9a4517a19c73ed4ddc45d16`

> 새 버전 소스로 `rust/trezor-connect-rs`를 교체하면 `src/psbt.rs` 변경은 사라지므로 반드시 다시 적용합니다. `trezor-bridge`의 `lib.rs`와 `trezor.udl`도 패치 2의 API와 구현이 유지되는지 함께 확인합니다.

**패치 3** — PSBT 트랜잭션 서명 처리 보완:

변경 대상 파일:
- `rust/trezor-bridge/src/lib.rs`
- `rust/trezor-bridge/src/trezor.udl`

- GitHub commit: `https://github.com/noncelab/coconut_wallet/commit/1b90f54100d2ae309f62c978d720203aa5f092c2`

**4. Cargo.toml 버전 업데이트**

`rust/trezor-bridge/Cargo.toml`의 `[dependencies]` 버전을 새 버전으로 변경합니다.

```toml
trezor-connect-rs = { version = "X.Y", default-features = false, features = ["bluetooth"] }
```

> `[patch.crates-io]`의 `path = "../trezor-connect-rs"` 는 그대로 둡니다.

**5. 컴파일 확인**

```bash
cd rust/trezor-bridge
cargo check
```

에러 없이 통과하면 완료. 이후 `make trezor-ios` / `make trezor-android`로 바이너리를 재빌드합니다.

---

## 8. 참고 자료

- [Trezor Host Protocol 스펙](https://docs.trezor.io/trezor-firmware/common/thp/specification.html)
- [trezor-connect-rs (GitHub)](https://github.com/coreyphillips/trezor-connect-rs)
- [hw-core — iOS/macOS FFI 타겟 포함 Rust 구현](https://github.com/hewigovens/hw-core)
- [btleplug — Rust 크로스플랫폼 BLE 라이브러리](https://github.com/deviceplug/btleplug)
- [trezorlib BLE transport (Python 참고 구현)](https://github.com/trezor/trezor-firmware/blob/main/python/src/trezorlib/transport/ble.py)
- [UniFFI Swift Bindings](https://mozilla.github.io/uniffi-rs/latest/swift/overview.html)
