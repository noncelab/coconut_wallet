# Feature Proposal Monetization Guide

한국어 버전: [monetization_guide.ko.md](./monetization_guide.ko.md)

This document defines the process a contributor goes through when they want to monetize a feature they're proposing.

Recommended reading:

- [feature_boundary.md](../getting_started/feature_boundary.md)

Contributors can propose a feature for free, or propose monetization designed to make their development activity sustainable. CCOS aims to support both directions.

## 1. Monetization Policy Status

A proposed feature can go through monetization discussion and actually ship as a paid feature. The Coconut dev team reviews it, then connects payment directly at deploy time.

- Which monetization model to use (free / one-time purchase / subscription / etc.) is decided together with the Coconut dev team, based on "Currently supported" below.
- The actual contract terms (settlement rate, payout cadence, scope of rights and responsibilities, etc.) are **worked out individually between the Coconut dev team and the contributor once the proposal is approved.** Terms vary by feature and contribution scale, so rather than publishing one standard contract here, we discuss each case on its own merits.

Once market viability is validated, we plan to automate the contract/settlement process with tools such as a contributor dashboard. (This is on the roadmap, and the plan may change depending on how things go.)

### Currently Supported

- documentation that classifies features as free / one-time purchase / subscription / future paid candidates
- rules for how monetization-related information is displayed
- review criteria for paid feature candidates
- proposing a paid feature and actually connecting payment for it through an individual contract with the Coconut dev team (the dev team connects it directly at deploy time)
- defining a settlement standard for how a contributor gets paid when their feature generates sales
  - the settlement standard is worked out individually as part of the contract discussion
- draft UX for a placeholder purchase flow
- a structure that separates listing metadata from activation / entitlement state
- card structures that help users understand both who made a feature and what pricing model it may follow

### Not Currently Supported

- contributors integrating a billing system themselves
- automatically wiring a new paid feature into the payment / entitlement pipeline (for now, the Coconut dev team connects each feature by hand; once it's connected, entitlement for individual purchases is granted automatically in the shipped app)
- automated subscription lifecycle management
- publishing contract terms as a standard template (terms vary by feature and contributor, so we run them as individual contracts)
- automated settlement through a contributor dashboard (this is on the roadmap, and the plan may change depending on how things go)

## 2. Proposal Process

If you want to propose a paid feature, follow this process:

1. Submit your monetization proposal as a GitHub issue. Answering the review questions in Section 3 yourself first will speed up the review.
2. The Coconut dev team reviews the proposal against Section 3.
3. If it's judged to be in scope, the Coconut dev team and the contributor work out the monetization model (free / one-time purchase / subscription) and settlement terms through an individual contract.
4. The Coconut dev team connects payment directly at deploy time.

Contract terms vary by feature and contribution scale, so this document does not lay out one standard contract in advance. If you have questions, ask directly on your proposal issue.

## 3. Review Questions and Judgment

These questions are the criteria the Coconut dev team uses when reviewing a paid feature proposal. Contributors are encouraged to check them themselves before proposing.

1. Does this feature require an automated billing integration that the contributor builds themselves, or can it be connected through manual discussion with the Coconut dev team?
2. Or is it only proposing metadata / policy for future monetization?
3. Could contributors misunderstand the monetization boundary?
4. Does the price label hide trust metadata such as author / intent / boundary?
5. Can entitlement and activation be recalculated when the app restarts?

Judgment (Coconut dev team's criteria):

- if it stays at policy / docs / metadata level, or is a payment connection the Coconut dev team handles manually, it is allowed in the current scope
- if it requires an automated billing integration built by the contributor, it is outside the current scope

## 4. Contributor Guidance

- propose monetization as a boundary and policy topic first, not as an implementation target — see Section 2 for how to propose
- you don't need to have a payment method or business registration ready at proposal time. The monetization model and settlement terms are worked out individually with the Coconut dev team after the proposal is approved.
- **you don't implement entitlement integration (the purchase button, payment pipeline, receipt verification code).** You only need to propose a `priceType` candidate (free / one-time / subscription) — the actual integration is done directly by the Coconut dev team at deploy time, after a contract is signed. See [architecture.md](./architecture.md) section 6.2 for the full principle.
- the detailed principles for how paid features are displayed in the Coconut Open Store are still being designed by the Coconut dev team. This document will be updated once they're finalized.
