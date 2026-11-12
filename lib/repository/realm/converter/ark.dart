import 'package:coconut_wallet/model/ark/ark_balance.dart';
import 'package:coconut_wallet/model/ark/ark_movement.dart';
import 'package:coconut_wallet/model/ark/ark_snapshot.dart';
import 'package:coconut_wallet/model/ark/ark_vtxo.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';

ArkBalance mapRealmToArkBalance(RealmArkWalletState state) => ArkBalance(
  spendable: state.spendableSats,
  pendingInRound: state.pendingInRoundSats,
  pendingBoard: state.pendingBoardSats,
  pendingExit: state.pendingExitSats,
  pendingLightningSend: state.pendingLightningSendSats,
  claimableLightningReceive: state.claimableLightningReceiveSats,
);

ArkRecovery mapRealmToArkRecovery(RealmArkWalletState state) => ArkRecovery(
  ArkRecoveryState.values.firstWhere(
    (value) => value.name == state.recoveryStateName,
    orElse: () => ArkRecoveryState.notRun,
  ),
  state.recoveryDescription,
);

RealmArkWalletState mapArkSnapshotToRealmState(int walletId, ArkSnapshot snapshot) => RealmArkWalletState(
  walletId,
  snapshot.balance.spendable,
  snapshot.balance.pendingInRound,
  snapshot.balance.pendingBoard,
  snapshot.balance.pendingExit,
  snapshot.balance.pendingLightningSend,
  snapshot.balance.claimableLightningReceive,
  snapshot.recovery.state.name,
  snapshot.recovery.description,
  address: snapshot.address,
  addressIndex: snapshot.addressIndex,
  lastSyncedAt: snapshot.syncedAt,
);

ArkVtxo mapRealmToArkVtxo(RealmArkVtxo vtxo) => ArkVtxo(
  id: vtxo.vtxoId,
  amountSats: vtxo.amountSats,
  expiryHeight: vtxo.expiryHeight,
  kind: vtxo.kind,
  isLocked: vtxo.isLocked,
  exitDepth: vtxo.exitDepth,
);

RealmArkVtxo mapArkVtxoToRealm(int walletId, ArkVtxo vtxo) => RealmArkVtxo(
  '$walletId:${vtxo.id}',
  walletId,
  vtxo.id,
  vtxo.amountSats,
  vtxo.expiryHeight,
  vtxo.kind,
  vtxo.isLocked,
  vtxo.exitDepth,
);

ArkMovement mapRealmToArkMovement(RealmArkMovement movement) => ArkMovement(
  id: movement.movementId,
  status: ArkMovementStatus.fromName(movement.status),
  subsystemName: movement.subsystemName,
  subsystemKind: movement.subsystemKind,
  metadataJson: movement.metadataJson,
  intendedBalanceSats: movement.intendedBalanceSats,
  effectiveBalanceSats: movement.effectiveBalanceSats,
  offchainFeeSats: movement.offchainFeeSats,
  sentTo: movement.sentTo.toList(),
  receivedOn: movement.receivedOn.toList(),
  inputVtxoIds: movement.inputVtxoIds.toList(),
  outputVtxoIds: movement.outputVtxoIds.toList(),
  exitedVtxoIds: movement.exitedVtxoIds.toList(),
  createdAt: movement.createdAt.toLocal(),
  updatedAt: movement.updatedAt.toLocal(),
  completedAt: movement.completedAt?.toLocal(),
  paymentHash: movement.paymentHash,
  lightningInvoice: movement.lightningInvoice,
  lightningOffer: movement.lightningOffer,
);

RealmArkMovement mapArkMovementToRealm(int walletId, ArkMovement movement) => RealmArkMovement(
  '$walletId:${movement.id}',
  walletId,
  movement.id,
  movement.status.name,
  movement.subsystemName,
  movement.subsystemKind,
  movement.metadataJson,
  movement.intendedBalanceSats,
  movement.effectiveBalanceSats,
  movement.offchainFeeSats,
  movement.createdAt.toUtc(),
  movement.updatedAt.toUtc(),
  sentTo: movement.sentTo,
  receivedOn: movement.receivedOn,
  inputVtxoIds: movement.inputVtxoIds,
  outputVtxoIds: movement.outputVtxoIds,
  exitedVtxoIds: movement.exitedVtxoIds,
  completedAt: movement.completedAt?.toUtc(),
  paymentHash: movement.paymentHash,
  lightningInvoice: movement.lightningInvoice,
  lightningOffer: movement.lightningOffer,
);
