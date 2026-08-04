# 코코넛 월렛 아키텍처

영문 버전: [architecture.en.md](./architecture.en.md)

이 문서는 기여자가 코코넛 월렛의 구조를 빠르게 이해하고, 새로운 기능을 어디에 어떻게 제안하면 좋을지 판단할 수 있도록 돕는 안내서예요.

먼저 읽어 보시면 좋은 문서:

- [feature_boundary.md](../getting_started/feature_boundary.md)
- [contributor_quickstart.md](../getting_started/contributor_quickstart.md)

이 문서는 두 부분으로 나뉘어요.

- **파트 A. 아키텍처 설명**: 코코넛 월렛이 실제로 어떻게 구성되어 있는지 설명해요.
- **파트 B. 기능 제안 지침**: 새 기능을 제안하거나 구현할 때 해야 할 것과 지양해야 할 것을 정리해요.

## 1. 목적

코코넛 월렛은 와치 온리 비트코인 월렛이에요. 새로운 기능은 사용자의 경험을 더 좋게 만들 수 있어야 하지만, 지갑의 핵심 동작과 안전성을 흔들어서는 안 돼요.

이 문서는 아래 질문에 답하기 위해 작성했어요.

- 코코넛 월렛의 주요 폴더는 어떤 역할을 하나요?
- 새 기능을 제안할 때 어느 영역을 먼저 보면 좋나요?
- 코코넛 오픈 스토어에 등록되는 기능은 어디에 정의하나요?
- 어떤 영역은 반드시 조심해서 다뤄야 하나요?
- PR에서 어떤 구조와 검증 내용을 설명해야 하나요?

## 파트 A. 아키텍처 설명

## 2. 큰 구조

현재 코코넛 월렛은 아래 역할을 기준으로 나누어져 있어요.

아래는 실제 `lib/` 구조 중, 기능 제안 시 먼저 이해하면 좋은 주요 폴더예요. `lib/` 전체 폴더 목록은 아니에요.

```text
lib/
  app/
  ccos/
  core/
  design_system/
  model/
  providers/
  repository/
  screens/
  services/
  ui/
  utils/
  widgets/
```

| 폴더 | 역할 |
|------|------|
| `lib/app/` | 앱 시작, 라우팅, 전역 provider, 앱 테마 연결 |
| `lib/ccos/` | 코코넛 오픈 스토어와 등록 기능 정의 |
| `lib/core/` | 비트코인 / 트랜잭션 등 지갑 핵심 로직 |
| `lib/design_system/` | 코코넛 월렛의 색상, 테마, 토큰 |
| `lib/model/` | 화면과 기능에서 사용하는 데이터 모델 |
| `lib/providers/` | 상태 관리, 설정, 화면별 view model |
| `lib/repository/` | 로컬 DB, 보안 저장소, 공유 설정 저장소 |
| `lib/screens/` | 사용자가 실제로 만나는 화면 |
| `lib/services/` | 네트워크, 하드웨어 월렛, 기타 서비스 로직 |
| `lib/ui/coconut/` | 코코넛 월렛에서 공통으로 사용하는 기본 UI 컴포넌트 |
| `lib/utils/` | 비트코인 유틸, QR 유틸, 시스템 보조 함수 |
| `lib/widgets/` | 여러 화면에서 재사용하는 조합 위젯 |

## 3. 앱 시작과 전역 구조

앱 시작과 전역 연결은 주로 `lib/app/` 아래에 있어요.

대표 영역:

- `lib/app/bootstrap/`
- `lib/app/providers/`
- `lib/app/router/`
- `lib/app/theme/`
- `lib/app/deep_link/`

이 영역은 앱 전체 동작에 영향을 줘요.

## 4. 화면과 위젯 구조

사용자 화면은 `lib/screens/` 아래에 있어요.

대표 예:

- `lib/screens/home/`
- `lib/screens/send/`
- `lib/screens/settings/`
- `lib/screens/wallet_detail/`
- `lib/screens/ccos/`

화면은 보통 `lib/providers/view_model/<도메인>/`의 view model과 짝을 이뤄요. 예를 들어 `lib/screens/home/wallet_home_screen.dart`는 `lib/providers/view_model/home/wallet_home_view_model.dart`와 함께 있어요.

재사용 UI는 아래 세 곳에 나뉘어 있어요.

- `lib/ui/coconut/`
  - coconut-design-system 패키지를 감싼 wrapper 컴포넌트
- `lib/widgets/common/`
  - 여러 화면에서 함께 쓰는 조합 위젯
- `lib/widgets/features/`
  - 특정 기능이나 도메인에 가까운 조합 위젯

## 5. 디자인 시스템과 공통 UI

코코넛 월렛의 테마와 색상은 `lib/design_system/`과 `lib/ui/coconut/`을 기준으로 정의돼요.

대표 영역:

- `lib/design_system/tokens/`
- `lib/design_system/theme/`
- `lib/design_system/context/`
- `lib/ui/coconut/`

테마 종류를 새로 추가하는 방법은 [새 테마 종류 추가 가이드](../theme/add_theme_variant.md)에서 다뤄요.

## 6. CCOS와 코코넛 오픈 스토어

CCOS 관련 코드는 크게 두 흐름으로 나뉘어요.

| 위치 | 역할 |
|------|------|
| `lib/ccos/features/<feature-id>/` | 실제 등록되는 기능 정의와 기능 전용 문구 |
| `lib/ccos/ccos_feature_registry.dart` | 코코넛 오픈 스토어에 등록되는 기능 목록 |
| `lib/screens/ccos/` | 실제 등록된 기능의 UI 화면 (신규 화면이 필요한 기능만 파일이 추가돼요) |

