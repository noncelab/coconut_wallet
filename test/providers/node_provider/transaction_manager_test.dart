import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/transaction_manager.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_manager.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/converter/utxo.dart';
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
  late MockWalletProvider walletProvider;
  late TransactionManager transactionManager;

  const int testWalletId = 1;
  const String testTxHash = 'test_tx_hash';
  final SinglesigWalletListItem testWalletItem =
      WalletMock.createSingleSigWalletItem();

  setUp(() async {
    realmManager = await setupTestRealmManager();
    transactionRepository = TransactionRepository(realmManager);
    utxoRepository = UtxoRepository(realmManager);

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
      utxoRepository,
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
      final scriptStatus =
          ScriptStatusMock.createMockScriptStatus(testWalletItem, 0);

      // 모의 historyList 설정
      final historyList = [
        GetHistoryRes(height: 100, txHash: 'tx1'),
        GetHistoryRes(height: 0, txHash: 'tx2'),
      ];

      // mock 동작 설정
      when(electrumService.getHistory(AddressType.p2wpkh, scriptStatus.address))
          .thenAnswer((_) async => historyList);

      // 함수 실행
      final result = await transactionManager.getFetchTransactionResponses(
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
      final unconfirmedTx =
          TransactionMock.createUnconfirmedTransactionRecord();

      // 트랜잭션 저장
      transactionRepository.addAllTransactions(testWalletId, [unconfirmedTx]);

      // 블록 타임스탬프 생성
      const blockHeight = 680000;
      final blockTimestamp =
          DateTime.fromMillisecondsSinceEpoch(1625097600 * 1000);

      // 블록 타임스탬프 저장
      realmManager.realm.write(() {
        realmManager.realm
            .add(RealmBlockTimestamp(blockHeight, blockTimestamp));
      });

      // 업데이트할 트랜잭션 정보 준비
      final fetchedTxMap = {
        testTxHash: FetchTransactionResponse(
          transactionHash: testTxHash,
          height: blockHeight,
          addressIndex: 0,
          isChange: false,
        )
      };

      final blockTimestampMap = {
        blockHeight: BlockTimestamp(blockHeight, blockTimestamp)
      };

      // 트랜잭션 상태 업데이트
      await transactionRepository.updateTransactionStates(
        testWalletId,
        [testTxHash], // 업데이트할 트랜잭션
        [], // 삭제할 트랜잭션 없음
        fetchedTxMap,
        blockTimestampMap,
      );

      // 업데이트된 트랜잭션 조회
      final updatedTx =
          transactionRepository.getTransactionRecord(testWalletId, testTxHash);
      final wallet = realmManager.realm.find<RealmWalletBase>(testWalletId);

      expect(updatedTx, isNotNull);
      expect(updatedTx!.blockHeight, blockHeight);
      expect(updatedTx.timestamp, isNotNull);
      final updatedTimestamp = updatedTx.timestamp;
      if (updatedTimestamp != null) {
        expect(updatedTimestamp.millisecondsSinceEpoch ~/ 1000,
            blockTimestamp.millisecondsSinceEpoch ~/ 1000);
      }
    });
  });

  group('fetchScriptTransaction 테스트', () {
    late ScriptStatus mockScriptStatus;
    final testAddress = testWalletItem.walletBase.getAddress(0);
    final now = DateTime.now();

    setUp(() {
      mockScriptStatus =
          ScriptStatusMock.createMockScriptStatus(testWalletItem, 0);
      // 모킹 기본 설정
      when(walletProvider.containsAddress(any, any)).thenReturn(false);

      when(electrumService.getBlockTimestamp(any))
          .thenAnswer((invocation) async {
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
        walletProvider,
        now: now,
      );

      // 검증
      verify(stateManager.addWalletSyncState(testWalletId, any)).called(1);
      verify(stateManager.addWalletCompletedState(testWalletId, any)).called(1);
      verify(electrumService.getHistory(any, testAddress)).called(1);
    });

    test('미확인 트랜잭션 처리를 올바르게 하는지 확인', () async {
      // 모의 트랜잭션 응답
      final mockTx = TransactionMock.createMockTransaction(
          testWalletItem.walletBase.getAddress(9999), 1000000);
      final prevTx = TransactionMock.createMockTransaction(
          testWalletItem.walletBase.getAddress(0), 1000000);

      transactionRepository.addAllTransactions(testWalletId, []);

      // 모의 응답 설정
      when(electrumService.getHistory(any, any)).thenAnswer((_) async => [
            GetHistoryRes(
                height: 0, txHash: mockTx.transactionHash), // 미확인 트랜잭션
          ]);
      when(electrumService.getTransaction(mockTx.transactionHash))
          .thenAnswer((_) async => mockTx.serialize());
      when(electrumService.getTransaction(mockTx.inputs[0].transactionHash))
          .thenAnswer((_) async => prevTx.serialize());

      // UTXO 관리자 모킹
      when(utxoManager.updateUtxoStatusToOutgoingByTransaction(any, any))
          .thenReturn(null);

      // 함수 실행
      await transactionManager.fetchScriptTransaction(
        testWalletItem,
        mockScriptStatus,
        walletProvider,
        now: now,
      );

      // 검증
      verify(electrumService.getHistory(any, testAddress)).called(1);
      verify(electrumService.getTransaction(mockTx.transactionHash)).called(1);
      verify(utxoManager.updateUtxoStatusToOutgoingByTransaction(
              testWalletId, any))
          .called(1);
    });

    test('확인된 트랜잭션 처리를 올바르게 하는지 확인', () async {
      // 모의 트랜잭션 응답
      final mockTx = TransactionMock.createMockTransaction(
          testWalletItem.walletBase.getAddress(9999), 1000000);
      final prevTx = TransactionMock.createMockTransaction(
          testWalletItem.walletBase.getAddress(0), 1000000);
      const mockBlockHeight = 700000;

      // 모의 응답 설정
      when(electrumService.getHistory(any, any)).thenAnswer((_) async => [
            GetHistoryRes(
                height: mockBlockHeight, txHash: mockTx.transactionHash),
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
        walletProvider,
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
        walletProvider,
        now: now,
        inBatchProcess: true,
      );

      // 검증 - 상태 관리자가 호출되지 않아야 함
      verifyNever(stateManager.addWalletSyncState(any, any));
      verifyNever(stateManager.addWalletCompletedState(any, any));
    });

    test('RBF 트랜잭션을 감지하고 처리하는지 확인', () async {
      // 모의 RBF 시나리오 설정
      final mockTx = TransactionMock.createMockTransaction(
          testWalletItem.walletBase.getAddress(9999), 1000000);
      final prevTx = TransactionMock.createMockTransaction(
          testWalletItem.walletBase.getAddress(0), 1000000);
      const mockOriginalTxHash = 'original_tx_hash';

      // UTXO 상태 생성 (RealmUtxoState 대신 적절한 Realm 모델 객체 사용)
      final utxoId = '${mockTx.inputs[0].transactionHash}:0';
      realmManager.realm.write(() {
        final utxo = RealmUtxo(
          utxoId, // id
          testWalletId, // walletId
          testAddress, // address
          1000000, // amount
          DateTime.now(), // timestamp
          mockTx.inputs[0].transactionHash, // transactionHash
          0, // index
          "m/84'/0'/0'/0/0", // derivationPath
          0, // blockHeight
          utxoStatusToString(UtxoStatus.outgoing), // status
        );
        utxo.spentByTransactionHash = mockOriginalTxHash;
        realmManager.realm.add(utxo);
      });

      // 원본 트랜잭션 추가
      transactionRepository.addAllTransactions(testWalletId, [
        TransactionRecord(
          mockOriginalTxHash,
          DateTime.now(),
          0, // 미확인 상태
          'SEND',
          '원본 트랜잭션',
          1000000,
          10000,
          [], // 입력 주소 리스트
          [], // 출력 주소 리스트
          250, // vSize
          DateTime.now(), // 생성 시간
        )
      ]);

      // 모의 응답 설정
      when(electrumService.getHistory(any, any)).thenAnswer((_) async => [
            GetHistoryRes(
                height: 0, txHash: mockTx.transactionHash), // 미확인 RBF 트랜잭션
          ]);
      when(electrumService.getTransaction(mockTx.transactionHash))
          .thenAnswer((_) async => mockTx.serialize());
      when(electrumService.getTransaction(mockTx.inputs[0].transactionHash))
          .thenAnswer((_) async => prevTx.serialize());

      // UTXO 관리자 모킹 - _detectRbfTransaction에서 사용될 입력 준비
      when(utxoManager.updateUtxoStatusToOutgoingByTransaction(any, any))
          .thenAnswer((_) {
        // RBF 시뮬레이션을 위한 모킹 작업
        return;
      });

      // 함수 실행
      await transactionManager.fetchScriptTransaction(
        testWalletItem,
        mockScriptStatus,
        walletProvider,
        now: now,
      );

      // RBF 내역이 저장되었는지 확인
      final rbfHistories = transactionRepository.getRbfHistoryList(
          testWalletId, mockTx.transactionHash);

      // 검증 (직접적인 RBF 저장 검증은 실제 구현에 따라 다를 수 있음)
      verify(electrumService.getHistory(any, testAddress)).called(1);
      verify(electrumService.getTransaction(mockTx.transactionHash)).called(1);

      expect(rbfHistories.length, 1);
      expect(rbfHistories.first.transactionHash, mockOriginalTxHash);
    });
  });
}
