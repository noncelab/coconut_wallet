# 새 Theme Variant 추가 가이드

이 문서는 Coconut Wallet의 theme/token 구조에 새로운 theme variant를 추가할 때 따라야 하는 절차를 정리한다.

기준 문서:

- [architecture.md](/Users/doey/workspace/coconut_wallet/docs/ccos/architecture.md)
- [phase0a_session_handoff.md](/Users/doey/workspace/coconut_wallet/docs/ccos/phase0a_session_handoff.md)
- [phase1.md](/Users/doey/workspace/coconut_wallet/docs/ccos/phase1.md)

이 가이드는 단순히 파일 몇 개를 수정하는 체크리스트가 아니다. CCOS 문맥에서는 Coconut Wallet이 관리하는 theme layer를 안전하게 확장하는 절차여야 한다.

## 1. 목적

새로운 theme variant는 다음 목적을 충족해야 한다.

- Coconut Wallet 본체의 token/theme layer 안에서 추가된다.
- 기존 wallet behavior를 바꾸지 않는다.
- 새 테마를 추가해도 기존 기본 테마의 화면 모양과 색감은 의도치 않게 바뀌지 않아야 한다.
- 필요하면 새 테마를 검사용으로 활용해, 아직 token이 적용되지 않은 UI 영역을 찾는 데 도움이 되어야 한다.

이 단계는 디자인 실험 문서가 아니다. 우선순위는 항상 theme abstraction의 일관성이다.

## 2. Further work

현재 구조에서 새 theme variant를 추가해도, 앱의 모든 경로가 자동으로 완전히 테마화되는 것은 아니다.

즉, variant 추가 자체는 가능하지만 아래 영역은 별도의 후속 작업이 필요하다.

### 2.1 Native splash

Flutter 위젯 트리 안에서 보이는 splash가 아니라, 앱 시작 직후의 native splash는 별도 경로로 관리된다.

대표 위치:

- `lib/app/bootstrap/splash_theme.dart`
- `android/app/src/main/res/drawable/launch_background.xml`
- `android/app/src/main/res/drawable-v21/launch_background.xml`
- `ios/Runner/Base.lproj/LaunchScreen.storyboard`
- `ios/Runner/Base.lproj/LaunchScreenRegtest.storyboard`

의미:

- 새 variant를 enum과 theme factory에 추가해도 native splash 배경색이나 자산은 자동으로 따라오지 않는다.
- 특히 현재 native splash는 Flutter `ThemeData`가 아니라 플랫폼 리소스와 별도 상수에 의존한다.
- 따라서 variant를 실제 사용자용 theme로 확장할 계획이라면, native splash를 그 variant와 어떻게 연결할지 별도로 설계해야 한다.


### 2.2 아직 token이 완전히 닿지 않은 영역

다음 영역은 theme variant를 추가한 뒤에도 실제 적용 상태를 다시 확인해야 한다.

- `lib/app/bootstrap/splash_theme.dart` 같은 bootstrap 전용 색상 경로
- scanner overlay
- dialog / loading overlay
- 일부 popup / tooltip / dim layer
- native 쪽 launch background

이유:

- 현재 repo에는 이미 많은 화면이 `context.coconutColors`를 쓰고 있지만,
- 일부 경로는 아직 하드코딩 색상, 상수, 또는 플랫폼 리소스에 의존할 수 있다.
- 이런 부분은 새 variant를 추가해도 자동으로 바뀌지 않을 수 있다.

### 2.3 Variant 추가의 한계

새 variant를 추가하는 것만으로는 아래 문제가 해결되지 않는다.

- 아직 token이 안 탄 UI 정리
- native splash와 앱 내부 theme의 일관성
- 하드코딩 색상 제거

즉, variant 추가는 theme system을 확장하는 작업이지, 남은 테마 이관 작업을 대체하는 작업이 아니다.

## 3. 수정 순서

## 3.1 색상 팔레트 정의

파일:

- `lib/design_system/tokens/coconut_colors.dart`

기존 `CoconutColors.light()` 또는 다른 variant factory를 참고해 새 factory를 추가한다.

예시:

```dart
factory CoconutColors.sepia() {
  return CoconutColors(
    homeBackground: ...,
    // 모든 필드 정의
  );
}
```

원칙:

- 일부 필드만 임의로 바꾸지 않는다.
- semantic token 전체를 정의한다.
- raw color를 늘리는 것보다 semantic meaning을 유지하는 것이 우선이다.

## 3.2 ThemeExtension factory 추가

파일:

- `lib/design_system/theme/coconut_theme_extension.dart`

예시:

```dart
factory CoconutThemeExtension.sepia() {
  return CoconutThemeExtension(
    colors: CoconutColors.sepia(),
  );
}
```

원칙:

- Theme variant는 semantic color set 전체를 일관되게 정의하는 데 집중한다.
- spacing/radius/typography는 현재 host-owned theme extension 필드가 아니므로 여기서 분기하지 않는다.

## 3.3 variant enum 및 resolver 수정

파일:

- `lib/design_system/theme/coconut_theme_data.dart`

수정 대상:

1. `enum CoconutThemeVariant`
2. `brightnessOf()`
3. `resolveCoconutThemeExtension()`

예시:

```dart
enum CoconutThemeVariant { dark, light, sepia }
```

```dart
case CoconutThemeVariant.sepia:
  return Brightness.light;
```

