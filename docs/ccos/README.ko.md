# CCOS 문서

영문 버전: [README.en.md](./README.en.md)

CCOS 문서 구조를 한눈에 볼 수 있도록 정리한 안내 문서예요.

## 폴더 구조 한눈에 보기

```text
docs/ccos/
  README.md
  getting_started/
    contributor_quickstart.md
    feature_boundary.md
    feature_proposal_template.md
  foundation/
    architecture.md
    monetization_guide.md
  review/
    review_checklist.md
  theme/
    add_theme_variant.md
```

처음 오셨다면 아래처럼 찾아보시면 편해요.

- 기여를 시작하고 싶다면 `getting_started/`
- 구조와 원칙을 이해하고 싶다면 `foundation/`
- 리뷰 기준을 보고 싶다면 `review/`
- 테마 관련 작업을 하고 싶다면 `theme/`

## 문서 언어 규칙

- 기여자가 확인할 핵심 문서는 반드시 `en/ko` 한 쌍으로 함께 관리해요.
- `<name>.md`는 언어를 고르는 엔트리 문서로 사용해요.
- 실제 본문은 `<name>.ko.md`, `<name>.en.md`에 둬요.

예:

- `contributor_quickstart.md`
- `contributor_quickstart.ko.md`
- `contributor_quickstart.en.md`

## 빠른 시작

- [CCOS 기여 시작하기](./getting_started/contributor_quickstart.md)
  기여자가 어디서부터 읽고, 어떤 순서로 준비하면 되는지 가장 빠르게 안내해요.
- [CCOS 기능 경계](./getting_started/feature_boundary.md)
  어떤 기능이 제안 가능한지, 어디부터는 위험한지 Green / Yellow / Red 기준으로 나눠 보여줘요.
- [CCOS 기능 제안 템플릿](./getting_started/feature_proposal_template.md)
  새 기능을 제안할 때 반드시 작성해야 할 정보와 함께 확인해야 할 검토 포인트를 한 번에 정리해 둔 템플릿이에요.

## 아키텍처 / 기반 문서

- [코코넛 월렛 아키텍처](./foundation/architecture.md)
  코코넛 월렛의 주요 폴더 역할과, 새 기능을 제안할 때 확인해야 할 구조적 기준을 설명해요.
- [제안 기능 유료화 가이드](./foundation/monetization_guide.md)
  유료 기능과 구매 흐름을 현재 어디까지 준비하고 있는지, 아직 다루지 않는 범위는 어디까지인지 정리해요.

## 기여 / 리뷰 문서

- [제안 기능 리뷰 체크리스트](./review/review_checklist.md)
  제안하거나 구현한 기능을 리뷰할 때 어떤 항목을 함께 확인해야 하는지 정리한 기본 체크리스트예요.

## 카테고리별 문서

### 테마

- [새 테마 종류 추가 가이드](./theme/add_theme_variant.md)
  새로운 테마 종류를 추가할 때 어떤 파일을 보고 어떤 순서로 손보면 되는지 안내해요.
