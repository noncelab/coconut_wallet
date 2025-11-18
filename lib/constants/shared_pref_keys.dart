import 'package:coconut_wallet/enums/electrum_enums.dart';

class SharedPrefKeys {
  /// 아래 7개는 비밀번호 분실 시 초기화 필요
  static const String kWalletCount = 'WALLET_COUNT';
  static const String kFaucetHistories = "FAUCET_HISTORIES";
  static const String kIsSetPin = "IS_SET_PIN";
  static const String kPinLength = "PIN_LENGTH";
  static const String kIsSetBiometrics = "IS_SET_BIOMETRICS"; // 생체 인증 사용 여부

  /// Fake Balance
  static const String kFakeBalanceTotal = 'FAKE_BALANCE_TOTAL';
  static const String kFakeBalanceMap = 'FAKE_BALANCE_MAP';

  static const String kNextVersionUpdateDialogDate = "NEXT_VERSION_UPDATE_DIALOG_DATE";
  static const String kCanCheckBiometrics = "CAN_CHECK_BIOMETRICS";
  static const String kIsBtcUnit = "IS_BTC_UNIT";
  static const String kShowOnlyUnusedAddresses = "SHOW_ONLY_UNUSED_ADDRESSES";
  static const String kIsReceivingTooltipDisabled = "IS_RECEIVING_TOOLTIP_DISABLED";
  static const String kIsChangeTooltipDisabled = "IS_CHANGE_TOOLTIP_DISABLED";
  static const String kIsBalanceHidden = "IS_BALANCE_HIDDEN";
  static const String kHideTermsShortcut = "IS_OPEN_TERMS_SCREEN";
  static const String kNextIdField = 'nextId';
  static const String kUtxoSortOrder = 'UTXO_SORT_ORDER';

  /// Home Features
  static const String kWalletOrder = "WALLET_ORDER"; // 지갑 순서
  static const String kFavoriteWalletIds = "FAVORITE_WALLET_IDS"; // 즐겨찾기된 지갑 목록
  static const String kExcludedFromTotalBalanceWalletIds =
      "EXCLUDED_FROM_TOTAL_BALANCE_WALLET_IDS"; // 홈화면 총 잔액에서 제외할 지갑 목록
  static const String kHomeFeatures = "HOME_FEATURES"; // 홈 화면에 표시할 기능(최근 거래, 분석, ...)
  static const String kAnalysisPeriod = "ANALYSIS_PERIOD"; // 분석 위젯에 사용되는 조회 기간
  static const String kAnalysisPeriodStart = "ANALYSIS_PERIOD_START"; // 분석 위젯에 사용되는 조회 기간 시작 날짜
  static const String kAnalysisPeriodEnd = "ANALYSIS_PERIOD_END"; // 분석 위젯에 사용되는 조회 기간 종료 날짜
  static const String kSelectedTransactionTypeIndices =
      "SELECTED_TRANSACTION_TYPE_INDICES"; // 분석 위젯에 사용되는 거래 유형

  /// 리뷰 요청 관련
  static const String kHaveSent = 'HAVE_SENT';
  static const String kHaveReviewed = 'HAVE_REVIEWED';
  static const String kAppRunCountAfterRejectReview = 'APP_RUN_COUNT_AFTER_REJECT_REVIEW';

  /// Language
  static const String kLanguage = 'LANGUAGE';

  /// Fiat
  static const String kSelectedFiat = 'SELECTED_FIAT';

  /// 보내기 화면 수신자 추가 카드 확인 여부
  static const String kHasSeenAddRecipientCard = "HAS_SEEN_ADD_RECIPIENT_CARD";

  // Electrum
  /// [DefaultElectrumServer.serverName] 또는 'CUSTOM'
  static const String kElectrumServerName = 'ELECTRUM_SERVER_NAME';
  static const String kCustomElectrumHost = 'CUSTOM_ELECTRUM_HOST';
  static const String kCustomElectrumPort = 'CUSTOM_ELECTRUM_PORT';
  static const String kCustomElectrumIsSsl = 'CUSTOM_ELECTRUM_IS_SSL';
  static const String kUserServers = 'USER_SERVERS';

  /// kHasLaunchedBefore 절대 초기화 금지
  static const String kHasLaunchedBefore = 'hasLaunchedBefore';

  static const List<String> keysToReset = [
    SharedPrefKeys.kWalletCount,
    SharedPrefKeys.kFaucetHistories,
    SharedPrefKeys.kIsSetPin,
    SharedPrefKeys.kPinLength,
    SharedPrefKeys.kIsSetBiometrics,
    SharedPrefKeys.kFakeBalanceTotal,
    SharedPrefKeys.kFakeBalanceMap,
  ];

  // Block explorer
  static const String kUseDefaultExplorer = 'USE_DEFAULT_EXPLORER';
  static const String kCustomExplorerUrl = 'CUSTOM_EXPLORER_URL';
}
