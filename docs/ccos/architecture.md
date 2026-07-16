# CCOS Phase 0A Architecture

## 1. Introduction

This document defines the Phase 0A architecture for CCOS in `coconut_wallet`.

Phase 0A is the prerequisite step before any CCOS FeatureRegistry, marketplace listing flow, or external feature contribution model is introduced. Its purpose is to refactor Coconut Wallet into an extension-ready host application at the UI layer without changing Bitcoin wallet behavior.

This document is written for:

- NonceLab maintainers working on host architecture.
- External contributors who need to understand the UI structure and contribution boundaries.
- Future CCOS feature authors who will build on top of the host app after Phase 0A is complete.

## 2. Problem Statement

The current application does not yet have a stable, token-based theme layer that can support future CCOS theming or UI extension work safely and consistently.

At present:

- UI colors, text styles, spacing, and component styling are embedded across screens and widgets.
- The app uses both legacy local styles and `coconut_design_system` primitives directly.
- `main.dart` and `app.dart` concentrate too many responsibilities, including theme setup, provider wiring, and route hosting.
- Common widgets exist, but the repository does not yet expose a clearly documented set of official host UI primitives for future contributors.
Because of this, introducing a Theme feature or a future FeatureRegistry now would be premature. A theme feature would not reliably affect the app, and external contributors would not have a clear or safe UI architecture to follow.

Phase 0A solves this by introducing a host-owned design token layer, stable theme access patterns, and a migration path for key screens.

## 3. Phase 0A Goals

Phase 0A has six goals:

1. Introduce a Coconut design token layer for colors, typography, spacing, and related theme values.
2. Provide context-based accessors so screens and widgets consume host theme values consistently.
3. Establish a set of official Coconut UI primitives for common surfaces.
4. Migrate a limited set of high-impact screens to the new token system.
5. Add lightweight guardrails against new hardcoded colors in migrated or CCOS-related areas.
6. Preserve current wallet behavior and keep the default theme visually equivalent to the current app as closely as possible.

## 4. Non-Goals

Phase 0A does not include:

- CCOS marketplace or store implementation.
- FeatureRegistry or feature listing logic.
- Entitlement, purchase, or IAP implementation.
- Runtime plugin loading.
- Developer PR onboarding flow for external CCOS features.
- Changes to signing, seed handling, transaction construction, broadcasting, UTXO selection, backup/recovery, fee policy, or other wallet-critical flows.

Phase 0A is a UI host refactor only.

## 5. Architectural Principles

Phase 0A should follow these principles:

### Host-owned theming

Global theme behavior must be controlled by the host app, not by ad hoc screen-level styling.

### Explicit tokens over ad hoc values

Screens and widgets should depend on named semantic tokens rather than raw `Color(...)`, one-off `TextStyle(...)`, or arbitrary spacing values.

### Incremental migration

The app should not be rewritten in one pass. Tokenization and migration must happen in safe, reviewable steps.

### Official primitives first

Where a common UI pattern exists, new code should use an official Coconut primitive instead of restyling the pattern locally.

### Visual parity before redesign

The default theme should preserve the current look first. Theme abstraction is the milestone, not a visual rebrand.

### Wallet behavior must remain unchanged

UI architecture changes must not change wallet security assumptions or Bitcoin behavior.

## 6. Current Repository Constraints

The current repository shape is a normal Flutter app layout, but several structural issues must be addressed before external contributors can safely reason about the UI architecture.

### `lib/main.dart`

`main.dart` currently handles:

- app bootstrap
- environment loading
- Firebase setup
- system UI setup
- file logger setup
- app icon behavior
- localization plural rules

This makes the app startup flow harder to explain and harder to evolve.

### `lib/app.dart`

`app.dart` currently combines:

- theme setup
- provider registration
- app shell creation
- route hosting
- entry flow switching

This makes it the central pressure point for future architectural changes.

### Dual style sources

The app currently mixes:

- local legacy styles in `lib/styles.dart`
- direct usage of `coconut_design_system`

This creates ambiguity about which styling layer is authoritative.

### Legacy widget structure

`lib/widgets/**` contains many reusable widgets, but it does not clearly distinguish:

- official host primitives
- screen-specific components
- transitional legacy widgets

That ambiguity makes contribution rules harder to document.

## 7. Target Architecture Overview

Phase 0A introduces a clearer host structure with separated responsibilities.

### 7.1 App Bootstrap Layer

The bootstrap layer initializes the app environment and framework concerns before rendering the app.

Expected responsibilities:

- framework initialization
- environment loading
- Firebase setup
- system UI configuration
- localization bootstrap
- logger initialization

This layer should be host-owned and not used as a general extension surface.

### 7.2 App Shell Layer

The app shell owns:

- provider composition
- root app widget setup
- navigator and route hosting
- top-level app state flow

This layer should remain explicit and host-controlled.

### 7.3 Theme and Token Layer

The theme layer is the Phase 0A core deliverable.

It should provide:

