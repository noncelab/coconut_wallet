# Coconut Wallet Architecture

한국어 버전: [architecture.ko.md](./architecture.ko.md)

This document helps contributors understand the Coconut Wallet structure and decide where and how to propose new features.

Recommended reading:

- [feature_boundary.md](../getting_started/feature_boundary.md)
- [contributor_quickstart.md](../getting_started/contributor_quickstart.md)

This document has two parts:

- **Part A. Architecture description**: how Coconut Wallet is actually organized.
- **Part B. Guidelines for proposing features**: what to do and what to avoid when proposing or implementing a feature.

## 1. Purpose

Coconut Wallet is a watch-only Bitcoin wallet. New features should improve the user experience, but they must not weaken core wallet behavior or safety.

This document answers:

- What are the main folders in Coconut Wallet responsible for?
- Where should contributors look first when proposing a new feature?
- Where are Coconut Open Store features defined?
- Which areas require extra care?
- What should be explained in a PR?

## Part A. Architecture Description

## 2. High-Level Structure

The current repository is organized around these roles:

The list below highlights the main folders worth understanding first when proposing a feature — it is not the full `lib/` folder listing.

```text
lib/
  app/
  ccos/
  core/
  design_system/
  model/
  providers/
  repository/
  screens/
  services/
  ui/
  utils/
  widgets/
```

| Folder | Role |
|--------|------|
| `lib/app/` | App startup, routing, global providers, app theme wiring |
| `lib/ccos/` | Coconut Open Store and registered feature definitions |
| `lib/core/` | Bitcoin, transaction, and wallet-critical logic |
| `lib/design_system/` | Coconut Wallet colors, themes, and tokens |
| `lib/model/` | Data models used by screens and features |
| `lib/providers/` | State management, preferences, screen-level view models |
| `lib/repository/` | Local database, secure storage, shared preferences |
| `lib/screens/` | User-facing screens |
| `lib/services/` | Network, hardware wallet, and service logic |
| `lib/ui/coconut/` | Shared Coconut Wallet UI components |
| `lib/utils/` | Bitcoin helpers, QR helpers, system utilities |
| `lib/widgets/` | Reusable composed widgets |

## 3. App Startup and Global Structure

App startup and global wiring mostly live under `lib/app/`.

Representative areas:

- `lib/app/bootstrap/`
- `lib/app/providers/`
- `lib/app/router/`
- `lib/app/theme/`
- `lib/app/deep_link/`

These areas affect the whole app.

## 4. Screens and Widgets

User-facing screens live under `lib/screens/`.

Examples:

- `lib/screens/home/`
- `lib/screens/send/`
- `lib/screens/settings/`
- `lib/screens/wallet_detail/`
- `lib/screens/ccos/`

Screens are usually paired with a view model under `lib/providers/view_model/<domain>/`. For example, `lib/screens/home/wallet_home_screen.dart` pairs with `lib/providers/view_model/home/wallet_home_view_model.dart`.

Reusable UI is split between:

- `lib/ui/coconut/`
  - wrapper components around the coconut-design-system package
- `lib/widgets/common/`
  - composed widgets shared across screens
- `lib/widgets/features/`
  - composed widgets tied to a specific feature or domain

## 5. Design System and Shared UI

Coconut Wallet theme and color rules are defined by `lib/design_system/` and `lib/ui/coconut/`.

Representative areas:

- `lib/design_system/tokens/`
- `lib/design_system/theme/`
- `lib/design_system/context/`
- `lib/ui/coconut/`

Adding a new theme variant is covered in the [Guide: Adding a New Theme Variant](../theme/add_theme_variant.md).

## 6. CCOS and Coconut Open Store

CCOS-related code is split into a few areas:

| Location | Role |
|----------|------|
| `lib/ccos/features/<feature-id>/` | Registered feature definition and feature-local copy |
| `lib/ccos/ccos_feature_registry.dart` | List of features registered in Coconut Open Store |
| `lib/screens/ccos/` | UI screens for registered features (a file is added here only when a feature needs a new screen) |

Features registered in Coconut Open Store are grouped under `lib/ccos/features/<feature-id>/`.

Example:

```text
lib/ccos/features/coconut_pulp/
  coconut_pulp_feature.dart
  coconut_pulp_feature_copy.dart
```

Roles:

- `*_feature.dart`
  - feature ID
  - category
  - price, purchase, or activation information
  - connected theme variant or runtime connection
- `*_feature_copy.dart`
  - title
  - description
  - author
  - author bio
  - author intent
  - why it belongs in Coconut
  - feature help
  - tags

The registry (`lib/ccos/ccos_feature_registry.dart`) doesn't hold copy such as title or description directly. Instead, it pulls the value defined in the feature's own folder, like this:

```dart
class CcosFeatureRegistrySource {
  static CcosFeatureListing get featuredListing => CoconutPulpFeature.listing;
}
```

### 6.1 Categories and entry points (host surfaces)

