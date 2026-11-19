import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_activity_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_movement_detail_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_receive_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_send_screen.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_export_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_fill_screen.dart';
import 'package:coconut_wallet/screens/send/select_wallet_bottom_sheet.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// 아크 지갑 홈에서 여는 화면들
class ArkWalletNavigation {
  const ArkWalletNavigation(this.context);

  final BuildContext context;

  void openReceive() => ArkReceiveScreen.open(context);

  void openSend() => ArkSendScreen.open(context);

  void openActivity() => ArkActivityScreen.open(context);

  void openMovement(ArkMovement movement) => ArkMovementDetailScreen.open(context, movement);

  /// 서명할 수 있는 싱글시그 핫월렛
  static List<int> fillWalletIds(WalletProvider wallets) => [
    for (final wallet in wallets.walletItemList)
      if (wallet.hasLocalKey && wallet.walletType == WalletType.singleSignature) wallet.id,
  ];

  Future<void> openFill() async {
    final candidates = fillWalletIds(context.read<WalletProvider>());
    if (candidates.isEmpty) {
      CoconutToast.showToast(context: context, text: t.ark_wallet.no_hot_wallet, isVisibleIcon: true);
      return;
    }
    final walletId = await _pickWallet(
      candidates,
      AnalyticsScreenNames.ccosArkWalletFillWallet,
      t.ark_wallet.fill_from,
    );
    if (walletId != null && context.mounted) await ArkFillScreen.open(context, walletId);
  }

  /// 코코넛 지갑 어디로든(핫월렛, 볼트 등 보기 전용 포함). 지갑이 없으면 주소를 직접 넣음
  Future<void> openExport() async {
    final candidates = [for (final wallet in context.read<WalletProvider>().walletItemList) wallet.id];
    if (candidates.isEmpty) {
      await ArkExportScreen.open(context, null);
      return;
    }
    final walletId = await _pickWallet(
      candidates,
      AnalyticsScreenNames.ccosArkWalletExportWallet,
      t.ark_wallet.export_to,
    );
    if (walletId != null && context.mounted) await ArkExportScreen.open(context, walletId);
  }

  Future<int?> _pickWallet(List<int> candidates, String screenName, String title) =>
      pickCoconutWallet(context, candidates, screenName, title: title);
}

/// 코코넛 지갑 고르기(보내기와 같은 시트). 하나뿐이면 바로 그 지갑
Future<int?> pickCoconutWallet(BuildContext context, List<int> candidates, String screenName, {String? title}) {
  if (candidates.length == 1) return Future.value(candidates.single);
  return SelectWalletBottomSheet.show<int>(
    context: context,
    screenName: screenName,
    child: SelectWalletBottomSheet(
      showOnlyMfpWallets: false,
      currentUnit: context.read<ArkWalletProvider>().unit,
      walletId: -1,
      title: title,
      candidateWalletIds: candidates,
      balanceMode: BalanceMode.onlyUnspent,
      onWalletChanged: (id) => Navigator.pop(context, id),
    ),
  );
}
