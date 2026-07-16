# CCOS Phase 1

이 문서는 `coconut_wallet`에서 CCOS의 첫 번째 실제 달성 단계를 정의한다.

여기서의 Phase 1은 기존 `Phase 0A` 아키텍처 정리 작업을 버리는 문서가 아니다.
반대로, `docs/ccos/architecture.md`와 `docs/ccos/phase0a_session_handoff.md`에서 정의한 host refactor를 **기술적 기반**으로 유지하면서, 첫 단계의 성공 기준을 "외부 기여자가 실제로 PR까지 완주할 수 있는가"까지 확장한 문서다.

즉, 이 문서는 다음 판단을 반영한다.

- 기존 `Phase 0A`의 token/theme/primitives/guardrail 작업은 계속 유효하다.
- 하지만 CCOS의 첫 단계 성공은 host refactor만으로는 충분하지 않다.
- 첫 단계 안에서 contributor onboarding, example, PR path까지 증명해야 한다.

## 1. 목적

CCOS Phase 1의 목적은 Coconut Wallet을 단순히 "정리된 Flutter 앱"으로 만드는 것이 아니라, **외부 개발자가 안전한 경계 안에서 UI-only 기여를 이해하고, AI와 예제를 활용해 실제 PR을 제출할 수 있는 contributor-safe host repository**로 만드는 것이다.

이 단계는 아직 marketplace commerce를 출시하는 단계가 아니다.
이 단계는 future store/platform을 위해 다음을 한 번에 성립시키는 단계다.

1. host architecture가 extension-safe 하다.
2. contribution boundary가 명확하다.
3. repo/documentation/template/example이 외부 개발자에게 실제로 작동한다.
4. maintainers가 그 기여를 일관되게 리뷰할 수 있다.

## 2. 이 문서가 우선하는 범위

다음 문서를 전제로 한다.

- [architecture.md](/Users/doey/workspace/coconut_wallet/docs/ccos/architecture.md)
- [phase0_seed.md](/Users/doey/workspace/coconut_wallet/docs/ccos/phase0_seed.md)
- [phase0a_session_handoff.md](/Users/doey/workspace/coconut_wallet/docs/ccos/phase0a_session_handoff.md)

우선순위 규칙:

- UI token/theme/primitives/refactor에 대한 세부 기술 원칙은 `architecture.md`를 따른다.
- 실제 세션 인수인계와 남은 host refactor 작업은 `phase0a_session_handoff.md`를 따른다.
- 다만 "첫 단계에서 어디까지 성공으로 볼 것인가"에 대해서는 이 `phase1.md`가 상위 문서다.

즉, 기존 문서에서 `Phase 0A`의 non-goal로 적혀 있던 외부 contributor PR onboarding은 이 문서 기준으로 **Phase 1 범위 안으로 승격**된다.

## 3. Phase 1 한 줄 목표

`coconut_wallet`를 contributor-safe UI extension host로 정리하고, Flutter 전문가는 아니지만 일반 프론트엔드 개발자가 AI와 예제를 활용해 sandboxed UI-only module을 구현하여 reviewable PR까지 완주할 수 있도록 만든다.

## 4. 핵심 성공 기준

Phase 1은 아래 조건이 충족되면 성공이다.

1. repository 구조와 architecture docs가 외부 기여자 관점에서 읽을 수 있게 정리되어 있다.
2. UI-only extension이 들어갈 수 있는 sandboxed boundary가 문서와 코드 양쪽에서 명확하다.
3. contributor-facing 문서, template, example이 준비되어 있다.
4. Phase 1 canonical example을 기준으로 외부 기여자가 실제 PR을 제출할 수 있다.
5. maintainers가 해당 PR을 새로운 boundary와 review rule만으로 검토할 수 있다.

## 5. Phase 1의 대상 contributor

Phase 1은 아래 persona를 기준으로 설계한다.

- Flutter/mobile specialist가 아닌 일반 프론트엔드 개발자
- AI assistance를 적극 활용할 수 있는 사람
- repo template, implementation example, guide 문서를 따라가며 기여할 수 있는 사람

의도적으로 아직 최적화하지 않는 대상:

- Coconut Wallet 내부 구조를 이미 잘 아는 core maintainer
- Flutter 전문가만을 위한 좁은 contributor profile
- 아이디어만 내고 실제 구현은 maintainer/AI가 대행해 주는 non-developer proposer

non-developer proposer 비전은 CCOS의 장기 목표로 유지하되, Phase 1의 acceptance gate로 삼지 않는다.

## 6. Day-one scope

Phase 1에서 공식적으로 허용하는 contribution 범위는 다음과 같다.

### In scope

- UI-only extensions
- host-owned token/theme/primitives 정리
- contribution boundaries 문서화
- contributor onboarding 문서
- PR template / review guide / implementation example
- paid feature를 위한 architecture hooks, policy, docs
- feature boundary taxonomy와 review gate 공개 정의
- 필요 시 free listing 또는 placeholder purchase flow를 위한 설계 수준의 자리 잡기

### Out of scope

- external service integrations
- wallet logic changes
- signing, seed handling, transaction construction, broadcasting, backup/recovery, fee policy 변경
- runtime plugin loading
- real marketplace commerce
- real one-time purchase execution
- subscription/IAP production flow

## 7. Paid feature boundary

Phase 1은 paid feature를 "실제 결제 출시"로 다루지 않는다.

우선순위:

1. architecture hooks
2. policy/docs
3. optional placeholder purchase flows

Phase 1에서 필요한 것은 다음이다.

- 어떤 extension이 free / one-time / in-app purchase 후보인지 구분 가능한 문서 모델
- paid extension이 future phase에서 붙을 수 있도록 boundary를 설계하는 것
- review 시 monetization-related metadata를 어디까지 허용하는지 정의하는 것

Phase 1에서 아직 필요하지 않은 것은 다음이다.

- 실제 결제 수행
- entitlement 발급
- subscription lifecycle
- platform billing integration

## 8. Canonical example

Phase 1의 증명용 example contribution은 아래 형태여야 한다.

- **새로운 sandboxed extension area 안에 들어가는 UI-only module**
- current repository에서는 이 example을 사용자가 실제로 볼 수 있도록 `theme_bottom_sheet.dart` 안에 CCOS entry를 두고, 상세 catalog/activation 데이터는 별도 source로 분리하는 접근을 허용한다.

의도:

- 기존 wallet-critical 화면을 직접 수정하지 않는다.
- regression risk를 낮춘다.
- boundary 설명을 가장 명확하게 만든다.
- maintainer review를 deterministic하게 만든다.

Phase 1에서는 다음보다 이 canonical example이 우선한다.

- 기존 화면을 extension slot으로 수정하는 예시
- behavior-heavy contribution 예시
- external integration이 필요한 demo

중요:

- canonical example이 UI-only sandboxed module이라는 뜻이지, 앞으로 검토 가능한 모든 PR 범위가 UI-only로만 고정된다는 뜻은 아니다.
- 실제 contributor program은 별도의 feature boundary 분류 체계를 먼저 공개적으로 정의한 뒤 운영한다.
- 즉, "예시는 가장 안전한 것부터" 시작하되, "허용 가능한 제안 범위"는 category 기반으로 더 넓게 설명해야 한다.

## 9. Feature boundary

CCOS는 외부 개발자가 "내가 생각한 기능이 이 프로젝트에 제안 가능한가"를 미리 판단할 수 있어야 한다.

이 기준이 필요한 이유:

- wallet software는 보안과 신뢰가 핵심이다.
- 경계가 불명확하면 contributor는 무엇이 허용되는지 모르고, 사용자와 maintainer는 무엇이 들어올 수 있는지 신뢰하기 어렵다.
- 공개적인 sandbox/boundary 정의는 단순한 운영 문서가 아니라, CCOS 자체의 신뢰 장치다.

Phase 1에서는 기능 제안과 PR 가능 범위를 아래처럼 카테고리화한다.

### 🟢 Green — 외부 개발자 자유 제안 가능

특징:

