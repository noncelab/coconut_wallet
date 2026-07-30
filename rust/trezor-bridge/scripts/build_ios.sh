#!/usr/bin/env bash
# build_ios.sh — Build trezor-bridge as an XCFramework for iOS/iOS Simulator
#
# Output: ios/Runner/TrezorBridge.xcframework
#
# Requirements:
#   cargo, rustup, cargo-swift (or cargo-xcode), lipo, xcodebuild
#   rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRATE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPO_ROOT="$(cd "$CRATE_DIR/../.." && pwd)"

CRATE_NAME="trezor_bridge"
OUT_DIR="$REPO_ROOT/ios/Runner"
XCFRAMEWORK_NAME="TrezorBridge.xcframework"
XCFRAMEWORK_OUT="$OUT_DIR/$XCFRAMEWORK_NAME"

TARGETS=(
    "aarch64-apple-ios"
    "aarch64-apple-ios-sim"
    "x86_64-apple-ios"
)

echo "==> Installing Rust targets"
for t in "${TARGETS[@]}"; do
    rustup target add "$t" 2>/dev/null || true
done

echo "==> Building for each target"
for t in "${TARGETS[@]}"; do
    echo "  Building $t ..."
    cargo build --manifest-path "$CRATE_DIR/Cargo.toml" \
        --release \
        --target "$t"
done

# --- Generate UniFFI Swift bindings ---
echo "==> Generating Swift bindings (uniffi-bindgen)"
cargo run \
    --manifest-path "$CRATE_DIR/Cargo.toml" \
    --features uniffi/cli \
    --bin uniffi-bindgen \
    generate \
    "$CRATE_DIR/src/trezor.udl" \
    --language swift \
    --out-dir "$CRATE_DIR/target/swift_bindings"

# Copy generated Swift file to iOS project
cp "$CRATE_DIR/target/swift_bindings/${CRATE_NAME}.swift" \
   "$OUT_DIR/TrezorBridgeFFI.swift"
# Copy the modulemap so Xcode can import TrezorBridgeFFI
if [[ -f "$CRATE_DIR/target/swift_bindings/${CRATE_NAME}FFI.modulemap" ]]; then
    cp "$CRATE_DIR/target/swift_bindings/${CRATE_NAME}FFI.modulemap" \
       "$OUT_DIR/TrezorBridgeFFI.modulemap"
fi
echo "  Swift bindings -> $OUT_DIR"

# --- Create fat library for simulator (arm64 + x86_64) ---
echo "==> Creating simulator fat library (lipo)"
SIM_ARM="$CRATE_DIR/target/aarch64-apple-ios-sim/release/lib${CRATE_NAME}.a"
SIM_X86="$CRATE_DIR/target/x86_64-apple-ios/release/lib${CRATE_NAME}.a"
SIM_FAT="$CRATE_DIR/target/sim_fat/lib${CRATE_NAME}.a"
mkdir -p "$(dirname "$SIM_FAT")"
lipo -create "$SIM_ARM" "$SIM_X86" -output "$SIM_FAT"

# --- Stage headers alongside each .a for xcodebuild ---
HEADERS_DIR="$CRATE_DIR/target/swift_bindings/headers"
mkdir -p "$HEADERS_DIR"
cp "$CRATE_DIR/target/swift_bindings/${CRATE_NAME}FFI.h"        "$HEADERS_DIR/"
cp "$CRATE_DIR/target/swift_bindings/${CRATE_NAME}FFI.modulemap" "$HEADERS_DIR/module.modulemap"

# --- Assemble XCFramework (with headers so Swift sees RustBuffer etc.) ---
echo "==> Assembling XCFramework"
rm -rf "$XCFRAMEWORK_OUT"
xcodebuild -create-xcframework \
    -library "$CRATE_DIR/target/aarch64-apple-ios/release/lib${CRATE_NAME}.a" \
    -headers "$HEADERS_DIR" \
    -library "$SIM_FAT" \
    -headers "$HEADERS_DIR" \
    -output "$XCFRAMEWORK_OUT"

echo ""
echo "Done! XCFramework at:"
echo "  $XCFRAMEWORK_OUT"
echo ""
echo "Next steps:"
echo "  1. In Xcode, add $XCFRAMEWORK_NAME to Runner target -> Frameworks, Libraries."
echo "  2. Add TrezorBridgeFFI.swift to the Runner target."
echo "  3. Replace TODO stubs in TrezorMethodHandler.swift with TrezorBridge* calls."
