import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/rbf_service.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
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
  UtxoSyncService,
  ElectrumService,
])
void main() {
  group('RbfService', () {
    TestRealmManager? realmManager;
    late TransactionRepository transactionRepository;
    late WalletRepository walletRepository;
    late AddressRepository addressRepository;
    late MockUtxoSyncService utxoSyncService;
    late MockElectrumService electrumService;
    late RbfService rbfService;

    const int walletId = 1;
    final walletItem = WalletMock.createSingleSigWalletItem(id: walletId);
    final otherWalletItem = WalletMock.createSingleSigWalletItem(
        id: walletId + 1, name: 'other', randomDescriptor: true);
    final Transaction inputTx = TransactionMock.createMockTransaction(
      toAddress: walletItem.walletBase.getAddress(0),
      amount: 10000,
    );
    final originalTx = TransactionMock.createMockTransaction(
      toAddress: otherWalletItem.walletBase.getAddress(0),
      amount: 9000,
      inputTransactionHash: inputTx.transactionHash,
    );
    final firstRbfTx = TransactionMock.createMockTransaction(
      toAddress: otherWalletItem.walletBase.getAddress(0),
      amount: 8000,
      inputTransactionHash: originalTx.transactionHash,
    );

    setUp(() {
      if (realmManager == null) {
        realmManager = TestRealmManager()..init(false);
      } else {
        realmManager!.dispose();
        realmManager = TestRealmManager()..init(false);
      }
      transactionRepository = TransactionRepository(realmManager!);
      walletRepository = WalletRepository(realmManager!);
      addressRepository = AddressRepository(realmManager!);
      final sharedPrefsRepository = SharedPrefsRepository()
        ..setSharedPreferencesForTest(MockSharedPreferences());
      when(sharedPrefsRepository.getInt('nextId')).thenReturn(walletItem.id);
      when(sharedPrefsRepository.setInt('nextId', walletItem.id + 1)).thenAnswer((_) async => true);

      walletRepository.addSinglesigWallet(WatchOnlyWallet(walletItem.name, walletItem.colorIndex,
          walletItem.iconIndex, walletItem.descriptor, null, null));
      addressRepository.ensureAddressesInit(walletItemBase: walletItem);
      utxoSyncService = MockUtxoSyncService();
      electrumService = MockElectrumService();
      rbfService = RbfService(transactionRepository, utxoSyncService, electrumService);
    });

    group('hasExistingRbfHistory', () {
      test('기존 RBF 내역이 있을 경우 true 반환', () async {
        // Given
        final rbfHistoryList = [
          RbfHistoryDto(
            walletId: walletId,
            originalTransactionHash: originalTx.transactionHash,
            transactionHash: firstRbfTx.transactionHash,
            feeRate: 1.0,
            timestamp: DateTime.now(),
          ),
        ];
        transactionRepository.addAllRbfHistory(rbfHistoryList);
        final secondRbfTx = TransactionMock.createMockTransaction(
          toAddress: otherWalletItem.walletBase.getAddress(0),
          amount: 7000,
          inputTransactionHash: firstRbfTx.transactionHash,
        );

        // When
        final result = rbfService.hasExistingRbfHistory(walletId, secondRbfTx.transactionHash);

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
          spentByTransactionHash: inputTx.transactionHash,
        );
        final originalTxRecord = TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: originalTx.transactionHash,
        );

        transactionRepository.addAllTransactions(walletId, [originalTxRecord]);

        // When
        final result = await rbfService.isRbfTransaction(walletId, firstRbfTx, utxo);

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
        final result = await rbfService.isRbfTransaction(walletId, firstRbfTx, utxo);

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
        final result = await rbfService.isRbfTransaction(walletId, originalTx, utxo);

        // Then
        expect(result, false);
      });
    });

    group('findOriginalTransactionHash', () {
      test('첫 RBF인 경우 대체되는 트랜잭션 해시 반환', () async {
        // Given
        final firstRbfTxRecord = TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: firstRbfTx.transactionHash,
        );

        transactionRepository.addAllTransactions(walletId, [firstRbfTxRecord]);

        // When
        final result =
            await rbfService.findOriginalTransactionHash(walletId, firstRbfTx.transactionHash);

        // Then
        expect(result, originalTx.transactionHash);
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
  });
}
