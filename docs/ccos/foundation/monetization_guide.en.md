# Feature Proposal Monetization Guide

한국어 버전: [monetization_guide.ko.md](./monetization_guide.ko.md)

This document defines the process a contributor goes through when they want to monetize a feature they're proposing.

Recommended reading:

- [feature_boundary.md](../getting_started/feature_boundary.md)

Contributors can propose a feature for free, or propose monetization designed to make their development activity sustainable. CCOS aims to support both directions.

## 1. Monetization Policy Status

A proposed feature can go through monetization discussion and actually ship as a paid feature. The Coconut dev team reviews it, then connects payment directly at deploy time.

Here's what's decided at this stage, and what isn't yet:

- **Decided**: which monetization model to use (free / one-time purchase / subscription / etc.) is decided together with the Coconut dev team, based on "Currently supported" below.
- **Not yet decided**: the formal process for how the Coconut dev team and a contributor work out a contract isn't documented yet. For now, it's discussed case by case through the "Proposal Process" in Section 2. `[TODO: link a separate document here once the contract process is formalized]`

Once market viability is validated, we plan to automate the contract/settlement process with tools such as a contributor dashboard. (This is on the roadmap, and the plan may change depending on how things go.)

### Currently Supported

- documentation that classifies features as free / one-time purchase / subscription / future paid candidates
- rules for how monetization-related information is displayed
- review criteria for paid feature candidates
- proposing a paid feature and actually connecting payment for it through manual discussion with the Coconut dev team (the dev team connects it directly at deploy time)
- defining a settlement standard for how a contributor gets paid when their feature generates sales
  - the standard itself stays internal and isn't publicly documented in full, but the contributor is briefed individually by the person in charge at proposal time. Contact channel: `[TODO: specify the settlement inquiry channel]`
- draft UX for a placeholder purchase flow
- a structure that separates listing metadata from activation / entitlement state
- card structures that help users understand both who made a feature and what pricing model it may follow

### Not Currently Supported

- contributors integrating a billing system themselves
- automatically wiring a new paid feature into the payment / entitlement pipeline (for now, the Coconut dev team connects each feature by hand; once it's connected, entitlement for individual purchases is granted automatically in the shipped app)
- automated subscription lifecycle management
- publicly documenting the contract process for every contributor
- automated settlement through a contributor dashboard (this is on the roadmap, and the plan may change depending on how things go)

## 2. Proposal Process

If you want to propose a paid feature, follow this process:

1. Submit your monetization proposal at `[TODO: where proposals are submitted — issue template / channel / etc.]`. Answering the review questions in Section 3 yourself first will speed up the review.
2. The Coconut dev team reviews the proposal against Section 3. Review typically takes about `[TODO: rough turnaround time]`.
3. If it's judged to be in scope, the Coconut dev team and the contributor work out the monetization model (free / one-time purchase / subscription) and settlement terms individually.
4. The Coconut dev team connects payment directly at deploy time.

This process is still early-stage, so the `[TODO]` items above will be filled in once finalized. Until then, reach out via `[TODO: temporary contact channel]`.

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
- the detailed principles for how paid features are displayed in the Coconut Open Store are still being designed by the Coconut dev team. This document will be updated once they're finalized.