- wallet core logic를 건드리지 않는다.
- security-sensitive path를 건드리지 않는다.
- 기본적으로 sandboxed area 또는 명확히 허용된 host-facing surface 안에서 동작한다.
- 원칙적으로 외부 의존성이나 외부 통신 없이도 설명 가능하다.

예시:

- wallet data를 읽기 전용으로 활용하는 analytics UI
- export UI
- notification-related UI layer
- widget-like presentation modules
- purely local insight / dashboard / summary surfaces
- predefined extension slot 또는 sandboxed module 안의 display-oriented feature

운영 원칙:

- Green은 외부 개발자가 자유롭게 제안하고 PR할 수 있다.
- 다만 일반 PR review, code quality, boundary adherence review는 여전히 필요하다.

### 🟡 Yellow — NonceLab 사전 검토 필요

특징:

- 동작 자체가 즉시 금지되는 것은 아니지만, boundary risk가 있다.
- host trust, data flow, privacy, dependency, long-term maintenance 비용이 커질 수 있다.

예시:

- network communication
- external API integration
- persistent data storage 추가
- 새로운 third-party dependency가 큰 기능
- background behavior 변화 가능성이 있는 기능
- wallet data를 host 외부와 간접적으로라도 연결할 수 있는 기능

운영 원칙:

- Yellow는 바로 PR부터 시작하는 것이 아니라, proposal과 사전 검토가 먼저다.
- 필요하면 별도 architecture review, privacy review, maintenance review를 거친다.
- Phase 1 canonical proof에는 Yellow feature를 포함하지 않는다.

### 🔴 Red — 절대 불가

특징:

- wallet trust boundary를 직접 흔들거나, core integrity를 약화시키는 영역
- 외부 contributor sandbox 모델로 다뤄서는 안 되는 영역

예시:

- 기존 wallet database 구조 직접 변경
- wallet data synchronization mechanism 변경
- wallet data collection을 통한 활용 기능
- signing / seed / recovery / transaction construction / broadcasting / fee policy 변경
- 보안 민감 경로를 우회하거나 내부 상태를 외부로 노출하는 기능

운영 원칙:

- Red는 CCOS contributor feature로 받지 않는다.
- maintainer-only internal work로도 별도 고위험 변경 절차가 필요하다.

### Boundary review rule

모든 제안은 먼저 아래 질문을 통과해야 한다.

1. 이 기능은 wallet core logic를 직접 수정하는가?
2. 이 기능은 wallet data를 외부 시스템과 연결하거나 저장하는가?
3. 이 기능은 새로운 trust/privacy/security surface를 여는가?
4. 이 기능은 sandboxed extension area 안에서 설명 가능한가?
5. 이 기능은 UI-only presentation 또는 host-approved boundary 안에서 끝나는가?

판정 방식:

- 대부분 `Yes`가 4, 5에 몰리면 Green 가능성이 높다.
- 2, 3이 `Yes`면 Yellow 또는 Red 검토가 필요하다.
- 1이 `Yes`면 기본적으로 Red로 본다.

## 10. Deliverables

Phase 1의 산출물은 크게 다섯 묶음이다.

### 10.1 Host architecture deliverables

- host-owned token/theme layer 적용 기반 확보
- `BuildContext` 기반 theme access 도입 완료
- 대표 화면과 공통 위젯의 token migration 기반 확보
- preview theme를 통한 token coverage 검증 경로 확보
- 남은 migrated area에 대한 visual parity 유지와 hardcoded color guardrail 보강

이 묶음의 세부 기준은 `architecture.md`와 `phase0a_session_handoff.md`를 따른다.

중요:

- theme 적용을 위한 핵심 refactor는 이미 repository에 반영되어 있다.
- 따라서 Phase 1에서의 host architecture 과제는 token/theme 시스템을 새로 설계하는 것이 아니라, 이미 도입된 기반을 contributor-safe host 관점에서 안정화하고 문서화하는 것이다.
- 특히 남은 일은 foundation 자체보다, 일부 잔여 migrated area 정리, parity 확인, guardrail 보강, boundary-friendly structure 정리에 가깝다.

### 10.2 Contributor architecture deliverables

