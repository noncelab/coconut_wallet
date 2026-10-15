# CCOS Docs

한국어 버전: [README.ko.md](./README.ko.md)

This guide helps you understand the CCOS documentation structure at a glance.

## Folder Overview

```text
docs/ccos/
  README.md
  getting_started/
    contributor_quickstart.md
    feature_boundary.md
    feature_proposal_template.md
  foundation/
    architecture.md
    monetization_guide.md
  review/
    review_checklist.md
  theme/
    add_theme_variant.md
```

If you are new here, this is usually the easiest way to navigate:

- Start with `getting_started/` if you want to contribute
- Read `foundation/` if you want to understand the structure and principles
- Open `review/` if you want to understand review expectations
- Use `theme/` if you are working on theme-related changes

## Language Rule

- Core contributor documents should always be maintained as `en/ko` pairs.
- `<name>.md` works as a language-entry document.
- The actual content lives in `<name>.ko.md` and `<name>.en.md`.

Example:

- `contributor_quickstart.md`
- `contributor_quickstart.ko.md`
- `contributor_quickstart.en.md`

## Getting Started

- [CCOS Contributor Quickstart](./getting_started/contributor_quickstart.md)
  The fastest guide for contributors to understand where to begin and in what order to prepare.
- [CCOS Feature Boundary](./getting_started/feature_boundary.md)
  Explains which kinds of features are safe to propose and where the Green / Yellow / Red boundaries are.
- [CCOS Feature Proposal Template](./getting_started/feature_proposal_template.md)
  A template that brings together the information every proposal must include and the review points that should be checked alongside it.

## Foundation

- [Coconut Wallet Architecture](./foundation/architecture.md)
  Explains the main folder roles in Coconut Wallet and the structural checks for proposing new features.
- [Feature Proposal Monetization Guide](./foundation/monetization_guide.md)
  Explains how far paid features and purchase flows are currently defined, and which areas remain outside the current scope.

## Contribution / Review

- [Feature Proposal Review Checklist](./review/review_checklist.md)
  A baseline checklist that explains which points should be reviewed together when a feature is proposed or implemented.

## Category-specific Guides

### Theme

- [Add Theme Variant](./theme/add_theme_variant.md)
  Explains which files to look at and what sequence to follow when adding a new theme variant.

## Documents Already Organized as `en/ko` Pairs

- `getting_started/contributor_quickstart`
- `getting_started/feature_boundary`
- `getting_started/feature_proposal_template`
- `foundation/architecture`
- `foundation/monetization_guide`
- `review/review_checklist`
- `theme/add_theme_variant`
