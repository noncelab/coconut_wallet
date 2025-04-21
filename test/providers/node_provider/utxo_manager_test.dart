import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/providers/node_provider/node_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';

import '../../mock/transaction_mock.dart';
import '../../mock/utxo_mock.dart';
import '../../mock/wallet_mock.dart';
import '../../repository/realm/test_realm_manager.dart';

@GenerateMocks([
  ElectrumService,
  NodeStateManager,
])
import 'utxo_manager_test.mocks.dart';

void main() {
  late TestRealmManager realmManager;
  late UtxoRepository utxoRepository;
  late MockElectrumService electrumService;
  late MockNodeStateManager stateManager;
  late UtxoSyncService utxoManager;
  late TransactionRepository transactionRepository;
  late AddressRepository addressRepository;
  SinglesigWalletListItem testWalletItem = WalletMock.createSingleSigWalletItem();
  const int testWalletId = 1;

  setUp(() async {
    realmManager = await setupTestRealmManager();
    utxoRepository = UtxoRepository(realmManager);
    transactionRepository = TransactionRepository(realmManager);
    addressRepository = AddressRepository(realmManager);
    electrumService = MockElectrumService();
    stateManager = MockNodeStateManager();

    utxoManager = UtxoSyncService(
      electrumService,
      stateManager,
      utxoRepository,
      transactionRepository,
      addressRepository,
    );
  });

  tearDown(() {
    realmManager.reset();
    realmManager.dispose();
  });

  group('UtxoManager 기능 테스트', () {
    final testAddress = testWalletItem.walletBase.getAddress(0);
    final toAddress = testWalletItem.walletBase.getAddress(9999);
    group('updateUtxoStatusToOutgoingByTransaction 테스트', () {
      test('기본 UTXO 상태 업데이트가 정상적으로 이루어지는지 확인', () {
        // 트랜잭션 생성
        final mockTx = TransactionMock.createMockTransaction(
          toAddress: testAddress,
          amount: 1000000,
        );

        // UTXO 추가 (unspent 상태)
        realmManager.realm.write(() {
          final utxo = UtxoMock.createUnspentUtxo(
            walletId: testWalletId,
            address: testAddress,
            amount: 1000000,
            transactionHash: mockTx.inputs[0].transactionHash,
            index: mockTx.inputs[0].index,
          );
          realmManager.realm.add(utxo);
        });

        // 함수 실행
        utxoManager.updateUtxoStatusToOutgoingByTransaction(
          testWalletId,
          mockTx,
        );

        // 검증
        final utxoId = makeUtxoId(
          mockTx.inputs[0].transactionHash,
          mockTx.inputs[0].index,
        );
        final updatedUtxo = utxoRepository.getUtxoState(testWalletId, utxoId);

        expect(updatedUtxo, isNotNull);
        expect(updatedUtxo!.status, equals(UtxoStatus.outgoing));
        expect(updatedUtxo.spentByTransactionHash, equals(mockTx.transactionHash));
      });

      test('자기 참조 UTXO는 업데이트되지 않아야 함', () {
        // 트랜잭션 생성
        final mockTx = TransactionMock.createMockTransaction(
          toAddress: testAddress,
          amount: 1000000,
        );

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

        // 함수 실행
        utxoManager.updateUtxoStatusToOutgoingByTransaction(
          testWalletId,
          mockTx,
        );

        // 검증 - spentByTransactionHash가 변경되지 않아야 함
        final utxoId = makeUtxoId(
          mockTx.inputs[0].transactionHash,
          mockTx.inputs[0].index,
        );
        final updatedUtxo = utxoRepository.getUtxoState(testWalletId, utxoId);

        expect(updatedUtxo, isNotNull);
        expect(updatedUtxo!.status, equals(UtxoStatus.outgoing));
        expect(updatedUtxo.spentByTransactionHash, equals(mockTx.transactionHash));
      });

      test('이미 outgoing 상태인 UTXO의 기존 spentByTransactionHash가 유지되어야 함', () {
        // 트랜잭션 생성
        final mockTx = TransactionMock.createMockTransaction(
          toAddress: toAddress,
          amount: 1000000,
        );

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

        // 함수 실행
        utxoManager.updateUtxoStatusToOutgoingByTransaction(
          testWalletId,
          mockTx,
        );

        // 검증 - spentByTransactionHash가 변경되지 않아야 함
        final utxoId = makeUtxoId(
          mockTx.inputs[0].transactionHash,
          mockTx.inputs[0].index,
        );
        final updatedUtxo = utxoRepository.getUtxoState(testWalletId, utxoId);

        expect(updatedUtxo, isNotNull);
        expect(updatedUtxo!.status, equals(UtxoStatus.outgoing));
        expect(updatedUtxo.spentByTransactionHash, equals(mockTx.transactionHash));
        expect(updatedUtxo.spentByTransactionHash, isNot(equals(previousTxHash)));
      });
    });
  });
}