- extension-safe area 정의
- host-owned area / protected area / allowed area 정의
- Green / Yellow / Red feature boundary 정의
- allowed dependency direction 문서화
- example module이 따라야 할 folder convention 정의
- host UI surface와 contributor catalog source를 분리하는 구조 정의
- free / one-time purchase 같은 monetization metadata를 결제 로직 없이도 표현할 수 있는 구조 정의

### 10.3 Contributor docs deliverables

- CCOS overview
- contribution boundary guide
- feature boundary guide
- feature proposal guide
- implementation guide
- monetization guide
- PR template
- maintainer review checklist
- canonical example walkthrough

### 10.4 Repo structure deliverables

- 외부 contributor가 읽기 쉬운 상위 레벨 문서 구조
- example path를 쉽게 찾을 수 있는 directory layout
- legacy area와 official extension path의 구분

### 10.5 Proof deliverables

- sandboxed UI-only example module 하나
- example module을 실제 사용자 경로에서 소개하는 host entry 하나
- 해당 example을 만드는 step-by-step 문서
- example PR template 또는 example PR checklist
- maintainer가 사용할 review checklist

## 11. Required documentation set

Phase 1 종료 전 최소한 아래 문서군이 있어야 한다.

1. Phase 1 overview 문서
2. architecture boundary 문서
3. feature boundary guide
4. contributor quickstart
5. feature proposal template
6. monetization policy draft
7. PR template
8. review checklist
9. canonical example guide
10. milestone / execution tracking 문서

권장 추가 문서:

- FAQ for external contributors
- "what is not allowed" 문서
- AI-assisted contribution workflow example

## 12. Repository rules for Phase 1

Phase 1에서는 아래 규칙을 분명히 해야 한다.

### Documentation placement rule

문서도 contributor experience의 일부이므로, 위치 규칙이 명확해야 한다.

기본 원칙:

- product, architecture, contribution boundary, onboarding, milestone, monetization 같은 CCOS 문서는 `docs/ccos/` 아래에 둔다.
- repository entry 문서인 `README.md`, `CONTRIBUTING.md`, `CHANGELOG.md`는 루트에 둔다.
- 특정 subsystem, package, tool만 설명하는 문서는 해당 디렉토리 옆에 둔다.

의도:

- 외부 기여자가 CCOS 관련 문서를 한 곳에서 찾을 수 있게 한다.
- repo entry 문서는 저장소 진입점에서 바로 보이게 유지한다.
- 로컬한 사용법 문서는 코드와 함께 두어 맥락을 잃지 않게 한다.

### Host-owned areas

- app bootstrap
- route hosting
- provider graph
- global theme wiring
- wallet core and security-sensitive code

### Contributor-safe areas

- sandboxed extension area
- official UI primitives consumption path
- approved screen/module patterns
- docs/example/template paths

### Protected areas

- `lib/core/**`
- `lib/services/**`
- `lib/repository/realm/**`
- `lib/providers/node_provider/**`
- send, backup, receive, signing, broadcasting, and recovery-critical flows

기여 문서에는 "allowed area"만 쓰는 것이 아니라, "왜 protected area를 건드리면 안 되는가"도 같이 설명해야 한다.

## 13. Milestones

Phase 1은 아래 작업축으로 나눈다.

### Milestone A — Host foundation completion

목표:

- `architecture.md`의 host refactor 방향을 실코드에 더 일치시킨다.
- token/theme/primitives/guardrail 기반을 충분히 안정화한다.

대표 작업:

- preview theme로 남은 hardcoded UI surface 정리
- `styles.dart` 의존 축소
- overlay / bottom sheet / common widgets token 정리
- lightweight hardcoded color guardrail 추가

### Milestone B — Contributor boundary definition

목표:

- 외부 기여자가 들어갈 수 있는 구조와 금지 영역을 코드/문서 기준으로 고정한다.

대표 작업:

- extension-safe area 설계
- naming / folder / dependency rules 정리
- host-owned vs contributor-owned 경계 문서화
- Green / Yellow / Red feature boundary 정리
- boundary 판정 질문과 review path 문서화
- contributor-offered theme metadata source와 host picker entry의 책임 분리

### Milestone C — Contributor docs and templates

목표:

