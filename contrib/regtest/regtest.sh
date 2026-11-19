#!/usr/bin/env bash
# Run the Ark faucet repo's regtest stack (bitcoind, electrs, mempool, captaind,
# watchmand, CLN, bark, faucet) for Coconut Wallet development, with
# ./compose.override.yml on top. Runs as its own compose project so it never
# touches a stack started from the faucet repo itself. See ./README.md.
#
#   ./regtest.sh up -d --build      start (first build compiles captaind etc.)
#   ./regtest.sh fund [BTC]         fund captaind, faucet and watchman
#   ./regtest.sh <compose args>     anything else, e.g. ps, logs -f captaind, down
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

# Checkout of https://gitlab.com/ark-bitcoin/faucet; defaults to a sibling of
# this repo or of its parent directory.
if [[ -z "${FAUCET_DIR:-}" ]]; then
    for candidate in "$REPO_ROOT/../faucet" "$REPO_ROOT/../../faucet"; do
        if [[ -f "$candidate/docker-compose.yml" ]]; then
            FAUCET_DIR="$candidate"
            break
        fi
    done
fi
if [[ ! -f "${FAUCET_DIR:-}/docker-compose.yml" ]]; then
    echo "Faucet repo not found. Clone https://gitlab.com/ark-bitcoin/faucet next to this repo," >&2
    echo "or set FAUCET_DIR to its path." >&2
    exit 1
fi
FAUCET_DIR="$(cd "$FAUCET_DIR" && pwd)"

# Faucet commit whose captaind matches the app's bark version (bark 0.7.1)
FAUCET_REV=b590fd2
if [[ "$(git -C "$FAUCET_DIR" rev-parse --short=7 HEAD 2>/dev/null)" != "$FAUCET_REV" ]]; then
    echo "Warning: faucet repo is not at $FAUCET_REV (bark 0.7.1). Run: git -C \"$FAUCET_DIR\" checkout $FAUCET_REV" >&2
fi

# The faucet always sets up GitHub login, but its dummy secrets lack those files
FAUCET_SECRETS_DIR="$HERE/.faucet-secrets"
mkdir -p "$FAUCET_SECRETS_DIR"
cp "$FAUCET_DIR"/not_so_secret/* "$FAUCET_SECRETS_DIR"/
for name in github_client_id github_client_secret jwt_secret; do
    [[ -f "$FAUCET_SECRETS_DIR/$name" ]] || printf 'unused-%s' "$name" > "$FAUCET_SECRETS_DIR/$name"
done
export COCONUT_FAUCET_SECRETS_DIR="$FAUCET_SECRETS_DIR"

export COMPOSE_PROJECT_NAME=coconut-regtest
export COCONUT_REGTEST_DIR="$HERE"
export COMPOSE_FILE="$FAUCET_DIR/docker-compose.yml:$HERE/compose.override.yml"

cd "$FAUCET_DIR"
if [[ "${1:-}" == "fund" ]]; then
    shift
    exec bash contrib/docker/fund.sh "$@"
fi
exec docker compose "$@"
