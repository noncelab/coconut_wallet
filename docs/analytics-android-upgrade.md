# Android 수집 거부 보호 — 업그레이드 체크리스트

Flutter, FlutterFire(`firebase_core`·`firebase_analytics`), Firebase BoM, measurement SDK 중 하나라도 올릴 때 확인한다.

## 자동 확인

- 모든 Android 빌드의 preBuild는 런타임에 실제로 들어가는 `firebase-common`·`play-services-measurement-api` 버전을 `android/app/build.gradle`의 compileOnly 고정값과 비교한다. 다르면 빌드가 멈춘다. 고정값은 아래 실기기 확인을 다시 한 뒤에 올린다.
- `flutter pub get` 후 `android/`에서 `./gradlew :app:testRegtestDebugUnitTest -x compileFlutterBuildRegtestDebug`를 실행한다. JVM 테스트라 Dart 빌드는 필요 없다.
  - `AnalyticsGatedPluginRegistry`: 보류, 해제 후 attach, 중복·순서, remove·removeAll, attach 직전 실패 뒤 재시도
  - `AnalyticsProcessState`: 저장된 OFF를 이미 시작된 SDK에만 다시 적용하고, SDK가 없으면 아무것도 시작하지 않는지
  - `GeneratedPluginRegistrant`: `firebase_analytics`가 `flutterEngine.getPlugins().add(...)`로만 등록되는지

## 실기기 확인

1. 저장된 OFF로 콜드 스타트하면 FirebaseApp이 초기화되지 않고, analytics 플러그인이 attach되지 않으며, FA 로그가 없다.
2. MainActivity에 `Analytics plugin attached before saved consent` 오류 로그가 없다. 이 로그가 보이면 Flutter가 제공된 엔진에 플러그인을 자동 등록한다는 뜻이다.
3. 앱 저장값은 OFF이고 SDK 영속값은 ON인 상태에서 같은 프로세스로 Activity를 다시 만든다. Dart 초기화가 끝나기 전에 SDK 로그 `Setting app measurement enabled (FE)`가 false로 남고, 새 Activity에서 `_s` 같은 자동 이벤트가 기록되지 않는다. 설정 호출은 비동기라 이 로그가 Android의 resume 표시보다 늦게 찍힐 수 있다. 기준은 SDK가 수집 설정을 새 Activity의 수명주기 처리보다 먼저 처리하는지와 이벤트가 없는지다.
4. OFF에서 ON으로 바꾸면 자동 이벤트와 업로드가 다시 동작한다.
