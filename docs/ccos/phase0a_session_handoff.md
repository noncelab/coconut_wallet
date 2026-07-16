# CCOS Phase 0A Session Handoff

이 문서는 `coconut_wallet`에서 진행 중인 CCOS Phase 0A 준비 작업의 현재 상태를 다음 세션으로 안전하게 넘기기 위한 인수인계 문서다.

목적:
- 다음 세션에서 중복 작업을 줄인다.
- Phase 0A 원칙을 위반하는 변경을 막는다.
- 어떤 구조를 이미 도입했고, 어떤 작업이 남았는지 빠르게 파악할 수 있게 한다.

## 1. 절대 원칙

이 리팩토링의 핵심은 **구조를 바꾸되, UI/UX와 사용자 플로우는 바꾸지 않는 것**이다.

반드시 지킬 것:
- 라우팅, 화면 진입 방식, 바텀시트/풀스크린 여부를 바꾸지 않는다.
- 화면 제목, 문구, 정보구조를 임의로 바꾸지 않는다.
- 기존 색상값을 바로 바꾸지 말고, 먼저 semantic token으로 옮긴다.
- 앱 화면/위젯은 외부 `coconut_design_system` 색에 직접 의존하지 않고 `context.coconutColors`를 사용한다.
- 이번 단계는 디자인 개선이 아니라 CCOS host theme abstraction 준비다.

하지 말아야 할 것:
- 새 화면을 만들어 기존 UX를 route/push로 바꾸기
- “더 좋아 보인다”는 이유로 문구, 구조, 네비게이션 변경
- `gray800 -> surface` 같은 의미 없는 기계적 일괄 치환

## 2. Phase 0A 문서 기준

반드시 먼저 읽을 문서:
- [architecture.md](/Users/doey/workspace/coconut_wallet/docs/ccos/architecture.md)
- [phase0_seed.md](/Users/doey/workspace/coconut_wallet/docs/ccos/phase0_seed.md)

핵심 목표:
- host-owned token layer 도입
- `BuildContext` 기반 theme access 도입
- 공통 UI primitive 정리
- 일부 핵심 화면을 semantic token으로 이관
- default theme 시각적 parity 유지
- lightweight sample theme로 abstraction 검증

## 3. 지금까지 한 일

### 3.1 theme/token layer 정리

다음 구조를 이미 사용 중이다.
- [coconut_colors.dart](/Users/doey/workspace/coconut_wallet/lib/design_system/tokens/coconut_colors.dart)
- [coconut_theme_extension.dart](/Users/doey/workspace/coconut_wallet/lib/design_system/theme/coconut_theme_extension.dart)
- [coconut_theme_data.dart](/Users/doey/workspace/coconut_wallet/lib/design_system/theme/coconut_theme_data.dart)
- [coconut_theme_context_extension.dart](/Users/doey/workspace/coconut_wallet/lib/design_system/context/coconut_theme_context_extension.dart)

이미 정리된 방향:
- 앱은 `context.coconutColors`를 단일 진입점으로 사용
- 외부 `coconut_design_system`은 token 내부 기본값 공급원 역할만 수행
- 레거시 `styles.dart`는 해체 중이며, 새 코드는 거기에 의존하지 않는 방향

### 3.2 preview theme 도입

토큰 적용 범위를 시각적으로 검증하기 위한 preview theme를 추가했다.

관련 파일:
- [coconut_theme_data.dart](/Users/doey/workspace/coconut_wallet/lib/design_system/theme/coconut_theme_data.dart)
- [coconut_theme_extension.dart](/Users/doey/workspace/coconut_wallet/lib/design_system/theme/coconut_theme_extension.dart)
- [coconut_colors.dart](/Users/doey/workspace/coconut_wallet/lib/design_system/tokens/coconut_colors.dart)
- [app_settings_screen.dart](/Users/doey/workspace/coconut_wallet/lib/screens/settings/app_settings/app_settings_screen.dart)

현재 preview theme 특징:
- dark 변형이 아니라 **light-leaning debug theme**
- 토큰을 탄 부분은 밝아지고
- 하드코딩된 `black/gray800/gray900`는 어둡게 남아
- 미적용 지점을 빠르게 찾을 수 있음

### 3.3 settings 구조 리팩토링 원칙 정리

중요한 결정:
- 최상위는 `settings` 문맥 유지
- `home-kebab`, `more-on-home` 같은 UI trigger 중심 이름은 사용하지 않음
- 폴더 구조는 사용자 정보구조를 따르되, UX는 그대로 유지

이미 확인된 원칙:
- app settings는 route screen이 아니라 **기존처럼 bottom sheet**
- `tools_screen.dart` 같은 별도 독립 진입 화면 추가는 금지

### 3.4 색상 semantic token 확장

`gray800/850/900`, `black`, `white`를 기계적으로 치우지 않고 문맥별 token을 추가했다.