`CcosFeatureCategory` already defines `analysis` / `tool` / `widget` alongside `theme`. But a category existing doesn't mean a feature in that category automatically shows up anywhere in the app.

- Right now, only the `theme` category has a working entry point (host surface): `lib/screens/settings/theme_bottom_sheet.dart`.
- **Building the entry point is part of the feature's deliverable, not optional.** A PR that only registers a listing without a working entry point isn't considered a complete contribution. "Choosing a category" and "wiring that category into an actual screen" happen in the same PR.
- `theme_bottom_sheet.dart` is just **one existing example, not a standard pattern you're expected to follow.** Which screen a feature should attach to, and how (a button, a card, a standalone screen, etc.), depends heavily on what the feature actually is — we deliberately haven't forced this into one common structure. Design the entry point that fits your own feature, and propose it as part of your contribution.

This is because CCOS doesn't support runtime plugin loading yet — whatever category a feature falls into, it's compiled statically into the app, and its entry point has to be wired directly in code. (This isn't the same as saying CCOS only accepts UI features. A Yellow proposal that needs network communication or storage can still be reviewed through the boundary guide — it just also needs a directly-wired entry point, same as everything else.) If you're the first to open up a new category, please propose the entry point design along with it.

### 6.2 Who owns entitlement integration

Registering a feature and making it actually sellable as a paid feature are different jobs.

- **Registry connection** (wiring the listing in `lib/ccos/ccos_feature_registry.dart`, marking a `priceType` candidate as free / one-time / subscription) **and building the entry point are the contributor's job** — see 6.1.
- **Actually wiring entitlement (the purchase button, the payment pipeline, receipt verification, the code that calls `markCcosFeaturePurchased` / `purchaseAndActivateCcosFeature`) is not the contributor's job.** The Coconut dev team (the reviewer or whoever handles deployment) implements this directly, after a contract is signed, at deploy time.
- Contributors can *propose* their feature as free / one-time purchase / subscription, but they don't need to implement the actual purchase logic themselves. Follow [monetization_guide.md](./monetization_guide.md) for the monetization process.

The reason for this split: the actual payment integration depends on contract terms (settlement rate, App Store/Play Store product registration, receipt verification) that can't be hard-coded before the contract is finalized.

## Part B. Guidelines for Proposing Features

Follow the [PR template](../../../.github/PULL_REQUEST_TEMPLATE/ccos_contribution.md) for what to explain in a PR.

## 7. What to Clarify Before Proposing a Feature

Before implementation, clarify:

- What user problem does this feature solve?
- Is it closer to Green, Yellow, or Red?
- Where will users encounter this feature?
- Does it require modifying an existing screen, or can it live in a new screen?
- Does it require external servers, external storage, or background behavior?
- Does it affect wallet identifiers, address derivation, UTXO interpretation, or transaction construction?
- Is it proposed as free, one-time purchase, subscription, or a future paid candidate?

Use the [feature proposal template](../getting_started/feature_proposal_template.md) when preparing a proposal.

## 8. What to Do

- Keep the [screen / view model pairing](#4-screens-and-widgets) when adding new screens.
- When building new UI, prefer this order:
  1. Use semantic tokens such as `context.coconutColors`.
  2. Check shared UI components in `lib/ui/coconut/` first.
  3. If a UI composition repeats, place it under `lib/widgets/common/` or `lib/widgets/features/`.
- If a new feature needs an entry button, card, or menu item in an existing screen, keep the existing screen change minimal. Put the main feature screen or detail logic in a separate screen, widget, or feature folder where possible.
- Don't embed screen copy directly in code. Follow the multilingual copy management approach described in [contributor_quickstart.md](../getting_started/contributor_quickstart.md).
- Group features registered in Coconut Open Store under `lib/ccos/features/<feature-id>/`.
- Keep the registry (`ccos_feature_registry.dart`) referencing feature definitions instead of carrying long copy directly.
- If a feature requires changes under `lib/app/`, explain the reason clearly before implementation. Adding a new screen can be reasonable; changing startup flow or global provider wiring requires separate review.

## 9. What to Avoid

- Avoid hardcoded colors such as `Color(0x...)` where possible.
- Don't modify app startup flow, routing structure, global provider wiring, or global theme wiring directly for a general feature proposal.
- The following areas are tied to core Coconut Wallet behavior. If a feature appears to require these areas, ask the Coconut team for review before implementing it.
  - wallet database
  - wallet sync
  - address derivation
  - UTXO interpretation
  - transaction construction
  - broadcasting
  - fee policy
  - backup / recovery flows

  Example code paths:

  - `lib/core/**`
  - `lib/services/**`
  - `lib/repository/realm/**`
  - `lib/providers/node_provider/**`

## 10. Core Principle

Coconut Wallet should grow by adding useful features while protecting core wallet behavior and user trust first.

CCOS and Coconut Open Store are not just about adding more features. They are a structure for helping useful features be discovered, reviewed safely, and presented to users in a way they can understand.
