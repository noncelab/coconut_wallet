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

ios-regtest:
	fvm flutter build ios --flavor regtest --release

aos-release:
	./android/scripts/build_android_release.sh

aos-run-release:
	./android/scripts/run_android_release.sh

# fastlane
pre-deploy: 
	fastlane pre_deploy

# gomobile bind targets
gomobile-android:
	cd go && gomobile bind -target=android -o ../android/app/libs/bitboxbridge.aar -androidapi 23 .

gomobile-ios:
	cd go && gomobile bind -target=ios -o ../ios/Runner/bitboxbridge.xcframework .

gomobile-bind: gomobile-android gomobile-ios

fastlane-mainnet:
	cd android && caffeinate -dimsu bundle exec fastlane release_android_mainnet && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_mainnet skip_prep:true

fastlane-regtest:
	cd android && caffeinate -dimsu bundle exec fastlane release_android_regtest && cd .. && cd ios && caffeinate -dimsu bundle exec fastlane release_ios_regtest skip_prep:true
	
