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

## 4. Testing

- Were appropriate tests added for the feature?
- If tests were not added, is the reason clearly explained?
- Is there a clear record of how the changed feature was verified manually?

## 5. Documentation

- Are the required document updates included?
- Does it stay consistent with the quickstart guide?

## 6. Scope

- If it is a Yellow feature, is there a record of prior review?
