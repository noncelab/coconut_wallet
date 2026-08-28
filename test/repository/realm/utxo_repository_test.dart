import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/transaction_mock.dart';
import '../../mock/utxo_mock.dart';
import '../../mock/wallet_mock.dart';
import 'test_realm_manager.dart';

void main() {
  late TestRealmManager realmManager;
  late UtxoRepository utxoRepository;
  SinglesigWalletItem testWalletItem = WalletMock.createSingleSigWalletItem();
  const int testWalletId = 1;

  setUp(() async {
    realmManager = await setupTestRealmManager();
    utxoRepository = UtxoRepository(realmManager);
  });

  tearDown(() {
    realmManager.reset();
    realmManager.dispose();
  });

  group('UtxoRepository 기능 테스트', () {
    final testAddress = testWalletItem.walletBase.getAddress(0);
    final toAddress = testWalletItem.walletBase.getAddress(9999);
    group('UTXO 태그 제한 테스트', () {
      test('단건 태그 추가는 UTXO당 최대 5개까지만 허용한다', () async {
        const utxoId = 'tx_hash_0';

        for (var i = 0; i < 5; i++) {
          final result = await utxoRepository.addUtxoToTag(testWalletId, 'tag-$i', utxoId, colorIndex: i);
          expect(result.isSuccess, isTrue);
        }

        final overflowResult = await utxoRepository.addUtxoToTag(testWalletId, 'tag-overflow', utxoId, colorIndex: 6);

        expect(overflowResult.isSuccess, isTrue);
        final tags = utxoRepository.getUtxoTagsByTxHash(testWalletId, utxoId);
        expect(tags.isSuccess, isTrue);
        expect(tags.value.length, 5);
        expect(tags.value.map((tag) => tag.name), isNot(contains('tag-overflow')));
      });

      test('batch 태그 추가도 UTXO당 최대 5개까지만 허용한다', () async {
        const utxoId = 'tx_hash_1';

        for (var i = 0; i < 4; i++) {
          final result = await utxoRepository.addUtxoToTag(testWalletId, 'existing-tag-$i', utxoId, colorIndex: i);
          expect(result.isSuccess, isTrue);
        }

        final result = await utxoRepository.addUtxosToTags(testWalletId, {
          utxoId: {
            (tag: 'imported-tag-1', colorIndex: 4),
            (tag: 'imported-tag-2', colorIndex: 5),
            (tag: 'imported-tag-3', colorIndex: 6),
          },
        });

        expect(result.isSuccess, isTrue);
        final tags = utxoRepository.getUtxoTagsByTxHash(testWalletId, utxoId);
        expect(tags.isSuccess, isTrue);
        expect(tags.value.length, 5);
        expect(tags.value.map((tag) => tag.name), contains('imported-tag-1'));
        expect(tags.value.map((tag) => tag.name), isNot(contains('imported-tag-2')));
        expect(tags.value.map((tag) => tag.name), isNot(contains('imported-tag-3')));
      });

      test('가져온 태그 colorIndex는 앱 팔레트 범위로 정규화한다', () async {
        const utxoId = 'tx_hash_2';

        final result = await utxoRepository.addUtxosToTags(testWalletId, {
          utxoId: {(tag: 'invalid-high-color', colorIndex: 11), (tag: 'invalid-low-color', colorIndex: -1)},
        });

        expect(result.isSuccess, isTrue);
        final tags = utxoRepository.getUtxoTagsByTxHash(testWalletId, utxoId);
        expect(tags.isSuccess, isTrue);
        expect(tags.value.map((tag) => tag.colorIndex), everyElement(inInclusiveRange(0, 9)));
      });
    });

    group('updateUtxoStatusToOutgoingByTransaction 테스트', () {
      test('기본 UTXO 상태 업데이트가 정상적으로 이루어지는지 확인', () async {
        // Given
        final mockTx = TransactionMock.createMockTransaction(toAddress: testAddress, amount: 1000000);

        realmManager.realm.write(() {
          final utxo = UtxoMock.createUnspentRealmUtxo(
            walletId: testWalletId,
            address: testAddress,
            amount: 1000000,
            transactionHash: mockTx.inputs[0].transactionHash,
            index: mockTx.inputs[0].index,
          );
          realmManager.realm.add(utxo);
        });

        // When
        await utxoRepository.markUtxoAsOutgoing(testWalletId, mockTx);

        // Then
        final utxoId = getUtxoId(mockTx.inputs[0].transactionHash, mockTx.inputs[0].index);
        final updatedUtxo = utxoRepository.getUtxoState(testWalletId, utxoId);

        expect(updatedUtxo, isNotNull);
        expect(updatedUtxo!.status, equals(UtxoStatus.outgoing));
        expect(updatedUtxo.spentByTransactionHash, equals(mockTx.transactionHash));
      });

      test('자기 참조 UTXO는 업데이트되지 않아야 함', () async {
        // Given
        final mockTx = TransactionMock.createMockTransaction(toAddress: testAddress, amount: 1000000);

        // 이미 자기 참조 상태인 UTXO 추가
        realmManager.realm.write(() {
          final utxo = UtxoMock.createRbfableUtxo(
            walletId: testWalletId,
            address: testAddress,
            amount: 1000000,
            transactionHash: mockTx.inputs[0].transactionHash,
            index: mockTx.inputs[0].index,
            spentByTransactionHash: mockTx.transactionHash, // 자기 참조 설정
          );
          realmManager.realm.add(utxo);
        });

        // When
        await utxoRepository.markUtxoAsOutgoing(testWalletId, mockTx);

        // Then
        final utxoId = getUtxoId(mockTx.inputs[0].transactionHash, mockTx.inputs[0].index);
        final updatedUtxo = utxoRepository.getUtxoState(testWalletId, utxoId);

        expect(updatedUtxo, isNotNull);
        expect(updatedUtxo!.status, equals(UtxoStatus.outgoing));
        expect(updatedUtxo.spentByTransactionHash, equals(mockTx.transactionHash));
      });

      test('이미 outgoing 상태인 UTXO의 기존 spentByTransactionHash가 유지되어야 함', () async {
        // Given
        final mockTx = TransactionMock.createMockTransaction(toAddress: toAddress, amount: 1000000);

        const previousTxHash = 'previous_tx_hash';

        // 이미 outgoing 상태이고 다른 트랜잭션에 의해 사용 중인 UTXO 추가
        realmManager.realm.write(() {
          final utxo = UtxoMock.createRbfableUtxo(
            walletId: testWalletId,
            address: testAddress,
            amount: 1000000,
            transactionHash: mockTx.inputs[0].transactionHash,
            index: mockTx.inputs[0].index,
            spentByTransactionHash: previousTxHash, // 이전 트랜잭션 설정
          );
          realmManager.realm.add(utxo);
        });

        // When
        await utxoRepository.markUtxoAsOutgoing(testWalletId, mockTx);

        // Then
        final utxoId = getUtxoId(mockTx.inputs[0].transactionHash, mockTx.inputs[0].index);
        final updatedUtxo = utxoRepository.getUtxoState(testWalletId, utxoId);

        expect(updatedUtxo, isNotNull);
        expect(updatedUtxo!.status, equals(UtxoStatus.outgoing));
        expect(updatedUtxo.spentByTransactionHash, equals(mockTx.transactionHash));
        expect(updatedUtxo.spentByTransactionHash, isNot(equals(previousTxHash)));
      });
    });

    group('snapshotLockedUtxoIds / restoreLockedUtxos 테스트', () {
      test('잠긴 UTXO id만 정확히 스냅샷됨', () async {
        realmManager.realm.write(() {
          realmManager.realm.add(
            UtxoMock.createMockUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: 'locked_tx_hash',
              status: UtxoStatus.locked,
            ),
          );
          realmManager.realm.add(
            UtxoMock.createUnspentRealmUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: 'unspent_tx_hash',
            ),
          );
        });

        final snapshot = utxoRepository.snapshotLockedUtxoIds(testWalletId);

        expect(snapshot, {getUtxoId('locked_tx_hash', 0)});
      });

      test('스냅샷 후 재발견된(unspent) UTXO만 다시 locked로 복원됨', () async {
        final lockedUtxoIds = {
          getUtxoId('reappeared_unspent_tx_hash', 0),
          getUtxoId('not_reappeared_tx_hash', 0),
        };

        realmManager.realm.write(() {
          // resync 이후 재동기화로 다시 unspent로 발견된 UTXO
          realmManager.realm.add(
            UtxoMock.createUnspentRealmUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: 'reappeared_unspent_tx_hash',
            ),
          );
          // not_reappeared_tx_hash는 재동기화로 아예 재발견되지 않았다고 가정(row 없음)
        });

        await utxoRepository.restoreLockedUtxos(testWalletId, lockedUtxoIds);

        final restored = utxoRepository.getUtxoState(testWalletId, getUtxoId('reappeared_unspent_tx_hash', 0));
        expect(restored!.status, UtxoStatus.locked);
      });

      test('스냅샷에 있어도 outgoing/incoming으로 재동기화된 UTXO는 강제로 잠그지 않음', () async {
        final lockedUtxoIds = {getUtxoId('now_outgoing_tx_hash', 0)};

        realmManager.realm.write(() {
          realmManager.realm.add(
            UtxoMock.createOutgoingRealmUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: 'now_outgoing_tx_hash',
            ),
          );
        });

        await utxoRepository.restoreLockedUtxos(testWalletId, lockedUtxoIds);

        final utxo = utxoRepository.getUtxoState(testWalletId, getUtxoId('now_outgoing_tx_hash', 0));
        expect(utxo!.status, UtxoStatus.outgoing);
      });

      test('빈 스냅샷은 아무 것도 하지 않음', () async {
        realmManager.realm.write(() {
          realmManager.realm.add(
            UtxoMock.createUnspentRealmUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: 'unspent_tx_hash',
            ),
          );
        });

        await utxoRepository.restoreLockedUtxos(testWalletId, {});

        final utxo = utxoRepository.getUtxoState(testWalletId, getUtxoId('unspent_tx_hash', 0));
        expect(utxo!.status, UtxoStatus.unspent);
      });
    });
  });
}
