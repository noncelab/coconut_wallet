# Feature Proposal Review Checklist

한국어 버전: [review_checklist.ko.md](./review_checklist.ko.md)

This document is the baseline checklist to check when reviewing a proposed feature.

## 1. Boundary

- Is it clear whether the feature is Green, Yellow, or Red?
- Is the reasoning for the boundary classification written down?
- Does it avoid Red areas?

## 2. Safety

- Does it avoid changing wallet core logic?
- Does it avoid touching security-sensitive paths?
- Does it avoid opening a new privacy or trust surface?

## 3. Architecture

- Does it follow Coconut Wallet theme / token / primitive rules?
- Can it be explained within the allowed contribution area?
- Does it follow the official paths and folder structure?
- If this opens up a category for the first time, does the same PR include a working entry point (host surface), not just a registry entry? (see `foundation/architecture.md` section 6.1). Don't reject it just because the entry point looks structurally different from the theme example (`theme_bottom_sheet.dart`) — different categories are expected to have different entry points.
- Does the PR avoid including actual entitlement integration code (purchase button, payment pipeline, receipt verification, etc.)? If it's there, that's not normal — that's the Coconut dev team's job at deploy time, after a contract is signed, not the contributor's (see `foundation/architecture.md` section 6.2)

## 4. Testing

- Were appropriate tests added for the feature?
- If tests were not added, is the reason clearly explained?
- Is there a clear record of how the changed feature was verified manually?

## 5. Documentation

- Are the required document updates included?
- Does it stay consistent with the quickstart guide?

## 6. Scope

- If it is a Yellow feature, is there a record of prior review?

## 7. After Merge (for reviewers/whoever merges)

- Did you notify the contributor right after merging? (default: a GitHub comment; also email if they proposed a paid feature)
- If it's a paid feature, did you assign someone to start the contract process (`foundation/monetization_guide.md`)?
- Did you tell the contributor this change ships with the next release, not immediately?

Detailed steps follow the Coconut dev team's internal guide.
