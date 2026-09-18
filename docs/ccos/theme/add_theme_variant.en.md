# Guide: Adding a New Theme Variant

한국어 버전: [add_theme_variant.ko.md](./add_theme_variant.ko.md)

This document explains how to add a new theme variant to Coconut Wallet's token/theme structure.

Recommended reading:

- [architecture.md](../foundation/architecture.md)
- [feature_boundary.md](../getting_started/feature_boundary.md)
- [contributor_quickstart.md](../getting_started/contributor_quickstart.md)

This is not just a checklist of file edits. In the CCOS context, it should be treated as a safe extension procedure for Coconut Wallet's theme layer.

## 1. Goal

A new theme variant should:

- live inside Coconut Wallet's token/theme layer
- not change wallet behavior
- avoid unintentionally changing the visual parity of the default themes
- help expose UI paths that still do not respect theme tokens, if used as a diagnostic variant

This is not a design experiment document. The first priority is always consistency of the theme abstraction.

## 2. Further Work

Even after adding a new theme variant, not every path in the app automatically becomes fully themed.

Adding the variant is possible, but the following areas still require separate follow-up work.

### 2.1 Native splash

The native splash shown before the Flutter widget tree is currently not affected by the app theme.

Representative locations:

- `lib/app/bootstrap/splash_theme.dart`
- `android/app/src/main/res/drawable/launch_background.xml`
- `android/app/src/main/res/drawable-v21/launch_background.xml`
- `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- `ios/Runner/Base.lproj/LaunchScreenRegtest.storyboard`

Meaning:

- adding a variant to the enum and theme factory does not automatically change native splash assets or colors
- the current native splash depends on platform resources and separate constants, not only on Flutter `ThemeData`
- in other words, adding a theme variant does not theme the native splash together with the app

### 2.2 Areas Not Updated Automatically When Adding a Theme Variant

Even after adding a new variant, the following areas are not updated automatically:

- remaining UI migration to tokens
- consistency between the theme-independent native splash and the in-app theme
- hardcoded colors

In other words, adding a variant extends the theme system. It does not automatically complete the remaining theme migration work or clean up separately managed areas.

## 3. Change Order

### 3.1 Define the color palette

File:

- `lib/design_system/tokens/coconut_colors.dart`

Use `CoconutColors.light()` or another variant factory as a reference and add a new factory.

Principles:

- do not change only a few arbitrary fields
- define the full semantic token set
- preserving semantic meaning is more important than adding more raw colors

### 3.2 Add a ThemeExtension factory

File:

- `lib/design_system/theme/coconut_theme_extension.dart`

Principles:

- focus on defining a full, consistent semantic color set for the variant
- spacing / radius / typography are not currently variant-owned ThemeExtension fields

### 3.3 Update the variant enum and resolver

File:

- `lib/design_system/theme/coconut_theme_data.dart`

Targets:

1. `enum CoconutThemeVariant`
2. `brightnessOf()`
3. `resolveCoconutThemeExtension()`

### 3.4 Add i18n labels

If the variant is exposed as a built-in theme, add the shared theme label to the main i18n files.

Target files:

- `assets/i18n/ko.i18n.yaml`
- `assets/i18n/en.i18n.yaml`
- `assets/i18n/ja.i18n.yaml`
- `assets/i18n/es.i18n.yaml`
- `assets/i18n/de.i18n.yaml`

Important:

- this rule is for shared theme labels managed by Coconut Wallet
- do not keep expanding these files with full feature listing copy for every CCOS feature

For CCOS themes offered by contributors, split the copy like this:

1. shared theme labels
   - `assets/i18n/*.i18n.yaml`
2. feature-specific listing copy
   - `lib/ccos/features/<feature-id>/<feature-id>_feature_copy.dart`

Example:

```text
lib/ccos/features/coconut_theme/
  coconut_theme_feature.dart
  coconut_theme_feature_copy.dart
```

In short:

- app-wide labels such as `theme_sepia` belong in central i18n
- feature introduction copy such as author / description / intent / feature help belongs in feature-local copy

In the current CCOS example, `*_feature_copy.dart` manages these locales together:

- `ko`
- `en`
- `ja`
- `es`
- `de`

After adding shared labels:

```bash
dart run slang
```

### 3.5 Connect theme selection UI

Files:

- `lib/screens/settings/theme_bottom_sheet.dart`
- `lib/screens/settings/app_settings/app_settings_screen.dart`
- if needed, `lib/ccos/ccos_feature_registry.dart`

What to do:

- decide first whether the theme is exposed directly as a built-in theme or through a CCOS catalog entry
- if built-in, add the variant to the selection list in `theme_bottom_sheet.dart`
- add a case for the current label switch
- if it is a CCOS theme offered by a contributor, add the feature definition and copy under `lib/ccos/features/<feature-id>/` and have `ccos_feature_registry.dart` reference it

### 3.6 Paths that usually do not need direct changes

The current repository already uses shared variant resolution for:

- Cupertino theme
- Android system bar color

If the enum, factory, and resolver are updated correctly, these files usually do not need case-by-case changes:

- `lib/app/theme/app_cupertino_theme.dart`
- `lib/utils/system_chrome_util.dart`

## 4. Verification

After adding the variant, check at minimum:

1. the app builds successfully
2. the theme selection UI shows the new entry
3. component-level implementations or platform resources that still require manual verification are checked explicitly
4. default theme parity has not been broken
5. the variant changes only UI-layer behavior, not wallet behavior

## 5. What Not To Do

- do not change existing UX while adding the variant
- do not add raw colors without semantic tokens
- do not mix structural refactoring into the task under the excuse of “design improvement”
- do not confuse preview/debug themes with user-facing themes without documenting the difference

## 6. File Summary

| File | Work |
|------|------|
| `lib/design_system/tokens/coconut_colors.dart` | Add a new palette factory |
| `lib/design_system/theme/coconut_theme_extension.dart` | Add a new ThemeExtension factory |
| `lib/design_system/theme/coconut_theme_data.dart` | Update enum, resolver, and brightness |
| `assets/i18n/*.i18n.yaml` | Add shared translation keys and run `dart run slang` |
| `lib/screens/settings/theme_bottom_sheet.dart` | Reflect built-in theme list or CCOS entry exposure |
| `lib/screens/settings/app_settings/app_settings_screen.dart` | Add a case to the current label switch |
| `lib/ccos/features/<feature-id>/` | Add contributor-provided feature definition and feature-local copy |
| `lib/ccos/ccos_feature_registry.dart` | Wire the registry to real registered features |

Usually no direct change needed:

- `lib/app/theme/app_cupertino_theme.dart`
- `lib/utils/system_chrome_util.dart`

If the new variant needs behavior that differs from the current brightness assumptions, verify it explicitly.

## 7. Document Placement Rule

This document belongs under `docs/ccos/` according to the CCOS documentation placement rule.

Why:

- the theme variant guide is a product / architecture oriented CCOS contribution document
- it is not a tool-specific local note, but an operational guide for Coconut Wallet's theme layer
