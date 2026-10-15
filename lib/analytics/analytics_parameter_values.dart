class AnalyticsParameterValues {
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

/// `source` (wallet_add_button_clicked): 지갑 추가를 시작한 홈 버튼 (앱바 + 버튼 / 지갑 목록 아래 추가 행 / 지갑이 없을 때 추가 카드)
enum WalletAddEntrySource { appBar, homeAddRow, homeEmpty }

/// `source` (backup_prompt_tapped): 백업하러 들어오며 누른 안내 (생성 직후 안내 / 홈 경고 카드 / 지갑 상세 배너)
enum BackupPromptLocation { postCreate, homeCard, detailBanner }

/// `element`: 지갑 상세 화면에서 누른 요소
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

/// `segment` (screen_view `/utxo-organizer`): 정리하기 화면에서 보이는 탭 (합치기 / 나누기)
enum UtxoOrganizerSegment { merge, split }

/// `segment` (screen_view `/utxo-overview`): 한눈에 보기 화면에서 보이는 탭 (개요 / 목록)
enum UtxoOverviewSegment { overview, list }

/// `external_link_destination`: 연 외부 링크의 목적지 분류
enum ExternalLinkDestination {
  tutorial('tutorial'),
  supportChat('support_chat'),
  supportEmail('support_email'),
  feedbackChat('feedback_chat'),
  x('x'),
  github('github'),
  contributing('contributing'),
  termsOfService('terms_of_service'),
  privacyPolicy('privacy_policy'),
  license('license'),
  openSourceLicense('open_source_license'),
  crewProfile('crew_profile'),
  appStore('app_store'),
  explorerTx('explorer_tx'),
  explorerBlock('explorer_block'),
  explorerAddress('explorer_address');

  const ExternalLinkDestination(this.value);
  final String value;
}