- semantic colors
- typography tokens
- spacing tokens
- radius tokens
- optional motion tokens
- default Coconut theme construction
- `BuildContext` accessors for token lookup

This becomes the single host-facing UI source of truth.

### 7.4 Official UI Primitive Layer

This layer contains approved host primitives such as:

- buttons
- cards
- list tiles
- app bars
- bottom sheets

Its job is to make new UI work consistent and easy to review.

### 7.5 Screen Layer

Screen code should consume:

- theme tokens
- official primitives
- view models and repositories already exposed by the host

Screen code should not define its own competing design system.

### 7.6 Legacy Compatibility Layer

Some legacy widgets and style utilities will remain temporarily during migration.

They should be:

- isolated
- documented as transitional
- gradually reduced over time

## 8. Proposed Directory Structure

Phase 0A should move the repository toward the following structure:

```text
lib/
  app/
    bootstrap/
    providers/
    router/
    shell/
    theme/

  design_system/
    tokens/
    theme/
    context/

  ui/
    coconut/

  screens/
    home/
    settings/
    wallet_detail/
    transaction_draft/
    send/
    onboarding/
    review/
    utility/

  widgets/
    legacy/
```

This structure defines clear responsibilities:

- `app/` is host-owned application wiring.
- `design_system/` defines the theme abstraction layer.
- `ui/coconut/` contains official UI primitives.
- `screens/` contains feature and flow screens.
- `widgets/legacy/` is transitional and should not be the default for new work.

Phase 0A does not require all files to move immediately, but this should be the target direction for refactoring.

## 9. Theme and Token Architecture

Phase 0A should use Flutter `ThemeData` and `ThemeExtension` to express Coconut-specific tokens.

### 9.1 Token Categories

Recommended token groups:

- `CoconutColors`
- `CoconutTypography`
- `CoconutSpacing`
- `CoconutRadius`
- optional `CoconutMotion`

### 9.2 Semantic Tokens

Tokens should be semantic rather than screen-specific wherever possible.

Preferred examples:

- `background`
- `surface`
- `surfaceMuted`
- `primary`
- `primaryText`
- `secondaryText`
- `borderSubtle`
- `danger`
- `success`

Avoid patterns like:

- `walletDetailCardColor`
- `settingsTileGray`
- `screenXTitleColor`

Semantic naming keeps the theme reusable.

### 9.3 Context Access

Screens and widgets should access tokens through `BuildContext` extensions.

Examples:

```dart
context.coconutColors.primary
context.coconutColors.background
context.coconutTypography.body
context.coconutSpacing.md
```

This keeps call sites small and makes theme injection explicit.

### 9.4 Default Theme

The default Coconut theme must match the current app appearance as closely as possible.

The purpose of the new theme layer is abstraction and consistency, not visible redesign.

## 10. Theme Source of Truth

The repository already depends on `coconut_design_system`, but the app also contains legacy local styles in `lib/styles.dart`.

Phase 0A must resolve this ambiguity.

### 10.1 Recommended Direction

The app should expose a local host theme access layer and use that as the source of truth for app code.

That layer may:

- wrap `coconut_design_system`
- map legacy values into host tokens
- bridge old and new implementations during migration

But screens should not need to know which internal source produced the final token value.

### 10.2 Transitional Strategy

During migration:

- `styles.dart` may remain temporarily
- old widgets may continue to use legacy values
- migrated areas should stop introducing new dependencies on legacy styles

New or migrated code should prefer host tokens and official primitives.

## 11. App Bootstrap and Theme Injection

The current startup path should be separated into clearer responsibilities.

### 11.1 Bootstrap Responsibilities

Bootstrap should own:

- environment initialization
- Firebase initialization
- system UI setup
- logging setup
- localization bootstrap

### 11.2 Theme Injection Responsibilities

Theme injection should happen in the app shell layer, not as scattered direct calls across the app.

The current direct call pattern:

```dart
CoconutTheme.setTheme(Brightness.dark);
```

should move behind a host-owned theme builder or adapter.

### 11.3 Why this matters

This separation makes it possible to:

- reason about app startup clearly
- document the host architecture for contributors
- introduce future theme switching in a controlled way

## 12. Official UI Primitives

Phase 0A should define a minimal set of approved primitives for repeated patterns.

Recommended first set:

- `CoconutButton`
- `CoconutCard`
- `CoconutListTile`
- `CoconutBottomSheet`
- `CoconutAppBar`

These primitives should:

- read from host theme tokens
- define consistent default spacing and typography
- reduce repeated local styling logic
- be easy to migrate incrementally

Not every existing widget should become a primitive. Only stable, repeated UI patterns should be promoted.

## 13. Migration Strategy

Migration should happen in four steps.

### Step 1. Introduce tokens with zero behavior change

- add token definitions
- add theme extension support
- add context accessors
- keep output visually equivalent

### Step 2. Migrate common primitives

- create official Coconut primitives
- update shared UI patterns first

### Step 3. Migrate selected screens

Target screens for Phase 0A:

- Home / Wallet list
- Wallet detail
- Settings
- Transaction detail

