# CCOS Feature Proposal Template

한국어 버전: [feature_proposal_template.ko.md](./feature_proposal_template.ko.md)

Fill out the items below when proposing a new feature.
It does not need to be perfect. What matters most is clearly explaining the problem you want to solve.

## 1. Summary

- Feature name:
- One-line description:
- Short intro line shown to users:

## 2. Author and Intent

- Author / team / studio name:
- Contact email (optional for free/Green proposals; please include it if you're also proposing monetization, since contract discussion needs it):
- Why you want this feature inside Coconut:
- What user problem it is trying to solve:
- What kind of trust signal should users see:

## 3. Boundary Classification

- Proposed boundary: `Green` / `Yellow` / `Red`
- Why:

## 4. User Value

- Who benefits:
- What problem it solves:

## 5. Technical Shape

- Is it mainly a UI-facing feature:
- External API needed:
- Persistent storage needed:
- Wallet core logic touched:

## 6. Coconut Open Store Presentation

- Information shown in Coconut Open Store:
  - Do you want to propose this as free, one-time purchase, subscription, or a future paid candidate:
  - Author name shown to users:
  - One-line intent summary shown to users:
  - Boundary badge shown to users:

Example:

- Information shown in Coconut Open Store
  - Free / one-time purchase / subscription / future paid candidate: Free
  - Author name: Coconut Team
  - One-line intent summary: We want to help users understand asset flow inside the wallet more easily.
  - Boundary badge: Green

## 7. Multilingual Support

- Feature-local copy file path:
  - Example: `lib/ccos/features/<feature-id>/<feature-id>_feature_copy.dart`
- Locales prepared with this proposal:
  - `ko`
  - `en`
  - `ja`
  - `es`
  - `de`
- Copy that requires translation:
  - title
  - description
  - author
  - author intent
  - feature help
- Did you check that copy length stays reasonably aligned across locales:
- Does the Korean copy follow Coconut's friendly tone by default while staying clear and direct when caution is needed:

## 8. Safety Check

- Does it affect wallet identifiers, address derivation, UTXO interpretation, or transaction construction?
- Does it require external servers, external storage, or background behavior?
- Does it create a new privacy or security surface?
- If it could affect existing wallet behavior, what impact do you expect?

## 9. Review Request

- Contact channel:
  - GitHub issue / draft PR
- What kind of review is needed:
- If implementation is included, how can reviewers test it:
- What is explicitly out of scope:
