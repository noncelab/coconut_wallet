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
	fvm flutter build ios --flavor regtest --profile

aos-release:
	./android/scripts/build_android_release.sh

aos-run-release:
	./android/scripts/run_android_release.sh

# fastlane
pre-deploy: 
	fastlane pre_deploy

# gomobile bind targets
gomobile-android:
	mkdir -p android/app/libs
	cd go && gomobile bind -target=android -ldflags="-extldflags=-Wl,-z,max-page-size=16384" -o ../android/app/libs/bitboxbridge.aar -androidapi 23 .

gomobile-ios:
	cd go && gomobile bind -target=ios -o ../ios/Runner/bitboxbridge.xcframework .

gomobile-bind: gomobile-android gomobile-ios

# trezor-bridge UniFFI targets
trezor-ios:
	bash rust/trezor-bridge/scripts/build_ios.sh

trezor-android:
	bash rust/trezor-bridge/scripts/build_android.sh

trezor-bind: trezor-android trezor-ios

fastlane-mainnet:
	cd android && REQUIRE_GOOGLE_SERVICES=true caffeinate -dimsu bundle exec fastlane release_android_mainnet && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_mainnet skip_prep:true

fastlane-regtest:
	cd android && caffeinate -dimsu bundle exec fastlane release_android_regtest && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_regtest skip_prep:true

# Production draft/App Store preparation (manual review submission remains required)
ifeq ($(SKIP_PREP),true)
PRODUCTION_PREP_COMMAND := true
else
PRODUCTION_PREP_COMMAND := $(MAKE) pre-deploy && $(MAKE) realm-clean
endif

fastlane-production-mainnet:
	@FASTLANE_USER="$${FASTLANE_USER:-}"; \
	if [ -z "$$FASTLANE_USER" ]; then printf "Apple ID Username: "; IFS= read -r FASTLANE_USER; fi; \
	if [ -z "$$FASTLANE_USER" ]; then echo "Apple ID username cannot be empty." >&2; exit 1; fi; \
	export FASTLANE_USER; \
	$(PRODUCTION_PREP_COMMAND) && \
	(cd android/fastlane_production && REQUIRE_GOOGLE_SERVICES=true caffeinate -dimsu bundle exec fastlane prepare_android_mainnet_production) && \
	(cd ios/fastlane_production && caffeinate -dimsu bundle exec fastlane prepare_ios_mainnet_production skip_prep:true)

fastlane-production-regtest:
	@FASTLANE_USER="$${FASTLANE_USER:-}"; \
	if [ -z "$$FASTLANE_USER" ]; then printf "Apple ID Username: "; IFS= read -r FASTLANE_USER; fi; \
	if [ -z "$$FASTLANE_USER" ]; then echo "Apple ID username cannot be empty." >&2; exit 1; fi; \
	export FASTLANE_USER; \
	$(PRODUCTION_PREP_COMMAND) && \
	(cd android/fastlane_production && caffeinate -dimsu bundle exec fastlane prepare_android_regtest_production) && \
	(cd ios/fastlane_production && caffeinate -dimsu bundle exec fastlane prepare_ios_regtest_production skip_prep:true)
	
fastlane-mainnet-skipbridge:
	cd android && REQUIRE_GOOGLE_SERVICES=true caffeinate -dimsu bundle exec fastlane release_android_mainnet skip_bridge:true && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_mainnet skip_bridge:true

fastlane-regtest-skipbridge:
	cd android && caffeinate -dimsu bundle exec fastlane release_android_regtest skip_bridge:true && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_regtest skip_bridge:true
