# mobile_scanner 7.0.1

Source: https://pub.dev/api/archives/mobile_scanner-7.0.1.tar.gz

Published archive SHA256: `54005bdea7052d792d35b4fef0f84ec5ddc3a844b250ecd48dc192fb9b4ebc95`.

This is the existing 7.0.1 dependency with its Android, iOS, macOS and web runtime retained. `UPSTREAM_MANIFEST.json` records all 85 upstream runtime files and their original and vendored hashes. LICENSE is unchanged. Examples, tests, release/readme documentation and upstream lint configuration are excluded. Web's upstream remote ZXing loading is unchanged. The upstream podspec's internal version 7.0.0 is intentionally preserved.

Local changes:

- `lib/src/mobile_scanner_controller.dart`: cancel input subscriptions on failed start before publishing the stopped error state, and on disposal before closing the public barcode stream. This prevents failed permission attempts from leaving listeners that duplicate barcode callbacks on retry or survive controller disposal.
- Twelve Kotlin files without an upstream final newline receive one final LF through text-file creation. The manifest identifies each `final-lf-only` change; no native logic, APIs or build settings change.
- `pubspec.yaml`: remove publishing-only screenshot metadata pointing to excluded example images, so source validation has no missing path references. Dependencies, plugin platforms and runtime assets are unchanged.

All other selected runtime bytes match the published archive. The root package uses a relative path to these tracked sources. No package version or transitive dependency constraint was upgraded. The regression in `test/widgets/mobile_scanner_permission_retry_test.dart` uses the actual widget/controller with a fake platform stream and does not claim native optical validation.
