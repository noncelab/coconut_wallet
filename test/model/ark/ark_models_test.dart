import 'package:coconut_wallet/model/ark/ark_balance.dart';
import 'package:coconut_wallet/model/ark/ark_movement.dart';
import 'package:coconut_wallet/model/ark/ark_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/ark/ark_fixtures.dart';

void main() {
  group('ArkBalance', () {
    test('total adds spendable and every pending field', () {
      const balance = ArkBalance(
        spendable: 1000,
        pendingInRound: 200,
        pendingBoard: 30,
        pendingExit: 4,
        pendingLightningSend: 5000,
        claimableLightningReceive: 60000,
      );

      expect(balance.pending, 65234);
      expect(balance.total, 66234);
      expect(ArkBalance.zero.total, 0);
    });
  });

  group('ArkMovement', () {
    test('kind follows bark subsystem name and kind', () {
      expect(createArkMovement(subsystemName: 'bark.arkoor', subsystemKind: 'send').kind, ArkMovementKind.arkSend);
      expect(
        createArkMovement(subsystemName: 'bark.arkoor', subsystemKind: 'receive').kind,
        ArkMovementKind.arkReceive,
      );
      expect(createArkMovement(subsystemName: 'bark.lightning_send').kind, ArkMovementKind.lightningSend);
      expect(createArkMovement(subsystemName: 'bark.lightning_receive').kind, ArkMovementKind.lightningReceive);
      expect(createArkMovement(subsystemName: 'bark.board', subsystemKind: 'board').kind, ArkMovementKind.board);
      expect(
        createArkMovement(subsystemName: 'bark.offboard', subsystemKind: 'offboard').kind,
        ArkMovementKind.offboard,
      );
      expect(
        createArkMovement(subsystemName: 'bark.offboard', subsystemKind: 'send_onchain').kind,
        ArkMovementKind.sendOnchain,
      );
      expect(createArkMovement(subsystemName: 'bark.round', subsystemKind: 'refresh').kind, ArkMovementKind.refresh);
      expect(createArkMovement(subsystemName: 'bark.exit', subsystemKind: 'start').kind, ArkMovementKind.exit);
      expect(createArkMovement(subsystemName: 'something.else').kind, ArkMovementKind.other);
    });

    test('linkedTxid reads the board outpoint or the offboard txid from metadata', () {
      final txid = 'a' * 64;
      expect(createArkMovement(metadataJson: '{"chain_anchor":"$txid:1","onchain_fee_sat":150}').linkedTxid, txid);
      expect(createArkMovement(metadataJson: '{"offboard_txid":"$txid"}').linkedTxid, txid);
      expect(createArkMovement(metadataJson: '{}').linkedTxid, isNull);
      expect(createArkMovement(metadataJson: 'not json').linkedTxid, isNull);
    });

    test('destinations decode bark payment methods', () {
      final movement = createArkMovement(
        receivedOn: ['{"type":"ark","value":"$arkAddress"}', 'garbage'],
        sentTo: ['{"type":"invoice","value":"lnbcrt1"}'],
      );

      expect(movement.receivedOnDestinations.first.type, 'ark');
      expect(movement.receivedOnDestinations.first.value, arkAddress);
      expect(movement.receivedOnDestinations.last.type, 'unknown');
      expect(movement.receivedOnDestinations.last.value, 'garbage');
      expect(movement.sentToDestinations.single.type, 'invoice');
    });

    test('failed or canceled movements without a balance change are hidden from history', () {
      expect(
        createArkMovement(status: ArkMovementStatus.canceled, effectiveBalanceSats: 0).isVisibleInHistory,
        isFalse,
      );
      expect(createArkMovement(status: ArkMovementStatus.failed, effectiveBalanceSats: 0).isVisibleInHistory, isFalse);
      expect(createArkMovement(status: ArkMovementStatus.failed, effectiveBalanceSats: -10).isVisibleInHistory, isTrue);
      expect(createArkMovement(status: ArkMovementStatus.pending, effectiveBalanceSats: 0).isVisibleInHistory, isTrue);
      // A Lightning send the server refused to start: bark leaves it pending with nothing locked.
      expect(
        createArkMovement(
          subsystemName: 'bark.lightning_send',
          subsystemKind: 'send',
          status: ArkMovementStatus.pending,
          effectiveBalanceSats: 0,
        ).isVisibleInHistory,
        isFalse,
      );
      expect(
        createArkMovement(
          subsystemName: 'bark.lightning_send',
          subsystemKind: 'send',
          status: ArkMovementStatus.pending,
          effectiveBalanceSats: -12048,
        ).isVisibleInHistory,
        isTrue,
      );
    });

    test('timestamp prefers the completion time', () {
      final created = DateTime.utc(2026, 10, 19, 10);
      final completed = DateTime.utc(2026, 10, 19, 11);
      expect(createArkMovement(createdAt: created, completedAt: completed).timestamp, completed);
      expect(createArkMovement(createdAt: created, status: ArkMovementStatus.pending).timestamp, created);
    });
  });

  group('ArkSnapshot', () {
    test('hasSameContent ignores the sync time', () {
      final a = createArkSnapshot();
      final b = ArkSnapshot(
        balance: a.balance,
        vtxos: a.vtxos,
        movements: a.movements,
        recovery: a.recovery,
        syncedAt: DateTime.utc(2030),
        address: a.address,
        addressIndex: a.addressIndex,
      );

      expect(a.hasSameContent(b), isTrue);
      expect(a.hasSameContent(createArkSnapshot(address: 'tark1other')), isFalse);
      expect(a.hasSameContent(createArkSnapshot(vtxos: [createArkVtxo(isLocked: true)])), isFalse);
    });

    test('recovery can be retried only while the Ark wallet is unused', () {
      expect(createArkSnapshot(balance: ArkBalance.zero, vtxos: [], movements: []).canRetryRecovery, isTrue);
      expect(createArkSnapshot(balance: ArkBalance.zero, vtxos: []).canRetryRecovery, isFalse);
      expect(
        createArkSnapshot(
          balance: ArkBalance.zero,
          vtxos: [],
          movements: [],
          recovery: const ArkRecovery(ArkRecoveryState.completed, 'done'),
        ).canRetryRecovery,
        isFalse,
      );
    });
  });
}
