# 앱스토어 배포 가이드

이 문서는 Coconut Wallet의 App Store 및 Google Play 배포 준비 과정을 설명합니다.

한국어 릴리스 노트를 작성하고 Codex로 번역 메타데이터를 생성한 뒤, production 전용 Fastlane으로 각 스토어의 심사 요청 전 단계까지 준비합니다.

## 0. 사전 준비

### App Store Connect

Apple ID와 팀 ID를 미리 환경변수로 설정할 필요는 없습니다. Fastlane 실행 중 프롬프트가 나타나면 Apple ID의 전체 이메일 주소와 필요한 인증값을 입력합니다.

매번 같은 값을 입력하지 않으려는 경우에만 다음 환경변수를 선택적으로 설정할 수 있습니다.

```shell
export FASTLANE_USER="App Store Connect 로그인 이메일"
export APP_STORE_CONNECT_TEAM_ID="App Store Connect 팀 ID"
```

`FASTLANE_USER` 또는 Fastlane의 `Apple ID Username` 프롬프트에는 `Ella Lim`과 같은 표시 이름이 아니라 Apple ID의 전체 이메일 주소를 입력합니다. 환경변수가 없으면 Fastlane이 Apple ID, 비밀번호, 팀 선택 등을 대화형으로 요청할 수 있습니다.

해당 Apple ID에는 다음 조건이 필요합니다.

- `App Manager` 이상의 역할
- Mainnet과 Regtest 앱 모두에 대한 접근 권한
- 유효한 배포 인증서와 프로비저닝 프로파일

새 Apple 계약이 있는 경우 Account Holder가 App Store Connect에서 먼저 동의해야 합니다.

## 1. 한국어 릴리스 노트 작성

배포할 앱에 맞는 파일에 업데이트 사항을 한국어로 작성합니다.
아래 파일의 변경사항은 커밋 대상이 아니므로 .gitignore에 포함되어있습니다.

### Mainnet

```text
fastlane/store_metadata/source/mainnet/release_notes.ko.md
```

### Regtest

```text
fastlane/store_metadata/source/regtest/release_notes.ko.md
```

업데이트 내용만 간결하게 작성합니다.

예시:

```markdown
- 하드웨어 지갑 연결 과정의 안정성을 개선했어요.
- 일부 오류 메시지를 더 이해하기 쉽게 개선했어요.
- 사용 중 발견된 버그를 수정했어요.
```

Mainnet과 Regtest의 업데이트 내용이 같더라도 각각의 원본 파일에 작성합니다.

## 2. 번역 메타데이터 생성

Codex에서 배포할 앱에 맞는 Skill을 실행합니다.

### Mainnet

```text
$generate-store-release-notes mainnet 메타데이터를 생성해줘.
```

### Regtest

```text
$generate-store-release-notes regtest 메타데이터를 생성해줘.
```

Skill은 한국어 원문만을 기준으로 다음 언어의 메타데이터를 생성합니다.

| 언어 | App Store locale | Play Store locale |
|---|---|---|
| 한국어 | `ko` | `ko-KR` |
| 영어(미국) | `en-US` | `en-US` |
| 일본어 | `ja` | `ja-JP` |
| 스페인어(스페인) | `es-ES` | `es-ES` |
| 독일어 | `de-DE` | `de-DE` |

생성 경로는 다음과 같습니다.

```text
fastlane/store_metadata/generated/ios/<flavor>/<locale>/release_notes.txt
fastlane/store_metadata/generated/android/<flavor>/<locale>/changelogs/<versionCode>.txt
```

Codex는 사용자가 작성하지 않은 업데이트 내용을 커밋이나 코드에서 추측해 추가하지 않습니다.

## 3. 생성 결과 검토

배포 전에 다음 내용을 확인합니다.

- 한국어 원문의 내용이 빠짐없이 반영됐는지
- 지원하는 5개 언어의 파일이 모두 생성됐는지
- 기능명과 제품명, 기술 용어가 올바른지
- 번역에 과장되거나 원문에 없는 설명이 추가되지 않았는지
- Android 변경사항 파일의 versionCode가 이번 빌드 번호와 일치하는지

