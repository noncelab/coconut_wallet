# 로컬 regtest 스택

[English](README.md)

bark(아크) 기능을 개발하기 위해 직접 띄우는 regtest 네트워크입니다.
아크 서버(`captaind`)는 자신이 서비스하는 체인의 Bitcoin Core RPC에 직접 접근해야 합니다.
코코넛이 운영하는 regtest에서는 이 접근이 불가능하므로 별도 로컬 환경의 regtest를 씁니다.

`regtest.sh`는 [아크 faucet 저장소](https://gitlab.com/ark-bitcoin/faucet)의 regtest 스택 위에
`compose.override.yml`을 덧씌워, 독립된 도커 컴포즈 프로젝트(`coconut-regtest`)로 실행합니다.
faucet 저장소는 이 저장소와 같은 상위 폴더에 클론합니다. `regtest.sh`는 `../faucet`, `../../faucet` 순서로 찾습니다.
예를 들어 이 저장소가 `~/workspace/coconut_wallet`이면 `~/workspace/faucet`에 둡니다.
다른 곳에 두려면 `FAUCET_DIR`로 경로를 지정합니다.
그리고 앱의 `bark_bitcoin`과 bark 버전이 같은 커밋으로 맞춥니다. 커밋이 다르면 `regtest.sh`가 경고합니다.

```bash
git clone https://gitlab.com/ark-bitcoin/faucet.git ../faucet
git -C ../faucet checkout b590fd2   # bark 0.7.1
```

```bash
./contrib/regtest/regtest.sh up -d --build   # 처음 실행할 때 captaind, CLN, faucet을 컴파일
./contrib/regtest/regtest.sh fund 5          # captaind, faucet, 감시 데몬(watchman)에 테스트 코인 지급
./contrib/regtest/regtest.sh ps              # 그 밖의 도커 컴포즈 명령
./contrib/regtest/regtest.sh down            # 중지 (-v를 붙이면 체인까지 삭제)
```

처음 빌드는 Rust와 C++ 컴파일이 많아 도커 메모리를 많이 씁니다. 도커 기본값(8GB 안팎)에서는 메모리 부족으로 컴파일이 중단될 수 있습니다.
Docker Desktop의 Settings → Resources → Memory를 12GB 이상으로 올리거나, 서비스를 하나씩 빌드한 뒤 띄웁니다.

```bash
for s in electrs captaind watchmand cln bark; do ./contrib/regtest/regtest.sh build $s; done
./contrib/regtest/regtest.sh up -d
```

블록은 5초마다 자동으로 채굴됩니다.

| 서비스 | 호스트 포트 | 용도 |
|---|---|---|
| bitcoind (RPC 사용자 `second`, 비밀번호 `ark`) | 18443 | 체인, `bitcoin-cli` |
| captaind | 3535 | 아크 서버 (gRPC) |
| electrs (Blockstream판) | 50001 / 3002 | 코코넛용 Electrum / bark용 Esplora REST |
| mempool | 8082 | 블록 탐색기, mempool API, 수수료 추정 |
| faucet / faucet 관리 화면 | 8080 / 8081 | 테스트 코인 |

덧씌운 설정은 faucet 스택의 mempool판 electrs를 Blockstream판 electrs로 바꿉니다.
Blockstream판은 `electrum-discovery` 기능을 켜고 빌드합니다(`electrs.Dockerfile`).
코코넛은 `server.features`로 서버가 어느 체인인지 확인하는데, 이 응답을 Blockstream판만 제공하기 때문입니다.
처음 빌드할 때 소스에서 컴파일합니다.

## 앱을 이 스택에 연결하기

`regtest.env`에 아래를 넣습니다. `10.0.2.2`는 안드로이드 에뮬레이터에서 본 호스트 맥의 주소입니다.
실기기는 같은 와이파이에 연결한 뒤 맥의 내부망 IP를 씁니다.

```env
NETWORK_TYPE=regtest
MEMPOOL_URL=http://10.0.2.2:8082
ELECTRUM_SERVER=tcp://10.0.2.2:50001
# 아크(bark): 아크 서버와, bark가 체인 정보를 가져오는 Esplora API
ARK_SERVER_URL=http://10.0.2.2:3535
ARK_ESPLORA_URL=http://10.0.2.2:3002
```

`API_HOST`는 비워 둡니다. 코코넛이 운영하는 faucet은 이 체인이 아니라 코코넛 regtest 체인에 코인을 보냅니다.

## 자주 쓰는 테스트

아래 명령은 저장소 루트에서 실행합니다. 길어서 별칭을 두면 편합니다.

```bash
R=./contrib/regtest/regtest.sh
```

### 상태 확인

```bash
$R ps                    # 서비스 상태 (bark는 필요할 때만 실행하는 도구라 종료 상태가 정상)
$R logs -f captaind      # 아크 서버 로그
```

블록 탐색기: http://localhost:8082

faucet 웹 화면(http://localhost:8080)은 GitHub 로그인이 필요해서 이 스택에서는 코인을 받을 수 없습니다.
아래처럼 `bitcoin-cli`와 bark CLI로 대신합니다.

### 온체인 코인 보내기

```bash
$R exec -u bitcoin bitcoind bitcoin-cli -regtest sendtoaddress <주소> 1
$R exec -u bitcoin bitcoind bitcoin-cli -regtest -generate 6    # 블록을 바로 채굴
```

### bark CLI를 상대 지갑으로 준비하기

스택의 bark CLI 지갑이 앱과 주고받는 상대 역할을 합니다. 처음 한 번 코인을 받아 보딩합니다.

```bash
$R run --rm bark onchain address
$R exec -u bitcoin bitcoind bitcoin-cli -regtest sendtoaddress <bark 온체인 주소> 0.01
$R run --rm bark board "500000 sats"
$R run --rm bark balance     # 30초쯤 뒤 spendable_sat에 잡힘
```

### 앱으로 받기 테스트

`bark send`는 아크 주소, 라이트닝 인보이스, 라이트닝 주소, 비트코인 주소, BIP321 결제 요청을 모두 받습니다.

```bash
$R run --rm bark send <앱의 아크 주소> "50000 sats"
$R run --rm bark send <앱의 라이트닝 인보이스>
$R run --rm bark send "<앱의 BIP321 결제 요청>"
```

### 앱에서 보내기 테스트

```bash
$R run --rm bark address                        # 받을 아크 주소
$R run --rm bark lightning invoice "10000 sats" # 받을 라이트닝 인보이스
$R run --rm bark lightning claim                # 앱이 결제한 뒤 수령
$R run --rm bark bip321                         # 받을 BIP321 결제 요청
```

### 잔액과 VTXO 확인

```bash
$R run --rm bark balance
$R run --rm bark vtxos
$R run --rm bark history
```

### 만료와 갱신 테스트

VTXO 만료 기간은 4320블록입니다(`bark ark-info`의 `vtxo_expiry_delta`). 블록이 5초마다 채굴되므로 약 6시간이 걸립니다.
기다리지 않으려면 블록을 한꺼번에 채굴합니다.

```bash
$R exec -u bitcoin bitcoind bitcoin-cli -regtest -generate 4000
```

### 처음부터 다시

```bash
$R down -v    # 체인, 아크 서버, 지갑 데이터까지 모두 삭제
```

## 앱 로그

앱의 bark 로그는 Android logcat에서 볼 수 있습니다: `adb logcat -s bark`
로그는 코코넛이 수정한 `bark_bitcoin`(`third_party/bark_bitcoin`)이 보내며, Android에서만 동작하므로 iOS에서는 나오지 않습니다.
