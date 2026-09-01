class AnalyticsEventNames {
  // 지갑 추가
  static const String walletAddButtonClicked = 'wallet_add_button_clicked'; // event
  static const String walletAddScreenEntered = 'wallet_add_screen_entered'; // event
  static const String walletAddCompleted = 'wallet_add_completed'; // event
  static const String walletAddSyncCompleted = 'wallet_add_sync_completed'; // event
  static const String walletAddSyncFailed = 'wallet_add_sync_failed'; // event

  // 앱 구동 또는 재연결 시 이미 등록된 지갑 일괄 재구독 및 동기화 이벤트
  static const String walletBulkSyncCompleted = 'wallet_bulk_sync_completed';
  static const String walletBulkSyncFailed = 'wallet_bulk_sync_failed';

  // 지갑 재동기화 (wipe & re-fetch) 이벤트
  static const String walletResyncStarted = 'wallet_resync_started';
  static const String walletResyncCompleted = 'wallet_resync_completed';
  static const String walletResyncFailed = 'wallet_resync_failed';
}
