# CCOS Canonical Example

이 문서는 CCOS Phase 1에서 proof contribution으로 사용하는 canonical example의 기준을 정의한다.

기준 문서:

- [phase1.md](./phase1.md)
- [feature_boundary.md](./feature_boundary.md)

## 1. Canonical Example Definition

Phase 1 canonical example은 다음이어야 한다.

- 새로운 sandboxed extension area 안에 들어가는 UI-only module

## 2. Why This Example

- 기존 wallet-critical 화면을 직접 수정하지 않는다.
- regression risk가 낮다.
- 외부 contributor onboarding proof로 적절하다.
- maintainer review를 deterministic하게 만들 수 있다.

## 3. Example Requirements

- Green category여야 한다.
- wallet core logic를 수정하지 않는다.
- external integration이 없어야 한다.
- official UI primitive와 host theme/token 기준을 따라야 한다.
- 문서만 보고 일반 프론트엔드 개발자가 AI와 함께 따라갈 수 있어야 한다.

## 4. Example Deliverables

- example module code
- folder/path explanation
- implementation walkthrough
- PR template example
- review checklist mapping

## 5. Non-goals

- extension slot modification proof
- Yellow feature proof
- paid commerce proof
- wallet logic behavior proof
