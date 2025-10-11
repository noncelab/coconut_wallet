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

ios-regtest:
	fvm flutter build ios --flavor regtest --release

aos-regtest:
	fvm flutter build appbundle --flavor regtest --release

# fastlane
pre-deploy: 
	fastlane pre_deploy

fastlane-mainnet:
	cd android && bundle exec fastlane release_android_mainnet && cd .. && cd ios && bundle exec fastlane release_ios_regtest skip_prep:true
	