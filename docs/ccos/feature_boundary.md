# CCOS Feature Boundary

이 문서는 CCOS Phase 1에서 외부 개발자가 제안하거나 PR할 수 있는 기능의 경계를 정의한다.

기준 문서:

- [phase1.md](/Users/doey/workspace/coconut_wallet/docs/ccos/phase1.md)
- [architecture.md](/Users/doey/workspace/coconut_wallet/docs/ccos/architecture.md)

## 1. 목적

외부 개발자가 생각한 기능이 CCOS에 들어갈 수 있는지 미리 판단할 수 있어야 한다.

이 문서는 다음 목적을 가진다.

- 허용 가능한 기능과 금지되는 기능을 공개적으로 분류한다.
- maintainer review를 일관되게 만든다.
- wallet trust boundary를 contributor-facing 방식으로 명시한다.

## 2. Boundary Categories

### Green

외부 개발자가 자유롭게 제안하고 PR할 수 있는 범주다.

조건:

- wallet core logic를 수정하지 않는다.
- security-sensitive path를 건드리지 않는다.
- sandboxed extension area 또는 host-approved boundary 안에 머문다.
- 외부 통신 또는 외부 저장소 의존이 없어도 기능 설명이 가능하다.

예시:

- analytics UI
- export UI
- local summary/dashboard
- notification-related UI layer
- widget-like presentation module

### Yellow

사전 검토가 필요한 범주다.

조건:

- 외부 통신, 외부 저장, privacy surface, dependency risk가 있다.
- host trust 또는 long-term maintenance 비용에 영향을 줄 수 있다.

예시:

- network communication
- external API integration
- persistent data storage
- large third-party dependency
- background behavior change

운영 규칙:

- 바로 구현 PR로 시작하지 않는다.
- 먼저 proposal과 architecture/privacy/maintenance review를 거친다.

### Red

CCOS contributor feature로 받지 않는 범주다.

조건:

- wallet trust boundary를 직접 흔든다.
- core integrity 또는 security assumptions를 약화시킨다.

예시:

- wallet database structure 변경
- wallet sync mechanism 변경
- signing / seed / recovery / transaction construction 변경
- broadcasting / fee policy 변경
- wallet data collection을 통한 활용 기능

## 3. Boundary Review Questions

모든 제안은 아래 질문으로 1차 분류한다.

1. wallet core logic를 직접 수정하는가?
2. wallet data를 외부 시스템과 연결하거나 저장하는가?
3. 새로운 trust/privacy/security surface를 여는가?
4. sandboxed extension area 안에서 설명 가능한가?
5. UI-only presentation 또는 host-approved boundary 안에서 끝나는가?

판정 기준:

- 4, 5가 중심이면 Green 가능성이 높다.
- 2, 3이 포함되면 Yellow 또는 Red 검토가 필요하다.
- 1이 포함되면 기본적으로 Red다.

## 4. Host-owned Areas

다음 영역은 외부 contributor 기능 경계 밖이다.

- app bootstrap
- route hosting
- provider graph
- global theme wiring
- wallet core and security-sensitive code

코드 경로 예시:

- `lib/core/**`
- `lib/services/**`
- `lib/repository/realm/**`
- `lib/providers/node_provider/**`

## 5. Contributor-safe Areas

Phase 1에서 contributor-friendly path로 정리해야 하는 영역:

- sandboxed extension area
- official UI primitives consumption path
- approved module patterns
- docs and examples paths

## 6. Review Outcome

모든 제안은 아래 셋 중 하나로 종료한다.

- `Accepted as Green`
- `Hold for Yellow review`
- `Rejected as Red`

## 7. Notes

- Canonical example은 Green category만 다룬다.
- Yellow category는 Phase 1 proof contribution에 포함하지 않는다.
- Red category는 proposal 단계에서 차단한다.
