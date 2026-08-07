# CCOS Contributor Quickstart

한국어 버전: [contributor_quickstart.ko.md](./contributor_quickstart.ko.md)

This document explains where and how contributors can get started with CCOS.

## 1. Who This Is For

This document is written for contributors who:

- are not Flutter specialists but have general frontend experience
- can use AI assistance effectively
- want to prepare a PR by following examples and templates

## 2. Before You Start

Read these first:

- [feature_boundary.md](./feature_boundary.md)

Checklist:

- Decide whether your feature is [`Green`, `Yellow`, or `Red`](./feature_boundary.md)
- Confirm that you can start with a safe, UI-focused contribution
- Confirm that you are not touching core wallet logic

## 3. Contribution Path

1. Classify the feature idea using the boundary guide.
2. If it is Green, start implementation preparation.
3. If it is Yellow, ask for Coconut team review before implementation.
4. If it looks Red, do not start implementation right away and ask first in a GitHub issue.

Use the following contact points when requesting review.

- If you are still at the proposal stage, open a GitHub issue first.
- If you want to show implementation direction as well, starting with a draft PR is also fine.
- For Yellow features, get review in an issue or draft PR before implementation grows too far.
- If a feature looks Red, open a GitHub issue first and ask whether that classification is correct.

Once your PR is merged, we'll notify you via GitHub by default. If you're proposing a paid feature, we'll also use the email you provided in the [feature proposal template](./feature_proposal_template.md) or the PR template to continue the contract discussion. Keep an eye on GitHub notifications while your review is in progress.

## 4. Branching

Create your branch from `develop`.

Example:

```bash
git checkout develop
git pull origin develop
git checkout -b feat/ccos-my-feature
```

## 5. Canonical Starting Point

The safest starting point is:

- adding a new UI module inside a safely isolated screen area

Areas with restricted changes:

- wallet DB changes
- signing or broadcasting flow changes
- features centered around calls to external services

## 6. Suggested Workflow

1. Read the related documents first and decide which boundary your feature belongs to.
2. Build the feature's screens and widgets using Coconut Wallet's core components and design tokens.
3. Before implementation grows, check once more whether the feature is truly Green or whether it belongs to a category that requires review.
4. Explain why you believe the feature stays within the allowed boundary, and why the change is needed, in a GitHub issue when pre-review is needed, or in the draft PR description when you are ready to share implementation.
5. If the scope feels ambiguous or close to Yellow, ask for Coconut team review first.

## 7. Where To Work

CCOS features separate "feature definition and descriptive metadata" from "the screen where the feature appears."

Principles:

- feature metadata and feature copy live in the feature folder
- If a new feature is reached through entry elements attached to an existing screen, such as buttons, cards, or menus, keep changes to that existing screen minimal.

Current structure example:

```text
lib/ccos/
  ccos_feature_registry.dart

lib/ccos/features/<feature-id>/
  <feature-id>_feature.dart
  <feature-id>_feature_copy.dart

lib/screens/...
lib/widgets/features/...
```

Example:

```text
lib/ccos/features/coconut_pulp/
  coconut_pulp_feature.dart
  coconut_pulp_feature_copy.dart
```

Roles:

- `*_feature.dart`
  - feature id
  - category
  - pricing / purchase or activation information
  - linked variant or runtime linkage
- `*_feature_copy.dart`
  - title: the name of the feature
  - description: short copy that explains what the feature does
  - author: the name of the person or team who made it
  - author bio: short copy that introduces the person or team behind the feature
  - author intent: copy that explains why the feature was added
  - why it belongs in Coconut: copy that explains why the feature should live inside Coconut
  - feature help: copy that helps users revisit the feature's source or intent from the product UI
  - tags: short labels that summarize the feature

## 8. How To Register a Feature

Only real store-listed features should be registered.

Current direction:

- `lib/ccos/ccos_feature_registry.dart` should keep only actual registrable features.
- the registry should reference feature-local definitions instead of owning long-form copy directly

Example:

```dart
class CcosFeatureRegistrySource {
  static CcosFeatureListing get featuredListing => CoconutPulpFeature.listing;
}
```

In practice, a contributor should:

1. create the feature definition under `lib/ccos/features/<feature-id>/`
2. connect that feature from the registry
3. implement the actual entry point and include it in the PR

Step 3 is not optional. The theme feature's entry point in `theme_bottom_sheet.dart` is one reference example, but **it's only natural because it's a theme — it's not a standard pattern you're expected to follow.** What screen a feature should attach to, and how, varies a lot by feature, so design the entry point that fits your own feature. See [architecture.md](../foundation/architecture.md) section 6.1 for the full principle.

On the other hand, **you don't implement entitlement integration (the actual purchase button, payment pipeline, receipt verification code).** If you proposed a paid feature, the Coconut dev team wires that up directly after a contract is signed, at deploy time. See [architecture.md](../foundation/architecture.md) section 6.2 and [monetization_guide.md](../foundation/monetization_guide.md) for details.

## 9. Multilingual Copy Structure

- Shared app copy belongs in the central i18n files at `assets/i18n/*.i18n.yaml`.
  - Example: common buttons, global labels, and strings included in base screens across multiple views
- Add-on feature copy belongs in `lib/ccos/features/<feature-id>/<feature-id>_feature_copy.dart`.
  - This includes feature introduction copy, author information, author intent, why the feature belongs in Coconut, feature help, and tags.
- Do not scatter feature-specific strings into the central i18n files when adding a new feature.
- Keep locale-specific copy in the `*_feature_copy.dart` file under the feature folder.

Example:

```dart
class CoconutPulpFeatureCopySource {
  static CoconutPulpFeatureCopy get current {
    switch (LocaleSettings.currentLocale) {
      case AppLocale.ko:
        return _ko;
      case AppLocale.en:
        return _en;
      ...
    }
  }
}
```

Contributors should provide at least these locales:

- `ko`
- `en`
- `ja`
- `es`
- `de`

Translation quality rules:

- machine translation is acceptable as a starting point, but review it for meaning
- Korean copy should follow Coconut's friendly `~yo` tone rather than a stiff or formal style
- When a term feels too technical, prefer plain language that users can understand right away
- Avoid developer-only phrasing or internal jargon when user-facing copy can be written more simply
- Keep copy length reasonably aligned across locales so one language does not become dramatically longer than the others
- author intent, feature help, and purchase/activation explanations must be especially clear
- avoid copy that depends heavily on manual line breaks because layouts can change

## 10. Pre-PR Checklist

Before opening the PR, confirm:

- the feature id matches the folder name under `lib/ccos/features/<feature-id>/`
- the registry only links actual store-listed entries
- you checked whether the change affects existing behavior, and explained the impact if it does
- you checked again that the feature does not cross the allowed boundary
- tests were added or updated when appropriate, or the reason for skipping them is explained
- the manual verification flow is written down with the relevant screens and user flows
- required document updates are included
- feature introduction copy is stored in feature-local copy, not dumped into central i18n
- the copy fields are aligned with the actual code structure
- the copy matches Coconut's tone
- copy length is kept reasonably aligned across locales
- `ko / en / ja / es / de` copy is all present
- if you're proposing a paid feature, the proposal or PR template includes a contact email (needed for contract discussion)
