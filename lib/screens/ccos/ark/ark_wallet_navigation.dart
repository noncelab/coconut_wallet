import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_activity_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_movement_detail_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_receive_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_send_screen.dart';
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

  /// 확정 잔액이 가장 많은 지갑
  static int defaultFillWalletId(WalletProvider wallets, List<int> candidates) =>
      ([...candidates]
        ..sort((a, b) => wallets.getWalletBalance(b).confirmed.compareTo(wallets.getWalletBalance(a).confirmed))).first;

  /// 고르는 시트 없이 바로 열고, 보내는 지갑은 화면에서 바꿈
  Future<void> openFill() async {
    final wallets = context.read<WalletProvider>();
    final candidates = fillWalletIds(wallets);
    if (candidates.isEmpty) {
      CoconutToast.showToast(context: context, text: t.ark_wallet.no_hot_wallet, isVisibleIcon: true);
      return;
    }
    await ArkFillScreen.open(context, defaultFillWalletId(wallets, candidates));
  }

  /// 바로 열고, 받는 주소는 화면에서 직접 넣거나 내 지갑 주소에서 고름
  Future<void> openExport() => ArkExportScreen.open(context);
}

/// 코코넛 지갑 고르기(보내기와 같은 시트). 하나뿐이면 바로 그 지갑
Future<int?> pickCoconutWallet(
  BuildContext context,
  List<int> candidates,
  String screenName, {
  String? title,
  Set<int> disabled = const {},
}) {
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
      disabledWalletIds: disabled,
      balanceMode: BalanceMode.onlyUnspent,
      onWalletChanged: (id) => Navigator.pop(context, id),
    ),
  );
}
