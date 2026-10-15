# 새 테마 종류 추가 가이드

영문 버전: [add_theme_variant.en.md](./add_theme_variant.en.md)

이 문서는 Coconut Wallet의 테마 / 토큰 구조에 새로운 테마 종류를 추가할 때 따라가면 좋은 절차를 정리한 안내서예요.

먼저 읽어 보시면 좋은 문서:

- [architecture.md](../foundation/architecture.md)
- [feature_boundary.md](../getting_started/feature_boundary.md)
- [contributor_quickstart.md](../getting_started/contributor_quickstart.md)

이 가이드는 단순히 파일 몇 개를 수정하는 체크리스트가 아니에요. CCOS 문맥에서는 Coconut Wallet이 관리하는 테마 레이어를 안전하게 확장하는 흐름으로 이해해 주시면 좋아요.

## 1. 목적

새로운 테마 종류는 아래 목적을 함께 충족하면 좋아요.

- Coconut Wallet 본체의 토큰 / 테마 레이어 안에서 추가해 주세요.
- 기존 지갑 동작은 바꾸지 않아야 해요.
- 새 테마를 추가해도 기존 기본 테마의 화면 모양과 색감은 의도치 않게 바뀌지 않는 편이 좋아요.
- 필요하면 새 테마를 검사용으로 활용해, 아직 토큰이 적용되지 않은 UI 영역을 찾는 데 도움이 되면 좋아요.

이 단계는 디자인 실험 문서가 아니에요. 우선순위는 항상 테마 추상화의 일관성이에요.

## 2. 후속 작업

현재 구조에서 새 테마 종류를 추가해도, 앱의 모든 경로가 자동으로 완전히 테마화되는 것은 아니에요.

즉, variant를 추가하는 일 자체는 가능하지만 아래 영역은 따로 후속 작업이 필요해요.

### 2.1 네이티브 스플래시

Flutter 위젯 트리 안에서 보이는 splash가 아니라, 앱 시작 직후의 native splash는 현재 theme의 영향을 받지 않아요.

대표 위치:

