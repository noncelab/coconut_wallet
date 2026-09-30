import 'package:coconut_wallet/analytics/analytics_event_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_values.dart';
import 'package:coconut_wallet/analytics/analytics_wallet_type.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/services/analytics_service.dart';

// 지갑 추가 퍼널
extension WalletAddAnalytics on AnalyticsService {
  void logWalletAddMenuEntered({required bool isHotWallet}) {
    logEvent(
      eventName: AnalyticsEventNames.walletAddMenuEntered,
      parameters: {
        AnalyticsParameterNames.walletType:
            (isHotWallet ? AnalyticsWalletType.hotWallet : AnalyticsWalletType.watchOnly).name,
      },
    );
  }

  void logHotWalletActionSelected({required bool isRestore}) {
    logEvent(
      eventName: AnalyticsEventNames.hotWalletActionSelected,
      parameters: {AnalyticsParameterNames.hotWalletAction: _hotWalletAction(isRestore)},
    );
  }

  void logHotWalletAddBlocked({required bool isRestore}) {
    logEvent(
      eventName: AnalyticsEventNames.hotWalletAddBlocked,
      parameters: {AnalyticsParameterNames.hotWalletAction: _hotWalletAction(isRestore)},
    );
  }

  void logWalletAddButtonClicked({WalletAddEntrySource? entrySource}) {
    logEvent(
      eventName: AnalyticsEventNames.walletAddButtonClicked,
      parameters: {if (entrySource != null) AnalyticsParameterNames.entrySource: entrySource.name},
    );
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

  void logHotWalletAddCompleted({required bool isRestore, bool isConverted = false}) {
    logEvent(
      eventName: AnalyticsEventNames.walletAddCompleted,
      parameters: {
        AnalyticsParameterNames.walletType: AnalyticsWalletType.hotWallet.name,
        AnalyticsParameterNames.hotWalletAction: _hotWalletAction(isRestore),
        if (isRestore) AnalyticsParameterNames.isConverted: isConverted,
      },
    );
  }

  void logWalletAddSyncCompleted(AnalyticsWalletType walletType) {
    logEvent(
      eventName: AnalyticsEventNames.walletAddSyncCompleted,
      parameters: {AnalyticsParameterNames.walletType: walletType.name},
    );
  }

  void logWalletAddSyncFailed(AnalyticsWalletType walletType) {
    logEvent(
      eventName: AnalyticsEventNames.walletAddSyncFailed,
      parameters: {AnalyticsParameterNames.walletType: walletType.name},
    );
  }

  String _hotWalletAction(bool isRestore) =>
      isRestore ? AnalyticsParameterValues.restore : AnalyticsParameterValues.create;
}
