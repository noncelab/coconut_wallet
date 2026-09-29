import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/services/analytics_service.dart';

// 지갑 추가 퍼널
extension WalletAddAnalytics on AnalyticsService {
  void logWalletAddMenuEntered({required bool isHotWallet}) {
    logEvent(
      eventName: AnalyticsEventNames.walletAddMenuEntered,
      parameters: {AnalyticsParameterNames.walletType: isHotWallet ? 'hotWallet' : 'watchOnly'},
    );
  }

  void logHotWalletFlowEntered({required bool isRestore}) {
    logEvent(
      eventName: AnalyticsEventNames.hotWalletFlowEntered,
      parameters: {AnalyticsParameterNames.hotWalletAction: isRestore ? 'restore' : 'create'},
    );
  }

  void logWalletAddButtonClicked() {
    logEvent(eventName: AnalyticsEventNames.walletAddButtonClicked);
  }

  void logWalletAddScreenEntered(WalletImportSource importSource) {
    logEvent(
      eventName: AnalyticsEventNames.walletAddScreenEntered,
      parameters: {AnalyticsParameterNames.walletAddImportSource: importSource.name},
    );
  }

  void logWalletAddCompleted(WalletImportSource importSource) {
    logEvent(
      eventName: AnalyticsEventNames.walletAddCompleted,
      parameters: {AnalyticsParameterNames.walletAddImportSource: importSource.name},
    );
  }

  void logWalletAddSyncCompleted() {
    logEvent(eventName: AnalyticsEventNames.walletAddSyncCompleted);
  }

  void logWalletAddSyncFailed() {
    logEvent(eventName: AnalyticsEventNames.walletAddSyncFailed);
  }
}
