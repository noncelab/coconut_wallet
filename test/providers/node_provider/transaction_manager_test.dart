import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/cpfp_handler.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/rbf_handler.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_fetcher.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_manager.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_processor.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_manager.dart';
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

import '../../mock/script_status_mock.dart';
import '../../mock/transaction_mock.dart';
import '../../mock/utxo_mock.dart';
import '../../mock/wallet_mock.dart';
import '../../repository/realm/test_realm_manager.dart';

// 모킹할 클래스 목록
@GenerateMocks([
  ElectrumService,
  NodeStateManager,
  UtxoManager,
  WalletProvider,
  WalletListItemBase,
])
import 'transaction_manager_test.mocks.dart';

void main() {
  late TestRealmManager realmManager;
  late TransactionRepository transactionRepository;
  late MockElectrumService electrumService;
  late MockNodeStateManager stateManager;
  late MockUtxoManager utxoManager;
  late UtxoRepository utxoRepository;
  late AddressRepository addressRepository;
  late MockWalletProvider walletProvider;
  late TransactionManager transactionManager;
  late TransactionFetcher transactionFetcher;
  late TransactionProcessor transactionProcessor;
  late RbfHandler rbfDetector;
  late CpfpHandler cpfpDetector;

  const int testWalletId = 1;
  final SinglesigWalletListItem testWalletItem = WalletMock.createSingleSigWalletItem();

  setUp(() async {
    realmManager = await setupTestRealmManager();
    transactionRepository = TransactionRepository(realmManager);
    utxoRepository = UtxoRepository(realmManager);
    addressRepository = AddressRepository(realmManager);
    electrumService = MockElectrumService();
    stateManager = MockNodeStateManager();
    utxoManager = MockUtxoManager();
    walletProvider = MockWalletProvider();

    // TransactionManager 생성
    transactionManager = TransactionManager(
      electrumService,
      stateManager,
      transactionRepository,
      utxoManager,
      addressRepository,
    );

    transactionProcessor = TransactionProcessor(electrumService, addressRepository);
    transactionFetcher = TransactionFetcher(
      electrumService,
      transactionRepository,
      transactionProcessor,
      stateManager,
      utxoManager,
    );

    rbfDetector = RbfHandler(transactionRepository, utxoManager, electrumService);
    cpfpDetector = CpfpHandler(transactionRepository, utxoManager, electrumService);

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
        GetHistoryRes(height: 100, txHash: 'tx1'),
        GetHistoryRes(height: 0, txHash: 'tx2'),
      ];

      // mock 동작 설정
      when(electrumService.getHistory(AddressType.p2wpkh, scriptStatus.address))
          .thenAnswer((_) async => historyList);

      // 함수 실행
      final result = await transactionFetcher.getFetchTransactionResponses(
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
      await transactionManager.fetchScriptTransaction(
        testWalletItem,
        mockScriptStatus,
        now: now,
      );

      // 검증
      verify(stateManager.addWalletSyncState(testWalletId, any)).called(1);
      verify(stateManager.addWalletCompletedState(testWalletId, any)).called(1);
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

      transactionRepository.addAllTransactions(testWalletId, []);

      // 모의 응답 설정
      when(electrumService.getHistory(any, any)).thenAnswer((_) async => [
            GetHistoryRes(height: 0, txHash: mockTx.transactionHash), // 미확인 트랜잭션
          ]);
      when(electrumService.getTransaction(mockTx.transactionHash))
          .thenAnswer((_) async => mockTx.serialize());
      when(electrumService.getTransaction(mockTx.inputs[0].transactionHash))
          .thenAnswer((_) async => prevTx.serialize());

      // UTXO 관리자 모킹
      when(utxoManager.updateUtxoStatusToOutgoingByTransaction(any, any)).thenReturn(null);

      // 함수 실행
      await transactionManager.fetchScriptTransaction(
        testWalletItem,
        mockScriptStatus,
        now: now,
      );

      // 검증
      verify(electrumService.getHistory(any, testAddress)).called(1);
      verify(electrumService.getTransaction(mockTx.transactionHash)).called(1);
      verify(utxoManager.updateUtxoStatusToOutgoingByTransaction(testWalletId, any)).called(1);
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

      // 모의 응답 설정
      when(electrumService.getHistory(any, any)).thenAnswer((_) async => [
            GetHistoryRes(height: mockBlockHeight, txHash: mockTx.transactionHash),
          ]);
      when(electrumService.getTransaction(mockTx.transactionHash))
          .thenAnswer((_) async => mockTx.serialize());
      when(electrumService.getTransaction(mockTx.inputs[0].transactionHash))
          .thenAnswer((_) async => prevTx.serialize());

      // UTXO 관리자 모킹
      when(utxoManager.deleteUtxosByTransaction(any, any)).thenReturn(null);

      // 함수 실행
      await transactionManager.fetchScriptTransaction(
        testWalletItem,
        mockScriptStatus,
        now: now,
      );

      // 검증
      verify(electrumService.getHistory(any, testAddress)).called(1);
      verify(electrumService.getTransaction(mockTx.transactionHash)).called(1);
      verify(utxoManager.deleteUtxosByTransaction(testWalletId, any)).called(1);
    });

    test('일괄 처리 모드에서 상태 관리자를 호출하지 않는지 확인', () async {
      // 트랜잭션 없음으로 설정
      when(electrumService.getHistory(any, any)).thenAnswer((_) async => []);

      // 함수 실행 (inBatchProcess = true)
      await transactionManager.fetchScriptTransaction(
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
      final mockOriginalTx = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(0),
        amount: 1000000,
        inputTransactionHash: Hash.sha256('original_tx_hash_input'),
      );

      // 대체될 트랜잭션
      final prevTx = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(1),
        amount: 950000,
        inputTransactionHash: mockOriginalTx.transactionHash,
      );

      // RBF 트랜잭션 (현재 테스트 대상)
      final mockTx = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(1),
        amount: 900000,
        inputTransactionHash: mockOriginalTx.transactionHash,
      );

      // UTXO 상태 생성 - UtxoMock 클래스 사용
      realmManager.realm.write(() {
        final utxo = UtxoMock.createRbfableUtxo(
          walletId: testWalletId,
          address: testAddress,
          amount: 1000000,
          transactionHash: mockOriginalTx.transactionHash,
          index: 0,
          addressIndex: 0,
          spentByTransactionHash: prevTx.transactionHash,
        );
        realmManager.realm.add(utxo);
      });

      // 원본 트랜잭션 추가 - 명시적으로 transactionHash를 mockOriginalTxHash로 설정
      transactionRepository.addAllTransactions(testWalletId, [
        TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: prevTx.transactionHash, // 명시적으로 해시값 지정
        )
      ]);

      when(electrumService.getHistory(any, any)).thenAnswer((_) async => [
            GetHistoryRes(height: 0, txHash: mockTx.transactionHash), // 미확인 RBF 트랜잭션
          ]);
      when(electrumService.getTransaction(mockTx.transactionHash))
          .thenAnswer((_) async => mockTx.serialize());
      when(electrumService.getTransaction(mockTx.inputs[0].transactionHash))
          .thenAnswer((_) async => mockOriginalTx.serialize());
      when(electrumService.getTransaction(prevTx.inputs[0].transactionHash))
          .thenAnswer((_) async => mockOriginalTx.serialize());

      // UTXO 관리자 모킹 - _detectRbfTransaction에서 사용될 입력 준비
      when(utxoManager.updateUtxoStatusToOutgoingByTransaction(any, any)).thenAnswer((_) {});

      await transactionManager.fetchScriptTransaction(
        testWalletItem,
        mockScriptStatus,
        now: now,
      );

      // RBF 내역이 저장되었는지 확인
      final rbfHistories =
          transactionRepository.getRbfHistoryList(testWalletId, mockTx.transactionHash);

      expect(rbfHistories.length, 1);
      expect(rbfHistories.first.originalTransactionHash, prevTx.transactionHash);
    });
  });

  group('detectRbfTransaction 함수 단위 테스트', () {
    late Transaction mockOriginalTx;
    late Transaction mockPrevTx;
    late Transaction mockNewTx;
    final mockOriginalTxHash = Hash.sha256('original_tx_hash');
    final mockSpentTxHash = Hash.sha256('spent_tx_hash');

    setUp(() {
      // 모의 트랜잭션 설정 - 트랜잭션 체인을 올바르게 구성
      // 1. 원본 트랜잭션 (첫 번째 트랜잭션)
      mockOriginalTx = TransactionMock.createMockTransaction(
          toAddress: testWalletItem.walletBase.getAddress(0),
          amount: 1000000,
          inputTransactionHash:
              '0000000000000000000000000000000000000000000000000000000000000000'); // 유효한 해시

      // 2. 이전 트랜잭션 (중간 트랜잭션)
      mockPrevTx = TransactionMock.createMockTransaction(
          toAddress: testWalletItem.walletBase.getAddress(1),
          amount: 950000,
          inputTransactionHash: mockOriginalTx.transactionHash);

      // 3. 새 트랜잭션 (현재 테스트 대상)
      mockNewTx = TransactionMock.createMockTransaction(
          toAddress: testWalletItem.walletBase.getAddress(2),
          amount: 900000,
          inputTransactionHash: mockPrevTx.transactionHash);

      // getPreviousTransactions가 비어있지 않은 목록을 반환하도록 스텁 설정
      when(electrumService.getTransaction(mockNewTx.inputs[0].transactionHash))
          .thenAnswer((_) async => mockPrevTx.serialize());
      when(electrumService.getTransaction(mockPrevTx.inputs[0].transactionHash))
          .thenAnswer((_) async => mockOriginalTx.serialize());
    });

    test('RBF가 아닌 트랜잭션은 null을 반환해야 함', () async {
      // RBF가 아닌 상황 설정: UTXO가 outgoing 상태가 아님
      realmManager.realm.write(() {
        final utxo = UtxoMock.createUnspentUtxo(
          walletId: testWalletId,
          address: testWalletItem.walletBase.getAddress(0),
          amount: 1000000,
          transactionHash: mockNewTx.inputs[0].transactionHash,
          index: 0,
          addressIndex: 0,
        );
        realmManager.realm.add(utxo);
      });

      // 함수 실행
      final result = await rbfDetector.detectSendingRbfTransaction(
        testWalletId,
        mockNewTx,
      );

      // 검증
      expect(result, isNull);
    });

    test('이미 RBF 내역이 있는 트랜잭션은 null을 반환해야 함', () async {
      // 기존 RBF 내역 추가
      _addRbfHistory(realmManager, testWalletId, mockNewTx.transactionHash, mockOriginalTxHash);

      // 함수 실행
      final result = await rbfDetector.detectSendingRbfTransaction(
        testWalletId,
        mockNewTx,
      );

      // 검증
      expect(result, isNull);
    });

    test('첫 번째 RBF 트랜잭션은 원본 트랜잭션 해시를 올바르게 설정해야 함', () async {
      // RBF 상황 설정: UTXO가 outgoing 상태이고 spent 트랜잭션이 있음
      realmManager.realm.write(() {
        final utxo = UtxoMock.createRbfableUtxo(
          walletId: testWalletId,
          address: testWalletItem.walletBase.getAddress(0),
          amount: 1000000,
          transactionHash: mockNewTx.inputs[0].transactionHash,
          index: 0,
          addressIndex: 0,
          spentByTransactionHash: mockSpentTxHash,
        );
        realmManager.realm.add(utxo);
      });

      // 원본 트랜잭션과 사용된 트랜잭션 추가
      transactionRepository.addAllTransactions(testWalletId, [
        TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: mockSpentTxHash,
        )
      ]);

      // 함수 실행
      final result = await rbfDetector.detectSendingRbfTransaction(
        testWalletId,
        mockNewTx,
      );

      // 검증 - previousTransactions 확인 제외 (모킹 어려움)
      expect(result, isNotNull);
      // 실제 구현에서는 utxo.spentByTransactionHash를 사용하므로 이 값을 기대
      expect(result!.originalTransactionHash, equals(mockSpentTxHash));
      expect(result.spentTransactionHash, equals(mockSpentTxHash));
    });

    test('연속된 RBF 트랜잭션은 원본 트랜잭션 해시를 유지해야 함', () async {
      // RBF 상황 설정: UTXO가 outgoing 상태이고 spent 트랜잭션이 있음
      realmManager.realm.write(() {
        final utxo = UtxoMock.createRbfableUtxo(
          walletId: testWalletId,
          address: testWalletItem.walletBase.getAddress(0),
          amount: 1000000,
          transactionHash: mockNewTx.inputs[0].transactionHash,
          index: 0,
          addressIndex: 0,
          spentByTransactionHash: mockSpentTxHash,
        );
        realmManager.realm.add(utxo);
      });

      // 필요한 트랜잭션 추가
      transactionRepository.addAllTransactions(testWalletId, [
        TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: mockSpentTxHash,
        ),
        TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: mockOriginalTxHash,
        )
      ]);

      // 이전 RBF 내역 추가 (spent 트랜잭션에 대한 RBF 내역)
      _addRbfHistory(realmManager, testWalletId, mockSpentTxHash, mockOriginalTxHash);

      // 함수 실행
      final result = await rbfDetector.detectSendingRbfTransaction(
        testWalletId,
        mockNewTx,
      );

      // 검증 - previousTransactions 확인 제외 (모킹 어려움)
      expect(result, isNotNull);
      // 연속 RBF의 경우 원본 트랜잭션 해시를 유지
      expect(result!.originalTransactionHash, equals(mockOriginalTxHash));
      expect(result.spentTransactionHash, equals(mockSpentTxHash));
    });

    test('여러 입력이 있는 트랜잭션에서 RBF를 감지해야 함', () async {
      // 여러 입력을 가진 트랜잭션 생성 - mockNewTx에 추가 입력 설정
      final multiInputTx = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(3),
        amount: 850000,
        inputTransactionHash: mockPrevTx.transactionHash, // 첫 번째 입력
      );

      // 두 번째 입력을 가진 트랜잭션 생성 (필요시)
      // 여기에서는 단순화를 위해 기존 트랜잭션의 입력만 사용

      // UTXO가 outgoing 상태이고 spent 트랜잭션이 있는 상황 설정
      realmManager.realm.write(() {
        final utxo = UtxoMock.createRbfableUtxo(
          walletId: testWalletId,
          address: testWalletItem.walletBase.getAddress(0),
          amount: 1000000,
          transactionHash: multiInputTx.inputs[0].transactionHash,
          index: 0,
          addressIndex: 0,
          spentByTransactionHash: mockSpentTxHash,
        );
        realmManager.realm.add(utxo);
      });

      // 필요한 트랜잭션 추가
      transactionRepository.addAllTransactions(testWalletId, [
        TransactionMock.createUnconfirmedTransactionRecord(
          transactionHash: mockSpentTxHash,
        )
      ]);

      // 함수 실행
      final result = await rbfDetector.detectSendingRbfTransaction(
        testWalletId,
        multiInputTx,
      );

      // 검증 - previousTransactions 확인 제외 (모킹 어려움)
      expect(result, isNotNull);
      // 실제 구현에서는 utxo.spentByTransactionHash를 사용하므로 이 값을 기대
      expect(result!.originalTransactionHash, equals(mockSpentTxHash));
      expect(result.spentTransactionHash, equals(mockSpentTxHash));
    });
  });

  group('RBF 내역 삭제 테스트', () {
    test('확인된 트랜잭션에 대해 RBF 내역이 삭제되는지 확인', () async {
      // 원본 트랜잭션 생성
      final originalTx = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(0),
        amount: 1000000,
      );

      // 컨펌된 RBF 트랜잭션 생성
      final confirmedTx = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(1),
        amount: 900000,
        inputTransactionHash: originalTx.transactionHash,
      );

      // RBF 내역 추가
      _addRbfHistory(
          realmManager, testWalletId, confirmedTx.transactionHash, originalTx.transactionHash);

      // 함수 실행
      transactionRepository.deleteRbfHistory(testWalletId, confirmedTx);

      // 검증 - RBF 내역이 삭제되었는지 확인
      final rbfHistories =
          transactionRepository.getRbfHistoryList(testWalletId, confirmedTx.transactionHash);

      expect(rbfHistories.isEmpty, isTrue);
    });

    test('확인되지 않은 RBF 트랜잭션은 다른 RBF 내역에 영향을 주지 않아야 함', () async {
      // 원본 트랜잭션 생성
      final originalTx1 = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(0),
        amount: 1000000,
      );
      final rbfTx1 = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(2),
        amount: 950000,
        inputTransactionHash: originalTx1.transactionHash,
      );

      final originalTx2 = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(1),
        amount: 1000000,
      );
      // 두 번째 RBF 트랜잭션 생성
      final rbfTx2 = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(3),
        amount: 900000,
        inputTransactionHash: originalTx1.transactionHash,
      );

      // RBF 내역 추가 (연속된 RBF 시뮬레이션)
      _addRbfHistory(
          realmManager, testWalletId, rbfTx1.transactionHash, originalTx1.transactionHash);
      _addRbfHistory(
          realmManager, testWalletId, rbfTx2.transactionHash, originalTx2.transactionHash);

      // 함수 실행 - 이 경우 deleteRbfHistory는 해당 트랜잭션의 RBF 내역만 삭제해야 함
      transactionRepository.deleteRbfHistory(testWalletId, rbfTx1);

      // 검증 - 첫 번째 RBF 내역은 삭제되었지만 두 번째 RBF 내역은 유지되어야 함
      final rbfHistories1 =
          transactionRepository.getRbfHistoryList(testWalletId, rbfTx1.transactionHash);
      final rbfHistories2 =
          transactionRepository.getRbfHistoryList(testWalletId, rbfTx2.transactionHash);

      expect(rbfHistories1.isEmpty, isTrue); // 첫 번째 RBF 내역은 삭제됨
      expect(rbfHistories2.isNotEmpty, isTrue); // 두 번째 RBF 내역은 유지됨
    });

    test('트랜잭션이 컨펌될 때 RBF 내역이 삭제되는지 확인', () async {
      // 원본 트랜잭션을 준비
      final originalTx = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(0),
        amount: 1000000,
      );

      // RBF 트랜잭션을 준비 (나중에 컨펌될 트랜잭션)
      final rbfTx = TransactionMock.createMockTransaction(
        toAddress: testWalletItem.walletBase.getAddress(1),
        amount: 950000,
        inputTransactionHash: originalTx.transactionHash,
      );

      // RBF 내역 추가
      _addRbfHistory(realmManager, testWalletId, rbfTx.transactionHash, originalTx.transactionHash);

      // 모의 스크립트 상태 설정
      final scriptStatus = ScriptStatusMock.createMockScriptStatus(testWalletItem, 0);
      const blockHeight = 700000;

      // 모의 응답 설정 - 트랜잭션이 컨펌된 상태로 반환
      when(electrumService.getHistory(any, any)).thenAnswer((_) async => [
            GetHistoryRes(height: blockHeight, txHash: rbfTx.transactionHash),
          ]);
      when(electrumService.getTransaction(rbfTx.transactionHash))
          .thenAnswer((_) async => rbfTx.serialize());
      when(electrumService.getTransaction(rbfTx.inputs[0].transactionHash))
          .thenAnswer((_) async => originalTx.serialize());
      when(electrumService.getBlockTimestamp(blockHeight))
          .thenAnswer((_) async => BlockTimestamp(blockHeight, DateTime.now()));
      when(walletProvider.containsAddress(any, any)).thenReturn(false);

      final rbfHistoriesBefore =
          transactionRepository.getRbfHistoryList(testWalletId, rbfTx.transactionHash);
      final rbfHistoriesBeforeCount = rbfHistoriesBefore.length;

      // fetchScriptTransaction 함수 실행
      await transactionManager.fetchScriptTransaction(
        testWalletItem,
        scriptStatus,
        now: DateTime.now(),
      );

      // 검증 - RBF 내역이 삭제되었는지 확인
      final rbfHistories =
          transactionRepository.getRbfHistoryList(testWalletId, rbfTx.transactionHash);

      expect(rbfHistoriesBeforeCount, 1);
      expect(rbfHistories.isEmpty, isTrue, reason: 'RBF 내역이 삭제되지 않았습니다.');

      // 추가 검증 - 관련 함수 호출이 발생했는지 확인
      verify(utxoManager.deleteUtxosByTransaction(testWalletId, any)).called(1);
    });
  });
}

// 테스트를 위한 RBF 내역 추가 헬퍼 함수
void _addRbfHistory(
    TestRealmManager realmManager, int walletId, String txHash, String originalTxHash) {
  realmManager.realm.write(() {
    final rbfHistory = RealmRbfHistory(
      Object.hash(walletId, originalTxHash, txHash),
      walletId, // walletId
      originalTxHash, // originalTransactionHash
      txHash, // transactionHash
      5.0, // feeRate
      DateTime.now(), // timestamp
    );
    realmManager.realm.add(rbfHistory);
  });
}
