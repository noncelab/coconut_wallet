# Integration Tests

이 폴더는 실제 모바일 기기에서 실행되어야 하는 통합 테스트들을 포함하고 있습니다.

## 테스트 실행 환경

- 실제 모바일 기기가 연결되어 있어야 합니다.
- Regtest flavor를 사용합니다.

## 테스트 실행 방법

각 테스트 파일은 다음 명령어로 실행할 수 있습니다:

```bash
flutter test integration_test/<test_file>.dart --flavor regtest
```

## 디버깅을 하고 싶을 때
### vscode 사용하는 경우
.vscode/launch.json
```
...
   "configuration": [
      ...
      {
            "name": "update_preparation_test Integration Test (Debug)",
            "request": "launch",
            "type": "dart",
            "program": "integration_test/[테스트 파일 이름].dart",
            "toolArgs": [
              "--flavor=regtest",
            ]
        },
   ]
```
launch.json 파일 수정 후, 해당 테스트 파일을 엽니다. vscode 왼쪽 메뉴에서 Run And Debug 메뉴를 연 후 설정한 configuration을 선택한 후 왼쪽의 재생버튼 모양을 누릅니다.
또는 해당 테스트 파일이 열려있고 포커스 된 상태에서 `F5` 키를 눌러 실행합니다.

### Android Studio 사용하는 경우
우측 상단에 main.dart 버튼을 눌러서 Edit Configuration을 누르고 윈도우 좌측 상단에 + 버튼 누릅니다.
Flutter Test를 클릭해주고, Test File 경로를 지정합니다. Additional args에 --flavor regtest 입력하고 OK 버튼을 눌러서 Configuration 파일 추가합니다.
특정 테스트만 진행하고 싶은 경우 IDE 좌측 숫자 부분에 디버그 아이콘 눌러서 Configuration 추가하여 실행합니다. 

### 현재 포함된 테스트들

1. `wallet_add_test.dart`
   - 외부 월렛 추가, 삭제, 로드 테스트(공개확장키, 디스크립터)

2. `realm_migration_test.dart`
   - 스키마 버전, 월렛 여부에 따른 Realm 마이그레이션 테스트

## 주의사항

- 테스트는 실제 디바이스의 저장소와 보안 기능을 사용합니다.
- 각 테스트는 실행 후 자동으로 테스트 데이터를 정리합니다. 설치했던 앱도 삭제합니다.
- 테스트 실패 시 디바이스에 테스트 데이터가 남아있을 수 있으니 수동 정리가 필요할 수 있습니다.
