# 무선으로 iPhone 연결 후 앱 실행

USB 케이블 없이 Wi-Fi를 통해 iPhone에 앱을 빌드·실행하는 방법.

> **참고:** `fvm flutter run`으로 무선 연결 기기를 감지하지 못하는 경우가 많습니다.
> 이 가이드에서는 **빌드 후 Xcode에서 실행**하는 방식을 권장합니다.

---

## 사전 준비

- 개발 Mac과 iPhone이 **같은 Wi-Fi 네트워크**에 연결되어 있어야 합니다.
- Mac에 **Xcode**가 설치되어 있어야 합니다.
- Apple Developer 계정이 필요합니다 (무료 계정도 가능, 단 앱 유효기간 7일).
- iPhone에서 **개발자 모드**가 활성화되어 있어야 합니다 (iOS 16+).
  - 설정 → 개인정보 보호 및 보안 → **개발자 모드** 토글 ON → 재부팅 후 확인
- 최초 1회는 **USB 케이블**로 Mac과 iPhone을 연결하여 신뢰 관계를 설정해야 합니다.

---

## 1. 최초 USB 연결 및 신뢰 설정

1. USB 케이블로 iPhone을 Mac에 연결
2. iPhone 화면에 **"이 컴퓨터를 신뢰하시겠습니까?"** 팝업이 표시되면 **신뢰** 탭
3. Xcode를 열고 **Window → Devices and Simulators** 메뉴 진입
4. 좌측 목록에 연결된 iPhone이 표시되는지 확인

> **Xcode 26 (iOS 17+) 부터는 "Connect via network" 체크박스가 제거되었습니다.**
> 무선 디버깅이 자동으로 활성화되므로 별도 설정이 필요 없습니다.
> USB 케이블을 분리해도 같은 Wi-Fi 네트워크에 있으면 자동으로 무선 연결이 유지됩니다.
>
> - iOS 17부터 모든 디버깅이 네트워크 기반으로 전환되었습니다 (USB 연결 시에도 가상 네트워크 인터페이스를 통해 통신)
> - Xcode 15에서는 체크박스가 회색으로 비활성화되었고, Xcode 26에서는 완전히 제거되었습니다

---

## 2. USB 케이블 분리 및 무선 연결 확인

1. USB 케이블을 분리합니다.
2. Xcode의 **Devices and Simulators** 창에서 기기가 여전히 목록에 표시되는지 확인
   - 기기 옆에 **네트워크 아이콘(🌐)** 이 표시되면 무선 연결 성공
3. iPhone이 잠겨 있지 않은지 확인 (잠금 상태에서는 인식되지 않을 수 있습니다)

> `fvm flutter devices`에서 무선 기기가 감지되지 않더라도 Xcode에서 보이면 정상입니다.
> Flutter CLI보다 Xcode의 무선 기기 감지가 더 안정적입니다.

---

## 3. 앱 빌드

터미널에서 iOS 빌드를 수행합니다:

```bash
# regtest debug 빌드
fvm flutter build ios --flavor regtest --debug
```

또는 Makefile 타겟 사용:

```bash
# regtest profile 빌드
make ios-build-profile
```

> 빌드가 완료되면 `build/ios/` 디렉토리에 Xcode 프로젝트가 생성됩니다.

---

## 4. Xcode에서 실행

1. Xcode로 `ios/Runner.xcworkspace` 열기
   ```bash
   open ios/Runner.xcworkspace
   ```
2. 상단에서 실행 대상 기기를 **연결된 iPhone**으로 선택
3. **Cmd + R** (또는 Run 버튼)을 눌러 빌드·설치·실행

> Xcode를 통해 실행하면 무선 연결 기기에도 안정적으로 배포할 수 있습니다.
> 코드 변경 후 다시 실행하려면 3단계(빌드)부터 반복하거나, Xcode에서 직접 Cmd + R로 재빌드할 수 있습니다.

---

## 5. 무선 연결이 되지 않는 경우

### 방법 A: Xcode에서 재연결

1. Xcode → **Window → Devices and Simulators** 진입
2. 문제가 되는 기기를 좌측 목록에서 선택 후 우클릭 → **Unpair Device**
3. USB 케이블로 다시 연결하여 페어링을 수행 (무선 연결은 자동으로 활성화됨)

### 방법 B: 터미널에서 기기 확인

```bash
xcrun xctrace list devices
```

기기가 목록에 표시되지 않으면 네트워크 연결 또는 방화벽 설정을 확인하세요.

### 방법 C: iPhone 재부팅

iPhone을 재부팅한 후 같은 Wi-Fi에 다시 연결하고 Xcode에서 기기 인식 여부를 확인합니다.

---

## 6. 연결 해제

무선 연결을 해제하려면:

1. Xcode → **Window → Devices and Simulators** 진입
2. 기기를 선택 후 우클릭 → **Unpair Device**

> Xcode 26에서는 "Connect via network" 체크박스가 없으므로, 무선 연결을 끊으려면 기기를 Unpair해야 합니다.

---

## 주의사항

- 무선 빌드는 USB 연결 대비 빌드·설치 속도가 느릴 수 있습니다.
- iPhone과 Mac이 같은 Wi-Fi 네트워크에 있어야 합니다. 다른 네트워크(예: 게스트 Wi-Fi)에 연결된 경우 인식되지 않습니다.
- 방화벽이 Xcode의 네트워크 트래픽을 차단하지 않는지 확인하세요.
- 무료 Apple Developer 계정으로 빌드한 앱은 7일 후 만료되므로 재빌드가 필요합니다.
- 최초 페어링 시 반드시 USB 케이블이 필요합니다. 이후에는 무선으로 연결할 수 있습니다.
- 기기를 재부팅하거나 Wi-Fi가 변경된 경우, 무선 연결이 끊길 수 있으며 Xcode에서 다시 인식될 때까지 시간이 걸릴 수 있습니다.
- `fvm flutter run`으로 무선 기기가 감지되지 않는 경우, Xcode에서 직접 실행하는 방식을 사용하세요.
- Trezor Model One USB 연결 테스트 시, 무선으로 앱을 실행한 후 USB 케이블로 Trezor를 iPhone에 연결합니다 (Lightning–USB 어댑터 필요).