- 일반 프론트엔드 개발자가 AI와 예제로 따라갈 수 있는 문서 체계를 준비한다.

대표 작업:

- quickstart 작성
- feature boundary guide 작성
- feature proposal template 작성
- monetization draft 작성
- PR template / review checklist 작성

### Milestone D — Canonical example proof

목표:

- sandboxed UI-only module example 하나를 end-to-end로 증명한다.

대표 작업:

- example module 구현
- example guide 작성
- example contributor path 검증
- maintainer review path 검증

## 14. Acceptance criteria

Phase 1은 아래를 모두 만족해야 seed-complete로 본다.

1. app builds successfully.
2. wallet behavior remains unchanged.
3. default theme visual parity가 유지된다.
4. migrated area와 CCOS-related path에서 신규 hardcoded color guardrail이 동작한다.
5. contribution boundary 문서가 명확히 존재한다.
6. Green / Yellow / Red feature boundary가 명확히 문서화되어 있다.
7. monetization은 architecture/policy/docs 수준으로 정리되어 있다.
8. external integrations과 wallet logic changes가 명시적으로 phase scope 밖 또는 Yellow/Red review path로 관리된다.
9. canonical example이 sandboxed UI-only module 기준으로 존재한다.
10. 일반 프론트엔드 개발자가 AI/example/template를 활용해 해당 example PR을 제출할 수 있다.
11. maintainer가 새 review rule로 그 PR을 검토할 수 있다.

## 15. Verification

검증은 세 층으로 본다.

### Build and regression verification

- app build 성공
- 주요 화면 렌더 이상 없음
- wallet-critical behavior regression 없음

### Architecture verification

- token/theme/primitives path가 single source of truth로 작동
- contributor-safe area와 protected area가 문서/코드 모두에서 일치
- preview/debug theme로 남은 token 미적용 지점을 찾을 수 있음

### Contributor proof verification

- contributor quickstart만으로 example path를 따라갈 수 있음
- feature idea를 Green / Yellow / Red로 스스로 1차 분류할 수 있음
- 필요한 template와 example이 누락되지 않음
- example PR이 review checklist로 검토 가능함

## 16. Risks

### Risk: host refactor와 contributor onboarding이 한 phase에서 충돌

대응:

- architecture foundation을 먼저 안정화하고 example scope를 좁게 유지한다.
- canonical example을 sandboxed new module로 제한한다.

### Risk: 문서만 많고 실제 기여 경험이 성립하지 않음

대응:

- 반드시 example PR proof를 acceptance에 넣는다.
- docs만으로 성공 처리하지 않는다.

### Risk: contributor-friendly를 핑계로 wallet boundary가 느슨해짐

대응:

- protected area를 명시적으로 유지한다.
- UI-only rule을 phase gate로 관리한다.
- Green / Yellow / Red taxonomy를 공개적으로 고정한다.

### Risk: paid feature 문서가 실제 commerce 요구사항으로 오해됨

대응:

- architecture hooks / policy/docs only를 반복 명시한다.
- entitlement, billing, IAP implementation은 out of scope로 고정한다.

### Risk: feature boundary가 추상적이어서 실제 판정에 도움이 안 됨

대응:

- category 설명뿐 아니라 concrete example을 같이 적는다.
- proposal template에 boundary self-classification 항목을 넣는다.
- maintainer review checklist에 boundary decision 항목을 넣는다.

## 17. Next document recommendations

이 문서 다음으로 우선 작성/보강할 문서는 다음이다.

1. `phase1_execution_plan.md`
2. `contribution_boundary.md`
3. `feature_boundary.md`
4. `contributor_quickstart.md`
5. `monetization_guide.md`
6. `canonical_example.md`

## 18. One-sentence restatement

CCOS Phase 1은 `coconut_wallet`를 contributor-safe UI extension host로 정리하고, feature boundary를 Green/Yellow/Red로 공개 정의하며, real commerce 없이 monetization boundary를 문서화하고, 일반 프론트엔드 개발자가 AI와 예제를 활용해 새로운 sandboxed UI-only module PR을 실제로 제출하고 review 받을 수 있음을 증명하는 단계다.
