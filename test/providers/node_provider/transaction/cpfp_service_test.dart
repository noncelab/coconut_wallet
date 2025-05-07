import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/node/cpfp_history.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/cpfp_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
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

@GenerateMocks([
  ElectrumService,
])
void main() {
  group('CpfpService', () {
    TestRealmManager? realmManager;
    late TransactionRepository transactionRepository;
    late WalletRepository walletRepository;
    late UtxoRepository utxoRepository;
    late MockElectrumService electrumService;
    late CpfpService cpfpService;

    const int walletId = 1;
    final walletItem = WalletMock.createSingleSigWalletItem(id: walletId);
    final parentTx = TransactionMock.createMockTransaction(
      toAddress: walletItem.walletBase.getAddress(0),
      amount: 10000,
    );
    final childTx = TransactionMock.createMockTransaction(
      toAddress: walletItem.walletBase.getAddress(1),
      amount: 9000,
      inputTransactionHash: parentTx.transactionHash,
    );

    setUp(() async {
      if (realmManager == null) {
        realmManager = await setupTestRealmManager();
      } else {
        realmManager!.dispose();
        realmManager = await setupTestRealmManager();
      }
      final sharedPrefsRepository = SharedPrefsRepository()
        ..setSharedPreferencesForTest(MockSharedPreferences());
      when(sharedPrefsRepository.getInt('nextId')).thenReturn(walletItem.id);
      when(sharedPrefsRepository.setInt('nextId', walletItem.id + 1)).thenAnswer((_) async => true);
      transactionRepository = TransactionRepository(realmManager!);
      utxoRepository = UtxoRepository(realmManager!);
      walletRepository = WalletRepository(realmManager!);
      electrumService = MockElectrumService();
      cpfpService = CpfpService(transactionRepository, utxoRepository, electrumService);
      walletRepository.addSinglesigWallet(WatchOnlyWallet(walletItem.name, walletItem.colorIndex,
          walletItem.iconIndex, walletItem.descriptor, null, null));
    });

    tearDown(() {
      realmManager?.dispose();
      realmManager = null;
    });

    group('hasExistingCpfpHistory', () {
      test('기존 CPFP 내역이 있을 경우 true 반환', () async {
        // Given
        final cpfpHistory = CpfpHistory(
          walletId: walletId,
          parentTransactionHash: parentTx.transactionHash,
          childTransactionHash: childTx.transactionHash,
          originalFee: 1.0,
          newFee: 2.0,
          timestamp: DateTime.now(),
        );
        transactionRepository.addAllCpfpHistory([cpfpHistory]);

        // When
        final result = cpfpService.hasExistingCpfpHistory(walletId, childTx.transactionHash);

        // Then
        expect(result, true);
      });

      test('기존 CPFP 내역이 없을 경우 false 반환', () async {
        // When
        final result = cpfpService.hasExistingCpfpHistory(walletId, childTx.transactionHash);

        // Then
        expect(result, false);
      });
    });

    group('detectCpfpTransaction', () {
      test('CPFP 트랜잭션 감지 성공', () async {
        // Given
        final utxo = UtxoMock.createOutgoingUtxo(
          walletId: walletId,
          transactionHash: parentTx.transactionHash,
          index: 0,
        );
        utxoRepository.addAllUtxos(walletId, [utxo]);
        final parentTxRecord = TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: parentTx.transactionHash,
          fee: 1000,
        );
        await transactionRepository.addAllTransactions(walletId, [parentTxRecord]);
        when(electrumService.getPreviousTransactions(childTx)).thenAnswer((_) async => [parentTx]);

        // When
        final result = await cpfpService.detectCpfpTransaction(walletId, childTx);

        // Then
        expect(result, isNotNull);
        expect(result?.parentTransactionHash, parentTx.transactionHash);
        expect(result?.originalFee, parentTxRecord.feeRate);
        expect(result?.previousTransactions, isA<List<Transaction>>());
      });

      test('이미 CPFP 내역이 있는 경우 null 반환', () async {
        // Given
        final cpfpHistory = CpfpHistory(
          walletId: walletId,
          parentTransactionHash: parentTx.transactionHash,
          childTransactionHash: childTx.transactionHash,
          originalFee: 1.0,
          newFee: 2.0,
          timestamp: DateTime.now(),
        );
        transactionRepository.addAllCpfpHistory([cpfpHistory]);

        // When
        final result = await cpfpService.detectCpfpTransaction(walletId, childTx);

        // Then
        expect(result, isNull);
      });

      test('부모 트랜잭션이 미확인 상태가 아닌 경우 null 반환', () async {
        // Given
        final utxo = UtxoMock.createOutgoingUtxo(
          walletId: walletId,
          transactionHash: parentTx.transactionHash,
          index: 0,
        );
        utxoRepository.addAllUtxos(walletId, [utxo]);
        final parentTxRecord = TransactionMock.createConfirmedTransactionRecord(
          transactionHash: parentTx.transactionHash,
        );
        await transactionRepository.addAllTransactions(walletId, [parentTxRecord]);

        // When
        final result = await cpfpService.detectCpfpTransaction(walletId, childTx);

        // Then
        expect(result, isNull);
      });
    });
  });
}
