# Handoff: florestad Android 시작 크래시 해결

## 목표
Android 에뮬레이터/기기에서 `florestad`(Floresta 노드)가 **시작 시 SIGSEGV**로 죽는 문제를 해결한다.
해결되면 앱이 **기기 로컬 노드로 직접 스캔**(동기화 / rescan / 디스크립터 인덱싱)하고,
**Docker 없이** 동작한다. (지금까지 Docker는 테스트 대역이었다.)

## 환경
- 앱: `/Volumes/mx500/github.com/coconut_wallet`, branch **`feat/floresta-embed`** (변경 다수 **미커밋**)
- Flutter: `fvm` (3.35.7) → 명령은 `fvm flutter ...`
- NDK: `~/Library/Android/sdk/ndk/27.0.12077973`
- cargo-ndk 설치됨, rust android 타깃(arm64/x86_64/armv7) 설치됨
- 에뮬레이터: AVD **`coconut_regtest`** (android-35 google_apis arm64-v8a)
- Floresta 소스: `/Volumes/mx500/github.com/Floresta` (v0.9.0-266, fork=4xvgal)
- 앱은 Floresta를 **Electrum 프로토콜 경로**로 접근한다: `ChainSource` → `ElectrumChainSource` → `ElectrumService`

## 현재 상태
- Docker regtest 스택(bitcoind + `utreexod --cfilters` + florestad)에서 **E2E 검증 완료**:
  디스크립터 등록, rescan, 잔액/거래 표시, 새 블록 동기화.
- Floresta 통합 앱 코드는 완성되어 있음:
  - `lib/utils/descriptor_util.dart` — SLIP-132→표준키 정규화(`toStandardKeys`), multipath `<0;1>` 분해(`toFlorestaDescriptors`)
  - `lib/services/floresta_rpc_client.dart` — `loaddescriptor` / `rescanblockchain` / `getblockchaininfo`
  - `lib/services/floresta_process_node.dart` (Android: `libflorestad.so` 프로세스 spawn)
  - `lib/services/floresta_node_controller.dart` (플랫폼 추상화: Android=프로세스, iOS=FFI)
  - `lib/services/floresta_node.dart` (iOS in-process FFI 래퍼), `native/floresta_ffi/` (Rust FFI)
  - `lib/providers/node_provider/node_provider.dart` — Floresta 모드 wiring
- **막힌 지점(broker)**: `florestad`가 Android에서 시작 시 죽음.

## 크래시 증거 (중요)
- 임베드(FFI `node_start`)와 프로세스(spawn `libflorestad.so`) **둘 다** SIGSEGV.
  - `Fatal signal 11 (SEGV_MAPERR), fault addr 0x0` (= null deref)
- 프로세스 tombstone: 프레임 2개만, PC `0xc66cd4` / `0xc408f8` (libflorestad.so). FFI판: `0xcb825c` / `0xc97e68`.
- 심볼 없어서 addr2line이 `getauxval` / `init_have_lse_atomics`로 나옴(오지시 가능).
- **`.so`가 NEEDED 없음 + static libc 번들**: 내부에 `malloc`/`free`/`pthread_create`를 로컬 정의.
  정상 동작하는 `libtrezor_bridge.so`는 `NEEDED libdl/libm/libc` 있음. → 정적 libc 의심(확정 아님).
- `pthread_atfork` 이슈는 `cargo ndk --platform 23`으로 해결(dlopen OK).
- 시도했으나 효과 없음: `floresta-node`의 `bitcoinkernel` feature 제거, `-C link-self-contained=no`(빌드 깨짐).

## 재현/관찰

### 1) florestad android 빌드
```bash
cd /Volumes/mx500/github.com/Floresta
ANDROID_NDK_HOME=~/Library/Android/sdk/ndk/27.0.12077973 \
  cargo ndk --platform 23 -t arm64-v8a build --release -p florestad
# 산출물: target/aarch64-linux-android/release/florestad  (PIE, interp /system/bin/linker64, 13MB)

cp target/aarch64-linux-android/release/florestad \
   /Volumes/mx500/github.com/coconut_wallet/android/app/src/main/jniLibs/arm64-v8a/libflorestad.so
```

