# 새 테마 Variant 추가 가이드

새로운 테마(예: `sepia`)를 추가할 때 수정해야 하는 파일 목록입니다.

---

## 1. 색상 팔레트 정의

**`lib/design_system/tokens/coconut_colors.dart`**

`CoconutColors.light()` factory를 참고하여 새 factory 추가:

```dart
factory CoconutColors.sepia() {
  return CoconutColors(
    homeBackground: ...,
    // 모든 필드 정의
  );
}
```

---

## 2. ThemeExtension factory 추가

**`lib/design_system/theme/coconut_theme_extension.dart`**

```dart
factory CoconutThemeExtension.sepia() {
  return CoconutThemeExtension(
    colors: CoconutColors.sepia(),
    typography: CoconutTypography.dark(),
    spacing: const CoconutSpacing.base(),
    radius: const CoconutRadius.base(),
  );
}
```

---

## 3. enum 및 컨트롤러 수정

**`lib/design_system/theme/coconut_theme_data.dart`**

① enum에 새 variant 추가:
```dart
enum CoconutThemeVariant { dark, light, sepia }
```

② `brightnessOf()` switch에 케이스 추가:
```dart
case CoconutThemeVariant.sepia:
  return Brightness.light; // 또는 dark
```

③ `resolveCoconutThemeExtension()` switch에 케이스 추가:
```dart
case CoconutThemeVariant.sepia:
  return CoconutThemeExtension.sepia();
```

---

## 4. i18n 번역 추가 (기본 제공 테마인 경우)

아래 5개 파일 모두에 키 추가:

- **`assets/i18n/ko.i18n.yaml`** → `theme_sepia: "세피아 테마"`
- **`assets/i18n/en.i18n.yaml`** → `theme_sepia: "Sepia theme"`
- **`assets/i18n/ja.i18n.yaml`** → `theme_sepia: "セピアテーマ"`
- **`assets/i18n/es.i18n.yaml`** → `theme_sepia: "Tema sepia"`
- **`assets/i18n/de.i18n.yaml`** → `theme_sepia: "Sepia-Design"`

추가 후 코드 생성 실행:
```bash
dart run slang
```

---

## 5. 테마 선택 bottom sheet에 항목 추가

**`lib/screens/settings/theme_bottom_sheet.dart`**

```dart
List<_ThemeOption> get _themes => [
  _ThemeOption(variant: CoconutThemeVariant.dark, title: t.theme_dark),
  _ThemeOption(variant: CoconutThemeVariant.light, title: t.theme_light),
  _ThemeOption(variant: CoconutThemeVariant.sepia, title: t.theme_sepia), // 추가
];
```

---

## 6. 설정 화면 subtitle 레이블 추가

**`lib/screens/settings/app_settings/app_settings_screen.dart`**

`currentLabel` switch에 케이스 추가:
```dart
final currentLabel = switch (variant) {
  CoconutThemeVariant.light => t.theme_light,
  CoconutThemeVariant.dark => t.theme_dark,
  CoconutThemeVariant.sepia => t.theme_sepia, // 추가
};
```

---

## 수정 파일 요약

| 파일 | 작업 |
|------|------|
| `lib/design_system/tokens/coconut_colors.dart` | 새 팔레트 factory 추가 |
| `lib/design_system/theme/coconut_theme_extension.dart` | 새 ThemeExtension factory 추가 |
| `lib/design_system/theme/coconut_theme_data.dart` | enum, `brightnessOf`, `resolveCoconutThemeExtension` 수정 |
| `assets/i18n/*.i18n.yaml` (5개) | 번역 키 추가 후 `dart run slang` 실행 |
| `lib/screens/settings/theme_bottom_sheet.dart` | 선택 목록에 항목 추가 |
| `lib/screens/settings/app_settings/app_settings_screen.dart` | subtitle switch에 케이스 추가 |