스토어에 등록되는 기능은 `lib/ccos/features/<feature-id>/` 아래에 모여 있어요.

예:

```text
lib/ccos/features/coconut_pulp/
  coconut_pulp_feature.dart
  coconut_pulp_feature_copy.dart
```

역할:

- `*_feature.dart`
  - 기능 ID
  - 카테고리
  - 가격 / 구매 또는 활성화 관련 정보
  - 연결된 테마 종류나 실행 연결 정보
- `*_feature_copy.dart`
  - 제목
  - 설명
  - 작성자
  - 작성자 소개
  - 작성 의도
  - 코코넛에 추가한 이유
  - 기능 도움말
  - 태그

레지스트리(`lib/ccos/ccos_feature_registry.dart`)는 제목, 설명 같은 문구를 직접 담고 있지 않아요. 대신 아래처럼 기능 폴더에 정의된 값을 그대로 가져와요.

```dart
class CcosFeatureRegistrySource {
  static CcosFeatureListing get featuredListing => CoconutPulpFeature.listing;
}
```

## 파트 B. 기능 제안 지침

PR을 올릴 때 설명해야 할 내용은 [PR 템플릿](../../../.github/PULL_REQUEST_TEMPLATE/ccos_phase1.md)을 따라 주세요.

## 7. 새 기능을 제안할 때 먼저 정리할 것

새 기능을 제안할 때는 구현보다 먼저 아래를 정리해 주세요.

- 이 기능이 어떤 사용자 문제를 해결하나요?
- Green / Yellow / Red 중 어디에 가까운가요?
- 어떤 화면에서 사용자가 이 기능을 만나나요?
- 기존 화면을 수정해야 하나요, 아니면 새 화면으로 분리할 수 있나요?
- 외부 서버, 외부 저장소, 백그라운드 동작이 필요한가요?
- 지갑 식별자, 주소 파생, UTXO 해석, 트랜잭션 구성 방식에 영향을 주나요?
- 무료 / 1회 구매 / 구독 / 향후 유료화 후보 중 어떤 방식으로 제안하나요?

제안서는 [기능 제안 템플릿](../getting_started/feature_proposal_template.md)을 기준으로 작성해 주세요.

## 8. 해야 할 것

- 새 화면을 만들 때는 [screen / view model 짝 구조](#4-화면과-위젯-구조)를 유지해 주세요.
- 새 UI를 만들 때는 아래 순서를 우선해 주세요.
  1. `context.coconutColors` 같은 의미 기반 토큰을 사용해요.
  2. `lib/ui/coconut/`에 있는 기본 컴포넌트를 먼저 확인해요.
  3. 반복되는 조합이면 `lib/widgets/common/` 또는 `lib/widgets/features/`로 분리해요.
- 새 기능이 기존 화면에 버튼, 카드, 메뉴 같은 진입 요소를 추가해야 한다면, 기존 화면은 최소한만 수정해 주세요. 기능의 본문 화면이나 상세 로직은 가능하면 별도 화면 / 별도 위젯 / 기능 폴더로 분리하는 편이 좋아요.
- 화면에 들어가는 문구는 코드에 직접 임베딩하지 말아 주세요. 언어별 대응 방식은 [contributor_quickstart.md](../getting_started/contributor_quickstart.md)의 다국어 문구 관리 방식을 따라 주세요.
- 코코넛 오픈 스토어에 실제로 등록되는 기능은 `lib/ccos/features/<feature-id>/` 아래에 모아 주세요.
- 레지스트리(`ccos_feature_registry.dart`)는 긴 소개 문구를 직접 들고 있기보다, 기능별 정의를 참조하는 방식으로 유지해 주세요.
- `lib/app/` 아래 전역 구조를 변경해야 한다면, 필요한 이유를 먼저 분명히 설명해 주세요. 예를 들어 새로운 화면을 추가하는 일은 가능하지만, 앱 시작 흐름이나 전역 provider 구조를 바꾸는 일은 별도 검토가 필요해요.

## 9. 지양해야 할 것

- `Color(0x...)` 같은 하드코딩 색상은 가능한 한 피해주세요.
- 앱 시작 흐름, 라우팅 구조, 전역 provider 구성, 전역 테마 연결 구조를 일반 기능 제안에서 바로 수정하지 마세요.
- 아래 영역은 코코넛 월렛의 핵심 동작과 연결되어 있어요. 이 영역이 필요해 보이면 바로 구현하지 말고, 먼저 코코넛 개발팀 검토를 받아 주세요.
  - 지갑 데이터베이스
  - 지갑 동기화
  - 주소 파생
  - UTXO 해석
  - 트랜잭션 구성
  - 브로드캐스트
  - 수수료 정책
  - 백업 / 복구와 연결된 흐름

  관련 코드 경로 예:

  - `lib/core/**`
  - `lib/services/**`
  - `lib/repository/realm/**`
  - `lib/providers/node_provider/**`

## 10. 핵심 원칙

코코넛 월렛은 좋은 기능을 더해가되, 지갑의 핵심 동작과 사용자의 신뢰를 가장 먼저 지켜야 해요.

CCOS와 코코넛 오픈 스토어는 단순히 기능을 추가하는 구조가 아니에요. 유용한 기능이 코코넛 월렛 안에서 발견되고, 안전하게 검토되고, 사용자가 이해할 수 있는 방식으로 전달되도록 돕는 구조예요.
