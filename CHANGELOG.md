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