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
      parameters: {AnalyticsParameterNames.addMethod: _addMethod(isRestore)},
    );
  }

  void logWalletAddButtonClicked({WalletAddEntrySource? entrySource}) {
    logEvent(
      eventName: AnalyticsEventNames.walletAddButtonClicked,
      parameters: {if (entrySource != null) AnalyticsParameterNames.source: entrySource.name},
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

  void logHotWalletAddCompleted({required bool isRestore}) {
    logEvent(
      eventName: AnalyticsEventNames.walletAddCompleted,
      parameters: {
        AnalyticsParameterNames.walletType: AnalyticsWalletType.hotWallet.name,
        AnalyticsParameterNames.addMethod: _addMethod(isRestore),
      },
    );
  }

  void logWalletAddSyncCompleted(AnalyticsWalletType walletType, {bool? hasHistory}) {
    logEvent(
      eventName: AnalyticsEventNames.walletAddSyncCompleted,
      parameters: {
        AnalyticsParameterNames.walletType: walletType.name,
        if (hasHistory != null) AnalyticsParameterNames.hasHistory: hasHistory,
      },
    );
  }

  void logWalletAddSyncFailed(AnalyticsWalletType walletType) {
    logEvent(
      eventName: AnalyticsEventNames.walletAddSyncFailed,
      parameters: {AnalyticsParameterNames.walletType: walletType.name},
    );
  }

  String _addMethod(bool isRestore) => isRestore ? AnalyticsParameterValues.restore : AnalyticsParameterValues.create;
}
