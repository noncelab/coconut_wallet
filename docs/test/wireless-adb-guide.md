# 무선 ADB로 Android 기기 연결 후 앱 실행

USB 케이블 없이 Wi-Fi를 통해 Android 기기에 앱을 빌드·실행하는 방법.

---

## 사전 준비

- 개발 PC와 Android 기기가 **같은 Wi-Fi 네트워크**에 연결되어 있어야 합니다.
- Android 기기에서 **개발자 옵션 → USB 디버깅**이 활성화되어 있어야 합니다.
- Android 11 이상에서는 **무선 디버깅** 옵션을 별도로 켜야 합니다.
  - 설정 → 개발자 옵션 → **무선 디버깅** 토글 ON
- 일부 Android 14 기기에는 **무선 디버깅** 메뉴가 노출되지 않을 수 있습니다. 이 경우 아래 [Android 14 대안](#android-14-대안) 절차를 사용하세요.

---

## 1. 기기 IP 및 포트 확인

1. Android 기기에서 **무선 디버깅** 화면 진입
2. **IP 주소 및 포트** 확인 (예: `192.168.1.100:37123`)

> 기기마다 포트 번호가 다르며, 재부팅 시 변경될 수 있습니다.

---

## 2. 무선 ADB 연결

```bash
adb connect <기기IP>:<포트>
```

예시:

```bash
adb connect 192.168.1.100:37123
```

페어링 코드가 필요한 경우 (Android 11+):

1. 무선 디버깅 화면에서 **기기 페어링** 버튼 탭
2. 표시된 **페어링 코드**와 **페어링 포트** 확인
3. PC에서 페어링 수행:

```bash
adb pair <기기IP>:<페어링포트>
# 페어링 코드 입력 프롬프트가 나타나면 코드 입력
```

4. 페어링 완료 후 다시 연결:

```bash
adb connect <기기IP>:<포트>
```

---

## 3. 연결 확인

```bash
adb devices
```

출력에 기기가 `device` 상태로 표시되면 연결 성공.

---

## 4. 앱 빌드 및 실행

regtest 디버그 빌드 실행:

```bash
make run-regtest-debug
```

또는 직접 명령:

```bash
fvm flutter run --flavor regtest --debug
```

> Flutter가 연결된 기기를 자동으로 감지하여 빌드·설치·실행합니다.
> 기기가 여러 대 연결된 경우 `fvm flutter run --flavor regtest --debug -d <기기ID>` 로 지정합니다.

---

## Android 14 대안

일부 Android 14 기기에서는 **무선 디버깅** 메뉴가 보이지 않습니다. 이 경우 USB 케이블로 초기 연결 후 `adb tcpip` 방식을 사용하세요.

1. Android 기기를 USB 케이블로 PC에 연결
2. 연결된 기기 확인:

```bash
adb devices
```

3. 여러 기기가 연결된 경우 기기 ID를 지정해 ADB를 TCP 모드로 전환:

```bash
adb -s <기기ID> tcpip 5555
```

기기가 한 대만 연결된 경우:

```bash
adb tcpip 5555
```

4. USB 케이블 분리
5. 기기의 Wi-Fi IP 주소 확인:
   - 설정 → Wi-Fi → 연결된 네트워크 → IP 주소
6. IP 주소로 연결:

```bash
adb connect <기기IP>:5555
```

예시:

```bash
adb connect 192.168.1.100:5555
```

> 기기를 재부팅하면 TCP 모드가 해제되므로, 다시 USB로 연결해 `adb tcpip 5555` (또는 `adb -s <기기ID> tcpip 5555`)를 실행해야 합니다.

---

## 5. 연결 해제

```bash
adb disconnect <기기IP>:<포트>
```

또는 전체 무선 연결 해제:

```bash
adb disconnect
```

---

## 주의사항

- 무선 디버깅은 USB 연결 대비 빌드·설치 속도가 느릴 수 있습니다.
- 기기를 재부팅하면 포트 번호가 변경되므로 다시 연결해야 합니다.
- 방화벽이 ADB 트래픽을 차단하지 않는지 확인하세요.
- Trezor Model One USB 연결 테스트 시, 무선 ADB로 앱을 실행한 후 USB 케이블로 Trezor를 Android 기기에 연결합니다.
