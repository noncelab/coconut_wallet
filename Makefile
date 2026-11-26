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

-include ios/fastlane/.env
export APP_STORE_CONNECT_API_KEY_KEY_ID APP_STORE_CONNECT_API_KEY_ISSUER_ID APP_STORE_CONNECT_API_KEY_KEY_FILEPATH

REQUIRE_ASC_API_KEY = \
	for var in APP_STORE_CONNECT_API_KEY_KEY_ID APP_STORE_CONNECT_API_KEY_ISSUER_ID APP_STORE_CONNECT_API_KEY_KEY_FILEPATH; do \
		if [ -z "$$(printenv $$var)" ]; then echo "$$var must be set in ios/fastlane/.env." >&2; exit 1; fi; \
	done;

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
	@$(REQUIRE_ASC_API_KEY) \
	cd android && REQUIRE_GOOGLE_SERVICES=true caffeinate -dimsu bundle exec fastlane release_android_mainnet && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_mainnet skip_prep:true

fastlane-regtest:
	@$(REQUIRE_REGTEST_BRANCH) \
	$(REQUIRE_ASC_API_KEY) \
	cd android && caffeinate -dimsu bundle exec fastlane release_android_regtest && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_regtest skip_prep:true

# Single-platform uploads
fastlane-mainnet-android:
	cd android && REQUIRE_GOOGLE_SERVICES=true caffeinate -dimsu bundle exec fastlane release_android_mainnet

fastlane-mainnet-ios:
	@$(REQUIRE_ASC_API_KEY) \
	cd ios && caffeinate -dimsu bundle exec fastlane release_ios_mainnet

fastlane-regtest-android:
	@$(REQUIRE_REGTEST_BRANCH) \
	cd android && caffeinate -dimsu bundle exec fastlane release_android_regtest

fastlane-regtest-ios:
	@$(REQUIRE_REGTEST_BRANCH) \
	$(REQUIRE_ASC_API_KEY) \
	cd ios && caffeinate -dimsu bundle exec fastlane release_ios_regtest

# Production draft/App Store preparation (manual review submission remains required)
fastlane-production-mainnet:
	@$(REQUIRE_ASC_API_KEY) \
	$(PREP_COMMAND) && \
	(cd android/fastlane_production && REQUIRE_GOOGLE_SERVICES=true caffeinate -dimsu bundle exec fastlane prepare_android_mainnet_production) && \
	(cd ios/fastlane_production && caffeinate -dimsu bundle exec fastlane prepare_ios_mainnet_production skip_prep:true)

fastlane-production-regtest:
	@$(REQUIRE_REGTEST_BRANCH) \
	$(REQUIRE_ASC_API_KEY) \
	$(PREP_COMMAND) && \
	(cd android/fastlane_production && caffeinate -dimsu bundle exec fastlane prepare_android_regtest_production) && \
	(cd ios/fastlane_production && caffeinate -dimsu bundle exec fastlane prepare_ios_regtest_production skip_prep:true)
	
fastlane-mainnet-skipbridge:
	@$(REQUIRE_ASC_API_KEY) \
	cd android && REQUIRE_GOOGLE_SERVICES=true caffeinate -dimsu bundle exec fastlane release_android_mainnet skip_bridge:true && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_mainnet skip_bridge:true

fastlane-regtest-skipbridge:
	@$(REQUIRE_REGTEST_BRANCH) \
	$(REQUIRE_ASC_API_KEY) \
	cd android && caffeinate -dimsu bundle exec fastlane release_android_regtest skip_bridge:true && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_regtest skip_bridge:true
