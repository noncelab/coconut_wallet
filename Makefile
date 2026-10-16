# ── Rust FFI (Floresta 임베딩) ────────────────────────────────────────────────
.PHONY: rust-build rust-check rust-clean florestad-android android-lib ios-lib ios-lib-sim ios-lib-device

RUST_DIR := native/floresta_ffi

rust-check:
	cargo check --manifest-path $(RUST_DIR)/Cargo.toml

rust-build:
	cargo build --release --manifest-path $(RUST_DIR)/Cargo.toml

rust-clean:
	cargo clean --manifest-path $(RUST_DIR)/Cargo.toml

# ── 모바일 FFI 라이브러리 ──────────────────────────────────────────────────────
# Android: florestad 실행파일을 jniLibs/<abi>/libflorestad.so 로 빌드/배치.
#   사전: rustup target add aarch64-linux-android x86_64-linux-android
#         cargo install cargo-ndk
#
#   주의: android-lib 은 반드시 API 24+ 로 빌드해야 한다. 자세한 이유는
#   android/scripts/build_florestad.sh 참고(정적 libc 번들 → 시작 SIGSEGV).
NDK_HOME ?= $(ANDROID_NDK_HOME)
JNI_LIBS := android/app/src/main/jniLibs

florestad-android:
	bash android/scripts/build_florestad.sh $(if $(ABI),$(ABI),arm64-v8a x86_64)

android-lib: florestad-android

# iOS FFI 빌드. 시뮬레이터(Apple Silicon)와 실기기(arm64)를 모두 만든다.
#   사전: rustup target add aarch64-apple-ios-sim aarch64-apple-ios
#   IPHONEOS_DEPLOYMENT_TARGET: Rust 링크 최소버전 기본값(ios10)과 커널 오브젝트(14.0)가
#   어긋나면 ___chkstk_darwin 미해결로 링크 실패하므로 앱 min(15.0)으로 맞춘다.
IPHONEOS_DEPLOYMENT_TARGET ?= 15.0
export IPHONEOS_DEPLOYMENT_TARGET

ios-lib-sim:
	cd $(RUST_DIR) && cargo build --release --target aarch64-apple-ios-sim

ios-lib-device:
	cd $(RUST_DIR) && cargo build --release --target aarch64-apple-ios

ios-lib: ios-lib-sim ios-lib-device

