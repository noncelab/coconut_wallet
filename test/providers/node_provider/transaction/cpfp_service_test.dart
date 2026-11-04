import 'package:coconut_wallet/constants/shared_pref_keys.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/cpfp_history.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/cpfp_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/transaction_mock.dart';
import '../../../mock/utxo_mock.dart';
import '../../../mock/wallet_mock.dart';
import '../../../repository/realm/test_realm_manager.dart';
import '../../../services/shared_prefs_service_test.mocks.dart';

void main() {
  group('CpfpService', () {
    TestRealmManager? realmManager;
    late TransactionRepository transactionRepository;
    late WalletRepository walletRepository;
    late UtxoRepository utxoRepository;
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
      // ignore: deprecated_member_use_from_same_package
      final sharedPrefsRepository = SharedPrefsRepository()..setSharedPreferencesForTest(MockSharedPreferences());
      when(sharedPrefsRepository.getInt(SharedPrefKeys.kNextIdField)).thenReturn(walletItem.id);
      when(sharedPrefsRepository.setInt(SharedPrefKeys.kNextIdField, walletItem.id + 1)).thenAnswer((_) async => true);
      transactionRepository = TransactionRepository(realmManager!);
      utxoRepository = UtxoRepository(realmManager!);
      walletRepository = WalletRepository(realmManager!, TransactionDraftRepository(realmManager!));
      cpfpService = CpfpService(transactionRepository, utxoRepository);
      walletRepository.addSinglesigWallet(
        WatchOnlyWallet(
          walletItem.name,
          walletItem.colorIndex,
          walletItem.iconIndex,
          walletItem.descriptor,
          null,
          null,
          WalletImportSource.coconutVault.name,
        ),
      );
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
      test('CPFP metadata comes from stored records without fetching parents', () async {
        // Given
        final utxo = UtxoMock.createOutgoingUtxo(
          walletId: walletId,
          transactionHash: parentTx.transactionHash,
          index: 0,
        );
        await utxoRepository.addAllUtxos(walletId, [utxo]);
        final parentTxRecord = TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: parentTx.transactionHash,
          fee: 1000,
        );
        await transactionRepository.addAllTransactions(walletId, [parentTxRecord]);

        // When
        final result = await cpfpService.detectCpfpTransaction(walletId, childTx);

        // Then
        expect(result, isNotNull);
        expect(result?.parentTransactionHash, parentTx.transactionHash);
        expect(result?.originalFee, parentTxRecord.feeRate);
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
        await utxoRepository.addAllUtxos(walletId, [utxo]);
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
