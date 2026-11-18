import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';

/// 거래 줄 둘째 줄에 붙는 경로, 실패면 뒤에 "실패"
String arkMovementRouteLabel(ArkMovement movement) {
  final route = switch (movement.kind) {
    ArkMovementKind.lightningSend || ArkMovementKind.lightningReceive => t.ark_wallet.route_lightning,
    ArkMovementKind.refresh => t.ark_wallet.route_refresh,
    _ => t.ark_wallet.route_ark,
  };
  return movement.isFailed ? '$route · ${t.ark_wallet.failed}' : route;
}

/// 코코넛 최근 거래 줄에 맞춘 모양. 지갑 이름 자리에 경로를 둠
HomeRecentTransaction arkMovementAsRecent(ArkMovement movement) => HomeRecentTransaction(
  walletId: 0,
  walletName: arkMovementRouteLabel(movement),
  amount: movement.effectiveBalanceSats,
  time: movement.timestamp,
  type: movement.isSend ? TransactionType.sent : TransactionType.received,
  status: movement.isPending ? (movement.isSend ? TransactionStatus.sending : TransactionStatus.receiving) : null,
  txHash: '${movement.id}',
);

/// 라이트닝 거래만 번개 아이콘, 나머지는 상태 아이콘
String? arkMovementIconPath(List<ArkMovement> movements, HomeRecentTransaction tx) {
  final movement = movements.where((movement) => '${movement.id}' == tx.txHash).firstOrNull;
  return movement != null && movement.isLightning ? FeatureTransactionIconPath.txLightning : null;
}