realm-clean:
	rm -f ./*.realm.lock ./*.realm.note
	rm -rf ./*.realm.management
	rm -f ./test_*.realm
	rm -rf ./test_*.realm.management

format:
	fvm dart format . --line-length 120

ready:
	fvm dart run build_runner clean && fvm dart run build_runner build --delete-conflicting-outputs && fvm dart run realm generate && fvm flutter pub run slang

slang:
	fvm dart pub run slang

ios-build-profile:
	fvm flutter build ios --flavor regtest --profile --dart-define=USE_FIREBASE=false

ios-mainnet:
	fvm flutter build ios --flavor mainnet --release --dart-define=USE_FIREBASE=true

ios-mainnet-appstore:
    fvm flutter build ipa --flavor mainnet --release --dart-define=USE_FIREBASE=true --export-method app-store

aos-mainnet:
	fvm flutter build appbundle --flavor mainnet --release --dart-define=USE_FIREBASE=true

run-regtest-debug:
	fvm flutter run --flavor regtest --debug

run-regtest:
	fvm flutter run --flavor regtest --profile

run-regtest-release:
	fvm flutter run --flavor regtest --release

run-regtest-release-debug-signing:
	ANDROID_USE_DEBUG_SIGNING_FOR_RELEASE_RUN=true fvm flutter run --flavor regtest --release

run-mainnet-debug:
	fvm flutter run --flavor mainnet --dart-define=USE_FIREBASE=true --debug

run-mainnet:
	fvm flutter run --flavor mainnet --dart-define=USE_FIREBASE=true --profile

run-mainnet-release:
	fvm flutter run --flavor mainnet --dart-define=USE_FIREBASE=true --release

ios-regtest:
	fvm flutter build ios --flavor regtest --release

aos-release:
	./android/scripts/build_android_release.sh

aos-run-release:
	./android/scripts/run_android_release.sh

# fastlane
pre-deploy: 
	bundle exec fastlane pre_deploy

ifeq ($(SKIP_PREP),true)
PREP_COMMAND := true
else
PREP_COMMAND := $(MAKE) pre-deploy && $(MAKE) realm-clean
endif


# gomobile bind targets
gomobile-android:
	mkdir -p android/app/libs
	cd go && gomobile bind -trimpath -target=android -ldflags="-extldflags=-Wl,-z,max-page-size=16384" -o ../android/app/libs/bitboxbridge.aar -androidapi 23 .

gomobile-ios:
	cd go && gomobile bind -trimpath -target=ios -o ../ios/Runner/bitboxbridge.xcframework .

gomobile-bind: gomobile-android gomobile-ios

# trezor-bridge UniFFI targets
trezor-ios:
	bash rust/trezor-bridge/scripts/build_ios.sh

trezor-android:
	bash rust/trezor-bridge/scripts/build_android.sh

trezor-bind: trezor-android trezor-ios

FASTLANE_USER :=
-include ios/fastlane/.env
export FASTLANE_USER

REQUIRE_APPLE_ID = if [ -z "$${FASTLANE_USER:-}" ]; then echo "FASTLANE_USER must be set in ios/fastlane/.env." >&2; exit 1; fi;

REQUIRE_REGTEST_BRANCH = \
	if [ "$$(git rev-parse --abbrev-ref HEAD)" != "release-regtest" ]; then \
		echo "Error: regtest fastlane targets must be run on the release-regtest branch." >&2; \
		exit 1; \
	fi; \
	if grep -qE '^[[:space:]]*firebase_' pubspec.yaml; then \
		echo "Error: firebase packages must be removed from pubspec.yaml for regtest deployment." >&2; \
		exit 1; \
	fi;

fastlane-mainnet:
	@$(REQUIRE_APPLE_ID) \
	cd android && REQUIRE_GOOGLE_SERVICES=true caffeinate -dimsu bundle exec fastlane release_android_mainnet && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_mainnet skip_prep:true

fastlane-regtest:
	@$(REQUIRE_REGTEST_BRANCH) \
	$(REQUIRE_APPLE_ID) \
	cd android && caffeinate -dimsu bundle exec fastlane release_android_regtest && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_regtest skip_prep:true

# Production draft/App Store preparation (manual review submission remains required)
fastlane-production-mainnet:
	@$(REQUIRE_APPLE_ID) \
	$(PREP_COMMAND) && \
	(cd android/fastlane_production && REQUIRE_GOOGLE_SERVICES=true caffeinate -dimsu bundle exec fastlane prepare_android_mainnet_production) && \
	(cd ios/fastlane_production && caffeinate -dimsu bundle exec fastlane prepare_ios_mainnet_production skip_prep:true)

fastlane-production-regtest:
	@$(REQUIRE_REGTEST_BRANCH) \
	$(REQUIRE_APPLE_ID) \
	$(PREP_COMMAND) && \
	(cd android/fastlane_production && caffeinate -dimsu bundle exec fastlane prepare_android_regtest_production) && \
	(cd ios/fastlane_production && caffeinate -dimsu bundle exec fastlane prepare_ios_regtest_production skip_prep:true)
	
fastlane-mainnet-skipbridge:
	@$(REQUIRE_APPLE_ID) \
	cd android && REQUIRE_GOOGLE_SERVICES=true caffeinate -dimsu bundle exec fastlane release_android_mainnet skip_bridge:true && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_mainnet skip_bridge:true

fastlane-regtest-skipbridge:
	@$(REQUIRE_REGTEST_BRANCH) \
	$(REQUIRE_APPLE_ID) \
	cd android && caffeinate -dimsu bundle exec fastlane release_android_regtest skip_bridge:true && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_regtest skip_bridge:true
