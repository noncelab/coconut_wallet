#!/usr/bin/env bash

set -euo pipefail

cleanup() {
  unset ANDROID_USE_DEBUG_SIGNING_FOR_RELEASE_RUN
}
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "Select Android flavor to run:"
echo "  1) mainnet"
echo "  2) regtest"

while true; do
  read -r -p "Flavor [1/mainnet, 2/regtest]: " FLAVOR_INPUT

  case "$FLAVOR_INPUT" in
    1 | mainnet)
      FLAVOR="mainnet"
      break
      ;;
    2 | regtest)
      FLAVOR="regtest"
      break
      ;;
    *)
      echo "Please enter 1, 2, mainnet, or regtest."
      ;;
  esac
done

export ANDROID_USE_DEBUG_SIGNING_FOR_RELEASE_RUN=true

RUN_CMD=(
  fvm flutter run
  --flavor "$FLAVOR"
  --release
)

if [[ "$FLAVOR" == "mainnet" ]]; then
  RUN_CMD+=(--dart-define=USE_FIREBASE=true)
fi

cd "$PROJECT_ROOT"
"${RUN_CMD[@]}"