- `lib/app/bootstrap/splash_theme.dart`
- `android/app/src/main/res/drawable/launch_background.xml`
- `android/app/src/main/res/drawable-v21/launch_background.xml`
- `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- `ios/Runner/Base.lproj/LaunchScreenRegtest.storyboard`

의미:

- 새 테마 종류를 enum과 테마 factory에 추가해도 네이티브 스플래시 배경색이나 자산은 자동으로 바뀌지 않아요.
- 현재 네이티브 스플래시는 Flutter `ThemeData`가 아니라 플랫폼 리소스와 별도 상수에 의존하고 있어요.
- 즉, 테마 종류를 추가하는 것만으로 네이티브 스플래시까지 함께 테마화되지는 않아요.

### 2.2 테마 종류를 추가해도 자동으로 바뀌지 않는 영역

새 테마 종류를 추가해도 아래 영역은 자동으로 함께 바뀌지 않아요.

- 아직 의미 기반 토큰이 적용되지 않은 UI
- 테마의 영향을 받지 않는 네이티브 스플래시와 앱 내부 테마의 일관성
- 하드코딩된 색상

즉, 테마 종류 추가는 테마 시스템을 확장하는 작업이에요. 남아 있는 테마 이관 작업이나 별도 관리 영역까지 자동으로 정리해 주는 작업은 아니에요.

## 3. 수정 순서

### 3.1 색상 팔레트 정의

파일:

- `lib/design_system/tokens/coconut_colors.dart`

기존 `CoconutColors.light()` 또는 다른 테마 factory를 참고해서 새 factory를 추가해 주세요.

이 단계에서는 아래 원칙을 지켜 주세요.

- 일부 필드만 임의로 바꾸지 않는 편이 좋아요.
- 의미 기반 토큰 전체를 한 번에 정의해 주세요.
- 원시 색상을 늘리는 것보다 의미를 유지하는 것이 우선이에요.

### 3.2 ThemeExtension factory 추가

파일:

- `lib/design_system/theme/coconut_theme_extension.dart`

여기서도 아래 원칙을 함께 봐 주세요.

- 테마 종류는 의미 기반 색상 세트 전체를 일관되게 정의하는 데 집중해 주세요.
- 간격 / 모서리 둥글기 / 타이포그래피는 현재 테마 종류별로 나누는 필드가 아니므로 여기서 분리하지 않는 편이 좋아요.

### 3.3 variant enum 및 resolver 수정

파일:

- `lib/design_system/theme/coconut_theme_data.dart`

수정 대상:

1. `enum CoconutThemeVariant`
2. `brightnessOf()`
3. `resolveCoconutThemeExtension()`

### 3.4 i18n 번역 추가

기본 제공 테마로 노출할 예정이라면 공용 테마 이름은 기존 중앙 i18n 파일에 추가해 주세요.

대상 파일:

- `assets/i18n/ko.i18n.yaml`
- `assets/i18n/en.i18n.yaml`
- `assets/i18n/ja.i18n.yaml`
- `assets/i18n/es.i18n.yaml`
- `assets/i18n/de.i18n.yaml`

이 부분은 특히 주의해 주세요.

- 이것은 코코넛 월렛이 직접 관리하는 공용 테마 이름에 대한 규칙이에요.
- CCOS 레지스트리에 올라가는 기능 소개 문구 전체를 이 파일들에 계속 누적하는 방식은 권장하지 않아요.

기여자가 제공하는 CCOS 테마라면 아래처럼 나눠서 관리해 주세요.

1. 공용 테마 이름
   - `assets/i18n/*.i18n.yaml`
2. 기능 전용 스토어 소개 문구
   - `lib/ccos/features/<feature-id>/<feature-id>_feature_copy.dart`

예:

```text
lib/ccos/features/coconut_theme/
  coconut_theme_feature.dart
  coconut_theme_feature_copy.dart
```

즉:

- `theme_sepia` 같은 앱 공용 이름은 중앙 i18n 파일
- 작성자 / 설명 / 의도 / 기능 도움말 같은 기능 소개 문구는 기능 전용 copy 파일

현재 CCOS 예시에서는 `*_feature_copy.dart` 안에서 아래 언어를 함께 관리하고 있어요.

- `ko`
- `en`
- `ja`
- `es`
- `de`

추가 후:

```bash
dart run slang
```

### 3.5 테마 선택 UI 연결

파일:

- `lib/screens/settings/theme_bottom_sheet.dart`
- `lib/screens/settings/app_settings/app_settings_screen.dart`
- 필요 시 `lib/ccos/ccos_feature_registry.dart`

해야 할 일:

- 기본 제공 테마로 직접 노출할지, CCOS 카탈로그 항목을 통해 노출할지 먼저 정해 주세요.
- 기본 제공 테마로 노출한다면 `theme_bottom_sheet.dart`의 선택 목록에 테마 종류를 추가해 주세요.
- 현재 테마 이름을 표시하는 switch에도 케이스를 추가해 주세요.
- CCOS 예시나 기여자가 제공하는 테마로 노출한다면, `lib/ccos/features/<feature-id>/` 아래에 기능 정의와 copy를 추가하고 `ccos_feature_registry.dart`에서 그 기능을 참조해 주세요.

### 3.6 보통 추가 수정이 필요 없는 경로

현재 레포에서는 아래 경로가 공통 resolver를 사용하고 있어요.

- Cupertino theme
- Android system bar color

따라서 새 테마 종류를 enum / factory / resolver에 올바르게 추가하면, 보통 아래 파일들에는 별도 케이스별 수정을 많이 하지 않아도 돼요.

- `lib/app/theme/app_cupertino_theme.dart`
- `lib/utils/system_chrome_util.dart`

## 4. 검증

새 테마 종류를 추가한 뒤에는 최소한 아래를 확인해 주세요.

1. 앱이 정상 빌드되는가
2. 테마 선택 UI에 새 항목이 보이는가
3. 테마 적용 시 일부 컴포넌트 구현이나 플랫폼 리소스가 여전히 수동 확인이 필요한지 점검했는가
4. 기본 테마의 화면 일관성은 깨지지 않았는가
5. 새 테마가 지갑 동작과 무관하게 UI 레이어에서만 동작하는가

## 5. 함께 피하면 좋은 것

- 기존 UX를 테마 종류 추가 과정에서 바꾸기
- 의미 기반 토큰 없이 원시 색상을 늘리기
- 테마 종류 추가를 “디자인 개선” 명분으로 삼아 구조 변경과 섞기
- 미리보기 / 디버그용 테마와 사용자용 테마를 문서 없이 혼동시키기

## 6. 수정 파일 요약

| 파일 | 작업 |
|------|------|
| `lib/design_system/tokens/coconut_colors.dart` | 새 팔레트 factory 추가 |
| `lib/design_system/theme/coconut_theme_extension.dart` | 새 ThemeExtension factory 추가 |
| `lib/design_system/theme/coconut_theme_data.dart` | enum, resolver, brightness 수정 |
| `assets/i18n/*.i18n.yaml` | 번역 키 추가 후 `dart run slang` 실행 |
| `lib/screens/settings/theme_bottom_sheet.dart` | 기본 제공 테마 목록 또는 CCOS 항목 노출 구조 반영 |
| `lib/screens/settings/app_settings/app_settings_screen.dart` | 현재 테마 이름 switch에 케이스 추가 |
| `lib/ccos/features/<feature-id>/` | 기여자가 제공하는 기능 정의와 기능 전용 copy 추가 |
| `lib/ccos/ccos_feature_registry.dart` | 실제 등록 기능을 참조하도록 연결 |

보통 수정 불필요:

- `lib/app/theme/app_cupertino_theme.dart`
- `lib/utils/system_chrome_util.dart`

단, 새 테마 종류가 기존 밝기 가정과 다르게 동작해야 한다면 이 부분은 직접 꼭 검증해 주세요.

## 7. 문서 위치 규칙

이 문서는 CCOS 문서 배치 원칙에 따라 `docs/ccos/` 아래에 둬요.

이유:

- 테마 종류 가이드는 제품 / 구조 기준의 CCOS 기여 문서에 속해요.
- 특정 로컬 툴 전용 문서가 아니라 Coconut Wallet의 테마 레이어 운영 문서이기 때문이에요.
