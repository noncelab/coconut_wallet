import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

import '../../../mock/transaction_mock.dart';
import '../../../mock/wallet_mock.dart';
import '../../../repository/realm/test_realm_manager.dart';

// 모킹할 클래스 목록
@GenerateMocks([ElectrumService, NodeStateManager])
import 'utxo_sync_service_test.mocks.dart';

void main() {
  late TestRealmManager realmManager;
  late TransactionRepository transactionRepository;
  late UtxoRepository utxoRepository;
  late AddressRepository addressRepository;
  late MockElectrumService electrumService;
  late MockNodeStateManager stateManager;
  late UtxoSyncService utxoSyncService;

  const int testWalletId = 1;
  final SinglesigWalletListItem testWalletItem = WalletMock.createSingleSigWalletItem();

  setUp(() async {
    realmManager = await setupTestRealmManager();
    transactionRepository = TransactionRepository(realmManager);
    addressRepository = AddressRepository(realmManager);
    utxoRepository = UtxoRepository(realmManager);
    electrumService = MockElectrumService();
    stateManager = MockNodeStateManager();

    utxoSyncService = UtxoSyncService(
      electrumService,
      stateManager,
      utxoRepository,
      transactionRepository,
      addressRepository,
    );

    // 테스트용 지갑 생성
    realmManager.realm.write(() {
      realmManager.realm.add(RealmWalletBase(testWalletId, 0, 0, 'test_descriptor', 'Test Wallet', 'singleSignature'));
    });
  });

  tearDown(() {
    realmManager.reset();
    realmManager.dispose();
  });

  group('cleanupOrphanedUtxos 테스트', () {
    test('컨펌된 트랜잭션에 연결된 outgoing UTXO가 정리되는지 확인', () async {
      // Given: 컨펌된 트랜잭션과 연결된 outgoing UTXO 생성
      const String confirmedTxHash = 'confirmed_tx_hash_123';

      // 트랜잭션 레코드 생성 (컨펌됨 - blockHeight > 0)
      final confirmedTx = TransactionMock.createConfirmedTransactionRecord(
        transactionHash: confirmedTxHash,
        blockHeight: 100,
      );
      await transactionRepository.addAllTransactions(testWalletId, [confirmedTx]);

      // Outgoing UTXO 생성
      final orphanedUtxo1 = UtxoState(
        transactionHash: confirmedTxHash,
        index: 0,
        amount: 1000000,
        derivationPath: "m/84'/0'/0'/0/0",
        blockHeight: 0,
        to: testWalletItem.walletBase.getAddress(0),
        timestamp: DateTime.now(),
        status: UtxoStatus.outgoing,
        spentByTransactionHash: confirmedTxHash,
      );
      final orphanedUtxo2 = UtxoState(
        transactionHash: confirmedTxHash,
        index: 1,
        amount: 1000000,
        derivationPath: "m/84'/0'/0'/0/1",
        blockHeight: 0,
        to: testWalletItem.walletBase.getAddress(1),
        timestamp: DateTime.now(),
        status: UtxoStatus.outgoing,
        spentByTransactionHash: confirmedTxHash,
      );

      await utxoRepository.addAllUtxos(testWalletId, [orphanedUtxo1, orphanedUtxo2]);

      // When: cleanupOrphanedUtxos 호출
      await utxoSyncService.cleanupOrphanedUtxos(testWalletItem);

      // Then: orphaned UTXO가 삭제되었는지 확인
      final remainingUtxos = utxoRepository.getUtxoStateList(testWalletId);
      expect(remainingUtxos.where((u) => u.utxoId == orphanedUtxo1.utxoId).isEmpty, isTrue);
      expect(remainingUtxos.where((u) => u.utxoId == orphanedUtxo2.utxoId).isEmpty, isTrue);
    });

    test('컨펌된 트랜잭션에 연결된 incoming UTXO가 정리되는지 확인', () async {
      // Given: 컨펌된 트랜잭션과 연결된 incoming UTXO 생성
      const String confirmedTxHash = 'confirmed_tx_hash_123';

      // 트랜잭션 레코드 생성 (컨펌됨 - blockHeight > 0)
      final confirmedTx = TransactionMock.createConfirmedTransactionRecord(
        transactionHash: confirmedTxHash,
        blockHeight: 100,
      );
      await transactionRepository.addAllTransactions(testWalletId, [confirmedTx]);

      // Incoming UTXO 생성
      final orphanedUtxo1 = UtxoState(
        transactionHash: confirmedTxHash,
        index: 0,
        amount: 1000000,
        derivationPath: "m/84'/0'/0'/0/0",
        blockHeight: 0,
        to: testWalletItem.walletBase.getAddress(0),
        timestamp: DateTime.now(),
        status: UtxoStatus.incoming,
        spentByTransactionHash: confirmedTxHash,
      );
      final orphanedUtxo2 = UtxoState(
        transactionHash: confirmedTxHash,
        index: 1,
        amount: 1000000,
        derivationPath: "m/84'/0'/0'/0/1",
        blockHeight: 0,
        to: testWalletItem.walletBase.getAddress(1),
        timestamp: DateTime.now(),
        status: UtxoStatus.incoming,
        spentByTransactionHash: confirmedTxHash,
      );

      await utxoRepository.addAllUtxos(testWalletId, [orphanedUtxo1, orphanedUtxo2]);

      // When: cleanupOrphanedUtxos 호출
      await utxoSyncService.cleanupOrphanedUtxos(testWalletItem);

      // Then: orphaned UTXO가 삭제되었는지 확인
      final remainingUtxos = utxoRepository.getUtxoStateList(testWalletId);
      expect(remainingUtxos.where((u) => u.utxoId == orphanedUtxo1.utxoId).isEmpty, isTrue);
      expect(remainingUtxos.where((u) => u.utxoId == orphanedUtxo2.utxoId).isEmpty, isTrue);
    });

    test('존재하지 않는 트랜잭션에 연결된 outgoing UTXO가 정리되는지 확인', () async {
      // Given: 존재하지 않는 트랜잭션에 연결된 outgoing UTXO 생성
      const String nonExistentTxHash = 'non_existent_tx_hash';

      final outgoingUtxo = UtxoState(
        transactionHash: nonExistentTxHash,
        index: 0,
        amount: 500000,
        derivationPath: "m/84'/0'/0'/1/0",
        blockHeight: 0,
        to: testWalletItem.walletBase.getAddress(0),
        timestamp: DateTime.now(),
        status: UtxoStatus.outgoing,
      );

      await utxoRepository.addAllUtxos(testWalletId, [outgoingUtxo]);

      // 트랜잭션은 DB에 없음 (null 반환)

      // When: cleanupOrphanedUtxos 호출
      await utxoSyncService.cleanupOrphanedUtxos(testWalletItem);

      // Then: orphaned UTXO가 삭제되었는지 확인
      final remainingUtxos = utxoRepository.getUtxoStateList(testWalletId);
      expect(remainingUtxos.where((u) => u.utxoId == outgoingUtxo.utxoId).isEmpty, isTrue);
    });

    test('존재하지 않는 트랜잭션에 연결된 incoming UTXO가 정리되는지 확인', () async {
      // Given: 존재하지 않는 트랜잭션에 연결된 incoming UTXO 생성
      const String nonExistentTxHash = 'non_existent_tx_hash';

      final incomingUtxo = UtxoState(
        transactionHash: nonExistentTxHash,
        index: 0,
        amount: 500000,
        derivationPath: "m/84'/0'/0'/1/0",
        blockHeight: 0,
        to: testWalletItem.walletBase.getAddress(0),
        timestamp: DateTime.now(),
        status: UtxoStatus.incoming,
      );

      await utxoRepository.addAllUtxos(testWalletId, [incomingUtxo]);

      // 트랜잭션은 DB에 없음 (null 반환)

      // When: cleanupOrphanedUtxos 호출
      await utxoSyncService.cleanupOrphanedUtxos(testWalletItem);

      // Then: orphaned UTXO가 삭제되었는지 확인
      final remainingUtxos = utxoRepository.getUtxoStateList(testWalletId);
      expect(remainingUtxos.where((u) => u.utxoId == incomingUtxo.utxoId).isEmpty, isTrue);
    });

    test('정상적인 pending UTXO가 남아있는지 확인', () async {
      // Given: 펜딩 트랜잭션과 연결된 outgoing, incoming UTXO 생성
      const String pendingTxHash = 'unconfirmed_tx_hash_789';

      final unconfirmedTx = TransactionMock.createMockTransactionRecord(
        transactionHash: pendingTxHash,
        blockHeight: 0, // 언컨펌
      );

      await transactionRepository.addAllTransactions(testWalletId, [unconfirmedTx]);

      final validOutgoingUtxo = UtxoState(
        transactionHash: pendingTxHash,
        index: 0,
        amount: 2000000,
        derivationPath: "m/84'/0'/0'/0/1",
        blockHeight: -1,
        to: testWalletItem.walletBase.getAddress(0),
        timestamp: DateTime.now(),
        status: UtxoStatus.outgoing,
        spentByTransactionHash: pendingTxHash,
      );

      final validIncomingUtxo = UtxoState(
        transactionHash: pendingTxHash,
        index: 1,
        amount: 2000000,
        derivationPath: "m/84'/0'/0'/1/1",
        blockHeight: -1,
        to: testWalletItem.walletBase.getAddress(1),
        timestamp: DateTime.now(),
        status: UtxoStatus.incoming,
      );

      await utxoRepository.addAllUtxos(testWalletId, [validOutgoingUtxo, validIncomingUtxo]);

      // When: cleanupOrphanedUtxos 호출
      await utxoSyncService.cleanupOrphanedUtxos(testWalletItem);

      // Then: 정상적인 pending UTXO는 유지되는지 확인
      final remainingUtxos = utxoRepository.getUtxoStateList(testWalletId);
      expect(remainingUtxos.where((u) => u.utxoId == validOutgoingUtxo.utxoId).isNotEmpty, isTrue);
      expect(remainingUtxos.where((u) => u.utxoId == validIncomingUtxo.utxoId).isNotEmpty, isTrue);
    });

    test('여러 orphaned UTXO가 한 번에 정리되는지 확인', () async {
      // Given: 여러 orphaned UTXO 생성
      final orphanedUtxos = <UtxoState>[];

      for (int i = 0; i < 3; i++) {
        final confirmedTx = TransactionMock.createConfirmedTransactionRecord(
          transactionHash: 'confirmed_tx_$i',
          blockHeight: 100 + i,
        );
        await transactionRepository.addAllTransactions(testWalletId, [confirmedTx]);

        orphanedUtxos.add(
          UtxoState(
            transactionHash: confirmedTx.transactionHash,
            index: 0,
            amount: 1000000 * (i + 1),
            derivationPath: "m/84'/0'/0'/0/$i",
            blockHeight: 0,
            to: testWalletItem.walletBase.getAddress(0),
            timestamp: DateTime.now(),
            status: UtxoStatus.outgoing,
            spentByTransactionHash: 'confirmed_tx_$i',
          ),
        );
      }

      await utxoRepository.addAllUtxos(testWalletId, orphanedUtxos);

      // When: cleanupOrphanedUtxos 호출
      await utxoSyncService.cleanupOrphanedUtxos(testWalletItem);

      // Then: 모든 orphaned UTXO가 삭제되었는지 확인
      final remainingUtxos = utxoRepository.getUtxoStateList(testWalletId);
      for (final orphanedUtxo in orphanedUtxos) {
        expect(remainingUtxos.where((u) => u.utxoId == orphanedUtxo.utxoId).isEmpty, isTrue);
      }
    });
  });
}