### 2) 앱 없이 격리 실행 (가장 빠른 재현)
```bash
ADB=~/Library/Android/sdk/platform-tools/adb
$ADB push /Volumes/mx500/github.com/Floresta/target/aarch64-linux-android/release/florestad /data/local/tmp/florestad
$ADB shell chmod +x /data/local/tmp/florestad
$ADB logcat -c
$ADB shell /data/local/tmp/florestad -n regtest --data-dir /data/local/tmp/flo-data \
  --electrum-address 127.0.0.1:50001 --rpc-address 127.0.0.1:8332
$ADB logcat -d | grep -iE "Fatal signal|DEBUG|libflorestad"
# tombstone: $ADB shell dumpsys dropbox --print | tail -250
```

### 3) 심볼 붙이기
- `native/floresta_ffi/Cargo.toml`에 `[profile.release] debug = true` 추가(또는 `--profile dev`) 후 재빌드.
- `~/Library/Android/sdk/ndk/27.0.12077973/toolchains/llvm/prebuilt/darwin-x86_64/bin/llvm-addr2line -f -C -e <so> <pc>`

### 4) 앱으로 확인
```bash
cd /Volumes/mx500/github.com/coconut_wallet   # key_regtest.properties, bitboxbridge.aar, trezor bridge 필요(존재/무시됨)
fvm flutter build apk --debug --flavor regtest
$ADB -s emulator-5554 install -r build/app/outputs/flutter-apk/app-regtest-debug.apk
# Floresta 서버로 설정(host=localhost, port=50001, isFloresta=true, rpcPort=8332) 후 로그 확인
```

## 디버깅 방향 (지시)
1. **화면**: 먼저 `native/floresta_ffi/Cargo.toml`에 `debug=true` 넣고, 위 "격리 실행"으로 **앱 없이** 크래시 지점을 심볼화. (앱 경로는 노이즈가 많음)
2. **정적 libc 원인 특정**: `floresta-node`가 `bitcoinkernel` feature(=`floresta-chain`의 optional dep, C++ via cc)를 강제 on. 어떤 의존성이 static libc(`libc.a`)를 링크하는지 `cargo build -v`의 링크 라인 확인. 필요시 최소 Rust 바이너리로 의존성별 격리.
3. **동적 libc 강제**: 링커가 NDK clang(=`aarch64-linux-android23-clang`, sysroot 사용)으로 동적 libc를 쓰도록 보장 → `llvm-readelf -d`에 `NEEDED libc.so/libm.so/libdl.so`가 나오게.
4. **크래시 함수 특정**: Floresta 초기화 어디서 null인지 — filesystem/`/proc` 접근, `bitcoinkernel` init, CPU feature detection(`getauxval`), tokio/signal 등.
5. `avc: denied { search } for name="tests"` SELinux 라인이 관련 있는지 확인.
6. **성공 후**: `FlorestaProcessController`가 기기에서 노드를 띄우고 앱이 `127.0.0.1:50001/8332`에 붙어 동기화/잔액까지 되는지 (도커 없이) 확인.
   - 참고: `node_provider._florestaFixedPeers()`의 `10.0.2.2:18333`은 **regtest 테스트용 하드코딩** → 프로덕션은 DNS 시드.

## 성공 기준
- `adb shell /data/local/tmp/florestad -n regtest ...`가 SIGSEGV 없이 뜨고 Electrum(50001)/RPC(8332) 응답.
- 앱(regtest flavor)에서 Floresta 모드로 지갑 생성 → **기기 로컬 노드가 스캔** → 잔액/거래 표시 (Docker 불필요).
- 이후 iOS는 기존 FFI(`FlorestaFfiController`)로 정적 링크 임베드 유지.

