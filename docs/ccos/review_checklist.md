# CCOS Review Checklist

이 문서는 CCOS Phase 1 contribution review 시 사용하는 기본 체크리스트다.

## 1. Boundary

- Feature가 Green / Yellow / Red 중 어디인지 명시되었는가
- Boundary classification 근거가 적혀 있는가
- Red 영역을 건드리지 않는가

## 2. Safety

- wallet core logic를 수정하지 않는가
- security-sensitive path를 건드리지 않는가
- 새로운 privacy/trust surface를 열지 않는가

## 3. Architecture

- host theme/token/primitives 기준을 따르는가
- contributor-safe area 안에서 설명 가능한가
- 공식 경로와 폴더 구조를 따르는가

## 4. Documentation

- 필요한 문서 업데이트가 같이 포함되었는가
- example or quickstart와 충돌하지 않는가

## 5. Scope

- Phase 1 scope를 넘어 real commerce를 요구하지 않는가
- Yellow feature라면 사전 검토 기록이 있는가
