import 'package:coconut_wallet/model/ark/ark_balance.dart';
import 'package:coconut_wallet/model/ark/ark_movement.dart';
import 'package:coconut_wallet/model/ark/ark_vtxo.dart';

enum ArkRecoveryState { notRun, failed, completed }

/// What bark's seed recovery did when the Ark wallet's database was created.
class ArkRecovery {
  const ArkRecovery(this.state, this.description);

  static const notRun = ArkRecovery(
    ArkRecoveryState.notRun,
    'Not run (new wallet, or the Ark server was unreachable).',
  );

  /// 복원할 때 돌린 복구가 끝나지 않았음(서버에 닿지 못했거나 실패), 앱을 다시 켠 뒤
  static const pending = ArkRecovery(ArkRecoveryState.failed, 'Did not complete when the wallet was restored.');

  final ArkRecoveryState state;
  final String description;
}

/// Everything Coconut caches about a hot wallet's Ark wallet, as of [syncedAt].
class ArkSnapshot {
  const ArkSnapshot({
    required this.balance,
    required this.vtxos,
    required this.movements,
    required this.recovery,
    required this.syncedAt,
    this.address,
    this.addressIndex,
  });

  final ArkBalance balance;
  final List<ArkVtxo> vtxos;
  final List<ArkMovement> movements;
  final ArkRecovery recovery;
  final DateTime? syncedAt;

  /// The Ark address the receive screen shows, until something is received on it.
  final String? address;
  final int? addressIndex;

  /// Seed recovery can be retried while the Ark wallet has never been used: recreating it then
  /// loses nothing.
  bool get canRetryRecovery =>
      recovery.state != ArkRecoveryState.completed && movements.isEmpty && vtxos.isEmpty && balance.total == 0;

  /// 복원할 때 이전 아크 잔액을 찾지 못해 다시 찾아볼 수 있음
  bool get needsRecoveryRetry => recovery.state == ArkRecoveryState.failed && canRetryRecovery;

  /// Whether [other] would show the same thing, ignoring [syncedAt].
  bool hasSameContent(ArkSnapshot other) => _contentKey == other._contentKey;

  String get _contentKey => [
    balance.spendable,
    balance.pendingInRound,
    balance.pendingBoard,
    balance.pendingExit,
    balance.pendingLightningSend,
    balance.claimableLightningReceive,
    address,
    addressIndex,
    recovery.state.name,
    recovery.description,
    ...([
      for (final vtxo in vtxos) '${vtxo.id}/${vtxo.amountSats}/${vtxo.expiryHeight}/${vtxo.isLocked}/${vtxo.exitDepth}',
    ]..sort()),
    ...([
      for (final movement in movements)
        '${movement.id}/${movement.status.name}/${movement.effectiveBalanceSats}/${movement.updatedAt.microsecondsSinceEpoch}',
    ]..sort()),
  ].join('|');
}
