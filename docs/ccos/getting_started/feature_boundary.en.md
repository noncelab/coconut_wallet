# CCOS Feature Boundary

한국어 버전: [feature_boundary.ko.md](./feature_boundary.ko.md)

This document defines the boundary of features that contributors may propose or submit as PRs in CCOS.

Recommended reading:

- [architecture.md](../foundation/architecture.md)

## 1. Purpose

Contributors should be able to judge in advance whether their feature idea can fit inside CCOS.

This document exists to:

- classify what is allowed and what is not
- make Coconut team review more consistent
- define the wallet's safety-critical boundary in a way contributors can easily understand

## 2. Boundary Categories

### Green `🟢`

Features in this category may be freely proposed and submitted by contributors.

Conditions:

- they do not modify wallet core logic
- they do not touch security-sensitive paths
- they stay inside a safely isolated extension area and do not go beyond the allowed boundary
- the feature can work without depending on external communication or external storage

Examples:

- analytics UI: a screen that presents existing wallet information clearly without sending data outside the wallet
- export UI: a screen where the user can review information already inside the wallet and share or move it outside the app when needed
- local summary or dashboard: a screen that summarizes state using information already available on the device
- notification-related UI: UI for showing notification settings or notification content
- widget-like presentation modules: screen elements that organize information into fast, glanceable cards or widgets

### Yellow `🟡`

Features in this category require review before implementation.

Conditions:

- they introduce external communication, external storage, privacy surface, or dependency risk
- they may affect Coconut Wallet trust or long-term maintenance cost

Examples:

- network communication: features that send or receive data from servers or services outside Coconut Wallet
- external API integration: screens or features that depend on responses from external services to work
- persistent data storage: features that keep data in external or separate storage over time
- large third-party dependencies: external libraries that can materially affect app behavior or maintenance cost
- background behavior changes: changes that affect how the app behaves when it must refresh or run even while the user is not actively on the screen

Operating rule:

- do not start by opening an implementation PR
- first share the proposal and get review on architecture, privacy, and maintenance

### Red `🔴`

Features in this category are not accepted as CCOS contribution features.

Conditions:

- they directly weaken the wallet's safety-critical boundary
- they weaken core integrity or security assumptions

Examples:

- changing wallet database structure: altering the core structure of data stored inside the wallet
- changing wallet sync mechanisms: altering how the wallet receives and aligns blockchain state
- changing wallet identifiers, address derivation, UTXO interpretation, or transaction construction: altering core actions that determine how the wallet understands and presents asset state
- changing broadcasting / fee policy: altering how transactions are sent or how fee decisions are made
- features that rely on collecting wallet data: features that only work by gathering wallet data as an input or analysis source

## 3. Boundary Review Questions

Every proposal should first be checked with these questions:

1. Does it directly modify wallet core logic?
2. Does it connect wallet data to an external system or store it externally?
3. Does it create a new trust / privacy / security surface?
4. Can it be explained entirely within a safely isolated extension area?
5. Does it remain a UI-facing presentation feature or stay inside an approved boundary?

How to judge:

- if 4 and 5 are central, it is likely Green
- if 2 or 3 applies, Yellow or Red review is needed
- if 1 applies, it is generally Red

## 4. Areas Outside Contributor Scope

The following areas are outside the boundary for contributor features:

- app bootstrap
- routing structure
- provider graph
- global theme wiring
- wallet core and other security-sensitive code

Example code paths:

- `lib/core/**`
- `lib/services/**`
- `lib/repository/realm/**`
- `lib/providers/node_provider/**`

## 5. Review Outcomes

Every proposal should end in one of these outcomes:

- `Accepted as Green`
- `Hold for Yellow review`
- `Rejected as Red`

## 6. Notes

- the recommended example covers Green features only
- Yellow features are not part of the default contribution path
- Red features are likely to be screened out at the proposal stage, but exceptionally high-value ideas may still be considered through separate review
