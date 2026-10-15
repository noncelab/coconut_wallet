---
name: generate-store-release-notes
description: Generate localized App Store and Google Play release-note metadata from user-authored Korean source notes in coconut_wallet. Use when the user asks to translate, prepare, create, refresh, or validate mainnet or regtest store release notes. Never upload builds, submit reviews, or edit Fastfile or Makefile as part of this skill.
---

# Generate store release notes

Generate store-ready release-note files from the Korean source without inferring changes from commits or code.

## Workflow

1. Require exactly one flavor: `mainnet` or `regtest`. Ask only when the request does not identify it.
2. Read `fastlane/store_metadata/source/<flavor>/release_notes.ko.md` relative to the repository root. Treat it as the complete source of truth.
3. Stop and ask the user to write the source when it is missing, empty, or contains only an HTML comment.
4. Ignore every HTML comment (`<!-- ... -->`) in the Korean source. Never translate or include comments in generated metadata.
5. Read [references/locales.md](references/locales.md) for the exact locale and output mapping.
6. Preserve facts, feature scope, bullet structure, product names, and technical terms. Do not add features, benefits, fixes, dates, versions, headings, emoji, or marketing claims that are absent from the Korean source.
7. Lightly polish the Korean text only when needed for natural store copy. Keep the user's meaning and level of certainty.
8. Translate into US English, Japanese, Spain Spanish, and German. Prefer natural app-update language over literal word order. Keep established names such as `Coconut Wallet`, `Bitcoin`, `PSBT`, `Trezor`, `BitBox02`, `Mainnet`, and `Regtest` unchanged unless the source explicitly localizes them.
9. Keep every locale at 500 Unicode characters or fewer so the same content is accepted by Google Play. If faithful content cannot fit, stop and propose a shorter Korean source instead of silently omitting information.
10. Read the next Android version code and expected paths by running:

   ```bash
   python3 .agents/skills/generate-store-release-notes/scripts/validate_release_metadata.py --flavor <flavor> --print-plan
   ```

11. Remove every existing `.txt` file for the selected flavor under both generated platform directories before writing new release notes:

   ```bash
   python3 .agents/skills/generate-store-release-notes/scripts/validate_release_metadata.py --flavor <flavor> --clean
   ```

   This command validates that the Korean source exists and is meaningful before deleting anything. Do not manually broaden the cleanup scope.
12. Write UTF-8 files with one trailing newline to every planned iOS and Android path. Use identical text for the corresponding iOS and Android language; only locale directory names differ.
13. Validate all generated files:

   ```bash
   python3 .agents/skills/generate-store-release-notes/scripts/validate_release_metadata.py --flavor <flavor>
   ```

14. Report the flavor, Android version code, cleanup count, generated paths, and validation result. Remind the user to review translations before deployment.

## Boundaries

- Modify only `fastlane/store_metadata/generated/<platform>/<flavor>/` for generated output.
- Do not modify the Korean source unless the user explicitly asks for editing.
- Cleanup may delete only `.txt` files within `fastlane/store_metadata/generated/<platform>/<flavor>/` for the selected flavor.
- Do not modify `Makefile`, either platform's `Fastfile`, credentials, or review attachments.
- Do not invoke Fastlane, build an app, upload metadata, or request store review.
