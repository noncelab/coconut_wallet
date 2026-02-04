## mainnet 0.7.0, regtest 3.6.0
### Added
* 홈화면 24시간 이내 거래, 입출금 횟수 요약 위젯 추가
### Fixed
* RBF 화면 진입 시 UTXO 삭제되어 불가능하던 오류 해결 (fix orphaned uxto filtering)
* 지갑 추가 - 직접 입력 - 붙여넣기 화면 제거됨
* PSBT 스캔 시 99%일 때 안내 문구 안뜨던 버그 수정
* 카메라 스위치 버튼 통일
* 지갑 추가 TopSheet 지갑 종류 언어 변경 안되는 버그 수정

## mainnet 0.6.2, regtest 3.5.2
### Added 
- 언어 선택 > 스페인어 추가
- 지갑 추가 > 직접 입력 > QR 스캔이 우선 > 클립보드 데이터 있는 경우 '붙여넣기로 추가하기' 가능

### Fixed
- 트랜잭션 동기화 로직 수정 (large tx를 처리하지 못하는 문제)
- [보내기 화면] 글자 사이즈 큰 기기에서 텍스트 필드와 주소 목록이 겹치는 현상 개선, 주소 입력 TextField 포커스 시에만 아래로 스크롤 되는 액션 실행되도록 수정
- [주소 스캔 화면] 카메라 Overlay 영역에 들어와야 스캔 진행되도록 개선
- [주소 스캔 화면] (폴드 펼친 화면) width 600 초과 화면에서 상단 텍스트박스 위치 조정
- [QR스캔/QRView] 갤럭시 폴드에서 화면이 꽉 차게 보이는 것을 개선

## mainnet 0.6.1, regtest 3.5.1 
### Fixed
* orphaned UTXO 정리 로직 추가
* 카메라 권한 없을 때 안내 개선
* 보내기 화면, 주소 찾기 화면 카메라 전환 버그 수정

## mainnet 0.6.0, regtest 3.5.0 - 2025-12-30
### Added
* 다중 서명 지갑 - '백업 데이터 보기' 메뉴 추가
* signedPsbtScannerDataHandler (통합 핸들러) 추가 / 적용 - RawTxHexString 스캔 가능
* 메인넷 - 생일주간 아이콘 변경 (iOS는 앱 실행 시 자동 변경, AOS는 배포 필요)

## mainnet 0.5.1, regtest 3.4.1 - 2025-11-27
### Fixed
* 안드로이드 - 일본어 사용 기기에서 앱 이름 수정
* 설정 언어에 따라 멤풀 url에 언어 추가
* 지갑 상세 화면 리팩토링

## mainnet 0.5.0, regtest 3.4.0 - 2025-11-03
### Fixed
* network에 따라 멤풀 URL 분기
* 가짜 잔액 오류 수정
* 콜드카드 PSBT - BBQR 스캔 오류 수정
* 불필요한 진동 제거, 안드로이드 진동 세기 조절
* 지갑 없을 때 일렉트럼 서버 에러 표시 문제 수정
* 일본어 개선 / 번역 개선
* 가짜 잔액 단위 오류(지갑 추가/삭제 시 오류) 수정
* 부동소수점 에러 수정

## mainnet 0.4.7, regtest 3.3.2 - 2025-11-03
### Added
* UTXO 다중 잠금
* 일본어 용어집
### Fixed
* 보내기 - 대문자로 된 bech32 QR주소 스캔 오류 해결
* 한/영 어순 구분이 필요한 화면에서 일본어는 한국어 어순대로 나오도록 설정
* UI 수정

## mainnet 0.4.6, regtest 3.3.1 - 2025-09-19
* flutter 3.29.0 + 안드로이드 8.0: BackDropFilter 에러 발생. flutter 3.29.1로 업데이트
* 안드로이드 앱 첫 실행 시 PrivacyScreen 깜빡임

## mainnet 0.4.5 - 2025-09-13
* 시드사이너 지갑 추가 버그 수정 (BC-UR)
* QR Scanner 라이브러리 교체
* 안드로이드 PrivacyScreen 버그 수정
* 보내기 화면
  - 등록된 지갑 주소 목록에서 보낼 주소 선택 시 주소 인덱스 증가
  - 등록된 지갑 주소 목록 스크롤 추가
  - 배치 트랜잭션 안내 UI 추가

