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
- listing metadata와 activation / entitlement 상태를 분리하는 구조 정의
- 사용자가 "누가 만든 기능인지"와 "어떤 가격 정책 후보인지"를 함께 이해할 수 있는 카드 구조 초안

## 3. Not Allowed in Phase 1

- real payment execution
- entitlement issuing
- subscription lifecycle
- billing integration
- production purchase flow

## 4. Store-side principles

monetization metadata는 billing 구현보다 먼저 다음 기준을 따라야 한다.

- price 정보는 trust metadata를 덮어쓰면 안 된다.
- author / intent / boundary 정보가 price label보다 먼저 읽혀야 한다.
- free / one-time / future paid candidate는 listing metadata일 뿐, activation state와 동일하지 않다.

즉, 미래의 store에서는 최소한 아래 세 가지를 분리해야 한다.

- listing metadata
- activation state
- entitlement state

## 5. Boot-time activation restore

future in-app purchase feature가 앱을 다시 켤 때마다 올바르게 동작하려면, launch 시점에 아래 순서가 안정적으로 성립해야 한다.

1. registry에서 어떤 feature가 존재하는지 먼저 읽는다.
2. entitlement source에서 사용자가 실제로 가진 권한을 복원한다.
3. local activation state에서 사용자가 켜 둔 feature를 복원한다.
4. host는 `listing + entitlement + activation`을 합쳐 최종 availability를 계산한다.

중요:

- UI는 billing SDK를 직접 신뢰하면 안 된다.
- feature 진입 가능 여부는 단일 resolver가 계산해야 한다.
- activation state는 local preference에 저장될 수 있지만, entitlement state와 섞이면 안 된다.
- billing 복원 실패 시 fallback policy도 별도로 정의되어야 한다.

즉, 구조적으로는 최소한 아래 계층이 필요하다.

- `FeatureRegistrySource`
- `FeatureEntitlementStore`
- `FeatureActivationStore`
- `FeatureAvailabilityResolver`

## 6. Review Questions

1. 이 기능은 실제 결제 시스템을 요구하는가?
2. 단지 future monetization을 위한 metadata/policy 수준인가?
3. contributor가 monetization boundary를 오해할 수 있는가?
4. price label이 author / intent / boundary 같은 trust metadata를 가리고 있지는 않은가?
5. 앱 재실행 후 entitlement와 activation을 다시 계산할 수 있는 구조인가?

판정:

- 정책/문서/metadata면 Phase 1 scope 가능
- 실제 결제 흐름이면 Phase 1 out of scope

## 7. Contributor Guidance

- monetization을 구현 대상으로 제안하지 말고, boundary와 policy 대상으로 제안한다.
- paid extension이어도 Phase 1에서는 commerce proof를 요구하지 않는다.
- 유료 후보 기능이라도 listing에는 author, intent, boundary 설명을 함께 넣는다.
