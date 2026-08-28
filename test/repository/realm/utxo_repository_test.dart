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
  });
}
