---
name: CCOS Feature Proposal
about: Propose a new feature or extension for the Coconut Open Store (CCOS) — not a fix or improvement to something that already exists
title: '[CCOS] '
labels: "🥥 ccos"
assignees: ''
---

<!--
Thank you for proposing a CCOS feature.
You may write this issue in English or Korean — 한국어로 작성하셔도 괜찮습니다.

Before filling this out, please read:
- CCOS docs: https://github.com/noncelab/coconut_wallet/blob/main/docs/ccos/README.md
- Feature boundary (Green/Yellow/Red): https://github.com/noncelab/coconut_wallet/blob/main/docs/ccos/getting_started/feature_boundary.md
- Contributor quickstart: https://github.com/noncelab/coconut_wallet/blob/main/docs/ccos/getting_started/contributor_quickstart.md

It doesn't need to be perfect — the most important part is explaining clearly
what problem you want to solve. If a section doesn't apply, write "N/A".
-->

# 🥥 CCOS Proposal - <!--( feature name )-->

### 1. Summary

- Feature name:
- One-line description:
- Short intro line to show users:

### 2. Author and Intent

- Author / team / studio name:
- Contact email (optional for free/Green proposals; required if you're also proposing monetization):
- Why you want this feature inside Coconut:
- What user problem it solves:

### 3. Boundary Classification

- Proposed boundary: `Green` / `Yellow` / `Red`
- Why:

### 4. Technical Shape

- Is it mainly a UI-facing feature: `Yes / No`
- External API needed: `Yes / No`
- Persistent storage needed: `Yes / No`
- Wallet core logic touched (address derivation, UTXO interpretation, transaction construction, broadcast, fee policy, backup/recovery): `Yes / No`

### 5. Coconut Open Store Presentation

- Category: `theme` / `analysis` / `tool` / `widget` / other (describe)
- Free / one-time purchase / subscription / future paid candidate:
- If this opens a category that has no existing host surface yet (only `theme` has one today), how do you propose surfacing it in the app?

### 6. Safety Check

- Does it require external servers, external storage, or background behavior?
- Does it create a new privacy or security surface?

### 7. Testing Plan

- Do you plan to add automated tests: `Yes / No`
  - If yes, what will they cover (e.g. availability/activation logic, repository read-write, locale copy completeness, widget rendering)?
  - If no, why not (e.g. this is a purely visual/story screen with no branching logic)?
- How can a reviewer manually verify this feature once implemented (steps, screens, states to check)?

### 8. Review Request

- What kind of review are you looking for at this stage (early feedback vs. ready-to-implement)?
- What is explicitly out of scope for this proposal?

<!--
Once this proposal looks ready, the next step is usually a draft PR using the
CCOS PR template (.github/PULL_REQUEST_TEMPLATE/ccos_contribution.md).
-->