주요 token:
- 배경/표면
  - `background`
  - `backgroundSubtle`
  - `surface`
  - `surfaceCard`
  - `surfaceCardStrong`
  - `surfaceButton`
  - `surfaceMuted`
  - `surfaceDisabled`
  - `surfaceBottomSheet`
  - `surfaceSectionBreak`
  - `inputSurface`
- filter chip
  - `surfaceFilterChip`
  - `surfaceFilterChipSelected`
  - `textFilterChip`
  - `textFilterChipSelected`
- skeleton
  - `surfaceSkeletonBase`
  - `surfaceSkeletonHighlight`
- interaction
  - `surfacePressed`
  - `dimOverlay`
- text/icon
  - `primaryText`
  - `secondaryText`
  - `tertiaryText`
  - `iconBackground`
  - `iconDefault`
  - `iconSubDefault`
  - `iconHighlight`
  - `iconDisabled`
- popup/menu
  - `pulldownMenuBackground`
  - `pulldownMenuDividerColor`
  - `pulldownMenuTextColor`
  - `popupBackground`
  - `shadowDefault`
- state
  - `sendingColor`
  - `receivingColor`
  - `success`
  - `danger`

## 4. 실제 적용이 들어간 대표 영역

### 4.1 홈 화면

대표 파일:
- [wallet_home_screen.dart](/Users/doey/workspace/coconut_wallet/lib/screens/home/wallet_home_screen.dart)

정리된 내용:
- 카드 문맥을 `surfaceCard` 중심으로 정리
- 작은 액션 버튼 문맥을 `surfaceButton`으로 분리
- 홈 섹션 굵은 divider 밴드는 `surfaceSectionBreak`
- 스켈레톤은 `surfaceSkeletonBase/highlight`
- 일부 popup/menu 문맥은 `popupBackground`, `pulldownMenuBackground` 등으로 이동

주의:
- 홈은 가장 많이 건드린 화면 중 하나다.
- 다음 세션에서 홈을 다시 만질 때는 preview theme로 실제 남은 hardcoded 영역만 확인하고 진행할 것.

### 4.2 바텀시트

공통 유틸:
- [common_bottom_sheets.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/overlays/common_bottom_sheets.dart)

정리된 내용:
- 바텀시트 기본 배경은 `surfaceBottomSheet`
- 다만 child 내부가 `Scaffold(backgroundColor: background)` 등으로 다시 덮으면 호출부 색이 먹지 않을 수 있음

실제 수정 예:
- [analysis_period_bottom_sheet.dart](/Users/doey/workspace/coconut_wallet/lib/screens/home/analysis_period_bottom_sheet.dart)
  - `surfaceBottomSheet`로 내부 배경 통일

중요한 교훈:
- 바텀시트 호출부만 바꾸면 끝이 아님
- 시트 내부 `Scaffold`/최상위 `Container` 배경도 같이 봐야 함

### 4.3 UTXO 목록

대표 파일:
- [utxo_list_screen.dart](/Users/doey/workspace/coconut_wallet/lib/screens/wallet_detail/utxo_list_screen.dart)
- [utxo_item_card.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/card/utxo_item_card.dart)
- [custom_tag_horizontal_selector.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/selector/custom_tag_horizontal_selector.dart)
- [utxo_list_sticky_header.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/header/utxo_list_sticky_header.dart)
- [selected_utxo_amount_header.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/header/selected_utxo_amount_header.dart)

정리된 내용:
- UTXO 카드 배경/pressed/텍스트를 token 기반으로 이동
- 전체/사용잠금/잔돈/#태그 칩은 filter chip token 도입 후 치환
- sticky header 배경/텍스트/아이콘 token화
- 선택 모드 헤더 배경/텍스트/아이콘 token화

### 4.4 공통 위젯

대표 파일:
- [transaction_item_card.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/card/transaction_item_card.dart)
- [single_button.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/button/single_button.dart)
- [fixed_bottom_button.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/button/fixed_bottom_button.dart)
- [copy_text_container.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/button/copy_text_container.dart)
- [input_and_share_overlay.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/input_and_share_overlay.dart)
- [long_pressed_menu_widget.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/long_pressed_menu_widget.dart)

정리된 내용:
- `TransactionItemCard`: text/icon token화, self/self-sending icon gradient 적용
- `SingleButton`: title/subtitle/arrow 색 token화
- `FixedBottomButton`: 생성자 기본 색상 하드코딩 제거, build 시 token으로 해석
- `CopyTextContainer`: card/pressed/text/icon/address accent token화
- `InputAndShareOverlay`: dim gradient, pressed, icon token화
- `LongPressedMenuWidget`: popup/pulldown 문맥 token화 + 반투명 효과 복원

## 5. typography/text 관련 진행 상태

이미 적용한 원칙:
- `Text`에서 `CoconutTypography`를 쓰는데 색이 없으면 `primaryText` 적용
- `TextSpan`에서도 같은 기준 적용

