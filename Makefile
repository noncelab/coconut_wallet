format:
	dart format . --line-length 100

ready:
	dart run build_runner clean && dart run build_runner build --delete-conflicting-outputs && dart run realm generate && flutter pub run slang

slang:
	dart pub run slang

ios-mainnet:
	flutter build ios --flavor mainnet --release --dart-define=USE_FIREBASE=true

aos-mainnet:
	flutter build appbundle --flavor mainnet --release --dart-define=USE_FIREBASE=true

ios-regtest:
	flutter build ios --flavor regtest --release

aos-regtest:
	flutter build appbundle --flavor regtest --release