#!/usr/bin/env bash
# build_android.sh — Build trezor-bridge as a JNI shared library for Android
#
# Output: android/app/src/main/jniLibs/<abi>/libtrezor_bridge.so
#         android/app/src/main/kotlin/.../TrezorBridgeFFI.kt  (UniFFI bindings)
#
# Requirements:
#   cargo, rustup, cargo-ndk (cargo install cargo-ndk), Android NDK
#   rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$CRATE_DIR/../.." && pwd)"

CRATE_NAME="trezor_bridge"
JNI_OUT="$REPO_ROOT/android/app/src/main/jniLibs"
# uniffi-bindgen creates uniffi/trezor_bridge/trezor_bridge.kt under the out-dir.
# Point to the kotlin source root so the package path resolves correctly.
KOTLIN_OUT="$REPO_ROOT/android/app/src/main/kotlin"

# Minimum Android API level (matches app/build.gradle minSdkVersion)
MIN_SDK=23

ABIS=(
    "arm64-v8a"
    "armeabi-v7a"
    "x86_64"
)

RUST_TARGETS=(
    "aarch64-linux-android"
    "armv7-linux-androideabi"
    "x86_64-linux-android"
)

echo "==> Installing Rust targets"
for t in "${RUST_TARGETS[@]}"; do
    rustup target add "$t" 2>/dev/null || true
done

echo "==> Building with cargo-ndk"
# cargo-ndk must be run from the crate directory (no --manifest-path support)
pushd "$CRATE_DIR" > /dev/null
cargo ndk \
    --target aarch64-linux-android \
    --target armv7-linux-androideabi \
    --target x86_64-linux-android \
    --platform "$MIN_SDK" \
    --output-dir "$JNI_OUT" \
    -- build --release
popd > /dev/null

echo "==> Generating Kotlin bindings (uniffi-bindgen)"
cargo run \
    --manifest-path "$CRATE_DIR/Cargo.toml" \
    --features uniffi/cli \
    --bin uniffi-bindgen \
    generate \
    "$CRATE_DIR/src/trezor.udl" \
    --language kotlin \
    --out-dir "$KOTLIN_OUT" \
    --config "$CRATE_DIR/uniffi.toml"

echo "  Kotlin bindings generated at $KOTLIN_OUT"

echo ""
echo "Done! JNI libraries at:"
for abi in "${ABIS[@]}"; do
    so="$JNI_OUT/$abi/lib${CRATE_NAME}.so"
    if [[ -f "$so" ]]; then
        echo "  $so"
    fi
done
echo ""
echo "Next steps:"
echo "  1. Open project in Android Studio — Kotlin bindings are already in onl.coconut.wallet.uniffi"
echo "  2. Build & run on device/emulator with Trezor Safe 7 nearby"