다음에 볼 것:
- `copyWith(...)`, `merge(...)`, `DefaultTextStyle` 내부에 숨어 있는 무색상 `CoconutTypography`

## 6. overlay/dim 관련 진행 상태

추가된 token:
- `dimOverlay`

현재 이 token은 일부 overlay에만 적용됨.
대표 적용:
- [long_pressed_menu_widget.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/long_pressed_menu_widget.dart)
- [input_and_share_overlay.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/input_and_share_overlay.dart)

아직 남아 있는 `black.withValues(alpha: ...)` 사용처는 더 있다.
특히 다음 범위는 이후 `dimOverlay` 문맥으로 점진 치환 대상:
- scanner overlay
- dialog overlay
- loading overlay
- 일부 tooltip/overview overlay

## 7. 아직 남은 주요 작업

### 7.1 하드코딩 색 추가 제거

우선순위:
1. `ShrinkAnimationButton` 사용처 전수 문맥 정리
2. `black.withValues(alpha: ...)` overlay/dim 계열 정리
3. `gray800/850/900`의 남은 surface/input/border/popup 문맥 정리
4. `SvgPicture.asset` 단색 UI icon의 colorFilter 정리

주의:
- `SvgPicture.asset`는 일괄 `iconDefault` 적용 금지
- 브랜드/상태/멀티컬러 자산은 제외

### 7.2 settings/home/send/detail 축 추가 정리

아직 남은 작업 후보:
- `send_screen.dart` 및 send/refactor 계열
- scanner screen 계열
- dialog / overlay 계열
- wallet detail overview 계열
- bottom sheet 내부 Scaffold 배경 재점검

### 7.3 styles.dart 계열 완전 정리

방향:
- legacy shim을 더 줄이기
- 남은 레거시 심볼을 token 또는 primitive로 흡수
- 새 코드는 legacy file import 금지

### 7.4 guardrail

문서 기준으로 결국 필요한 것:
- migrated area 또는 CCOS path에서 신규 hardcoded color를 막는 lightweight script/CI

아직 구현 안 됨.

## 8. 다음 세션에서 먼저 할 일

추천 순서:
1. preview theme 켠 상태에서 남은 하드코딩 색이 크게 보이는 영역 확인
2. `ShrinkAnimationButton` override 사용처 우선 정리
3. `dimOverlay`를 scanner/dialog/loading overlay 쪽으로 확장
4. `SvgPicture.asset` 중 단색 UI icon만 token 기반 colorFilter 적용
5. 남은 bottom sheet 내부 배경 재검토

## 9. 다음 세션에서 하면 안 되는 일

- settings 진입 UX를 route/push로 바꾸기
- 새로운 독립 screen 추가 후 기존 bottom sheet를 대체하기
- preview theme를 실제 사용자 theme처럼 다듬기
- token 도입 중에 디자인/문구/네비게이션 개선까지 같이 하기
- “카드가 더 나아 보인다”는 이유만으로 현재 값 자체를 바꾸기

## 10. 확인용 참고 파일

핵심 구조:
- [coconut_colors.dart](/Users/doey/workspace/coconut_wallet/lib/design_system/tokens/coconut_colors.dart)
- [coconut_theme_extension.dart](/Users/doey/workspace/coconut_wallet/lib/design_system/theme/coconut_theme_extension.dart)
- [coconut_theme_data.dart](/Users/doey/workspace/coconut_wallet/lib/design_system/theme/coconut_theme_data.dart)
- [coconut_theme_context_extension.dart](/Users/doey/workspace/coconut_wallet/lib/design_system/context/coconut_theme_context_extension.dart)

대표 적용 예시:
- [wallet_home_screen.dart](/Users/doey/workspace/coconut_wallet/lib/screens/home/wallet_home_screen.dart)
- [analysis_period_bottom_sheet.dart](/Users/doey/workspace/coconut_wallet/lib/screens/home/analysis_period_bottom_sheet.dart)
- [utxo_list_screen.dart](/Users/doey/workspace/coconut_wallet/lib/screens/wallet_detail/utxo_list_screen.dart)
- [utxo_item_card.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/card/utxo_item_card.dart)
- [transaction_item_card.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/card/transaction_item_card.dart)
- [fixed_bottom_button.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/button/fixed_bottom_button.dart)
- [copy_text_container.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/button/copy_text_container.dart)
- [input_and_share_overlay.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/input_and_share_overlay.dart)
- [long_pressed_menu_widget.dart](/Users/doey/workspace/coconut_wallet/lib/widgets/long_pressed_menu_widget.dart)

## 11. 한 줄 요약

지금까지 한 일은 **host-owned token/theme layer를 실제 화면과 공통 위젯에 연결하는 작업**이다.

다음 세션에서도 목표는 같다:
**하드코딩 색과 외부 DS 직접 의존을 줄이되, UI/UX는 절대 바꾸지 않는다.**
