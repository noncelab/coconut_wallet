import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

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
  final SinglesigWalletItem testWalletItem = WalletMock.createSingleSigWalletItem();

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
        spentByTransactionHash: nonExistentTxHash,
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

  group('fetchUtxoStateList 테스트', () {
    test('같은 트랜잭션의 다른 output이 잠겨 있어도 잠근 적 없는 output은 unspent로 유지되는지 확인', () async {
      // Given: 하나의 트랜잭션이 지갑 소유 output을 2개 생성 (수신 output index 0, 잔돈 output index 1)
      const String sharedTxHash = 'shared_tx_hash_receive_and_change';

      final confirmedTx = TransactionMock.createConfirmedTransactionRecord(
        transactionHash: sharedTxHash,
        blockHeight: 100,
      );
      await transactionRepository.addAllTransactions(testWalletId, [confirmedTx]);

      // 수신 output(index 0)은 사용자가 수동으로 잠금 처리한 상태로 저장
      final lockedReceiveUtxo = UtxoState(
        transactionHash: sharedTxHash,
        index: 0,
        amount: 1000000,
        derivationPath: "m/84'/0'/0'/0/0",
        blockHeight: 100,
        to: testWalletItem.walletBase.getAddress(0),
        timestamp: DateTime.now(),
        status: UtxoStatus.locked,
      );
      await utxoRepository.addAllUtxos(testWalletId, [lockedReceiveUtxo]);

      // 잔돈 output(index 1)의 scriptStatus - 잠근 적 없음
      final changeScriptStatus = ScriptStatus(
        derivationPath: "m/84'/0'/0'/1/0",
        address: testWalletItem.walletBase.getAddress(0, isChange: true),
        index: 0,
        isChange: true,
        scriptPubKey: 'change_script_pub_key',
        status: 'change_status_hash',
        timestamp: DateTime.now(),
      );

      // electrum이 잔돈 주소에 대해 같은 트랜잭션의 output 1을 반환하도록 모킹
      when(electrumService.getUnspentList(any, any)).thenAnswer((_) async {
        return [ListUnspentRes(height: 100, txHash: sharedTxHash, txPos: 1, value: 500000)];
      });

      // When: 잔돈 주소에 대해 UTXO 상태를 재계산
      final result = await utxoSyncService.fetchUtxoStateList(testWalletItem, changeScriptStatus);

      // Then: 잔돈 UTXO는 locked로 전파되지 않고 unspent 상태를 유지해야 함
      expect(result.length, 1);
      expect(result.first.transactionHash, sharedTxHash);
      expect(result.first.index, 1);
      expect(result.first.status, UtxoStatus.unspent);
    });

    test('전체 재동기화처럼 대량 콜드 스캔 도중, UTXO를 만든 트랜잭션이 아직 RealmTransaction에 없어도 '
        'UTXO 자체는 유실되지 않고 반환된다(예전 버그: null check로 전체 리스트가 빈 리스트로 대체됨)', () async {
      // Given: RealmTransaction에는 아무 것도 저장하지 않은 상태(트랜잭션 fetch가 아직 안 됐거나
      // 늦게 반영된 상황을 재현)
      const String unknownTxHash = 'not_yet_recorded_tx_hash';

      final scriptStatus = ScriptStatus(
        derivationPath: "m/84'/0'/0'/0/0",
        address: testWalletItem.walletBase.getAddress(0),
        index: 0,
        isChange: false,
        scriptPubKey: 'receive_script_pub_key',
        status: 'receive_status_hash',
        timestamp: DateTime.now(),
      );

      when(electrumService.getUnspentList(any, any)).thenAnswer((_) async {
        return [ListUnspentRes(height: 100, txHash: unknownTxHash, txPos: 0, value: 700000)];
      });

      // When
      final result = await utxoSyncService.fetchUtxoStateList(testWalletItem, scriptStatus);

      // Then: 예외로 인해 빈 리스트가 아니라, UTXO가 그대로(타임스탬프만 대체돼서) 반환돼야 함
      expect(result.length, 1);
      expect(result.first.transactionHash, unknownTxHash);
      expect(result.first.amount, 700000);
      expect(result.first.status, UtxoStatus.unspent);
    });
  });
}
