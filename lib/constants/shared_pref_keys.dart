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
  static const String kIsBalanceHidden = "IS_BALANCE_HIDDEN";
  static const String kHideTermsShortcut = "IS_OPEN_TERMS_SCREEN";

  /// 리뷰 요청 관련
  static const String kHaveSent = 'HAVE_SENT';
  static const String kHaveReviewed = 'HAVE_REVIEWED';
  static const String kAppRunCountAfterRejectReview = 'APP_RUN_COUNT_AFTER_REJECT_REVIEW';

  /// Language
  static const String kLanguage = 'LANGUAGE';

  /// Fiat
  static const String kSelectedFiat = 'SELECTED_FIAT';

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
}
