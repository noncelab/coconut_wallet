# CCOS Monetization Guide

이 문서는 CCOS Phase 1에서 monetization을 어디까지 다루는지 정의한다.

기준 문서:

- [phase1.md](/Users/doey/workspace/coconut_wallet/docs/ccos/phase1.md)

## 1. Phase 1 Position

Phase 1은 monetization을 실제 결제 출시로 다루지 않는다.

우선순위:

1. architecture hooks
2. policy/docs
3. optional placeholder purchase flow

## 2. Allowed in Phase 1

- free / one-time / in-app purchase 후보 분류 문서
- monetization-related metadata 규칙 정의
- paid extension review 기준 정의
- placeholder purchase UX 설계 초안

## 3. Not Allowed in Phase 1

- real payment execution
- entitlement issuing
- subscription lifecycle
- billing integration
- production purchase flow

## 4. Review Questions

1. 이 기능은 실제 결제 시스템을 요구하는가?
2. 단지 future monetization을 위한 metadata/policy 수준인가?
3. contributor가 monetization boundary를 오해할 수 있는가?

판정:

- 정책/문서/metadata면 Phase 1 scope 가능
- 실제 결제 흐름이면 Phase 1 out of scope

## 5. Contributor Guidance

- monetization을 구현 대상으로 제안하지 말고, boundary와 policy 대상으로 제안한다.
- paid extension이어도 Phase 1에서는 commerce proof를 요구하지 않는다.
