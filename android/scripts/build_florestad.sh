#!/usr/bin/env bash
#
# Android용 florestad 실행파일을 빌드해 jniLibs/<abi>/libflorestad.so 로 배치한다.
#
# 왜 필요한가:
#   floresta-node 는 floresta-chain/bitcoinkernel 을 강제 on 하고, 그 의존성인
#   libbitcoinkernel-sys 의 build.rs 가 NDK sysroot 루트 디렉터리
#   (sysroot/usr/lib/<triple>)를 링커 search path 에 추가한다.
#   그 디렉터리에는 정적 bionic(libc.a/libm.a/libdl.a)만 있고 동적 스텁(libc.so)은
#   API 레벨 하위 디렉터리(sysroot/usr/lib/<triple>/<api>)에 있어서, -L 순서상
#   libc.a 가 먼저 잡혀 정적 libc 가 .so/.exe 에 번들된다.
#   → 시작 시 init_have_lse_atomics 가 null auxv 를 deref 해 SIGSEGV.
#
# 해결:
#   타깃 전용 RUSTFLAGS 로 API 레벨 디렉터리를 build.rs 의 -L 보다 앞에 검색시킨다.
#   API 24 이상이어야 한다(Bitcoin Core kernel 이 getifaddrs 사용, libbitcoinkernel-sys MIN_ANDROID_API=24).
#
# 소스: native/floresta_ffi/Cargo.toml 의 git 의존(rev 고정)이 가리키는 cargo git checkout 을
#   그대로 쓴다. 로컬 Floresta 클론도, 스크립트에 박힌 rev 도 없다 → 해시 단일 출처.
#   FFI 라이브러리와 florestad 실행파일이 항상 같은 커밋에서 나온다.
#   로컬 개발에서 FLORESTA_DIR 를 지정하면 그 경로를 우선한다.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
JNI_LIBS="$PROJECT_ROOT/android/app/src/main/jniLibs"

# Floresta rev 는 FFI 매니페스트에서 유도한다(하드코딩 금지).
RUST_MANIFEST="$PROJECT_ROOT/native/floresta_ffi/Cargo.toml"
CARGO_TARGET_DIR="${CARGO_TARGET_DIR:-$PROJECT_ROOT/native/floresta_ffi/target}"
FLORESTA_DIR="${FLORESTA_DIR:-}"
if [[ -z "$FLORESTA_DIR" ]]; then
  FLORESTA_DIR="$(cargo metadata --manifest-path "$RUST_MANIFEST" --format-version 1 \
    | python3 -c '
import json, os, sys
pkg = next(p for p in json.load(sys.stdin)["packages"] if p["name"] == "floresta-node")
d = os.path.dirname(pkg["manifest_path"])
while d != "/" and not os.path.isdir(os.path.join(d, "bin", "florestad")):
    d = os.path.dirname(d)
print(d)
')"
fi
API_LEVEL="${ANDROID_API_LEVEL:-24}"
HOST_TAG="${NDK_HOST_TAG:-darwin-x86_64}"

NDK="${ANDROID_NDK_HOME:-}"
if [[ -z "$NDK" ]]; then
  NDK="$(ls -d "$HOME"/Library/Android/sdk/ndk/* 2>/dev/null | sort -V | tail -n 1)"
fi
if [[ -z "$NDK" || ! -d "$NDK" ]]; then
  echo "Android NDK not found. Set ANDROID_NDK_HOME." >&2
  exit 1
fi
if [[ ! -d "$FLORESTA_DIR" ]]; then
  echo "Floresta source not found at $FLORESTA_DIR. Set FLORESTA_DIR." >&2
  exit 1
fi

SYSROOT_LIB="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/sysroot/usr/lib"

# abi:rust-triple
TARGETS=()
if [[ $# -eq 0 ]]; then
  TARGETS=("arm64-v8a:aarch64-linux-android")
else
  for abi in "$@"; do
    case "$abi" in
      arm64-v8a) TARGETS+=("arm64-v8a:aarch64-linux-android") ;;
      x86_64) TARGETS+=("x86_64:x86_64-linux-android") ;;
      armeabi-v7a) TARGETS+=("armeabi-v7a:armv7-linux-androideabi") ;;
      *) echo "Unknown ABI: $abi" >&2; exit 1 ;;
    esac
  done
fi

echo "NDK:      $NDK"
echo "Floresta: $FLORESTA_DIR"
echo "API:      $API_LEVEL"

for entry in "${TARGETS[@]}"; do
  abi="${entry%%:*}"
  triple="${entry##*:}"
  api_dir="$SYSROOT_LIB/$triple/$API_LEVEL"
  if [[ ! -e "$api_dir/libc.so" ]]; then
    echo "API $API_LEVEL sysroot not found for $triple: $api_dir" >&2
    exit 1
  fi

  env_var="CARGO_TARGET_$(echo "$triple" | tr 'a-z-' 'A-Z_')_RUSTFLAGS"
  echo "→ building $abi ($triple)"
  (
    cd "$FLORESTA_DIR"
    env "ANDROID_NDK_HOME=$NDK" \
      "CARGO_TARGET_DIR=$CARGO_TARGET_DIR" \
      "$env_var=-L native=$api_dir" \
      cargo ndk --platform "$API_LEVEL" -t "$abi" build --release -p florestad
  )

  mkdir -p "$JNI_LIBS/$abi"
  cp "$CARGO_TARGET_DIR/$triple/release/florestad" "$JNI_LIBS/$abi/libflorestad.so"
  echo "   placed $JNI_LIBS/$abi/libflorestad.so"

  # 동적 libc 링크 회귀 방지: NEEDED 에 libc.so 가 있는지 확인.
  readelf="$NDK/toolchains/llvm/prebuilt/$HOST_TAG/bin/llvm-readelf"
  if [[ -x "$readelf" ]] && ! "$readelf" -d "$JNI_LIBS/$abi/libflorestad.so" | grep -q "libc.so"; then
    echo "ERROR: $abi libflorestad.so is not dynamically linked to libc.so" >&2
    exit 1
  fi
done

echo "done."