A placeholder CCOS store screen may be added only if it helps prove the abstraction, but it is not required.

### Step 4. Add guardrails

- add a script or CI check for new raw color usage
- scope checks to modified files or migrated areas

## 14. Migration Scope for Phase 0A

Phase 0A is intentionally limited.

Included:

- token layer introduction
- official primitive introduction
- selected screen migration
- guardrail introduction

Excluded:

- full app migration
- all legacy widget replacement
- deep visual redesign

This keeps the diff reviewable and lowers regression risk.

## 15. Guardrails

After Phase 0A, migrated and CCOS-related areas should not introduce new raw style values casually.

### 15.1 Guarded patterns

The initial guardrail should flag new usages of:

- `Color(0x...)`
- raw button colors
- hardcoded text colors
- ad hoc spacing in migrated areas

### 15.2 Allowed exceptions

Exceptions are acceptable for:

- illustrations
- charts
- brand assets
- debug or test-only code
- package-level limitations outside host control

### 15.3 Enforcement Strategy

Phase 0A should use a lightweight script or CI check.

It should:

- avoid blocking the entire legacy codebase
- focus on new or modified files
- focus especially on migrated areas and future CCOS-related paths

This keeps the guardrail practical.

## 16. Contribution Boundaries

Even before CCOS Phase 0B, the repository needs clearer contribution boundaries.

### Host-owned areas

Host-owned architectural areas include:

- app bootstrap
- route hosting
- provider graph
- global theme wiring
- wallet core and security-sensitive code

### Migration-safe UI areas

Migration work should primarily target:

- design tokens
- official UI primitives
- selected screen styling
- documentation and guardrails

### Protected wallet-critical areas

The following areas remain highly sensitive and are out of scope for UI extension work:

- `lib/core/**`
- `lib/services/**`
- `lib/repository/realm/**`
- `lib/providers/node_provider/**`
- send, backup, receive, signing, broadcasting, and recovery-critical flows

UI refactors must not cross into behavior changes in these areas.

## 17. Backward Compatibility and Visual Parity

Default-theme visual parity is a hard requirement for Phase 0A.

This means:

- no intentional redesign unless documented
- no behavior regressions
- no changed wallet logic
- visual differences should be limited to cases where abstraction requires minor cleanup

If visual changes are intentional, they should be documented explicitly in PR review notes.

## 18. Testing and Verification

Phase 0A should be verified through a combination of build, review, and targeted UI checks.

Recommended checks:

- app builds successfully
- selected migrated screens render correctly
- default theme remains visually close to current app
- a second sample theme can be applied in development to prove the abstraction works
- no wallet behavior changes are introduced
- new raw color guardrail catches new violations in migrated areas

Where practical, widget tests or snapshot-like checks should be added for official primitives and token resolution.

## 19. Risks and Mitigations

### Risk: Migration diff becomes too large

Mitigation:

- keep Phase 0A screen scope limited
- prefer incremental PRs
- separate token introduction from broad screen rewrites

### Risk: Two style systems continue indefinitely

Mitigation:

- define host token access as the target source of truth
- prevent new migrated code from relying on `styles.dart`
- document transition status clearly

### Risk: Visual regression

Mitigation:

- preserve default values first
- review migrated screens carefully
- validate a small number of high-impact screens before broad rollout

### Risk: Architecture docs drift from code

Mitigation:

- land docs alongside refactors
- keep directory boundaries explicit
- update examples when migration conventions change

## 20. Phase 0A Exit Criteria

Phase 0A is complete when:

- the app builds successfully
- wallet behavior remains unchanged
- a host token layer exists
- theme values are available through `BuildContext`
- selected target screens use token-based colors for background, text, surfaces, and primary actions
- official Coconut primitives exist for core repeated UI patterns
- a second sample theme can be applied in development
- a guardrail can detect newly introduced hardcoded colors in migrated or CCOS-related areas
- documentation clearly states that Phase 0A is the prerequisite for Phase 0B CCOS FeatureRegistry work

## 21. Handoff to Phase 0B

Phase 0B will introduce CCOS host architecture such as FeatureRegistry, listing, slots, and contribution boundaries for official feature modules.

Phase 0A is required first because:

- a Theme reference feature is not credible without a host theme abstraction
- future UI-facing features need stable host primitives
- external contributors need a readable, documented structure before UI extension points are exposed

Once Phase 0A is complete, Theme can serve as a valid reference category for CCOS without forcing the architecture to be theme-only.

## 22. Appendix

### Example Usage

```dart
final colors = context.coconutColors;
final spacing = context.coconutSpacing;

return Container(
  color: colors.background,
  padding: EdgeInsets.all(spacing.md),
  child: Text(
    'Wallet',
    style: context.coconutTypography.body,
  ),
);
```

### Do

- use semantic tokens
- use official primitives where they exist
- keep default theme visually stable
- migrate incrementally

### Do Not

- add new raw `Color(0x...)` values in migrated areas
- create one-off local design systems inside screens
- couple theme migration with wallet logic changes
- treat Phase 0A as marketplace implementation
