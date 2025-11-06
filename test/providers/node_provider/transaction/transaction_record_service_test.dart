import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/transaction_mock.dart';
import '../../../mock/wallet_mock.dart';
import '../../../repository/realm/test_realm_manager.dart';

// 모킹할 클래스 목록
@GenerateMocks([ElectrumService])
import 'transaction_record_service_test.mocks.dart';

void main() {
  late TestRealmManager realmManager;
  late AddressRepository addressRepository;
  late MockElectrumService electrumService;
  late TransactionRecordService transactionRecordService;

  const int testWalletId = 1;
  final SinglesigWalletListItem testWalletItem = WalletMock.createSingleSigWalletItem(id: testWalletId);
  final SinglesigWalletListItem testExternalWalletItem = WalletMock.createSingleSigWalletItem(
    randomDescriptor: true,
    id: testWalletId + 1,
  );
  final blockTimestamp = DateTime.parse('2025-01-01T00:00:00Z');

  setUp(() async {
    realmManager = await setupTestRealmManager();
    addressRepository = AddressRepository(realmManager);
    electrumService = MockElectrumService();

    transactionRecordService = TransactionRecordService(electrumService, addressRepository);

    realmManager.realm.write(() {
      realmManager.realm.add(
        RealmWalletBase(
          testWalletId,
          0, // colorIndex
          0, // iconIndex
          testWalletItem.descriptor,
          testWalletItem.name,
          testWalletItem.walletType.name,
        ),
      );
    });

    final testAddress = testWalletItem.walletBase.getAddress(0);
    realmManager.realm.write(() {
      realmManager.realm.add(
        RealmWalletAddress(
          1,
          testWalletId,
          testAddress,
          0, // index
          false, // isChange
          'm/0/0', // derivationPath
          false, // isUsed
          0, // confirmed
          0, // unconfirmed
          0, // total
        ),
      );
    });
  });

  tearDown(() {
    realmManager.reset();
    realmManager.dispose();
  });

  group('getTransactionRecord 테스트', () {
    test('컨펌 트랜잭션을 올바르게 조회하는지 확인', () async {
      // Given
      final testAddress = testWalletItem.walletBase.getAddress(0);
      const blockHeight = 700000;
      final prevTx = TransactionMock.createMockTransaction(
        toAddress: testExternalWalletItem.walletBase.getAddress(0),
        amount: 2000000,
      );
      final receiveTx = TransactionMock.createMockTransaction(
        toAddress: testAddress,
        amount: 1000000,
        inputTransactionHash: prevTx.transactionHash,
      );

      // Given - Mock 동작 설정
      when(electrumService.getTransaction(receiveTx.transactionHash)).thenAnswer((_) async => receiveTx.serialize());
      when(
        electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList')),
      ).thenAnswer((_) async => [prevTx]);
      when(
        electrumService.getHistory(AddressType.p2wpkh, testAddress),
      ).thenAnswer((_) async => [GetTxHistoryRes(height: blockHeight, txHash: receiveTx.transactionHash)]);
      when(
        electrumService.getBlockTimestamp(blockHeight),
      ).thenAnswer((_) async => BlockTimestamp(blockHeight, blockTimestamp));

      // When
      final result = await transactionRecordService.getTransactionRecord(testWalletItem, receiveTx.transactionHash);

      TransactionRecord? updatedTx;
      if (result.isSuccess) {
        updatedTx = result.value;
      } else {
        fail('❌ result IS FAILED: ${result.error}');
      }

      // Then
      expect(updatedTx.transactionHash, receiveTx.transactionHash);
      expect(updatedTx.blockHeight, blockHeight);
      expect(updatedTx.timestamp.millisecondsSinceEpoch, blockTimestamp.millisecondsSinceEpoch);
      expect(updatedTx.transactionType, TransactionType.received);
      expect(updatedTx.amount, 1000000);

      verify(electrumService.getTransaction(receiveTx.transactionHash)).called(1);
      verify(electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList'))).called(1);
      verify(electrumService.getHistory(AddressType.p2wpkh, testAddress)).called(1);
      verify(electrumService.getBlockTimestamp(blockHeight)).called(1);
    });

    test('언컨펌 트랜잭션을 올바르게 조회하는지 확인', () async {
      // Given
      final testAddress = testWalletItem.walletBase.getAddress(0);
      final externalAddress = testExternalWalletItem.walletBase.getAddress(0);
      final prevTx = TransactionMock.createMockTransaction(toAddress: testAddress, amount: 150000);
      final sendTx = TransactionMock.createMockTransaction(
        toAddress: externalAddress,
        amount: 140000,
        inputTransactionHash: prevTx.transactionHash,
      );

      // Given - Mock 동작 설정
      when(electrumService.getTransaction(sendTx.transactionHash)).thenAnswer((_) async => sendTx.serialize());
      when(
        electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList')),
      ).thenAnswer((_) async => [prevTx]);
      when(electrumService.getHistory(AddressType.p2wpkh, testAddress)).thenAnswer(
        (_) async => [
          GetTxHistoryRes(height: 0, txHash: sendTx.transactionHash), // 미확인 트랜잭션
        ],
      );

      // When
      final result = await transactionRecordService.getTransactionRecord(testWalletItem, sendTx.transactionHash);

      // Then
      TransactionRecord? updatedTx;
      if (result.isSuccess) {
        updatedTx = result.value;
      } else {
        fail('❌ result IS FAILED: ${result.error}');
      }

      expect(updatedTx.transactionHash, sendTx.transactionHash);
      expect(updatedTx.blockHeight, 0);
      expect(updatedTx.transactionType, TransactionType.sent);
      expect(updatedTx.amount, -150000);

      verify(electrumService.getTransaction(sendTx.transactionHash)).called(1);
      verify(electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList'))).called(1);
      verify(electrumService.getHistory(AddressType.p2wpkh, testAddress)).called(1);
    });

    test('히스토리에서 트랜잭션을 찾을 수 없는 경우 언컨펌으로 처리', () async {
      // Given
      final testAddress = testWalletItem.walletBase.getAddress(0);
      final externalAddress = testExternalWalletItem.walletBase.getAddress(0);
      final prevTx = TransactionMock.createMockTransaction(toAddress: externalAddress, amount: 1000000);
      final tx = TransactionMock.createMockTransaction(
        toAddress: testAddress,
        amount: 500000,
        inputTransactionHash: prevTx.transactionHash,
      );

      // Given - Mock 동작 설정 - 히스토리에서 해당 트랜잭션을 찾을 수 없음
      when(electrumService.getTransaction(tx.transactionHash)).thenAnswer((_) async => tx.serialize());
      when(
        electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList')),
      ).thenAnswer((_) async => [prevTx]);
      when(electrumService.getHistory(AddressType.p2wpkh, testAddress)).thenAnswer((_) async => []); // 빈 히스토리

      // When
      final result = await transactionRecordService.getTransactionRecord(testWalletItem, tx.transactionHash);

      TransactionRecord? updatedTx;
      if (result.isSuccess) {
        updatedTx = result.value;
      } else {
        fail('❌ result IS FAILED: ${result.error}');
      }

      // Then
      expect(updatedTx.transactionHash, tx.transactionHash);
      expect(updatedTx.blockHeight, 0);
      expect(updatedTx.transactionType, TransactionType.received);

      verify(electrumService.getTransaction(tx.transactionHash)).called(1);
      verify(electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList'))).called(1);
      verify(electrumService.getHistory(AddressType.p2wpkh, testAddress)).called(1);
    });
  });
}