## mainnet 0.4.4, regtest 3.3.0 - 2025-09-13
* 니모닉 문구 바이너리 검색
* utxo 정렬 기준 선택값 유지
* 보내기 - 내 주소 - 지갑 순서대로 보임 (단, 내 주소가 제일 첫번째)
* appLifecycle - PrivacyScreen
* 이름 편집 아이콘 - 서드파티 하드웨어에만 보임
* 지갑 아이콘, 지갑 상세화면 UI 변경
* 크럭스 지원
* block explorer 설정 가능 (only mainnet)

## mainnet 0.4.3 - 2025-08-22
### Fixed
* 일부 화면 레이아웃 수정

## mainnet 0.4.2 - 2025-08-22
### Fixed
* recipient address prefix 3 허용
* utxo 선택 화면 스크롤 멈춤 현상
* 트랜잭션 생성시 추천 수수료율 미만, 0.1 이상의 수수료율 허용
* 보내기 화면 utxo auto-select 모드일 때 잔액 보여주지 말기 (confirmed utxo의 전체 합이 노출됨)
* 큰 글자 모드에서 잔액 가려지는 현상 수정
* 콜드카드 에어갭 트랜잭션 호환성 해결
### Added
* wallet_list 법정화폐 가격 보여주기

## mainnet 0.4.1, regtest 3.2.1 - 2025-08-13
### Fixed
* 보내기 화면 - 에러 처리 누락 버그 수정
* 보내기 화면 - masterFingerprint 없는 지갑 보내기 다음 화면 이동 불가
* 안드로이드 백버튼 클릭 시 키보드 위 요소가 남아있는 버그 수정
* 가짜 잔액 버그 수정
### Added
* JPY 시세 보기 추가
  
## mainnet 0.4.0, regtest 3.2.0 - 2025-08-08
### Fixed
* coconut_lib 1.0.0 적용
* Android API 35로 업데이트 (qr-code-scanner 라이브러리 내부로 옮김)
* 가짜 잔액 버그 수정
### Added
* VPN 통한 일렉트럼 서버 연결 지원
* 새로운 홈화면, 보내기 화면
* QR 스캔 프로그레스 UI 추가
* 콜드카드 지원

## mainnet 0.3.0 - 2025-07-28
### Fixed
* 지갑 추가 예외 메시지 프롬프트에 추가
### Added
* 일렉트럼 노드 설정 기능
* 추천수수료 조회 루트 2개 추가, util 함수 생성 후 적용

## mainnet 0.2.1 - 2025-07-25
### Fixed
* UTXO 조회 시 realm.refresh()
* 주소 보기 화면 툴팁 개선
* QR 스캔 시 노이즈 처리, QR Density 변경 시에도 스캔 가능하게 처리
* RBF 엣지 케이스에서 TX 생성 에러 발생 시 Sweep으로 생성 (임시처리)

## mainnet 0.2.0 - 2025-07-21
### Fixed
* 보내기 - 수수료 선택 화면 버그 수정
* 후원하기 배너 안드로이드에서만 노출

## mainnet 0.1.0

## mainnet 0.0.15(beta), regtest 3.1.8 - 2025-07-18
### Fixed
* utxo_selection 버그 수정
* 영문화 문구 일부 수정

## mainnet 0.0.14(beta) - 2025-07-16
### Fixed
* 영문화 문구 일부 수정
### Added
* 설정 > 앱 정보 보기 > 코코넛 크루: 제네시스 멤버 추가
  
## mainnet 0.0.13(beta), regtest 3.1.7(only aos) - 2025-07-14
### Fixed
* 비밀번호 분실 > 초기화 안되는 버그 수정
* 지갑 상세 화면에서 지갑 정보 화면으로 가는 앱 바 버튼 스타일 수정
* QR View 여백 수정
* 저사양 기기에서도 오류 없도록 동기화 상태 관리 방법 개선
### Added
* 언어 - 영어 지원
* 4자리/6자리 비밀번호 선택 설정 가능
* 후원하기
* 주소 입력 시 BIP21 주소 파싱

