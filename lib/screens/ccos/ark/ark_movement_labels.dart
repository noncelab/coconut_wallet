import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';

/// 거래 내역 필터 칩, 갱신은 아크에 포함
enum ArkActivityRail { all, onchain, ark, lightning }

ArkActivityRail arkMovementRail(ArkMovement movement) => switch (movement.kind) {
  ArkMovementKind.lightningSend || ArkMovementKind.lightningReceive => ArkActivityRail.lightning,
  ArkMovementKind.board ||
  ArkMovementKind.offboard ||
  ArkMovementKind.sendOnchain ||
  ArkMovementKind.exit => ArkActivityRail.onchain,
  _ => ArkActivityRail.ark,
};

/// 거래 줄 둘째 줄에 붙는 경로, 실패면 뒤에 "실패"
String arkMovementRouteLabel(ArkMovement movement) {
  final route = switch (movement.kind) {
    ArkMovementKind.lightningSend || ArkMovementKind.lightningReceive => t.ark_wallet.route_lightning,
    ArkMovementKind.refresh => t.ark_wallet.route_refresh,
    ArkMovementKind.board ||
    ArkMovementKind.offboard ||
    ArkMovementKind.sendOnchain ||
    ArkMovementKind.exit => t.ark_wallet.route_onchain,
    _ => t.ark_wallet.route_ark,
  };
  return movement.isFailed ? '$route · ${t.ark_wallet.failed}' : route;
}

/// 코코넛 최근 거래 줄에 맞춘 모양. 경로는 시각 옆([arkMovementRouteLabel]), 지갑 이름 자리에는 메모
HomeRecentTransaction arkMovementAsRecent(ArkMovement movement, {String? memo}) => HomeRecentTransaction(
  walletId: 0,
  walletName: memo ?? '',
  amount: movement.effectiveBalanceSats,
  time: movement.timestamp,
  type:
      movement.kind == ArkMovementKind.refresh
          ? TransactionType.self
          : movement.isSend
          ? TransactionType.sent
          : TransactionType.received,
  status:
      movement.kind == ArkMovementKind.refresh
          ? (movement.isPending ? TransactionStatus.selfsending : TransactionStatus.self)
          : movement.isPending
          ? (movement.isSend ? TransactionStatus.sending : TransactionStatus.receiving)
          : null,
  txHash: '${movement.id}',
);

/// 상태 아이콘, 라이트닝 거래는 가운데만 번개, 채우기는 +, 내보내기·출금은 −, 갱신은 내 지갑 안 이동. 원 채움 진하기는 상태끼리 같음
String? arkMovementIconPath(List<ArkMovement> movements, HomeRecentTransaction tx) {
  final movement = movements.where((movement) => '${movement.id}' == tx.txHash).firstOrNull;
  if (movement == null) return null;
  if (movement.kind == ArkMovementKind.refresh) {
    return movement.isPending ? FeatureArkIconPath.txRenewing : FeatureArkIconPath.txRenewed;
  }
  if (arkMovementRail(movement) == ArkActivityRail.onchain) {
    return movement.kind == ArkMovementKind.board
        ? (movement.isPending ? FeatureArkIconPath.txFilling : FeatureArkIconPath.txFilled)
        : (movement.isPending ? FeatureArkIconPath.txExporting : FeatureArkIconPath.txExported);
  }
  final lightning = movement.isLightning;
  return switch ((movement.isSend, movement.isPending)) {
    (true, true) => lightning ? FeatureArkIconPath.txLightningSending : FeatureArkIconPath.txSending,
    (true, false) => lightning ? FeatureArkIconPath.txLightningSent : FeatureArkIconPath.txSent,
    (false, true) => lightning ? FeatureArkIconPath.txLightningReceiving : FeatureArkIconPath.txReceiving,
    (false, false) => lightning ? FeatureArkIconPath.txLightningReceived : FeatureArkIconPath.txReceived,
  };
}

/// 시각 옆에 붙일 경로
String? arkMovementTimeDetail(List<ArkMovement> movements, HomeRecentTransaction tx) {
  final movement = movements.where((movement) => '${movement.id}' == tx.txHash).firstOrNull;
  return movement == null ? null : arkMovementRouteLabel(movement);
}

/// 거래 줄·상세의 상태 이름. 출금·채우기·내보내기는 한 일을 이름으로(feat/ark의 arkActivityText), 나머지는 null로 기본 상태 이름
String? arkMovementStatusText(ArkMovement movement) => switch (movement.kind) {
  ArkMovementKind.exit =>
    movement.isFailed
        ? t.ark_wallet.activity_exit_failed
        : movement.isPending
        ? t.ark_wallet.activity_exit_pending
        : t.ark_wallet.activity_exit_done,
  ArkMovementKind.refresh =>
    movement.isFailed
        ? t.ark_wallet.activity_renew_failed
        : movement.isPending
        ? t.ark_wallet.activity_renew_pending
        : t.ark_wallet.activity_renew_done,
  ArkMovementKind.board => movement.isPending ? t.ark_wallet.activity_fill_pending : t.ark_wallet.activity_fill_done,
  ArkMovementKind.offboard || ArkMovementKind.sendOnchain =>
    movement.isPending ? t.ark_wallet.activity_export_pending : t.ark_wallet.activity_export_done,
  _ => null,
};

/// 거래 줄의 상태 이름, 목록의 거래를 찾아 [arkMovementStatusText]
String? arkMovementStatusTextOf(List<ArkMovement> movements, HomeRecentTransaction tx) {
  final movement = movements.where((movement) => '${movement.id}' == tx.txHash).firstOrNull;
  return movement == null ? null : arkMovementStatusText(movement);
}
