import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/repository/realm/converter/utxo.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
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
  const lockedTxHash = '0000000000000000000000000000000000000000000000000000000000000031';
  const unspentTxHash = '0000000000000000000000000000000000000000000000000000000000000032';
  const reappearedUnspentTxHash = '0000000000000000000000000000000000000000000000000000000000000033';
  const notReappearedTxHash = '0000000000000000000000000000000000000000000000000000000000000034';
  const nowOutgoingTxHash = '0000000000000000000000000000000000000000000000000000000000000035';

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

    group('reserveSpentInputs 테스트', () {
      const staleSpender = '00000000000000000000000000000000000000000000000000000000000000aa';
      final spend = TransactionMock.createMockTransaction(toAddress: toAddress, amount: 900000);
      final input = spend.inputs.single;
      final utxoId = getUtxoId(input.transactionHash, input.index);

      void addCoin({required int walletId, required UtxoStatus status, String? spentBy}) {
        realmManager.realm.write(() {
          realmManager.realm.add(
            UtxoMock.createMockUtxo(
              walletId: walletId,
              address: testAddress,
              transactionHash: input.transactionHash,
              index: input.index,
              blockHeight: status == UtxoStatus.incoming ? 0 : 100,
              status: status,
              spentByTransactionHash: spentBy,
            ),
          );
        });
      }

      void addRecord(String txHash, {int blockHeight = 0, String? replacedBy}) {
        realmManager.realm.write(() {
          realmManager.realm.add(
            RealmTransaction(
              txHash.hashCode,
              txHash,
              testWalletId,
              DateTime.now(),
              blockHeight,
              'sent',
              -100000,
              1000,
              141,
              DateTime.now(),
              replaceByTransactionHash: replacedBy,
            ),
          );
        });
      }

      UtxoState? coin([int walletId = testWalletId]) => utxoRepository.getUtxoState(walletId, utxoId);

      test('unspent 코인은 outgoing이 되고 spender는 이 거래가 된다', () async {
        addCoin(walletId: testWalletId, status: UtxoStatus.unspent);
        await utxoRepository.reserveSpentInputs(testWalletId, spend);
        expect(coin()!.status, UtxoStatus.outgoing);
        expect(coin()!.spentByTransactionHash, spend.transactionHash);
      });

      test('이미 outgoing인 코인은 RBF 감지를 위해 이전 spender를 유지한다', () async {
        addCoin(walletId: testWalletId, status: UtxoStatus.outgoing, spentBy: staleSpender);
        await utxoRepository.reserveSpentInputs(testWalletId, spend);
        expect(coin()!.spentByTransactionHash, staleSpender);
      });

      test('되돌려진 코인의 이전 spender가 아직 미확정 기록이면 유지하고 outgoing으로 예약한다', () async {
        addCoin(walletId: testWalletId, status: UtxoStatus.unspent, spentBy: staleSpender);
        addRecord(staleSpender);
        await utxoRepository.reserveSpentInputs(testWalletId, spend);
        expect(coin()!.status, UtxoStatus.outgoing);
        expect(coin()!.spentByTransactionHash, staleSpender);
      });

      for (final (label, blockHeight, replacedBy) in [
        ('기록이 없으면', null, null),
        ('대체된 기록이면', 0, 'replacement'),
        ('확정된 기록이면', 100, null),
      ]) {
        test('되돌려진 코인의 이전 spender가 $label 이 거래로 바꾼다', () async {
          addCoin(walletId: testWalletId, status: UtxoStatus.unspent, spentBy: staleSpender);
          if (blockHeight != null) addRecord(staleSpender, blockHeight: blockHeight, replacedBy: replacedBy);
          await utxoRepository.reserveSpentInputs(testWalletId, spend);
          expect(coin()!.status, UtxoStatus.outgoing);
          expect(coin()!.spentByTransactionHash, spend.transactionHash);
        });
      }

      test('미확정 받는 코인(CPFP 자식이 쓰는 incoming)도 예약한다', () async {
        addCoin(walletId: testWalletId, status: UtxoStatus.incoming);
        await utxoRepository.reserveSpentInputs(testWalletId, spend);
        expect(coin()!.status, UtxoStatus.outgoing);
        expect(coin()!.spentByTransactionHash, spend.transactionHash);
      });

      test('같은 outpoint를 가진 다른 지갑의 코인은 건드리지 않는다', () async {
        const twinWalletId = 2;
        addCoin(walletId: testWalletId, status: UtxoStatus.unspent);
        addCoin(walletId: twinWalletId, status: UtxoStatus.unspent);
        await utxoRepository.reserveSpentInputs(testWalletId, spend);
        expect(coin()!.status, UtxoStatus.outgoing);
        expect(coin(twinWalletId)!.status, UtxoStatus.unspent);
      });

      test('여러 입력을 함께 예약하고, 지워진 코인은 되살리지 않는다', () async {
        final threeInputs = Transaction.withInputsAndOutputs(
          [
            for (final index in [0, 1, 2]) TransactionInput.forPayment(input.transactionHash, index),
          ],
          [TransactionOutput.forPayment(1000, toAddress)],
          AddressType.p2wpkh,
        );
        realmManager.realm.write(() {
          for (final index in [0, 1, 2]) {
            final utxo = UtxoMock.createMockUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: input.transactionHash,
              index: index,
              blockHeight: 100,
            );
            utxo.isDeleted = index == 1;
            realmManager.realm.add(utxo);
          }
        });

        await utxoRepository.reserveSpentInputs(testWalletId, threeInputs);

        RealmUtxo row(int index) =>
            realmManager.realm.find<RealmUtxo>(getRealmUtxoId(testWalletId, input.transactionHash, index))!;
        expect([row(0).status, row(2).status], everyElement(utxoStatusToString(UtxoStatus.outgoing)));
        expect(row(1).isDeleted, isTrue);
        expect(row(1).status, utxoStatusToString(UtxoStatus.unspent));
        expect(row(1).spentByTransactionHash, isNull);
      });
    });

    group('snapshotLockedUtxoIds / restoreLockedUtxos 테스트', () {
      test('도메인 UTXO id 목록으로 여러 UTXO를 잠근다', () async {
        realmManager.realm.write(() {
          realmManager.realm.add(
            UtxoMock.createUnspentRealmUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: lockedTxHash,
            ),
          );
          realmManager.realm.add(
            UtxoMock.createUnspentRealmUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: unspentTxHash,
            ),
          );
        });

        final result = await utxoRepository.lockAllUtxos(testWalletId, [
          getUtxoId(lockedTxHash, 0),
          getUtxoId(unspentTxHash, 0),
        ]);

        expect(result.isSuccess, isTrue);
        expect(utxoRepository.getUtxosByStatus(testWalletId, UtxoStatus.locked), hasLength(2));
      });

      test('잠긴 UTXO id만 정확히 스냅샷됨', () async {
        realmManager.realm.write(() {
          realmManager.realm.add(
            UtxoMock.createMockUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: lockedTxHash,
              status: UtxoStatus.locked,
            ),
          );
          realmManager.realm.add(
            UtxoMock.createUnspentRealmUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: unspentTxHash,
            ),
          );
        });

        final snapshot = utxoRepository.snapshotLockedUtxoIds(testWalletId);

        expect(snapshot, {getUtxoId(lockedTxHash, 0)});
      });

      test('스냅샷 후 재발견된(unspent) UTXO만 다시 locked로 복원됨', () async {
        final lockedUtxoIds = {getUtxoId(reappearedUnspentTxHash, 0), getUtxoId(notReappearedTxHash, 0)};

        realmManager.realm.write(() {
          // resync 이후 재동기화로 다시 unspent로 발견된 UTXO
          realmManager.realm.add(
            UtxoMock.createUnspentRealmUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: reappearedUnspentTxHash,
            ),
          );
          // not_reappeared_tx_hash는 재동기화로 아예 재발견되지 않았다고 가정(row 없음)
        });

        await utxoRepository.restoreLockedUtxos(testWalletId, lockedUtxoIds);

        final restored = utxoRepository.getUtxoState(testWalletId, getUtxoId(reappearedUnspentTxHash, 0));
        expect(restored!.status, UtxoStatus.locked);
      });

      test('스냅샷에 있어도 outgoing/incoming으로 재동기화된 UTXO는 강제로 잠그지 않음', () async {
        final lockedUtxoIds = {getUtxoId(nowOutgoingTxHash, 0)};

        realmManager.realm.write(() {
          realmManager.realm.add(
            UtxoMock.createOutgoingRealmUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: nowOutgoingTxHash,
            ),
          );
        });

        await utxoRepository.restoreLockedUtxos(testWalletId, lockedUtxoIds);

        final utxo = utxoRepository.getUtxoState(testWalletId, getUtxoId(nowOutgoingTxHash, 0));
        expect(utxo!.status, UtxoStatus.outgoing);
      });

      test('빈 스냅샷은 아무 것도 하지 않음', () async {
        realmManager.realm.write(() {
          realmManager.realm.add(
            UtxoMock.createUnspentRealmUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: unspentTxHash,
            ),
          );
        });

        await utxoRepository.restoreLockedUtxos(testWalletId, {});

        final utxo = utxoRepository.getUtxoState(testWalletId, getUtxoId(unspentTxHash, 0));
        expect(utxo!.status, UtxoStatus.unspent);
      });

      test('일부 UTXO 조회 실패 후 재동기화해도 마이그레이션 잠금을 복원함', () async {
        final reappearedUtxoId = getUtxoId(reappearedUnspentTxHash, 0);
        final missingUtxoId = getUtxoId(notReappearedTxHash, 0);
        realmManager.realm.write(() {
          realmManager.realm.add(
            UtxoMock.createUnspentRealmUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: reappearedUnspentTxHash,
            ),
          );
          realmManager.realm.add(
            RealmPendingUtxoLock('$testWalletId:$reappearedUtxoId', testWalletId, reappearedUtxoId),
          );
          realmManager.realm.add(RealmPendingUtxoLock('$testWalletId:$missingUtxoId', testWalletId, missingUtxoId));
        });

        await utxoRepository.restorePendingUtxoLocks(testWalletId);

        expect(utxoRepository.getUtxoState(testWalletId, reappearedUtxoId)!.status, UtxoStatus.locked);
        expect(realmManager.realm.all<RealmPendingUtxoLock>().map((lock) => lock.utxoId), [missingUtxoId]);

        // 재시도에서도 아직 조회되지 않으면 복원 대기 정보를 유지한다.
        await utxoRepository.restorePendingUtxoLocks(testWalletId);
        expect(realmManager.realm.all<RealmPendingUtxoLock>(), hasLength(1));

        realmManager.realm.write(() {
          realmManager.realm.add(
            UtxoMock.createUnspentRealmUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: notReappearedTxHash,
            ),
          );
        });
        await utxoRepository.restorePendingUtxoLocks(testWalletId);
        expect(utxoRepository.getUtxoState(testWalletId, missingUtxoId)!.status, UtxoStatus.locked);
        expect(realmManager.realm.query<RealmPendingUtxoLock>(r'walletId == $0', [testWalletId]), isEmpty);
      });

      test('마이그레이션 잠금 설정은 outgoing UTXO를 잠그지 않음', () async {
        final outgoingUtxoId = getUtxoId(nowOutgoingTxHash, 0);
        realmManager.realm.write(() {
          realmManager.realm.add(
            UtxoMock.createOutgoingRealmUtxo(
              walletId: testWalletId,
              address: testAddress,
              transactionHash: nowOutgoingTxHash,
            ),
          );
          realmManager.realm.add(RealmPendingUtxoLock('$testWalletId:$outgoingUtxoId', testWalletId, outgoingUtxoId));
        });

        await utxoRepository.restorePendingUtxoLocks(testWalletId);

        expect(utxoRepository.getUtxoState(testWalletId, outgoingUtxoId)!.status, UtxoStatus.outgoing);
        expect(realmManager.realm.all<RealmPendingUtxoLock>(), hasLength(1));
      });
    });
  });
}
