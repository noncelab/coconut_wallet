import 'package:coconut_wallet/model/ark/ark_balance.dart';
import 'package:coconut_wallet/model/ark/ark_movement.dart';
import 'package:coconut_wallet/model/ark/ark_snapshot.dart';
import 'package:coconut_wallet/model/ark/ark_vtxo.dart';

const arkAddress = 'tark1pwh9vsmezqqpjy9akejayl2vvcse6he97rn40g84xrlvrlnhayuuyefrp9nse2y3zqqpj';

ArkVtxo createArkVtxo({String id = 'vtxo1:0', int amountSats = 50000, int expiryHeight = 5000, bool isLocked = false}) {
  return ArkVtxo(
    id: id,
    amountSats: amountSats,
    expiryHeight: expiryHeight,
    kind: 'Pubkey',
    isLocked: isLocked,
    exitDepth: 1,
  );
}

ArkMovement createArkMovement({
  int id = 1,
  String subsystemName = 'bark.arkoor',
  String subsystemKind = 'receive',
  ArkMovementStatus status = ArkMovementStatus.successful,
  int effectiveBalanceSats = 50000,
  int offchainFeeSats = 0,
  String metadataJson = '{}',
  List<String> receivedOn = const [],
  List<String> sentTo = const [],
  DateTime? createdAt,
  DateTime? completedAt,
  String? paymentHash,
  String? lightningInvoice,
}) {
  final created = createdAt ?? DateTime.utc(2026, 10, 19, 12);
  return ArkMovement(
    id: id,
    status: status,
    subsystemName: subsystemName,
    subsystemKind: subsystemKind,
    metadataJson: metadataJson,
    intendedBalanceSats: effectiveBalanceSats + offchainFeeSats,
    effectiveBalanceSats: effectiveBalanceSats,
    offchainFeeSats: offchainFeeSats,
    sentTo: sentTo,
    receivedOn: receivedOn,
    inputVtxoIds: const [],
    outputVtxoIds: const ['vtxo1:0'],
    exitedVtxoIds: const [],
    createdAt: created,
    updatedAt: completedAt ?? created,
    completedAt: completedAt ?? (status == ArkMovementStatus.pending ? null : created),
    paymentHash: paymentHash,
    lightningInvoice: lightningInvoice,
  );
}

ArkSnapshot createArkSnapshot({
  ArkBalance balance = const ArkBalance(
    spendable: 50000,
    pendingInRound: 0,
    pendingBoard: 0,
    pendingExit: 0,
    pendingLightningSend: 0,
    claimableLightningReceive: 0,
  ),
  List<ArkVtxo>? vtxos,
  List<ArkMovement>? movements,
  ArkRecovery recovery = ArkRecovery.notRun,
  String? address = arkAddress,
  int? addressIndex = 0,
}) {
  return ArkSnapshot(
    balance: balance,
    vtxos: vtxos ?? [createArkVtxo()],
    movements: movements ?? [createArkMovement()],
    recovery: recovery,
    syncedAt: DateTime.utc(2026, 10, 19, 12, 30),
    address: address,
    addressIndex: addressIndex,
  );
}