## 관련 파일
- 앱 Floresta 통합: `lib/services/floresta_*`, `lib/utils/descriptor_util.dart`, `lib/providers/node_provider/node_provider.dart`
- 네이티브: `native/floresta_ffi/` (Cargo.toml, src/lib.rs), `android/app/src/main/jniLibs/<abi>/libflorestad.so`
- 빌드: `Makefile` (`rust-build`, `android-lib`), `android/app/build.gradle`, MainActivity.kt(`nativeLibraryDir` 채널)
- Docker 테스트 스택: `docker/regtest/` (README에 실행법/배경 정리)

---

## 해결 (Resolved)

### 원인: 정적 bionic(libc.a) 번들
`floresta-node`가 `floresta-chain/bitcoinkernel`을 강제 on → `libbitcoinkernel-sys` 의존.
그 build.rs가 Android에서 `libc++_static.a`/`libc++abi.a`를 찾으려고 **NDK sysroot 루트**
(`sysroot/usr/lib/aarch64-linux-android`)를 링커 search path에 추가한다. 그런데 그 디렉터리에는
정적 `libc.a`/`libm.a`/`libdl.a`만 있고 동적 스텁 `libc.so`는 API 레벨 하위 디렉터리
(`.../aarch64-linux-android/<api>/`)에만 있다. `ld.lld`는 `-L` 순서대로 해석하므로 build.rs의
`-L <root>`가 clang 기본 `-L <root>/<api>`보다 앞서 → `-lc`가 `libc.a`를 집어 정적 libc가
통째로 번들된다. 그 결과:
- `llvm-readelf -d`에 `NEEDED` 없음
- 시작 시 bionic의 `init_have_lse_atomics`가 초기화되지 않은 auxv를 deref → `SIGSEGV_MAPERR, fault addr 0x0`

재현/확정:
```
-L <root> -L <root>/<api>   → NEEDED 없음 (정적)   ← 문제
-L <root>/<api> -L <root>   → NEEDED libdl/libm/libc (동적)
```

### 수정
1. **동적 libc 강제**: 타깃 전용 rustflags로 API 디렉터리를 build.rs의 `-L`보다 앞세운다.
   ```bash
   CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS="-L native=$NDK/.../sysroot/usr/lib/aarch64-linux-android/24"
   cargo ndk --platform 24 -t arm64-v8a build --release -p florestad
   ```
2. **API 23 → 24**: Bitcoin Core kernel이 `getifaddrs`(API 24+)를 쓰고 `libbitcoinkernel-sys`의
   `MIN_ANDROID_API=24`이다. API 23 스텁으로 동적 링크하면 `undefined symbol: getifaddrs/freeifaddrs`로 실패.
   (앱 minSdk도 Flutter 기본 24라 일치.)
3. 재현 가능하게 `android/scripts/build_florestad.sh` + `make florestad-android`(= `android-lib`)로 고정.
   Android는 프로세스 spawn 경로만 쓰므로 더 이상 쓰지 않는 `libfloresta_ffi.so`/`libfloresta_chain.so`는
   jniLibs에서 제거(iOS/데스크톱 FFI는 `native/floresta_ffi` + `make ios-lib`로 유지).

### 부수적으로 발견/수정한 통합 버그
- `lib/enums/electrum_enums.dart`: 기본 `FLORESTA_REGTEST` 서버의 `rpcPort`가 50001(일렉트럼 포트와 동일)이라
  노드가 electrum/RPC를 같은 포트에 바인딩하려다 실패 → **8332**로 수정.
- `lib/services/floresta_rpc_client.dart`: 노드 재시작 시 같은 디스크립터를 `loaddescriptor`하면
  `Descriptor is already cached`(HTTP 400)로 실패해 rescan이 아예 안 돌던 문제 → 이미 캐시된 경우 성공으로 처리.
