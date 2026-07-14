format:
	fvm dart format . --line-length 120

ready:
	fvm dart run build_runner clean && fvm dart run build_runner build --delete-conflicting-outputs && fvm dart run realm generate && fvm flutter pub run slang

slang:
	fvm dart pub run slang

ios-mainnet:
	fvm flutter build ios --flavor mainnet --release --dart-define=USE_FIREBASE=true

ios-mainnet-appstore:
    fvm flutter build ipa --flavor mainnet --release --dart-define=USE_FIREBASE=true --export-method app-store

aos-mainnet:
	fvm flutter build appbundle --flavor mainnet --release --dart-define=USE_FIREBASE=true

run-regtest-debug:
	fvm flutter run --flavor regtest --debug

run-regtest:
	fvm flutter run --flavor regtest --profile -d ios

run-regtest-release:
	fvm flutter run --flavor regtest --release -d ios

run-mainnet-debug:
	fvm flutter run --flavor mainnet --dart-define=USE_FIREBASE=true --debug -d ios

run-mainnet:
	fvm flutter run --flavor mainnet --dart-define=USE_FIREBASE=true --profile -d ios

run-mainnet-release:
	fvm flutter run --flavor mainnet --dart-define=USE_FIREBASE=true --release -d ios

ios-regtest:
	fvm flutter build ios --flavor regtest --release

aos-regtest:
	fvm flutter build appbundle --flavor regtest --release

# fastlane
pre-deploy: 
	fastlane pre_deploy

# gomobile bind targets
gomobile-android:
	cd go && gomobile bind -target=android -o ../android/app/libs/bitboxbridge.aar -androidapi 23 .

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
	cd android && caffeinate -dimsu bundle exec fastlane release_android_mainnet && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_mainnet skip_prep:true

fastlane-regtest:
	cd android && caffeinate -dimsu bundle exec fastlane release_android_regtest && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_regtest skip_prep:true
	
