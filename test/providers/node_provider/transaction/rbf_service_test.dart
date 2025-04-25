import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/rbf_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/transaction_mock.dart';
import '../../../mock/utxo_mock.dart';
import '../../../mock/wallet_mock.dart';
import '../../../repository/realm/test_realm_manager.dart';
import '../../../services/shared_prefs_service_test.mocks.dart';
import 'rbf_service_test.mocks.dart';

// 테스트에 필요한 모킹 클래스 생성
@GenerateMocks([
  ElectrumService,
])
void main() {
  group('RbfService', () {
    TestRealmManager? realmManager;
    late TransactionRepository transactionRepository;
    late WalletRepository walletRepository;
    late AddressRepository addressRepository;
    late UtxoRepository utxoRepository;
    late MockElectrumService electrumService;
    late RbfService rbfService;

    const int walletId = 1;
    final walletItem = WalletMock.createSingleSigWalletItem(id: walletId);
    final otherWalletItem = WalletMock.createSingleSigWalletItem(
        id: walletId + 1, name: 'other', randomDescriptor: true);
    final Transaction inputTx = TransactionMock.createMockTransaction(
      toAddress: walletItem.walletBase.getAddress(0),
      amount: 10000,
    ); // 이미 컨펌된 OriginalTx에 사용된 입력 트랜잭션
    final originalTx = TransactionMock.createMockTransaction(
      toAddress: otherWalletItem.walletBase.getAddress(0),
      amount: 9000,
      inputTransactionHash: inputTx.transactionHash,
    ); // 수수료가 낮은 트랜잭션
    final firstRbfTx = TransactionMock.createMockTransaction(
      toAddress: otherWalletItem.walletBase.getAddress(0),
      amount: 8000,
      inputTransactionHash: inputTx.transactionHash,
    ); // 수수료를 처음 올리려고 시도한 RBF 트랜잭션

    setUp(() async {
      if (realmManager == null) {
        realmManager = TestRealmManager()..init(false);
      } else {
        realmManager!.dispose();
        realmManager = TestRealmManager()..init(false);
      }
      transactionRepository = TransactionRepository(realmManager!);
      utxoRepository = UtxoRepository(realmManager!);
      walletRepository = WalletRepository(realmManager!);
      addressRepository = AddressRepository(realmManager!);
      final sharedPrefsRepository = SharedPrefsRepository()
        ..setSharedPreferencesForTest(MockSharedPreferences());
      when(sharedPrefsRepository.getInt('nextId')).thenReturn(walletItem.id);
      when(sharedPrefsRepository.setInt('nextId', walletItem.id + 1)).thenAnswer((_) async => true);

      walletRepository.addSinglesigWallet(WatchOnlyWallet(walletItem.name, walletItem.colorIndex,
          walletItem.iconIndex, walletItem.descriptor, null, null));
      await addressRepository.ensureAddressesInit(walletItemBase: walletItem);
      electrumService = MockElectrumService();
      rbfService = RbfService(transactionRepository, utxoRepository, electrumService);
    });

    group('hasExistingRbfHistory', () {
      test('기존 RBF 내역이 있을 경우 true 반환', () async {
        // Given
        final rbfHistoryList = [
          RbfHistoryDto(
            walletId: walletId,
            originalTransactionHash: originalTx.transactionHash,
            transactionHash: originalTx.transactionHash,
            feeRate: 1.0,
            timestamp: DateTime.now(),
          ),
          RbfHistoryDto(
            walletId: walletId,
            originalTransactionHash: originalTx.transactionHash,
            transactionHash: firstRbfTx.transactionHash,
            feeRate: 2.0,
            timestamp: DateTime.now(),
          ),
        ];
        transactionRepository.addAllRbfHistory(rbfHistoryList);
        // When
        final result = rbfService.hasExistingRbfHistory(walletId, firstRbfTx.transactionHash);

        // Then
        expect(result, true);
      });

      test('기존 RBF 내역이 없을 경우 false 반환', () async {
        // When
        final result = rbfService.hasExistingRbfHistory(walletId, firstRbfTx.transactionHash);

        // Then
        expect(result, false);
      });
    });

    group('isRbfTransaction', () {
      test('유효한 RBF 조건을 만족할 경우 true 반환', () async {
        // Given
        final utxo = UtxoMock.createOutgoingUtxo(
          walletId: walletId,
          spentByTransactionHash: originalTx.transactionHash,
        );
        final originalTxRecord = TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: originalTx.transactionHash,
        );

        await transactionRepository.addAllTransactions(walletId, [originalTxRecord]);

        // When
        final result = await rbfService.isRbfTransaction(walletId, utxo);

        // Then
        expect(result, true);
      });

      test('이미 컨펌된 트랜잭션은 RBF 대상이 아님', () async {
        // Given
        final utxo = UtxoMock.createOutgoingUtxo(
          walletId: walletId,
          transactionHash: inputTx.transactionHash,
        );
        final originalTxRecord = TransactionMock.createConfirmedTransactionRecord(
          transactionHash: originalTx.transactionHash,
        );

        transactionRepository.addAllTransactions(walletId, [originalTxRecord]);

        // When
        final result = await rbfService.isRbfTransaction(walletId, utxo);

        // Then
        expect(result, false);
      });

      test('outgoing 상태가 아니거나 spentByTransactionHash가 없으면 false 반환', () async {
        // Given
        final utxo = UtxoMock.createUnspentUtxo(
          walletId: walletId,
          transactionHash: inputTx.transactionHash,
        );

        // When
        final result = await rbfService.isRbfTransaction(walletId, utxo);

        // Then
        expect(result, false);
      });
    });

    group('findOriginalTransactionHash', () {
      test('첫 RBF인 경우 대체되는 트랜잭션 해시 반환', () async {
        // Given
        final originalTxRecord = TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: originalTx.transactionHash,
        );
        final utxo = UtxoMock.createOutgoingUtxo(
          walletId: walletId,
          transactionHash: originalTx.transactionHash,
        );

        transactionRepository.addAllTransactions(walletId, [originalTxRecord]);
        utxoRepository.addAllUtxos(walletId, [utxo]);

        // When
        final result =
            await rbfService.findOriginalTransactionHash(walletId, firstRbfTx.transactionHash);

        // Then
        expect(result, firstRbfTx.transactionHash);
      });

      test('이미 RBF된 트랜잭션인 경우 원본 트랜잭션 해시 반환', () async {
        // Given
        final rbfHistoryList = [
          RbfHistoryDto(
            walletId: walletId,
            originalTransactionHash: originalTx.transactionHash,
            transactionHash: originalTx.transactionHash,
            feeRate: 1.0,
            timestamp: DateTime.now(),
          ),
          RbfHistoryDto(
            walletId: walletId,
            originalTransactionHash: originalTx.transactionHash,
            transactionHash: firstRbfTx.transactionHash,
            feeRate: 2.0,
            timestamp: DateTime.now(),
          ),
        ];
        transactionRepository.addAllRbfHistory(rbfHistoryList);

        // When
        final result =
            await rbfService.findOriginalTransactionHash(walletId, firstRbfTx.transactionHash);

        // Then
        expect(result, originalTx.transactionHash);
      });
    });
    group('findRbfCandidate', () {
      test('RBF 후보가 있을 경우 해당 UTXO 반환', () async {
        // Given

        final utxo = UtxoMock.createOutgoingUtxo(
          transactionHash: inputTx.transactionHash,
          spentByTransactionHash: originalTx.transactionHash,
        );

        utxoRepository.addAllUtxos(walletId, [utxo]);

        final originalTxRecord = TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: originalTx.transactionHash,
        );
        await transactionRepository.addAllTransactions(walletId, [originalTxRecord]);

        // When
        final result = await rbfService.findRbfCandidate(walletId, firstRbfTx);

        // Then
        expect(result, isNotNull);
        expect(result?.transactionHash, inputTx.transactionHash);
        expect(result?.spentByTransactionHash, originalTx.transactionHash);
      });

      test('RBF 후보가 없을 경우 null 반환', () async {
        // When
        final result = await rbfService.findRbfCandidate(walletId, firstRbfTx);

        // Then
        expect(result, isNull);
      });
    });

    group('detectSendingRbfTransaction', () {
      test('RBF 트랜잭션 감지 성공', () async {
        // Given
        final utxo = UtxoMock.createOutgoingUtxo(
          transactionHash: inputTx.transactionHash,
          spentByTransactionHash: originalTx.transactionHash,
        );

        utxoRepository.addAllUtxos(walletId, [utxo]);

        final originalTxRecord = TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: originalTx.transactionHash,
        );

        final inputTxRecord = TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: inputTx.transactionHash,
        );

        await transactionRepository.addAllTransactions(walletId, [originalTxRecord, inputTxRecord]);

        // When
        final result = await rbfService.detectSendingRbfTransaction(walletId, firstRbfTx);

        // Then
        expect(result, isNotNull);
        expect(result?.originalTransactionHash, originalTx.transactionHash,
            reason: '원본 트랜잭션 해시 ${originalTx.transactionHash.substring(0, 6)}...가 반환되어야 함.');
        expect(result?.spentTransactionHash, firstRbfTx.transactionHash,
            reason: '첫 RBF 트랜잭션 해시 ${firstRbfTx.transactionHash.substring(0, 6)}...가 반환되어야 함.');
      });
      test('이미 RBF 내역이 있는 경우 null 반환', () async {
        // Given
        final rbfHistoryList = [
          RbfHistoryDto(
            walletId: walletId,
            originalTransactionHash: originalTx.transactionHash,
            transactionHash: originalTx.transactionHash,
            feeRate: 1.0,
            timestamp: DateTime.now(),
          ),
          RbfHistoryDto(
            walletId: walletId,
            originalTransactionHash: originalTx.transactionHash,
            transactionHash: firstRbfTx.transactionHash,
            feeRate: 2.0,
            timestamp: DateTime.now(),
          ),
        ];

        // 기존 RBF 내역 있음
        transactionRepository.addAllRbfHistory(rbfHistoryList);

        // When
        final result = await rbfService.detectSendingRbfTransaction(walletId, firstRbfTx);

        // Then
        expect(result, isNull);
      });
    });

    group('detectReceivingRbfTransaction', () {
      test('incoming 트랜잭션이 대체된 경우 해당 트랜잭션 해시 반환', () async {
        // Given
        final incomingUtxoList = [
          UtxoMock.createIncomingUtxo(
            transactionHash: originalTx.transactionHash,
            id: makeUtxoId(originalTx.transactionHash, 0),
          ),
        ];

        utxoRepository.addAllUtxos(walletId, incomingUtxoList);

        // 트랜잭션 대체됨 (예외 발생)
        when(electrumService.getTransaction(originalTx.transactionHash, verbose: true))
            .thenThrow(Exception('Transaction not found'));

        // When
        final result = await rbfService.detectReceivingRbfTransaction(walletId, firstRbfTx);

        // Then
        expect(result, originalTx.transactionHash);
      });

      test('incoming 트랜잭션이 유효한 경우 null 반환', () async {
        // Given
        final incomingUtxoList = [
          UtxoMock.createIncomingUtxo(
            transactionHash: originalTx.transactionHash,
            id: makeUtxoId(originalTx.transactionHash, 0),
          ),
        ];

        utxoRepository.addAllUtxos(walletId, incomingUtxoList);

        // 트랜잭션 유효함 (예외 발생하지 않음)
        when(electrumService.getTransaction(originalTx.transactionHash, verbose: true))
            .thenAnswer((_) async => originalTx.serialize());

        // When
        final result = await rbfService.detectReceivingRbfTransaction(walletId, firstRbfTx);

        // Then
        expect(result, isNull);
      });
    });

    group('saveRbfHistory', () {
      test('첫 RBF 내역 저장 시 원본 트랜잭션 내역과 첫 RBF 트랜잭션 내역이 모두 저장되어야 함', () async {
        // Given
        final rbfInfo = TransactionMock.createMockRbfInfo(
          originalTransactionHash: originalTx.transactionHash,
          spentTransactionHash: firstRbfTx.transactionHash,
        );

        final originalTxRecord = TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: originalTx.transactionHash,
        );

        final firstRbfTxRecord = TransactionMock.createRbfTransactionRecord(
          transactionHash: firstRbfTx.transactionHash,
        );
        transactionRepository.addAllTransactions(walletId, [originalTxRecord, firstRbfTxRecord]);

        final beforeRbfHistoryList =
            transactionRepository.getRbfHistoryList(walletId, firstRbfTx.transactionHash);
        expect(beforeRbfHistoryList.length, 0);

        // When
        await rbfService.saveRbfHistoryMap(
            RbfSaveRequest(
                walletItem: walletItem,
                rbfInfoMap: {firstRbfTx.transactionHash: rbfInfo},
                txRecordMap: {firstRbfTx.transactionHash: firstRbfTxRecord}),
            walletId);

        // Then
        final afterRbfHistoryList =
            transactionRepository.getRbfHistoryList(walletId, firstRbfTx.transactionHash);
        expect(afterRbfHistoryList.length, 2);
      });
    });

    group('saveRbfHistoryMap', () {
      test('2번째 RBF 내역 저장 시 추가로 1개만 저장되어야 함', () async {
        // Given
        final originalTxRecord = TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: originalTx.transactionHash,
        );
        final firstRbfTxRecord = TransactionMock.createRbfTransactionRecord(
          transactionHash: firstRbfTx.transactionHash,
        );
        final secondRbfTx = TransactionMock.createMockTransaction(
          toAddress: otherWalletItem.walletBase.getAddress(0),
          amount: 7000,
          inputTransactionHash: inputTx.transactionHash,
        );
        final secondRbfTxRecord = TransactionMock.createRbfTransactionRecord(
          transactionHash: secondRbfTx.transactionHash,
        );

        final rbfInfoMap = {
          secondRbfTx.transactionHash: TransactionMock.createMockRbfInfo(
            originalTransactionHash: originalTx.transactionHash,
            spentTransactionHash: secondRbfTx.transactionHash,
          )
        };

        final txRecordMap = {
          originalTx.transactionHash: originalTxRecord,
          firstRbfTx.transactionHash: firstRbfTxRecord,
          secondRbfTx.transactionHash: secondRbfTxRecord,
        };

        final rbfSaveRequest = RbfSaveRequest(
          walletItem: walletItem,
          rbfInfoMap: rbfInfoMap,
          txRecordMap: txRecordMap,
        );

        transactionRepository.addAllTransactions(walletId, [originalTxRecord, firstRbfTxRecord]);
        transactionRepository.addAllRbfHistory([
          RbfHistoryDto(
            walletId: walletId,
            originalTransactionHash: originalTx.transactionHash,
            transactionHash: originalTx.transactionHash,
            feeRate: 1.0,
            timestamp: DateTime.now(),
          ),
          RbfHistoryDto(
            walletId: walletId,
            originalTransactionHash: originalTx.transactionHash,
            transactionHash: firstRbfTx.transactionHash,
            feeRate: 2.0,
            timestamp: DateTime.now(),
          ),
        ]);

        final beforeRbfHistoryList =
            transactionRepository.getRbfHistoryList(walletId, firstRbfTx.transactionHash);
        expect(beforeRbfHistoryList.length, 2, reason: '2번째 RBF 내역 저장 전 총 갯수는 2개여야 함.');

        // When
        await rbfService.saveRbfHistoryMap(rbfSaveRequest, walletId);

        // Then
        final afterRbfHistoryList =
            transactionRepository.getRbfHistoryList(walletId, secondRbfTx.transactionHash);
        expect(afterRbfHistoryList.length, 3,
            reason: '2번째 RBF 내역 저장 시 추가로 1개만 저장되어 전체 갯수는 3개여야 함.');
      });
    });
  });
}