번역에 수정이 필요하면 한국어 원본을 고친 후 Skill을 다시 실행하는 것을 권장합니다. 특정 언어만 직접 수정하면 다음 생성 과정에서 덮어써질 수 있습니다.

## 4. App Store 심사 첨부파일

App Store Connect의 앱 심사 정보에 사용할 첨부파일은 다음 위치에서 관리합니다.

```text
ios/fastlane/store_metadata/review_attachments/mainnet/
ios/fastlane/store_metadata/review_attachments/regtest/
```

Mainnet과 Regtest에 맞는 첨부파일이 존재하는지 배포 전에 확인합니다.

각 flavor 디렉터리에는 첨부파일이 정확히 하나만 있어야 합니다. production Fastlane은 기존 App Store 심사 첨부파일을 해당 파일로 교체합니다.

## 5. Fastlane 배포

번역 결과를 검토한 후 배포할 앱에 맞는 production 명령을 실행합니다.

### Mainnet

```shell
make fastlane-production-mainnet
```

### Regtest

```shell
make fastlane-production-regtest
```

위 Make 명령은 Android를 먼저 처리한 다음 iOS를 처리합니다. Android가 성공한 뒤 iOS가 실패하면 Android production draft와 Android 빌드 번호 갱신은 유지됩니다.

### 플랫폼 하나만 배포

Android만 처리하려면 다음 명령을 사용합니다.

```shell
cd android/fastlane_production
bundle exec fastlane prepare_android_mainnet_production
bundle exec fastlane prepare_android_regtest_production
```

두 lane을 모두 실행하는 것이 아니라 배포할 flavor에 해당하는 lane 하나만 실행합니다.

iOS만 처리하려면 다음 명령을 사용합니다.

```shell
cd ios/fastlane_production
bundle exec fastlane prepare_ios_mainnet_production
bundle exec fastlane prepare_ios_regtest_production
```

마찬가지로 배포할 flavor에 해당하는 lane 하나만 실행합니다.

production 명령은 기존 내부 테스트 및 TestFlight 명령과 별도의 Fastlane 구성을 사용합니다. 기존 명령은 그대로 유지됩니다.

```shell
make fastlane-mainnet
make fastlane-regtest
```

production 명령이 수행하는 작업은 다음과 같습니다.

- 생성된 5개 언어의 릴리스 노트 검증
- Android AAB 및 iOS IPA 빌드
- Android production 트랙에 draft 상태로 AAB와 변경사항 업로드
- Google Play 변경사항을 자동으로 심사 전송하지 않도록 설정
- App Store Connect 출시 버전에 IPA와 릴리스 노트 업로드
- Mainnet 또는 Regtest에 해당하는 App Store 심사 첨부파일 업로드
- 성공한 플랫폼의 `pubspec.yaml` 빌드 번호 갱신

이 명령은 최종 심사 요청이나 실제 출시를 수행하지 않습니다.

### 기존 production 및 draft 확인

배포 전에 각 콘솔의 현재 상태를 확인합니다.

- Play Console에 기존 production draft가 있으면 새 업로드가 기존 draft를 대체하거나 충돌할 수 있습니다.
- Play Console에서 단계적 출시나 처리되지 않은 변경사항이 있으면 새 draft 생성이 실패할 수 있습니다.
- Android `versionCode`는 이전에 업로드한 적 없는 값이어야 합니다.
- App Store에 같은 마케팅 버전이 `Prepare for Submission` 상태라면 릴리스 노트와 심사 첨부파일이 갱신됩니다.
- App Store의 같은 마케팅 버전이 이미 출시됐다면 `pubspec.yaml`의 마케팅 버전을 올려야 합니다.
- iOS build number는 이전에 업로드한 적 없는 값이어야 합니다.

생성된 번역 메타데이터는 Git에서 제외되므로 다른 컴퓨터나 새 checkout에서 배포할 때는 Codex Skill을 다시 실행해야 합니다.

## 6. 수동 심사 요청

Fastlane 업로드가 완료되면 App Store Connect와 Play Console에서 빌드, 번역된 릴리스 노트, 심사 정보를 최종 확인한 뒤 수동으로 심사를 요청합니다.
