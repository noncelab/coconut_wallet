import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import '../../../mock/script_status_mock.dart';
import '../../../mock/transaction_mock.dart';
import '../../../mock/utxo_mock.dart';
import '../../../mock/wallet_mock.dart';
import '../../../repository/realm/test_realm_manager.dart';

// 모킹할 클래스 목록
@GenerateMocks([
  ElectrumService,
  NodeStateManager,
  WalletProvider,
])
import 'transaction_sync_service_test.mocks.dart';

void main() {
  late TestRealmManager realmManager;
  late TransactionRepository transactionRepository;
  late MockElectrumService electrumService;
  late MockNodeStateManager stateManager;
  late UtxoRepository utxoRepository;
  late AddressRepository addressRepository;
  late MockWalletProvider walletProvider;
  late TransactionSyncService transactionSyncService;
  late TransactionRecordService transactionRecordService;
  late ScriptCallbackService scriptCallbackService;

  const int testWalletId = 1;
  final SinglesigWalletListItem testWalletItem = WalletMock.createSingleSigWalletItem();

  setUp(() async {
    realmManager = await setupTestRealmManager();
    transactionRepository = TransactionRepository(realmManager);
    addressRepository = AddressRepository(realmManager);
    electrumService = MockElectrumService();
    stateManager = MockNodeStateManager();
    utxoRepository = UtxoRepository(realmManager);
    walletProvider = MockWalletProvider();
    scriptCallbackService = ScriptCallbackService();

    transactionRecordService = TransactionRecordService(electrumService, addressRepository);

    // TransactionManager 생성
    transactionSyncService = TransactionSyncService(
      electrumService,
      transactionRepository,
      transactionRecordService,
      stateManager,
      utxoRepository,
      scriptCallbackService,
    );
    transactionSyncService = TransactionSyncService(
      electrumService,
      transactionRepository,
      transactionRecordService,
      stateManager,
      utxoRepository,
      scriptCallbackService,
    );

    // 테스트용 지갑 생성
    realmManager.realm.write(() {
      realmManager.realm.add(RealmWalletBase(
        testWalletId, // id
        0, // colorIndex
        0, // iconIndex
        'test_descriptor', // descriptor
        'Test Wallet', // name
        'singleSignature', // walletType
      ));
    });
  });

  tearDown(() {
    realmManager.reset();
    realmManager.dispose();
  });

  group('TransactionManager 기능 테스트', () {
    test('getFetchTransactionResponses가 올바르게 작동하는지 확인', () async {
      // 스크립트 상태 설정
      final scriptStatus = ScriptStatusMock.createMockScriptStatus(testWalletItem, 0);

      // 모의 historyList 설정
      final historyList = [
        GetTxHistoryRes(height: 100, txHash: 'tx1'),
        GetTxHistoryRes(height: 0, txHash: 'tx2'),
      ];

      // mock 동작 설정
      when(electrumService.getHistory(AddressType.p2wpkh, scriptStatus.address))
          .thenAnswer((_) async => historyList);

      // 함수 실행
      final result = await transactionSyncService.getFetchTransactionResponses(
        AddressType.p2wpkh,
        scriptStatus,
        {'known_tx_hash'}, // 이미 알고 있는 트랜잭션 해시
      );

      // 검증
      expect(result.length, 2);
      expect(result[0].transactionHash, 'tx1');
      expect(result[0].height, 100);
      expect(result[1].transactionHash, 'tx2');
      expect(result[1].height, 0);
    });
  });

  group('트랜잭션 상태 변경 테스트', () {
    test('미확인 트랜잭션이 확인 상태로 업데이트되는지 확인', () async {
      // 테스트용 미확인 트랜잭션 추가
      final unconfirmedTx = TransactionMock.createUnconfirmedTransactionRecord();

      // 트랜잭션 저장
      transactionRepository.addAllTransactions(testWalletId, [unconfirmedTx]);

      // 블록 타임스탬프 생성
      const blockHeight = 2100;
      final blockTimestamp = DateTime.now();

      // 블록 타임스탬프 저장
      realmManager.realm.write(() {
        realmManager.realm.add(RealmBlockTimestamp(blockHeight, blockTimestamp));
      });

      // 업데이트할 트랜잭션 정보 준비
      final fetchedTxMap = {
        unconfirmedTx.transactionHash: FetchTransactionResponse(
          transactionHash: unconfirmedTx.transactionHash,
          height: blockHeight,
          addressIndex: 0,
          isChange: false,
        )
      };

      final blockTimestampMap = {blockHeight: BlockTimestamp(blockHeight, blockTimestamp)};

      // 트랜잭션 상태 업데이트
      await transactionRepository.updateTransactionStates(
        testWalletId,
        [unconfirmedTx.transactionHash], // 업데이트할 트랜잭션
        [], // 삭제할 트랜잭션 없음
        fetchedTxMap,
        blockTimestampMap,
      );

      // 업데이트된 트랜잭션 조회
      final updatedTx =
          transactionRepository.getTransactionRecord(testWalletId, unconfirmedTx.transactionHash);

      expect(updatedTx, isNotNull);
      expect(updatedTx!.blockHeight, blockHeight);
      expect(updatedTx.timestamp, isNotNull);
      final updatedTimestamp = updatedTx.timestamp;
      expect(updatedTimestamp.millisecondsSinceEpoch ~/ 1000,
          blockTimestamp.millisecondsSinceEpoch ~/ 1000);
    });
  });

  group('fetchScriptTransaction 테스트', () {
    late ScriptStatus mockScriptStatus;
    final testAddress = testWalletItem.walletBase.getAddress(0);
    final now = DateTime.now();

    setUp(() {
      mockScriptStatus = ScriptStatusMock.createMockScriptStatus(testWalletItem, 0);
      // 모킹 기본 설정
      when(walletProvider.containsAddress(any, any)).thenReturn(false);

      when(electrumService.getBlockTimestamp(any)).thenAnswer((invocation) async {
        final height = invocation.positionalArguments[0] as int;
        return BlockTimestamp(height, DateTime.now());
      });
    });

    test('트랜잭션이 없을 때 정상적으로 처리되는지 확인', () async {
      // 빈 트랜잭션 목록 반환하도록 설정
      when(electrumService.getHistory(any, any)).thenAnswer((_) async => []);

      // 상태 관리자 호출 검증 설정
      when(stateManager.addWalletSyncState(any, any)).thenReturn(null);
      when(stateManager.addWalletCompletedState(any, any)).thenReturn(null);

      // 함수 실행
      await transactionSyncService.fetchScriptTransaction(
        testWalletItem,
        mockScriptStatus,
        now: now,
        inBatchProcess: false,
      );

      // 검증
      verify(stateManager.addWalletSyncState(testWalletId, UpdateElement.transaction)).called(1);
      verify(stateManager.addWalletCompletedState(testWalletId, UpdateElement.transaction))
          .called(1);
      verify(electrumService.getHistory(any, testAddress)).called(1);
    });

    test('미확인 트랜잭션 처리를 올바르게 하는지 확인', () async {
      // 모의 트랜잭션 응답
      final prevTx = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(0),
        amount: 1000000,
      );
      final mockTx = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(9999),
        amount: 1000000,
        inputTransactionHash: prevTx.transactionHash,
      );

      await transactionRepository.addAllTransactions(testWalletId, []);

      // 모의 응답 설정
      when(electrumService.getHistory(any, any)).thenAnswer((_) async => [
            GetTxHistoryRes(height: 0, txHash: mockTx.transactionHash), // 미확인 트랜잭션
          ]);
      when(electrumService.getTransaction(mockTx.transactionHash))
          .thenAnswer((_) async => mockTx.serialize());
      when(electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList')))
          .thenAnswer((_) async => [prevTx]);

      // 함수 실행
      await transactionSyncService.fetchScriptTransaction(
        testWalletItem,
        mockScriptStatus,
        now: now,
      );

      // 검증
      verify(electrumService.getHistory(any, testAddress)).called(1);
      verify(electrumService.getTransaction(mockTx.transactionHash)).called(2);
    });

    test('확인된 트랜잭션 처리를 올바르게 하는지 확인', () async {
      // 모의 트랜잭션 응답
      final prevTx = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(0),
        amount: 1000000,
      );
      final mockTx = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(9999),
        amount: 1000000,
        inputTransactionHash: prevTx.transactionHash,
      );
      const mockBlockHeight = 700000;
      final mockBlockTimestamp = BlockTimestamp(mockBlockHeight, DateTime.now());

      // 모의 응답 설정
      when(electrumService.getHistory(any, any)).thenAnswer((_) async => [
            GetTxHistoryRes(height: mockBlockHeight, txHash: mockTx.transactionHash),
          ]);
      when(electrumService.getTransaction(mockTx.transactionHash))
          .thenAnswer((_) async => mockTx.serialize());
      when(electrumService.getTransaction(mockTx.inputs[0].transactionHash))
          .thenAnswer((_) async => prevTx.serialize());
      when(electrumService.fetchBlocksByHeight(any)).thenAnswer((_) async => {
            mockBlockHeight: mockBlockTimestamp,
          });
      when(electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList')))
          .thenAnswer((_) async => [prevTx]);

      // 함수 실행
      await transactionSyncService.fetchScriptTransaction(
        testWalletItem,
        mockScriptStatus,
        now: now,
      );

      // 검증
      verify(electrumService.getHistory(any, testAddress)).called(1);
      verify(electrumService.getTransaction(mockTx.transactionHash)).called(1);
    });

    test('일괄 처리 모드에서 상태 관리자를 호출하지 않는지 확인', () async {
      // 트랜잭션 없음으로 설정
      when(electrumService.getHistory(any, any)).thenAnswer((_) async => []);

      // 함수 실행 (inBatchProcess = true)
      await transactionSyncService.fetchScriptTransaction(
        testWalletItem,
        mockScriptStatus,
        now: now,
        inBatchProcess: true,
      );

      // 검증 - 상태 관리자가 호출되지 않아야 함
      verifyNever(stateManager.addWalletSyncState(any, any));
      verifyNever(stateManager.addWalletCompletedState(any, any));
    });

    test('RBF 트랜잭션을 감지하고 처리하는지 확인', () async {
      // 이전 트랜잭션을 먼저 생성하고 해시를 얻음
      final originalTx = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(0),
        amount: 1000000,
        inputTransactionHash: Hash.sha256('original_tx_hash_input'),
      );

      // 대체될 트랜잭션
      final prevTx = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(1),
        amount: 950000,
        inputTransactionHash: originalTx.transactionHash,
      );

      // RBF 트랜잭션 (현재 테스트 대상)
      final rbfTx = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(1),
        amount: 900000,
        inputTransactionHash: originalTx.transactionHash,
      );

      // UTXO 상태 생성 - UtxoMock 클래스 사용
      realmManager.realm.write(() {
        final utxo = UtxoMock.createRbfableUtxo(
          walletId: testWalletId,
          address: testAddress,
          amount: 1000000,
          transactionHash: originalTx.transactionHash,
          index: 0,
          addressIndex: 0,
          spentByTransactionHash: prevTx.transactionHash,
        );
        realmManager.realm.add(utxo);
      });

      // 원본 트랜잭션 추가 - 명시적으로 transactionHash를 mockOriginalTxHash로 설정
      await transactionRepository.addAllTransactions(testWalletId, [
        TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: prevTx.transactionHash, // 명시적으로 해시값 지정
        )
      ]);

      when(electrumService.getHistory(any, any)).thenAnswer((_) async => [
            GetTxHistoryRes(height: 0, txHash: rbfTx.transactionHash), // 미확인 RBF 트랜잭션
          ]);
      when(electrumService.getTransaction(rbfTx.transactionHash))
          .thenAnswer((_) async => rbfTx.serialize());
      when(electrumService.getTransaction(rbfTx.inputs[0].transactionHash))
          .thenAnswer((_) async => originalTx.serialize());
      when(electrumService.getTransaction(prevTx.inputs[0].transactionHash))
          .thenAnswer((_) async => originalTx.serialize());
      when(electrumService.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList')))
          .thenAnswer((_) async => [originalTx]);

      await transactionSyncService.fetchScriptTransaction(
        testWalletItem,
        mockScriptStatus,
        now: now,
      );

      // RBF 내역이 저장되었는지 확인
      final rbfHistories =
          transactionRepository.getRbfHistoryList(testWalletId, rbfTx.transactionHash);

      expect(rbfHistories.length, 2);
      expect(rbfHistories.first.originalTransactionHash, prevTx.transactionHash);
      expect(rbfHistories.last.originalTransactionHash, prevTx.transactionHash);
    });
  });
}