```dart
case CoconutThemeVariant.sepia:
  return CoconutThemeExtension.sepia();
```

## 3.4 i18n 번역 추가

기본 제공 theme로 노출한다면 i18n 키를 추가한다.

대상 파일:

- `assets/i18n/ko.i18n.yaml`
- `assets/i18n/en.i18n.yaml`
- `assets/i18n/ja.i18n.yaml`
- `assets/i18n/es.i18n.yaml`
- `assets/i18n/de.i18n.yaml`

예시:

- `theme_sepia: "세피아 테마"`
- `theme_sepia: "Sepia theme"`

추가 후:

```bash
dart run slang
```

## 3.5 Theme selection UI 연결

파일:

- `lib/screens/settings/theme_bottom_sheet.dart`
- `lib/screens/settings/app_settings/app_settings_screen.dart`
- 필요 시 `lib/ccos/theme/ccos_theme_catalog.dart`

해야 할 일:

- built-in theme로 직접 노출할지, CCOS catalog entry를 통해 노출할지 먼저 결정한다.
- built-in theme로 노출한다면 `theme_bottom_sheet.dart`의 선택 목록에 variant를 추가한다.
- 현재 variant label을 표시하는 switch에 케이스를 추가한다.
- CCOS 예시나 contributor-offered theme로 노출한다면, `ccos_theme_catalog.dart`에 entry와 free / one-time purchase metadata를 추가한다.

예시:

```dart
_ThemeOption(variant: CoconutThemeVariant.sepia, title: t.theme_sepia)
```

```dart
CoconutThemeVariant.sepia => t.theme_sepia,
```

CCOS catalog 예시:

```dart
CcosThemeOffer(
  id: 'ccos-theme-sepia-pack',
  title: 'Sepia Pack',
  description: '...',
  priceType: CcosThemePriceType.oneTimePurchase,
  linkedVariant: CoconutThemeVariant.sepia,
)
```

참고:

- 현재 theme persistence 경로는 enum name 기반으로 공통 처리된다.
- 즉 `PreferenceProvider.changeThemeVariant()`는 전달된 variant를 저장하고, app bootstrap 시 저장값을 다시 읽어 적용한다.
- 따라서 새 variant를 enum에 정상 추가하면 persistence를 위해 별도의 special-case 로직을 추가할 필요는 보통 없다.

관련 코드:

- `lib/providers/preferences/preference_provider.dart`
- `lib/app/bootstrap/app_bootstrap.dart`

## 3.6 보통 추가 수정이 필요 없는 경로

현재 레포에서는 아래 경로가 공통 resolver를 사용한다.

- Cupertino theme
- Android system bar color

즉 아래 경로가 이미 variant 기반 공통 처리를 사용한다.

- `CoconutThemeController.brightnessOf()`
- `resolveCoconutThemeExtension()`

따라서 새 variant를 enum/factory/resolver에 올바르게 추가하면, 보통 이 파일들에 별도 case-by-case 수정을 추가할 필요는 없다.

관련 코드:

- `lib/app/theme/app_cupertino_theme.dart`
- `lib/utils/system_chrome_util.dart`

## 4. 검증

새 variant를 추가한 뒤 최소한 아래를 확인한다.

1. 앱이 정상 build 되는가
2. theme selection UI에 새 항목이 보이는가
3. variant 적용 시 token이 안 탄 하드코딩 영역이 어색하게 남는지 확인했는가
4. 기본 theme의 parity는 깨지지 않았는가
5. variant가 wallet behavior와 무관하게 UI layer에서만 동작하는가

## 5. 하지 말아야 할 것

- 기존 UX를 variant 추가 과정에서 바꾸기
- semantic token 없이 raw color를 늘리기
- variant를 “디자인 개선” 명분으로 써서 구조 변경과 섞기
- preview/debug theme와 사용자용 theme를 문서 없이 혼동시키기

## 6. 수정 파일 요약

| 파일 | 작업 |
|------|------|
| `lib/design_system/tokens/coconut_colors.dart` | 새 palette factory 추가 |
| `lib/design_system/theme/coconut_theme_extension.dart` | 새 ThemeExtension factory 추가 |
| `lib/design_system/theme/coconut_theme_data.dart` | enum, resolver, brightness 수정 |
| `assets/i18n/*.i18n.yaml` | 번역 키 추가 후 `dart run slang` 실행 |
| `lib/screens/settings/theme_bottom_sheet.dart` | built-in theme 목록 또는 CCOS entry 노출 구조 반영 |
| `lib/screens/settings/app_settings/app_settings_screen.dart` | 현재 label switch에 케이스 추가 |
| `lib/ccos/theme/ccos_theme_catalog.dart` | contributor-offered theme entry와 monetization metadata 추가 시 수정 |

보통 수정 불필요:

- `lib/app/theme/app_cupertino_theme.dart`
- `lib/utils/system_chrome_util.dart`

단, 새 variant가 기존 brightness 가정과 다르게 동작해야 한다면 동작을 직접 검증해야 한다.

## 7. 문서 위치 규칙

이 문서는 CCOS 문서 배치 원칙에 따라 `docs/ccos/` 아래에 둔다.

이유:

- theme variant 가이드는 product/architecture/contributor-facing CCOS 문서에 속한다.
- 특정 로컬 툴 전용 문서가 아니라 Coconut Wallet의 theme layer 운영 문서이기 때문이다.
