#!/usr/bin/env bash
#
# Coconut Wallet regtest 헬퍼.
# bitcoind(채굴/RPC) + florestad(Electrum/RPC) 스택을 제어하고,
# 앱이 붙을 수 있도록 디스크립터를 등록/리셋하는 데 사용한다.
#
#   ./docker/regtest/regtest.sh up            # 스택 기동
#   ./docker/regtest/regtest.sh status        # 동기화 상태
#   ./docker/regtest/regtest.sh mine [n]      # 블록 채굴 (기본 10)
#   ./docker/regtest/regtest.sh send <addr> <btc>
#   ./docker/regtest/regtest.sh descriptor    # 테스트용 wpkh 디스크립터 출력
#   ./docker/regtest/regtest.sh load <desc>   # florestad에 디스크립터 등록 + rescan
#   ./docker/regtest/regtest.sh electrum      # Electrum 서버 헤더 응답 확인
#   ./docker/regtest/regtest.sh down          # 종료 (볼륨 유지)
#   ./docker/regtest/regtest.sh reset         # 종료 + 볼륨 삭제
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPOSE="docker compose -f ${HERE}/docker-compose.yml"
BTC="docker exec cw_bitcoind bitcoin-cli -regtest -rpcuser=coconut -rpcpassword=coconut -rpcwallet=regtest"
FL="docker exec cw_florestad floresta-cli"

cmd_up() { "$COMPOSE" up -d; echo "대기 중... (bitcoind healthcheck → florestad 기동)"; sleep 3; cmd_status; }
cmd_down() { "$COMPOSE" down; }
cmd_reset() { "$COMPOSE" down -v; }
cmd_status() {
  echo "== bitcoind =="
  docker exec cw_bitcoind bitcoin-cli -regtest -rpcuser=coconut -rpcpassword=coconut getblockchaininfo \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); print(f"blocks={d[\"blocks\"]} chain={d[\"chain\"]}")'
  echo "== florestad (json-rpc getblockchaininfo) =="
  "$FL" getblockchaininfo \
    | python3 -c 'import sys,json; d=json.load(sys.stdin); h=d.get("height",d.get("blocks")); v=d.get("validated",d.get("blocks")); print(f"height={h} validated={v} ibd={d.get(\"ibd\",d.get(\"initialblockdownload\"))} progress={d.get(\"progress\",d.get(\"verificationprogress\"))}")' \
    || echo "  (florestad RPC 미응답 — logs 확인: $COMPOSE logs florestad)"
}
cmd_mine() {
  local n="${1:-10}"
  local addr; addr="$($BTC getnewaddress)"
  $BTC generatetoaddress "$n" "$addr" >/dev/null
  echo "mined $n → $addr"
}
cmd_send() { $BTC sendtoaddress "$1" "$2"; }
cmd_descriptor() {
  docker exec cw_bitcoind bitcoin-cli -regtest -rpcuser=coconut -rpcpassword=coconut createwallet regtest >/dev/null 2>&1 || true
  $BTC listdescriptors \
    | python3 -c 'import sys,json; ds=json.load(sys.stdin)["descriptors"]; print(next(d["desc"] for d in ds if d["desc"].startswith("wpkh(") and "/0/*" in d["desc"]))'
}
cmd_load() {
  local desc="$1"
  "$FL" loaddescriptor "$desc"
  "$FL" rescanblockchain
  echo "loaded + rescanned"
}
cmd_electrum() {
  printf '{"id":1,"method":"blockchain.headers.subscribe","params":[]}\n' | nc 127.0.0.1 50001
}

"cmd_${1:-status}" "${@:2}"
