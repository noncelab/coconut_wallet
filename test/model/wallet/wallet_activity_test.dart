import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/transaction_enums.dart';
import 'package:coconut_wallet/model/ark/ark_movement.dart';
import 'package:coconut_wallet/model/wallet/wallet_activity.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/ark/ark_fixtures.dart';
import '../../mock/transaction_record_mock.dart';

void main() {
  DateTime at(int hour) => DateTime.utc(2026, 10, 19, hour);

  test('merge lists pending entries first, then newest first, across both histories', () {
    final transactions = [
      TransactionRecordMock.createMockTransactionRecord(
        transactionHash: 'confirmed-10h',
        timestamp: at(10),
        blockHeight: 100,
        inputAddressList: const [],
        outputAddressList: const [],
      ),
      TransactionRecordMock.createMockTransactionRecord(
        transactionHash: 'pending-onchain',
        blockHeight: 0,
        createdAt: at(9),
        inputAddressList: const [],
        outputAddressList: const [],
      ),
    ];
    final movements = [
      createArkMovement(id: 1, createdAt: at(12)),
      createArkMovement(id: 2, createdAt: at(8)),
      createArkMovement(id: 3, createdAt: at(11), status: ArkMovementStatus.pending),
      createArkMovement(id: 4, createdAt: at(13), status: ArkMovementStatus.canceled, effectiveBalanceSats: 0),
    ];

    final merged = WalletActivity.merge(transactions, movements);

    expect(merged.map((activity) => activity.key), ['ark:3', 'pending-onchain', 'ark:1', 'confirmed-10h', 'ark:2']);
  });

  test('Ark movements map to the transaction statuses rows already show', () {
    expect(ArkActivity(createArkMovement(effectiveBalanceSats: 1000)).status, TransactionStatus.received);
    expect(
      ArkActivity(createArkMovement(effectiveBalanceSats: 1000, status: ArkMovementStatus.pending)).status,
      TransactionStatus.receiving,
    );
    expect(
      ArkActivity(
        createArkMovement(subsystemName: 'bark.arkoor', subsystemKind: 'send', effectiveBalanceSats: -1000),
      ).status,
      TransactionStatus.sent,
    );
    final refresh = ArkActivity(
      createArkMovement(subsystemName: 'bark.round', subsystemKind: 'refresh', effectiveBalanceSats: -50),
    );
    expect(refresh.status, TransactionStatus.self);
    expect(refresh.label, ArkActivityLabel.refresh);
    expect(ArkActivity(createArkMovement(subsystemName: 'bark.lightning_receive')).rail, ArkRail.lightning);
  });

  test('equality follows the key and content, so unchanged lists diff as equal', () {
    final movement = createArkMovement(id: 5);
    expect(ArkActivity(movement), ArkActivity(movement));
    expect(ArkActivity(movement) == ArkActivity(createArkMovement(id: 5, status: ArkMovementStatus.pending)), isFalse);
    final tx = TransactionRecordMock.createMockTransactionRecord(
      transactionType: TransactionType.received,
      inputAddressList: const [],
      outputAddressList: const [],
    );
    expect(OnchainActivity(tx), OnchainActivity(tx));
  });

  group('moves between on-chain and Ark', () {
    final fundingTxid = 'f' * 64;
    final offboardTxid = 'e' * 64;

    test('a board and its funding transaction are one entry', () {
      final funding = TransactionRecordMock.createMockTransactionRecord(
        transactionHash: fundingTxid,
        timestamp: at(10),
        blockHeight: 120,
        transactionType: TransactionType.sent,
        amount: -100300,
        inputAddressList: const [],
        outputAddressList: const [],
      );
      final board = createArkMovement(
        id: 9,
        subsystemName: 'bark.board',
        subsystemKind: 'board',
        effectiveBalanceSats: 99800,
        metadataJson: '{"chain_anchor":"$fundingTxid:0"}',
        createdAt: at(10),
      );

      final merged = WalletActivity.merge([funding], [board]);

      expect(merged, hasLength(1));
      final move = merged.single as ArkActivity;
      expect(move.isMove, isTrue);
      expect(move.linkedTx, same(funding));
      expect(move.amount, -500); // the on-chain fee and the board fee
      expect(move.displayAmount, 99800); // what arrived in Ark
      expect(move.status, TransactionStatus.self);
      expect(move.label, ArkActivityLabel.movedToArk);
    });

    test('a move is pending until its on-chain transaction confirms', () {
      final funding = TransactionRecordMock.createMockTransactionRecord(
        transactionHash: fundingTxid,
        blockHeight: 0,
        amount: -100300,
        inputAddressList: const [],
        outputAddressList: const [],
      );
      final board = createArkMovement(
        subsystemName: 'bark.board',
        subsystemKind: 'board',
        effectiveBalanceSats: 99800,
        metadataJson: '{"chain_anchor":"$fundingTxid:0"}',
      );

      final move = WalletActivity.merge([funding], [board]).single as ArkActivity;

      expect(move.isPending, isTrue);
      expect(move.status, TransactionStatus.selfsending);
    });

    test('an on-chain payment from Ark to this wallet pairs with its receive', () {
      final receive = TransactionRecordMock.createMockTransactionRecord(
        transactionHash: offboardTxid,
        timestamp: at(11),
        blockHeight: 121,
        transactionType: TransactionType.received,
        amount: 30000,
        inputAddressList: const [],
        outputAddressList: const [],
      );
      final send = createArkMovement(
        subsystemName: 'bark.offboard',
        subsystemKind: 'send_onchain',
        effectiveBalanceSats: -30400,
        metadataJson: '{"offboard_txid":"$offboardTxid"}',
      );

      final move = WalletActivity.merge([receive], [send]).single as ArkActivity;

      expect(move.amount, -400);
      expect(move.displayAmount, 30000);
      expect(move.label, ArkActivityLabel.movedOnchain);
    });

    test('an offboard to another wallet stays a send', () {
      final send = createArkMovement(
        subsystemName: 'bark.offboard',
        subsystemKind: 'offboard',
        effectiveBalanceSats: -50000,
        metadataJson: '{"offboard_txid":"$offboardTxid"}',
      );

      final activity = WalletActivity.merge([], [send]).single as ArkActivity;

      expect(activity.isMove, isFalse);
      expect(activity.status, TransactionStatus.sent);
      expect(activity.label, isNull);
      expect(activity.rail, ArkRail.onchain);
      expect(activity.displayAmount, -50000);
    });
  });
}
