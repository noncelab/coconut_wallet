#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Bark FFI Dart Bindings Generator - FOR MAINTAINERS ONLY
# ============================================================================
# ⚠️  THIS SCRIPT IS FOR PACKAGE MAINTAINERS/DEVELOPERS ONLY ⚠️
#
# This script is used by bark maintainers to generate and prepare the Dart
# bindings BEFORE publishing to pub.dev or committing to git.
#
# END USERS of the bark Dart package DO NOT need to run this script!
# When users install the package, the native library is automatically built
# by Dart's Native Assets system from the rust/ directory.
#
# ============================================================================

# Get the absolute directory where this script is located
DART_PKG_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RUST_DIR="$DART_PKG_DIR/rust"

OS=$(uname -s)
echo "🚀 Bark FFI Dart Bindings Generator"
echo "===================================="
echo "Running on: $OS"
echo ""

# Navigate to Dart package directory and check Dart version
cd "$DART_PKG_DIR"

echo "📦 Checking Dart version..."
dart --version
echo ""

echo "📥 Getting Dart dependencies..."
dart pub get
echo ""

# Determine library extension based on OS
if [[ "$OS" == "Darwin" ]]; then
    LIB_EXT="dylib"
elif [[ "$OS" == "Linux" ]]; then
    LIB_EXT="so"
else
    echo "❌ Unsupported OS: $OS"
    echo "Supported: Darwin (macOS), Linux"
    exit 1
fi

# Navigate to rust directory and build bark_ffi_dart
cd "$RUST_DIR"

# Resolve Cargo's target directory instead of assuming ./target — it moves with
# CARGO_TARGET_DIR or a [build] target-dir in .cargo/config.toml.
CARGO_TARGET="$(cargo metadata --format-version 1 --no-deps | jq -r '.target_directory')"
if [ -z "$CARGO_TARGET" ] || [ "$CARGO_TARGET" = "null" ]; then
    echo "❌ Error: could not resolve the Cargo target directory via 'cargo metadata'."
    exit 1
fi

echo "🔨 Building bark_ffi_dart..."
cargo build --release

# Find bark-ffi library in deps (it has the UniFFI metadata embedded).
# Pick the NEWEST match: stale builds from older `cargo build` runs linger in
# deps/ under different hashes, and an old one carries outdated UniFFI metadata
# (e.g. a renamed method), producing bindings that mismatch the freshly-built
# dylib. Sort by mtime so we always use the lib just built above.
BARK_FFI_LIB=$(find "$CARGO_TARGET/release/deps" \( -name "libbark_ffi-*.$LIB_EXT" -o -name "libbark_ffi.$LIB_EXT" \) -type f \
    | while read -r f; do echo "$(date -r "$f" +%s) $f"; done \
    | sort -rn | head -1 | cut -d' ' -f2-)

if [ -z "$BARK_FFI_LIB" ]; then
    echo "❌ Error: Could not find bark-ffi library in $CARGO_TARGET/release/deps"
    echo "Expected pattern: libbark_ffi-*.$LIB_EXT"
    exit 1
fi

echo "📚 Using bark-ffi library with embedded metadata: $BARK_FFI_LIB"
echo ""

# Generate Dart bindings using library mode
# Our uniffi-bindgen binary will:
# 1. Extract metadata from the library
# 2. Auto-locate bark.udl from bark-ffi's source using cargo_metadata
# 3. Generate Dart bindings to lib/src/generated/{namespace}.dart (namespace from bark.udl)
echo "🔧 Generating Dart bindings with library mode..."
cargo run --release --bin uniffi-bindgen -- "$BARK_FFI_LIB" --out-dir "$DART_PKG_DIR/lib/src/generated"

echo ""
echo "✅ Dart bindings generated successfully!"
echo "📄 Output: $DART_PKG_DIR/lib/src/generated/bark.dart"