- `lib/providers/node_provider/node_provider.dart`: 신규 노드는 시작 직후 IBD 상태라 `rescanblockchain`이
  HTTP 503으로 거부됨 → IBD 종료 후 재시도하도록 `_pendingFlorestaRescan` 예약/재시도 추가.

### 검증 (emulator-5554, arm64)
- `adb shell /data/local/tmp/florestad -n regtest ...` → SIGSEGV 없이 기동, Electrum(50001)/RPC(8332) 리스닝.
- 앱(regtest flavor, `FLORESTA_REGTEST`) → `libflorestad.so` spawn → RPC 준비 → `loaddescriptor` 성공 →
  IBD 종료 후 rescan 성공 → **잔액 2 BTC / 수신 트랜잭션 표시** (앱은 `localhost:50001/8332`만 사용).

### 남은 것 (프로덕션)
- `_florestaFixedPeers()`의 `10.0.2.2:18333`은 regtest 테스트 하드코딩(에뮬레이터→호스트 루프백).
  배포는 florestad 내장 DNS 시드 사용.
- `android-lib`은 이제 Floresta FFI가 아니라 `florestad`를 빌드한다(Android는 프로세스 격리 모델).

## 트랜잭션 릴레이 이슈 조사 (regtest)

### 증상
앱에서 서명/브로드캐스트한 tx가 device node(Floresta) Electrum에 `blockchain.transaction.broadcast`로
전달되면 node는 성공(txid)을 반환하고 node mempool에도 들어가지만, **utreexod/bitcoind로 전파되지 않음**
(bitcoind `getrawmempool` 비어 있음). raw tx를 bitcoind에 직접 제출하면 정상 채굴/확인됨.

### 근본 원인 (utreexod ↔ bitcoind regtest 비호환)
- utreexod v0.6.0의 `RegressionNetParams.DeploymentSegwit`는 **BIP9 시그널링** 배포판이다
  (`MinActivationHeight` 없음, bit 1, 표준 threshold 108/144).
- bitcoind regtest는 segwit이 **always-active**라 블록에 bit 1을 세팅하지 않는다.
- 따라서 utreexod 체인에서 segwit이 영원히 미활성 → mempool에서 witness tx를
  `transaction ... has witness data, but segwit isn't active yet`로 거부.
- Coconut 지갑(BIP84, P2WPKH)은 전부 witness tx → utreexod가 받지/릴레이하지 않음.

대조 실험:
```
legacy(P2PKH) tx  → utreexod sendrawtransaction 성공 → bitcoind mempool 전파 ✅
segwit(P2WPKH) tx → utreexod "segwit isn't active yet" 거부 ❌
```
노드 peerinfo의 `relaytxes:false`는 결과가 아니라 전송 측면의 부수 관찰.
(`broadcast_to_peers`는 Ready 피어 전체에 INV를 보내지만 utreexod가 pull/accept하지 않음.)

### 수정 (앱)
임베드 노드가 segwit을 받아주는 bitcoind P2P에도 직접 연결하도록 regtest 고정 피어에 추가:
`lib/providers/node_provider/node_provider.dart` → `_florestaFixedPeers()`
```dart
return const ['10.0.2.2:18333', '10.0.2.2:18444']; // utreexod(proof/filter) + bitcoind(segwit relay)
```
검증: node RPC `addnode 10.0.2.2:18444 add` 후 witness tx(`has_witness=True`)를 node Electrum으로
브로드캐스트 → **bitcoind mempool 진입 확인**. (utreexod는 proof/filter 소스로 계속 유지, 블록 동기화 정상.)

### 프로덕션 영향
mainnet은 segwit이 활성(height > 481824)이므로 utreexod/실피어가 witness tx를 정상 수용·릴레이한다.
이 이슈는 **regtest 스택 한정**이다. 다만 향후 Floresta 브릿지 피어가 tx를 릴레이하지 않는 구성이면
별도 브로드캐스트 폴백을 고려해야 한다.
