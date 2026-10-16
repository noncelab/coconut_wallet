# Coconut Wallet regtest 스택

앱을 Floresta에 붙여 로컬에서 검증하기 위한 Docker 기반 regtest 환경.

```
bitcoind (채굴/RPC, faucet)
     │ 127.0.0.1:18444  (utreexod와 netns 공유)
     ▼
utreexod (bridge 모드: --utreexoproofindex)   ← bitcoind는 utreexo proof를 안 만든다
     │ bitcoind:18333
     ▼
florestad
     ├ Electrum  50001  ← 앱의 ElectrumChainSource
     └ JSON-RPC   8332  ← loaddescriptor / getblockchaininfo
```

## 왜 utreexod가 필요한가

Floresta는 utreexo accumulator/proof로 검증한다. bitcoind는 proof를 만들지 않으므로
utreexod를 bridge(`--utreexoproofindex`)로 띄워 proof를 제공해야 florestad가 블록을 **검증**한다.
(`--utreexoproofindex`를 켜면 utreexod가 자동으로 `--noutreexo` bridge 모드가 된다.)

## 왜 네트워크 네임스페이스를 공유하나

utreexod는 **regtest에서 피어 주소가 `127.0.0.1`/`localhost`일 때만** 동기화 피어로 인정한다
(`utreexod/netsync/manager.go`의 `isSyncCandidate`). Docker 브리지 IP로는 동기화를 거부하므로
utreexod를 bitcoind와 같은 netns(`network_mode: service:bitcoind`)에 두고 `127.0.0.1:18444`로 붙인다.
bitcoind에는 그런 제약이 없어 florestad는 `bitcoind:18333`(utreexod)으로 접속한다.

## 실행

```bash
# 이미지 빌드(utreexod) + 기동
docker compose -f docker/regtest/docker-compose.yml up -d --build

# 상태
./docker/regtest/regtest.sh status

# 최초 1회: bitcoind 지갑 생성 + 110블록 채굴
docker exec cw_bitcoind bitcoin-cli -regtest -rpcuser=coconut -rpcpassword=coconut createwallet regtest
./docker/regtest/regtest.sh mine 110

# 노드가 마이닝 전에 떴다면 한 번 재시작하면 동기화된다
docker compose -f docker/regtest/docker-compose.yml restart utreexod
docker compose -f docker/regtest/docker-compose.yml restart florestad
```

> 주의: utreexod/florestad가 bitcoind보다 먼저(높이 0에서) 뜨면, 새 블록을 자동으로 따라오지
> 않는 경우가 있다. 마이닝 후 한 번 재시작하는 것이 확실하다.

## 과거 내역 스캔 (`rescanblockchain`)

Floresta의 `rescanblockchain`(JSON-RPC)은 지갑 주소를 **BIP158 compact block filter**와 대조해
매칭되는 블록만 받아 처리한다(`cfilters.match_any` → `node.get_block` → `wallet.block_process`).
따라서 **compact filter를 서빙하는 피어**가 있어야 한다.

utreexod는 `--cfilters`를 주면 **`NODE_COMPACT_FILTERS`를 광고**하고 `OnGetCFilters`로 필터를 서빙한다.
그래서 utreexod **하나로 utreexo proof + compact filter를 모두** 제공할 수 있고,
florestad는 `--connect utreexod` 단일 피어로 `rescanblockchain`까지 동작한다.

```bash
docker exec cw_florestad floresta-cli rescanblockchain   # 과거 블록 스캔
```

> 대안: 필터를 별도 피어(bitcoind `-blockfilterindex=1 -peerblockfilters=1`)에서 받을 수도 있지만,
> utreexod `--cfilters`로 피어 하나로 끝내는 게 깔끔하다.
> Floresta의 원래 권장 흐름은 **지갑 디스크립터를 IBD 전에 등록**해 동기화 중 매칭하는 것.

## 앱에서 붙이기

Electrum 서버를 커스텀으로 추가한다:
- Android 에뮬레이터: host `10.0.2.2`, port `50001`, ssl off, **isFloresta=true**, rpcPort `8332`
- iOS 시뮬레이터/desktop: host `127.0.0.1`, port `50001`

앱은 florestad에 지갑 디스크립터를 등록(JSON-RPC `loaddescriptor`)하고 `rescanblockchain`을 호출한 뒤,
Electrum `scripthash.*`로 잔액/이력/UTXO를 조회한다.

## 수동 파이프라인 확인

```bash
BTC="docker exec cw_bitcoind bitcoin-cli -regtest -rpcuser=coconut -rpcpassword=coconut"
DESC=$($BTC -rpcwallet=regtest listdescriptors | python3 -c 'import sys,json; d=json.load(sys.stdin)["descriptors"]; print(next(x["desc"] for x in d if x["desc"].startswith("wpkh(") and "/0/*" in x["desc"]))')
ADDR=$($BTC deriveaddresses "$DESC" "[0,0]" | python3 -c 'import sys,json; print(json.load(sys.stdin)[0])')

docker exec cw_florestad floresta-cli loaddescriptor "$DESC"
docker exec cw_florestad floresta-cli rescanblockchain
$BTC -rpcwallet=regtest sendtoaddress "$ADDR" 1
./docker/regtest/regtest.sh mine 1
```

## 종료

```bash
./docker/regtest/regtest.sh down      # 볼륨 유지
./docker/regtest/regtest.sh reset     # 볼륨 삭제(체인/지갑 초기화)
```

## 네이티브(에뮬레이터)에서 실행

Floresta를 앱에 **임베드**(FFI)해서 도는 경우와, **도커 florestad에 접속**하는 경우 두 가지가 있다.

### A. 임베드(FFI) — 기기에서 노드가 직접 돌아감

필요 도구(최초 1회):

```bash
rustup target add aarch64-linux-android x86_64-linux-android armv7-linux-androideabi
cargo install cargo-ndk
# Android SDK/NDK 필요 (ANDROID_NDK_HOME)
```

Android용 `.so` 빌드 → `android/app/src/main/jniLibs/<abi>/`에 자동 배치(그래들이 번들):

```bash
make android-lib     # arm64-v8a + x86_64
```

AVD 생성(최초 1회):

```bash
export ANDROID_HOME=~/Library/Android/sdk
yes | "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --licenses
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" "system-images;android-35;google_apis;arm64-v8a" "platforms;android-35"
echo no | "$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager" create avd \
  -n coconut_regtest -k "system-images;android-35;google_apis;arm64-v8a" -d pixel_6
"$ANDROID_HOME/emulator/emulator" -avd coconut_regtest &
```

앱 실행(regtest flavor):

```bash
fvm flutter run --flavor regtest -d emulator-5554
```

임베드 노드는 앱 샌드박스(`getApplicationSupportDirectory()/floresta`)에 체인 데이터를 저장하고,
앱의 Floresta 서버 설정(isFloresta + rpcPort)에 따라 `FlorestaNode.start(...)`로 기동된다.

### B. 도커 florestad 접속(임베드 없이, E2E 검증용)

앱 설정에서 커스텀 Electrum 서버를 추가:

| 항목 | 값 |
|---|---|
| host | `10.0.2.2` (에뮬레이터→호스트) |
| port | `50001` |
| ssl | off |
| isFloresta | on |
| rpcPort | `8332` |

그러면 앱이 florestad에 디스크립터를 등록/리셋하고 Electrum `scripthash.*`로 조회한다.
