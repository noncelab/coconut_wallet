# CCOS Contributor Quickstart

이 문서는 CCOS Phase 1 기준으로 외부 개발자가 가장 빠르게 기여를 시작하는 경로를 설명한다.

기준 문서:

- [phase1.md](/Users/doey/workspace/coconut_wallet/docs/ccos/phase1.md)
- [feature_boundary.md](/Users/doey/workspace/coconut_wallet/docs/ccos/feature_boundary.md)
- [canonical_example.md](/Users/doey/workspace/coconut_wallet/docs/ccos/canonical_example.md)

## 1. Who This Is For

이 문서는 아래 contributor를 기준으로 한다.

- Flutter specialist는 아니지만 일반 프론트엔드 개발 경험이 있는 사람
- AI assistance를 활용할 수 있는 사람
- example과 template를 따라가며 PR을 만들고 싶은 사람

## 2. Before You Start

먼저 읽을 문서:

1. [phase1.md](/Users/doey/workspace/coconut_wallet/docs/ccos/phase1.md)
2. [feature_boundary.md](/Users/doey/workspace/coconut_wallet/docs/ccos/feature_boundary.md)
3. [canonical_example.md](/Users/doey/workspace/coconut_wallet/docs/ccos/canonical_example.md)

체크할 것:

- 내 기능이 Green / Yellow / Red 중 어디에 속하는지
- canonical example 수준의 sandboxed UI-only 기여로 시작할 수 있는지
- core logic를 건드리지 않는지

## 3. Contribution Path

1. 기능 아이디어를 boundary 기준으로 분류한다.
2. Green이면 구현 준비를 시작한다.
3. Yellow면 구현 전에 maintainer review를 요청한다.
4. Red면 CCOS contributor feature로 진행하지 않는다.

## 4. Branching

브랜치는 `develop` 기준으로 만든다.

예시:

```bash
git checkout develop
git pull origin develop
git checkout -b feat/ccos-my-module
```

## 5. Canonical Starting Point

가장 안전한 시작점은 다음이다.

- sandboxed extension area 안에 새로운 UI-only module 추가

피해야 할 시작점:

- wallet DB 관련 변경
- signing or broadcasting flow 관련 변경
- external API 연동으로 바로 시작하는 기능

## 6. Suggested Workflow

1. example 문서를 보고 구조를 이해한다.
2. 필요한 화면과 위젯을 official primitive와 token 기준으로 구성한다.
3. boundary를 다시 점검한다.
4. PR template에 맞춰 변경 이유와 boundary 판단을 작성한다.
5. maintainer review를 받는다.

## 7. AI-assisted Contribution

AI를 활용해도 된다. 다만 아래는 contributor 책임이다.

- boundary 판단이 맞는지 확인
- generated code가 wallet-critical area를 건드리지 않는지 확인
- 문서와 코드가 실제 repo structure를 따르는지 확인

## 8. Definition of Done

Quickstart 관점에서 contribution 준비가 끝난 상태는 다음과 같다.

- feature가 Green 범주로 정리됨
- 구현 경로가 sandboxed UI-only module 기준으로 설명 가능함
- PR template 작성이 가능함