## mainnet 0.0.12(beta), regtest 3.1.6 - 2025-07-01
### Fixed
* 숨겨진 잔액 UI를 수정
* UTXO 상세 화면에서 태그 변경, 삭제 가능하게 함
* 트랜잭션 상세 화면에서 PTR할 경우 네트워크를 통해 데이터 refetching
* BTC 수량 표기 규칙을 수정
### Added
* 가짜 잔액 기능 추가
* 제이드 호환

## mainnet 0.0.11(beta) - 2025-06-26
### Fixed
* 브로드캐스팅 후 긴 로딩, 실패 오류 해결
* 전체 주소 보기 0번 주소 안나오는 오류 해결
* derivation path에 h가 포함된 descriptor 추가 후 트랜잭션 생성 시 오류 해결
### Added
* 앱 잠금 기능을 추가했어요.
* 트랜잭션 전송 버튼의 UI와 텍스트를 '보내기'로 변경했어요.
* 트랜잭션 전송 직후 '메모' 추가 가능해졌습니다.
* 코코넛 볼트와의 에어갭 통신을 bc-ur 표준으로 변경
  
## mainnet 0.0.10(beta), regtest 3.1.5 - 2025-06-20
### Fixed
* Bech32 대문자 주소 입력 가능
### Added
* 트랜잭션 목록에 '메모' 보여주기
  
## mainnet 0.0.9(beta)
### Fixed
* [입력 정보 확인] 화면 - 예상 수수료 항목에 dust 잔돈 포함되어 보내지는 경우에도 예상 수수료에 포함이 안되어 있음
* 보내기 - QR 스캔 화면에서 다른 앱에서 주고 복사 후 돌아왔을 때 '붙여넣기' 버튼 활성화가 안됨
* 보내기 - 클립보드에 legacy 주소 복사 후 QR 스캔 화면에 진입 시 화면 에러
### Added
* 사용 전 주소만 보기 
* 주소 검색 기능 추가
* UTXO 잠금

## mainnet 0.0.8(beta) 
### Fixed
* 용어집 바텀싯 닫힘 중단 현상
* 용어집에 디스코드에 물어보기 글가 줄바뀜되는 것 방지
* tx-input-output-card input 없을 때 ui 버그 수정
* tx-input-output-card 더보기 버튼 노출 버그 수정
### Added
* 거래 내역 총 개수 표시

## mainnet 0.0.7(beta)
### Fixed
* coconut_lib ^0.10.3 버전 업그레이드

## mainnet 0.0.6(beta), regtest 3.1.4 - 2025-06-11
### Fixed
* 툴팁 동작 버그 개선
* 지갑 직접 추가 시 0이 아닌 account도 허용
* utxo 관리 화면 개선
* 수수료 소숫점 2자리까지 허용
* 버튼 고정 너비 수정
* 트랜잭션, UTXO 누락 버그 수정
* OP_RETURN 표기 제외
* 스크롤 프레임 드랍 최적화
### Added
* btc - sats 단위 변환 기능 추가


## mainnet 0.0.5(beta), regtest 3.1.3 - 2025-06-09
### Fixed
* 지갑 추가 시 중복 체크 로직 수정
* 백그라운드 진입, 재연결, 지갑 삭제, 지갑 추가 시 동기화 로직 개선

## mainnet 0.0.4(beta) - 2025-06-04
### Fixed
* 지갑 추가 - 직접 입력 h(hardened) 기호 가진 descriptor도 추가 가능하도록 수정
* 지갑 추가 - 직접 입력 완료 후 mfp 입력 화면으로 전환 시, 키보드 유지 / bottomSheet의 버튼을 누르면 키보드가 닫히도록 수정
* utxo 목록 화면: '큰 금액순'을 기본값으로 변경
* 용어집 RBF/CPFP 추가
  
## regtest 3.1.2 - 2025-06-02
### Fixed
* 배치 트랜잭션 UI 버그 수정

## mainnet 0.0.3(beta) - 2025-06-02
### Fixed
* 짧은 시간 내 앱 상태 resume 됐을 때 지갑 동기화 안되는 버그 수정 (isolate_manager _send 반환 타입 에러 수정)

## mainnet 0.0.2(beta) - 2025-05-28
### Fixed
* 트랜잭션 상세 - 승인 번호 누락
* transaction_input_output_card overflow error
  
