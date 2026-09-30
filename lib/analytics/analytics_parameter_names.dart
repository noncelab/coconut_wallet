class AnalyticsParameterNames {
  // 지갑 추가
  static const String walletType = 'wallet_type'; // watchOnly / multisig / inheritance / hotWallet
  static const String hotWalletAction = 'hot_wallet_action'; // create / restore
  static const String walletAddImportSource = 'wallet_add_import_source'; // parameter: enum WalletImportSource
  static const String entrySource = 'entry_source';
  static const String isConverted = 'is_converted';

  // 공통
  static const String sinceCreatedBucket = 'since_created_bucket';

  // 백업
  static const String promptLocation = 'prompt_location';

  // 보내기
  static const String entryPoint = 'entry_point';
  static const String isFirstSend = 'is_first_send';

  // 지갑 상세
  static const String action = 'action';

  // 지갑 필터
  // all / watchOnly(다중서명·상속 포함) / hot, WalletFilter.name 그대로
  static const String walletTypeFilter = 'wallet_type_filter';

  // 외부 링크
  static const String externalLinkDestination = 'external_link_destination';
}

class AnalyticsUserPropertyNames {
  static const String userCohort = 'user_cohort';
}
