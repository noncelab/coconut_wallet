# Store locale mapping

Use these five localizations for both `mainnet` and `regtest`.

| Language | Source key | App Store locale | Play Store locale |
|---|---|---|---|
| Korean | `ko` | `ko` | `ko-KR` |
| English (US) | `en` | `en-US` | `en-US` |
| Japanese | `ja` | `ja` | `ja-JP` |
| Spanish (Spain) | `es` | `es-ES` | `es-ES` |
| German | `de` | `de-DE` | `de-DE` |

## Output patterns

For `<flavor>` equal to `mainnet` or `regtest`:

```text
fastlane/store_metadata/generated/ios/<flavor>/<app-store-locale>/release_notes.txt
fastlane/store_metadata/generated/android/<flavor>/<play-store-locale>/changelogs/<next-version-code>.txt
```

The next Android version code is the current `pubspec.yaml` value for `app_versions.aos_<flavor>` plus one, matching the existing Fastlane lane behavior.
