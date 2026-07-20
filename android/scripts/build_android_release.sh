#!/usr/bin/env bash

set -euo pipefail

cleanup() {
  unset ANDROID_SIGNING_STORE_PASSWORD
  unset ANDROID_SIGNING_KEY_PASSWORD
  unset SIGNING_PASSWORD
  if [[ -n "${KEYCHECK_DIR:-}" ]]; then
    rm -rf "$KEYCHECK_DIR"
  fi
}
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ANDROID_DIR="$PROJECT_ROOT/android"
APP_DIR="$ANDROID_DIR/app"

read_property() {
  local key="$1"
  local file="$2"
  sed -n "s/^[[:space:]]*$key[[:space:]]*=[[:space:]]*//p" "$file" | tail -n 1
}

resolve_store_file() {
  local store_file="$1"

  if [[ "$store_file" = /* ]]; then
    printf '%s\n' "$store_file"
  else
    printf '%s\n' "$APP_DIR/$store_file"
  fi
}

validate_signing_password() {
  local key_properties_file="$ANDROID_DIR/key_${FLAVOR}.properties"

  if [[ ! -f "$key_properties_file" ]]; then
    echo "Keystore properties file not found: $key_properties_file" >&2
    exit 1
  fi

  local key_alias
  local store_file
  key_alias="$(read_property "keyAlias" "$key_properties_file")"
  store_file="$(read_property "storeFile" "$key_properties_file")"

  if [[ -z "$key_alias" || -z "$store_file" ]]; then
    echo "keyAlias and storeFile are required in $key_properties_file." >&2
    exit 1
  fi

  local resolved_store_file
  resolved_store_file="$(resolve_store_file "$store_file")"

  if [[ ! -f "$resolved_store_file" ]]; then
    echo "Keystore file not found: $resolved_store_file" >&2
    exit 1
  fi

  KEYCHECK_DIR="$(mktemp -d)"

  if ! keytool -importkeystore \
    -srckeystore "$resolved_store_file" \
    -srcalias "$key_alias" \
    -srcstorepass "$SIGNING_PASSWORD" \
    -srckeypass "$SIGNING_PASSWORD" \
    -destkeystore "$KEYCHECK_DIR/keycheck.p12" \
    -deststoretype PKCS12 \
    -deststorepass "$SIGNING_PASSWORD" \
    -destkeypass "$SIGNING_PASSWORD" \
    -noprompt >/dev/null 2>&1; then
    echo "Invalid keystore/key password for $FLAVOR." >&2
    exit 1
  fi

  echo "Keystore/key password verified for $FLAVOR."
}

echo "Select Android flavor to build:"
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

read -r -s -p "Keystore/key password: " SIGNING_PASSWORD
echo

if [[ -z "$SIGNING_PASSWORD" ]]; then
  echo "Password cannot be empty." >&2
  exit 1
fi

validate_signing_password

export ANDROID_SIGNING_STORE_PASSWORD="$SIGNING_PASSWORD"
export ANDROID_SIGNING_KEY_PASSWORD="$SIGNING_PASSWORD"

BUILD_CMD=(
  fvm flutter build appbundle
  --flavor "$FLAVOR"
  --release
)

if [[ "$FLAVOR" == "mainnet" ]]; then
  BUILD_CMD+=(--dart-define=USE_FIREBASE=true)
fi

cd "$PROJECT_ROOT"
"${BUILD_CMD[@]}"
