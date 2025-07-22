# 코코넛 월렛 ・ Coconut Wallet

[![Github](https://img.shields.io/badge/github-Noncelab-orange?logo=github&logoColor=white)](https://github.com/noncelab)
[![GitHub tag](https://img.shields.io/badge/dynamic/yaml.svg?url=https://raw.githubusercontent.com/noncelab/coconut_wallet/main/pubspec.yaml&query=$.version&label=Version)](https://github.com/noncelab/coconut_wallet)
[![License](https://img.shields.io/badge/License-X11-green.svg)](https://github.com/noncelab/coconut_wallet/blob/main/LICENSE)

[![Coconut Wallet Logo](./assets/readme/wallet_logo_mainnet.png)]()
[![App Store Badge](./assets/readme/app-store-badge.png)](https://apps.apple.com/app/id6654902298)
[![Google Play Badge](./assets/readme/google-play-badge.png)](https://play.google.com/store/apps/details?id=onl.coconut.wallet.regtest)


비트코인을 주고 받기 위해 [코코넛 볼트](https://github.com/noncelab/coconut_vault)와 쌍으로 사용하는 모바일 애플리케이션이에요.

현재는 개발팀이 직접 구축한 '로컬 테스트넷 비트코인 네트워크'와 연결해서 사용하실 수 있어요.

휴대폰 두 대를 사용한다는 가정 하에 하나의 폰에는 `코코넛 볼트`를 설치하고, '내보내기'메뉴의 QR 코드를 월렛으로 스캔해야만 보기 전용(watch-only) 지갑이 추가돼요. 

월렛은 온라인 상태를 유지하여 지갑의 정보를 최신으로 유지하고, 서명된 트랜잭션을 비트코인 네트워크로 전송해요.

테스트 비트코인을 받아서 코코넛 볼트와 함께 에어갭 트랜잭션 전송 연습을 할 수 있어요.

더 상세한 설명이 필요하시면 [튜토리얼](https://noncelab.gitbook.io/coconut.onl) 사이트를 참고해주세요.

<br/>

<img src="./assets/readme/coconut_universe_mainnet.webp" width="600"/>

<br/>

비트코인 지갑 개발을 위한 라이브러리로 [코코넛 라이브러리](https://pub.dartlang.org/packages/coconut_lib)를 사용하고 있어요.

| coconut_lib         | [![pub package](https://img.shields.io/pub/v/coconut_lib.svg?label=coconut_lib&color=blue)](https://pub.dartlang.org/packages/coconut_lib)                 |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| coconut_vault | [![GitHub tag](https://img.shields.io/badge/dynamic/yaml.svg?url=https://raw.githubusercontent.com/noncelab/coconut_vault/main/pubspec.yaml&query=$.version&label=coconut_vault)](https://github.com/noncelab/coconut_vault) |
| coconut_wallet | [![GitHub tag](https://img.shields.io/badge/dynamic/yaml.svg?url=https://raw.githubusercontent.com/noncelab/coconut_wallet/main/pubspec.yaml&query=$.version&label=coconut_wallet)](https://github.com/noncelab/coconut_wallet) |

<br/>

## 개발환경 설정 및 실행

### 개발환경 설정

1. 이 프로젝트는 Flutter로 만들어졌습니다.
코드를 통해 앱을 실행하기 위해서는 컴퓨터에 [Flutter 개발환경](https://docs.flutter.dev/get-started/install)이 반드시 갖추어져 있어야 합니다.

2. 이 프로젝트는 'flutter_dotenv' 라이브러리를 통해 설정한 환경변수가 있어야 정상 동작합니다. 현재 비트코인 Regtest(로컬 테스트넷) 환경변수가 준비되어 있으나 오픈소스로 공개해 두지는 않았습니다. 개발 환경에서 직접 코코넛 월렛을 구동하기 위해 환경변수 파일이 필요하신 분은 포우팀으로 연락주시면 언제든지 답변 드리겠습니다. [hello@noncelab.com](mailto:hello@noncelab.com)

3. 버전 확인
    ```bash
    flutter --version
    ```

    ```bash
    # 스토어에 배포된 버전입니다.
    Flutter 3.24.3 • channel stable • https://github.com/flutter/flutter.git
    Framework • revision 2663184aa7 (7 weeks ago) • 2024-09-11 16:27:48 -0500
    Engine • revision 36335019a8
    Tools • Dart 3.5.3 • DevTools 2.37.3
    ```

4. 자동 생성 파일 준비

   ```bash
   flutter pub run build_runner clean # realm generate 오류 발생 시 캐시 삭제

   dart run build_runner build --delete-conflicting-outputs

   dart run realm generate

   flutter pub run slang

   # or
   dart run build_runner clean && dart run build_runner build --delete-conflicting-outputs && dart run realm generate && flutter pub run slang
   ```

### 실행하기

1. 포우팀에게 문의하여 환경변수 파일 준비하기

2. 앱을 실행할 모바일 기기 또는 시뮬레이터 준비하기

3. 소스코드 다운로드
   ```bash
   git clone https://github.com/noncelab/coconut_wallet.git
   cd coconut_wallet
   ```

4. 플러터 플러그인 설치
   ```bash
   flutter pub get
   ```

5. IDE debug mode 실행시 Default flavor 설정
    * Android Studio or IntelliJ 
        *  Run -> Edit Configurations... -> Build Flavor에 regtest 입력
    * Visual Studio Code
        * .vscode/launch.json 내부에 args 항목을 추가합니다.
          ```json
          {
          "name": "coconut_wallet (debug)",
            "request": "launch",
            "type": "dart",
            "args": ["--flavor", "regtest"]
          }
          ```
6. 터미널 실행 가이드
    ```bash
    # debug mode
    flutter run --flavor regtest

    # release mode
    flutter run --release --flavor regtest
    ```

    <br />

    **flavor 옵션은 왜 설정해야 하나요❓**
        
    현재 코코넛 볼트와 코코넛 월렛 프로젝트는 저희 팀이 직접 구축한 **로컬 비트코인 테스트넷** (regtest)을 사용합니다. 

    그렇기 때문에 여러분이 코코넛 월렛에서 테스트용 비트코인을 바로 받아보고, 전송 연습을 하실 수 있는 것이죠.

    만약 원하시는 분들이 많아진다면, 비트코인 mainnet 네트워크용 코코넛 볼트와 월렛도 지원할 예정이기 때문에 미리 flavor를 적용해서, 동일한 코드베이스에서 여러 환경에 맞는 앱을 빌드하고 배포할 준비를 해놓았습니다.
        
    현재는 regtest flavor만 설정해 놓은 상태입니다.

<br/>

## 기여하기

자세한 사항은 [CONTRIBUTING](https://github.com/noncelab/coconut_wallet/blob/main/CONTRIBUTING.md)을 참고해주세요.

* [Issues](https://github.com/noncelab/coconut_wallet/issues)를 통해 버그를 보고하기
* [Pull Request](https://github.com/noncelab/coconut_wallet/pulls)를 통해
    * 새로운 기능을 추가하기
    * 문서를 업데이트하거나 예제를 추가하기
    * 오타나 문법 오류를 수정하기

<br/>

## 라이선스
X11 Consortium License (MIT와 같고 저작권자 이름을 홍보에 사용할 수 없다는 제약이 추가된 라이선스입니다.)

자세한 사항은 [LICENSE](https://github.com/noncelab/coconut_wallet/blob/main/LICENSE)를 참고해주세요.

### Dependencies
사용하는 라이브러리들은 MIT, BSD, Apache 중 하나의 라이선스로 설정되어 있으며 상세 내용은 [이 링크](https://github.com/noncelab/coconut_wallet/blob/main/lib/oss_licenses.dart)를 참고해주세요.