## mainnet 0.0.1(beta) - 2025-05-27
### Fixed
* utxo 동기화 버그 수정
* 받는 중 utxo가 rbf로 인해 대체될 경우 사라지지 않는 버그 수정
* MFP 지정 안된 지갑 RBF/CPFP 불가능하도록 변경
* RBF - dust limit 미만의 change output 발생 시 수수료로 소진


## regtest 3.1.1 - 2025-05-19
### Fixed
* rbf/cpfp 시 walletImportSource 지정 누락

## regtest 3.1.0 - 2025-05-09
### Added
* SeedSigner, KeyStone의 보기 전용 지갑 추가, 트랜잭션 보내기 가능
* 확장 공개키, Descriptor로 보기 전용 지갑 추가, 트랜잭션 보내기 가능

## regtest 3.0.1 - 2025-04-17
### Changed
* `Coconut_Design_System` 패키지 적용
* 네트워크 동기화 동시성 오류 해결

### Fixed
* 새로 추가되는 지갑에 '보내는 중'인 트랜잭션 있을 때 관련 UTXO 생성
* 앱 실행 후 지갑 동기화 중 지갑 추가 시 오류 해결
* UTXO 목록 화면에서 모든 리스트 사라질 때 오류 해결
* 수도꼭지 툴팁 노출
* UTXO 태그 추가 후 목록에 반영

## regtest 3.0.0 - 2025-04-02
### Added
* `RBF` 기능 지원
* `CPFP` 기능 지원
* `Batch Transaction` 기능 지원
* `Coconut_Design_System` 패키지 적용
* `i18n` 관리를 위해 slang 패키지 적용

### Changed
* 앱 전체 코드 리팩토링을 통해 유지보수성 개선
* 네트워크 관련 로직 개선

## regtest 2.1.1 - 2025-01-10
### Changed
* `지갑 상세`화면에서 unconfirmed 트랜잭션의 경우 `일시`에 생성일시 보여주기
* `전송` 실패 시에도 임시 트랜잭션 전송 일시 기록하던 버그 수정
  
## regtest 2.1.0 - 2025-01-08
### Added
* `UTXO 고르기` 기능 추가
* `태그` 기능 추가
* `트랜잭션 메모` 기능 추가

### Changed
* 테스트넷 라벨 적용 화면 변경
* `UTXO 잔액 상세` 기능이 `지갑 상세`화면으로 이동

### Deprecated
* `UTXO 잔액 상세` 화면 삭제

### Security
* PIN 보안 강화

## regtest 2.0.0 - 2024-12-06
### Added
* `다중 서명 지갑` 기능 추가

### Changed
* 홈 화면 지갑 목록 UI 및 로드 로직 변경

## regtest 1.0.2 - 2024-10-25
### Added
* 홈 화면 더보기 버튼 `용어집`, `니모닉 문구 단어집`, `셀프 보안점검` / `설정`, `앱 정보 보기` 드롭다운 메뉴 추가
* 홈 화면 용어집 `바로가기` 카드 추가
* 홈 화면 지갑 `바로 추가하기` 카드 추가

### Changed
* App, Splash 아이콘 변경
* 지갑 상세화면 더보기 버튼 아이콘 변경
* 설정 화면 팝업으로 변경
* 니모닉 문구 단어집 페이지로 변경
* 보내기 화면 `붙여넣기` 버튼 변경

### Removed
* 설정 화면 `용어집`, `니모닉 문구 단어집`, `셀프 보안점검`, `앱 정보 보기` 제거

### Fixed
* 생체인증 권한요청 시점 버그 수정 (비밀번호 생성시 체크 누락)
* 홈 화면 `모르는 용어가 있으신가요?` Container 화면 벗어나는 버그 수정
* 용어집 일부 단어들 클릭 후 상세내용 화면에서 슬라이드를 통한 닫기 불가능 버그 수정
* QR스캔 화면에서 알림 문구와 사각 영역이 겹침 버그 수정
* 생체인증 사용하기 활성화/비활성화 로직 버그 수정

## regtest 1.0.1 - 2024-09-20
### Added
* 배포 이슈로 인한 버전 업데이트

### Fixed
* 수도꼭지 요청 TextField 커서 버그 수정

## regtest 1.0.0 - 2024-09-19
### Added
* Initial version