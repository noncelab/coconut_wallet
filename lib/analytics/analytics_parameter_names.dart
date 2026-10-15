class AnalyticsParameterNames {
  // 지갑 추가
  static const String walletType = 'wallet_type'; // watchOnly / multisig / inheritance / hotWallet
  static const String addMethod = 'add_method'; // create / restore
  static const String walletAddImportSource = 'wallet_add_import_source'; // parameter: enum WalletImportSource
  static const String hasHistory = 'has_history';

  // 공통
  static const String source = 'source'; // 어디서 눌렀나
  static const String sinceCreatedBucket = 'since_created_bucket';

  // 지갑 상세
  static const String element = 'element';

  // 지갑 필터
  // all / watchOnly(다중서명·상속 포함) / hot, WalletFilter.name 그대로
  static const String walletTypeFilter = 'wallet_type_filter';

  // 외부 링크
  static const String externalLinkDestination = 'external_link_destination';

  // 화면 (screen_view): 탭이 있는 화면에서 보이는 탭, UtxoOrganizerSegment / UtxoOverviewSegment .name
  static const String segment = 'segment';
}

class AnalyticsUserPropertyNames {
  static const String userCohort = 'user_cohort';
  static const String hotWalletInUse = 'hot_wallet_in_use';
}
