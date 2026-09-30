class AnalyticsParameterValues {
  // 사용자 지정 익스플로러
  static const String customExplorer = 'CUSTOM_EXPLORER';

  // hot_wallet_action
  static const String create = 'create';
  static const String restore = 'restore';
}

/// `user_cohort` 사용자 속성: 이번 버전 첫 실행 시 신규 설치 / 기존 지갑 사용자 / 지갑 없는 기존 설치자
enum AnalyticsUserCohort {
  newUser('new'),
  existing('existing'),
  dormant('dormant');

  const AnalyticsUserCohort(this.value);
  final String value;
}

/// `entry_source`: 지갑 추가를 시작한 홈 버튼 (앱바 + 버튼 / 지갑 목록 아래 추가 행 / 지갑이 없을 때 추가 카드)
enum WalletAddEntrySource { appBar, homeAddRow, homeEmpty }

/// `prompt_location`: 백업하러 들어오며 누른 안내 (생성 직후 안내 / 홈 경고 카드 / 지갑 상세 배너)
enum BackupPromptLocation { postCreate, homeCard, detailBanner }

/// `entry_point`: 전송을 시작한 곳 (홈 / 지갑 상세 / UTXO 분할 / UTXO 병합 / 거래 상세의 수수료 올리기)
enum SendAnalyticsEntryPoint { home, walletDetail, utxoSplit, utxoMerge, feeBump }

/// `action`: 지갑 상세 화면에서 누른 요소
enum WalletDetailAction {
  targetCard,
  utxoOverview,
  utxoOrganize,
  walletInfo,
  send,
  receive,
  txDetail,
  txMore,
  backupBanner,
}
