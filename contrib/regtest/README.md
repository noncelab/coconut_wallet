# Local regtest stack

[한국어](README.ko.md)

A self-hosted regtest network for developing the bark (Ark) proof of concept.
The Ark server (`captaind`) needs Bitcoin Core RPC on the chain it serves, so
development uses a separate local regtest rather than Coconut's hosted one.

`regtest.sh` runs the regtest stack from the [Ark faucet repo](https://gitlab.com/ark-bitcoin/faucet)
with `compose.override.yml` on top, as a separate compose project
(`coconut-regtest`). Clone the faucet repo into the same parent directory as
this repo (`regtest.sh` looks for `../faucet`, then `../../faucet`), or set
`FAUCET_DIR` to its path. Check out the commit whose bark version
matches the app's `bark_bitcoin` (`regtest.sh` warns otherwise):

```bash
git clone https://gitlab.com/ark-bitcoin/faucet.git ../faucet
git -C ../faucet checkout b590fd2   # bark 0.7.1
```

```bash
./contrib/regtest/regtest.sh up -d --build   # first run compiles captaind, CLN and the faucet
./contrib/regtest/regtest.sh fund 5          # fund captaind, the faucet and the watchman
./contrib/regtest/regtest.sh ps              # any other docker compose command
./contrib/regtest/regtest.sh down            # stop (add -v to wipe the chain)
```

The first build compiles a lot of Rust and C++ and needs memory. With Docker
Desktop's default (about 8 GB) compilers can be killed for lack of memory. Raise
Settings → Resources → Memory to 12 GB or more, or build the services one at a
time before starting the stack:

```bash
for s in electrs captaind watchmand cln bark; do ./contrib/regtest/regtest.sh build $s; done
./contrib/regtest/regtest.sh up -d
```

A block is mined every 5 seconds.

| Service | Host port | Use |
|---|---|---|
| bitcoind (RPC user `second`, password `ark`) | 18443 | chain, `bitcoin-cli` |
| captaind | 3535 | Ark server (gRPC) |
| electrs (Blockstream) | 50001 / 3002 | Electrum for Coconut / Esplora REST for bark |
| mempool | 8082 | block explorer, mempool API, fee estimates |
| faucet / faucet admin | 8080 / 8081 | test coins |

The override swaps the faucet stack's mempool electrs fork for Blockstream's
electrs built with the `electrum-discovery` feature (`electrs.Dockerfile`),
since Coconut needs `server.features` to check which chain a server is on. The
first build compiles it from source.

## Pointing the app at the stack

In `regtest.env` (`10.0.2.2` is the host machine as seen from the Android emulator):

```env
NETWORK_TYPE=regtest
MEMPOOL_URL=http://10.0.2.2:8082
ELECTRUM_SERVER=tcp://10.0.2.2:50001
# Ark (bark): the Ark server and the Esplora API bark uses as its chain source
ARK_SERVER_URL=http://10.0.2.2:3535
ARK_ESPLORA_URL=http://10.0.2.2:3002
```

Leave `API_HOST` unset: Coconut's hosted faucet pays out on its own chain, not this one.

## Common tasks

Run these from the repo root. An alias keeps them short:

```bash
R=./contrib/regtest/regtest.sh
```

### Status

```bash
$R ps                    # service status (bark is a CLI run on demand, so "exited" is normal)
$R logs -f captaind      # Ark server logs
```

Block explorer: http://localhost:8082

The faucet web page (http://localhost:8080) needs a GitHub login, so it can't
hand out coins on this stack. Use `bitcoin-cli` and the bark CLI instead.

### On-chain coins

```bash
$R exec -u bitcoin bitcoind bitcoin-cli -regtest sendtoaddress <address> 1
$R exec -u bitcoin bitcoind bitcoin-cli -regtest -generate 6    # mine blocks now
```

### The bark CLI as the other wallet

The stack's bark CLI wallet plays the counterparty. Fund and board it once:

```bash
$R run --rm bark onchain address
$R exec -u bitcoin bitcoind bitcoin-cli -regtest sendtoaddress <bark on-chain address> 0.01
$R run --rm bark board "500000 sats"
$R run --rm bark balance     # shows in spendable_sat after about 30 seconds
```

### Receiving in the app

`bark send` takes an Ark address, a Lightning invoice or address, a Bitcoin
address or a BIP321 payment request:

```bash
$R run --rm bark send <app's Ark address> "50000 sats"
$R run --rm bark send <app's Lightning invoice>
$R run --rm bark send "<app's BIP321 payment request>"
```

### Sending from the app

```bash
$R run --rm bark address                        # Ark address to pay
$R run --rm bark lightning invoice "10000 sats" # Lightning invoice to pay
$R run --rm bark lightning claim                # claim it once the app has paid
$R run --rm bark bip321                         # BIP321 payment request to pay
```

### Balances and VTXOs

```bash
$R run --rm bark balance
$R run --rm bark vtxos
$R run --rm bark history
```

### Expiry and refresh

VTXOs expire after 4320 blocks (`vtxo_expiry_delta` in `bark ark-info`), about
6 hours at one block every 5 seconds. Mine ahead instead of waiting:

```bash
$R exec -u bitcoin bitcoind bitcoin-cli -regtest -generate 4000
```

### Start over

```bash
$R down -v    # removes the chain, Ark server and wallet data
```

## App logs

The app's bark logs are in Android logcat: `adb logcat -s bark`. Coconut's
patched `bark_bitcoin` (`third_party/bark_bitcoin`) sends them on Android only,
so iOS shows none.
