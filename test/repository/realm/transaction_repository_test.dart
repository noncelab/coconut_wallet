import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/cpfp_history.dart';
import 'package:coconut_wallet/model/node/rbf_history.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_list_item.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mock/transaction_mock.dart';
import '../../mock/wallet_mock.dart';
import 'test_realm_manager.dart';

void main() {
  late TestRealmManager realmManager;
  late TransactionRepository transactionRepository;
  SinglesigWalletListItem testWalletItem = WalletMock.createSingleSigWalletItem();

  setUp(() async {
    // 테스트 실행 전 셋업
    realmManager = await setupTestRealmManager();
    transactionRepository = TransactionRepository(realmManager);

    // 테스트용 지갑 생성
    realmManager.realm.write(() {
      realmManager.realm.add(RealmWalletBase(
          testWalletItem.id,
          testWalletItem.colorIndex,
          testWalletItem.iconIndex,
          testWalletItem.descriptor,
          testWalletItem.name,
          WalletType.singleSignature.name));
    });
  });

  tearDown(() {
    // 테스트 실행 후 정리
    realmManager.reset();
    realmManager.dispose();
  });

  group('트랜잭션 기본 CRUD 테스트', () {
    test('새 트랜잭션을 추가하고 조회할 수 있어야 함', () async {
      // 테스트용 트랜잭션 생성
      final testTransaction = TransactionMock.createMockTransactionRecord();

      // 트랜잭션 추가
      await transactionRepository.addAllTransactions(testWalletItem.id, [testTransaction]);

      // 트랜잭션 조회
      final transactions = transactionRepository.getTransactionRecordList(testWalletItem.id);

      // 검증
      expect(transactions, isNotEmpty);
      expect(transactions.length, 1);
      expect(transactions[0].transactionHash, testTransaction.transactionHash);
    });
  });

  group('트랜잭션 상태 업데이트 테스트', () {
    test('미확인 트랜잭션이 확인 상태로 업데이트되어야 함', () async {
      // 미확인 트랜잭션 생성
      final testTransaction = TransactionMock.createUnconfirmedTransactionRecord();

      // 트랜잭션 추가
      transactionRepository.addAllTransactions(testWalletItem.id, [testTransaction]);

      // 블록 타임스탬프 데이터 생성
      const blockHeight = 680000;
      final blockTimestamp = BlockTimestamp(
        blockHeight,
        DateTime.fromMillisecondsSinceEpoch(1625097600 * 1000),
      );

      // 블록 타임스탬프 저장
      realmManager.realm.write(() {
        realmManager.realm.add(RealmBlockTimestamp(blockHeight, blockTimestamp.timestamp));
      });

      // 트랜잭션 상태 업데이트 데이터 준비
      final fetchedTxMap = {
        testTransaction.transactionHash: FetchTransactionResponse(
          transactionHash: testTransaction.transactionHash,
          height: blockHeight,
          addressIndex: 0,
          isChange: false,
        ),
      };

      final blockTimestampMap = {
        blockHeight: blockTimestamp,
      };

      // 지갑의 최근 트랜잭션 상태 플래그 설정
      realmManager.realm.write(() {
        final wallet = realmManager.realm.find<RealmWalletBase>(testWalletItem.id);
        wallet!.isLatestTxBlockHeightZero = true;
      });

      // 트랜잭션 상태 업데이트
      await transactionRepository.updateTransactionStates(
        testWalletItem.id,
        [testTransaction.transactionHash], // 업데이트할 트랜잭션
        [], // 삭제할 트랜잭션 없음
        fetchedTxMap,
        blockTimestampMap,
      );

      // 업데이트된 트랜잭션 조회
      final updatedTransaction = transactionRepository.getTransactionRecord(
          testWalletItem.id, testTransaction.transactionHash);
      final wallet = realmManager.realm.find<RealmWalletBase>(testWalletItem.id);

      // 검증
      expect(updatedTransaction?.blockHeight, blockHeight);

      // 타임스탬프 비교 (null 안전하게 처리)
      final actualTimestamp = updatedTransaction?.timestamp;
      expect(actualTimestamp, isNotNull);
      if (actualTimestamp != null) {
        expect(actualTimestamp.millisecondsSinceEpoch ~/ 1000,
            blockTimestamp.timestamp.millisecondsSinceEpoch ~/ 1000);
      }

      expect(wallet?.isLatestTxBlockHeightZero, false);
    });
  });

  group('RBF 기능 테스트', () {
    test('RBF 내역을 일괄 추가할 수 있어야 함', () async {
      // 테스트용 RBF DTO 생성
      final rbfDtoList = [
        RbfHistory(
          walletId: testWalletItem.id,
          originalTransactionHash: 'original_tx_1',
          transactionHash: 'new_tx_1',
          feeRate: 5.0,
          timestamp: DateTime.now(),
        ),
        RbfHistory(
          walletId: testWalletItem.id,
          originalTransactionHash: 'original_tx_2',
          transactionHash: 'new_tx_2',
          feeRate: 7.5,
          timestamp: DateTime.now(),
        ),
      ];

      // RBF 내역 일괄 추가
      transactionRepository.addAllRbfHistory(rbfDtoList);

      // RBF 내역 조회
      final rbfHistory1 = transactionRepository.getRbfHistoryList(testWalletItem.id, 'new_tx_1');
      final rbfHistory2 = transactionRepository.getRbfHistoryList(testWalletItem.id, 'new_tx_2');

      // 검증
      expect(rbfHistory1, isNotEmpty);
      expect(rbfHistory2, isNotEmpty);
      expect(rbfHistory1.length, 1);
      expect(rbfHistory2.length, 1);
      expect(rbfHistory1[0].originalTransactionHash, 'original_tx_1');
      expect(rbfHistory2[0].originalTransactionHash, 'original_tx_2');
    });

    test('RBF 내역을 조회할 때 연관된 RBF 내역도 함께 조회되어야 함', () async {
      // 테스트용 RBF DTO 생성
      final rbfDtoList = [
        RbfHistory(
          walletId: testWalletItem.id,
          originalTransactionHash: 'original_tx_1',
          transactionHash: 'new_tx_1',
          feeRate: 5.0,
          timestamp: DateTime.now(),
        ),
        RbfHistory(
          walletId: testWalletItem.id,
          originalTransactionHash: 'original_tx_1',
          transactionHash: 'new_tx_2',
          feeRate: 7.5,
          timestamp: DateTime.now(),
        ),
        RbfHistory(
          walletId: testWalletItem.id,
          originalTransactionHash: 'original_tx_1',
          transactionHash: 'new_tx_3',
          feeRate: 10.0,
          timestamp: DateTime.now(),
        ),
      ];

      // RBF 내역 일괄 추가
      transactionRepository.addAllRbfHistory(rbfDtoList);

      // RBF 내역 조회
      final rbfHistory = transactionRepository.getRbfHistoryList(testWalletItem.id, 'new_tx_1');

      // 검증
      expect(rbfHistory, isNotEmpty);
      expect(rbfHistory.length, 3);
      expect(rbfHistory[2].originalTransactionHash, 'original_tx_1');
      expect(rbfHistory[2].transactionHash, 'new_tx_1');
      expect(rbfHistory[1].originalTransactionHash, 'original_tx_1');
      expect(rbfHistory[1].transactionHash, 'new_tx_2');
      expect(rbfHistory[0].originalTransactionHash, 'original_tx_1');
      expect(rbfHistory[0].transactionHash, 'new_tx_3');
    });

    test('RBF 내역 일괄 추가 시 중복은 무시되어야 함', () async {
      // 첫 번째 추가
      final rbfDto = RbfHistory(
        walletId: testWalletItem.id,
        originalTransactionHash: 'original_tx',
        transactionHash: 'new_tx',
        feeRate: 5.0,
        timestamp: DateTime.now(),
      );

      transactionRepository.addAllRbfHistory([rbfDto]);

      // 동일한 내역 다시 추가
      transactionRepository.addAllRbfHistory([rbfDto]);

      // RBF 내역 조회
      final rbfHistory = transactionRepository.getRbfHistoryList(testWalletItem.id, 'new_tx');

      // 검증 - 중복이 추가되지 않아야 함
      expect(rbfHistory.length, 1);
    });
  });

  group('CPFP 기능 테스트', () {
    test('CPFP 내역을 일괄 추가할 수 있어야 함', () async {
      // 테스트용 CPFP DTO 생성
      final cpfpDtoList = [
        CpfpHistory(
          walletId: testWalletItem.id,
          parentTransactionHash: 'parent_tx_1',
          childTransactionHash: 'child_tx_1',
          originalFee: 3.0,
          newFee: 10.0,
          timestamp: DateTime.now(),
        ),
        CpfpHistory(
          walletId: testWalletItem.id,
          parentTransactionHash: 'parent_tx_2',
          childTransactionHash: 'child_tx_2',
          originalFee: 4.0,
          newFee: 12.0,
          timestamp: DateTime.now(),
        ),
      ];

      // CPFP 내역 일괄 추가
      transactionRepository.addAllCpfpHistory(cpfpDtoList);

      // CPFP 내역 조회
      final cpfpHistory1 = transactionRepository.getCpfpHistory(testWalletItem.id, 'parent_tx_1');
      final cpfpHistory2 = transactionRepository.getCpfpHistory(testWalletItem.id, 'parent_tx_2');

      // 검증
      expect(cpfpHistory1, isNotNull);
      expect(cpfpHistory2, isNotNull);
      expect(cpfpHistory1?.parentTransactionHash, 'parent_tx_1');
      expect(cpfpHistory2?.parentTransactionHash, 'parent_tx_2');
      expect(cpfpHistory1?.childTransactionHash, 'child_tx_1');
      expect(cpfpHistory2?.childTransactionHash, 'child_tx_2');
    });

    test('CPFP 내역 일괄 추가 시 중복은 무시되어야 함', () async {
      // 첫 번째 추가
      final cpfpDto = CpfpHistory(
        walletId: testWalletItem.id,
        parentTransactionHash: 'parent_tx',
        childTransactionHash: 'child_tx',
        originalFee: 3.0,
        newFee: 10.0,
        timestamp: DateTime.now(),
      );

      transactionRepository.addAllCpfpHistory([cpfpDto]);

      // 동일한 내역 다시 추가
      transactionRepository.addAllCpfpHistory([cpfpDto]);

      // CPFP 내역 조회
      final allCpfpHistories = realmManager.realm.all<RealmCpfpHistory>();

      // 검증 - 중복이 추가되지 않아야 함
      expect(allCpfpHistories.length, 1);
    });
  });

  group('트랜잭션 목록 관련 테스트', () {
    test('미확인 트랜잭션과 확인된 트랜잭션이 정렬되어 반환되어야 함', () async {
      // 테스트용 트랜잭션 생성
      final confirmedTx1 = TransactionMock.createConfirmedTransactionRecord(
        transactionHash: 'confirmed_tx_1',
        timestamp: DateTime.fromMillisecondsSinceEpoch(1000),
        blockHeight: 680000,
      );

      final confirmedTx2 = TransactionMock.createConfirmedTransactionRecord(
        transactionHash: 'confirmed_tx_2',
        timestamp: DateTime.fromMillisecondsSinceEpoch(2000),
        blockHeight: 680001,
        amount: 2000000,
        fee: 20000,
      );

      final unconfirmedTx = TransactionMock.createUnconfirmedTransactionRecord(
        transactionHash: 'unconfirmed_tx',
        timestamp: DateTime.fromMillisecondsSinceEpoch(500),
      );

      // 트랜잭션 추가 (순서 섞어서)
      await transactionRepository
          .addAllTransactions(testWalletItem.id, [confirmedTx1, unconfirmedTx, confirmedTx2]);

      // 트랜잭션 목록 조회
      final transactions = transactionRepository.getTransactionRecordList(testWalletItem.id);

      // 검증: 미확인 트랜잭션이 먼저 나오고, 이후 확인된 트랜잭션이 타임스탬프 역순으로 정렬되어야 함
      expect(transactions.length, 3);
      expect(transactions[0].transactionHash, 'unconfirmed_tx');
      expect(transactions[1].transactionHash, 'confirmed_tx_2');
      expect(transactions[2].transactionHash, 'confirmed_tx_1');
    });

    test('getExistingConfirmedTxHashes는 확인된 트랜잭션 해시 목록을 반환해야 함', () async {
      // 테스트용 트랜잭션 생성 (확인된 것과 미확인된 것)
      final confirmedTx1 = TransactionMock.createConfirmedTransactionRecord(
        transactionHash: 'confirmed_tx_1',
        blockHeight: 680000,
      );

      final confirmedTx2 = TransactionMock.createConfirmedTransactionRecord(
        transactionHash: 'confirmed_tx_2',
        blockHeight: 680001,
        amount: 2000000,
        fee: 20000,
      );

      final unconfirmedTx = TransactionMock.createUnconfirmedTransactionRecord(
        transactionHash: 'unconfirmed_tx',
      );

      // 트랜잭션 추가
      await transactionRepository
          .addAllTransactions(testWalletItem.id, [confirmedTx1, unconfirmedTx, confirmedTx2]);

      // 확인된 트랜잭션 해시 목록 조회
      final confirmedTxHashes =
          transactionRepository.getExistingConfirmedTxHashes(testWalletItem.id);

      // 검증
      expect(confirmedTxHashes.length, 2);
      expect(confirmedTxHashes.contains('confirmed_tx_1'), true);
      expect(confirmedTxHashes.contains('confirmed_tx_2'), true);
      expect(confirmedTxHashes.contains('unconfirmed_tx'), false);
    });
  });

  group('임시 브로드캐스트 시간 기록 테스트', () {
    test('임시 브로드캐스트 시간을 기록하고 조회할 수 있어야 함', () async {
      // 테스트용 트랜잭션 해시와 시간
      const txHash = 'broadcast_tx_hash';
      final broadcastTime = DateTime.now();

      // 임시 브로드캐스트 시간 기록
      await transactionRepository.recordTemporaryBroadcastTime(txHash, broadcastTime);

      // 기록된 데이터 조회
      final tempRecords = realmManager.realm.all<TempBroadcastTimeRecord>();
      final recordedItem = tempRecords.firstWhere((r) => r.transactionHash == txHash);

      // 검증
      expect(tempRecords, isNotEmpty);
      expect(recordedItem.transactionHash, txHash);

      // DateTime 비교는 정밀도 차이 때문에 근사값으로 비교
      final timeDiff = recordedItem.createdAt.difference(broadcastTime).inMilliseconds.abs();
      expect(timeDiff < 1000, true); // 1초 이내 차이는 허용
    });
  });

  group('RBF 대체 표시 테스트', () {
    test('markAsRbfReplaced 함수가 트랜잭션에 대체 정보를 올바르게 설정해야 함', () async {
      // 테스트용 트랜잭션 생성 및 추가
      final originalTx = TransactionMock.createMockTransactionRecord(
        transactionHash: 'original_tx',
        blockHeight: 0, // 미확인 트랜잭션
      );

      final spentTx = TransactionMock.createMockTransactionRecord(
        transactionHash: 'spent_tx',
        blockHeight: 0,
      );

      // 두 개의 원본 트랜잭션을 DB에 추가
      await transactionRepository.addAllTransactions(testWalletItem.id, [originalTx, spentTx]);

      // RBF 정보 맵 생성
      final rbfInfoMap = {
        'spent_tx': TransactionMock.createMockRbfInfo(
          originalTransactionHash: 'original_tx',
          previousTransactionHash: 'original_tx',
        ),
      };

      // markAsRbfReplaced 함수 호출
      transactionRepository.markAsRbfReplaced(testWalletItem.id, rbfInfoMap);

      // 트랜잭션 조회 및 검증
      final updatedTx = realmManager.realm.query<RealmTransaction>(
        r'walletId == $0 AND transactionHash == $1',
        [testWalletItem.id, 'original_tx'],
      ).first;
      // replaceByTransactionHash 필드가 올바르게 설정되었는지 확인
      expect(updatedTx.replaceByTransactionHash, 'spent_tx');
    });

    test('존재하지 않는 트랜잭션에 대한 RBF 정보는 처리되지 않아야 함', () async {
      // 테스트용 트랜잭션 추가 - 하나만 DB에 추가
      final originalTx = TransactionMock.createMockTransactionRecord(
        transactionHash: 'original_tx',
        blockHeight: 0,
      );
      final spentTx = TransactionMock.createMockTransactionRecord(
        transactionHash: 'spent_tx',
        blockHeight: 0,
      );
      final spentTx2 = TransactionMock.createMockTransactionRecord(
        transactionHash: 'spent_tx2',
        blockHeight: 0,
      );

      await transactionRepository
          .addAllTransactions(testWalletItem.id, [originalTx, spentTx, spentTx2]);

      // 존재하는 트랜잭션과 존재하지 않는 트랜잭션에 대한 RBF 정보 맵 생성
      final rbfInfoMap = {
        'spent_tx': TransactionMock.createMockRbfInfo(
          originalTransactionHash: 'original_tx',
          previousTransactionHash: 'original_tx',
        ),
        'not_exists': TransactionMock.createMockRbfInfo(
          originalTransactionHash: 'original_tx',
          previousTransactionHash: 'spent_tx2',
        ),
      };

      // markAsRbfReplaced 함수 호출
      transactionRepository.markAsRbfReplaced(testWalletItem.id, rbfInfoMap);

      // 존재하는 트랜잭션 조회 및 검증
      final updatedTx = realmManager.realm.query<RealmTransaction>(
        r'walletId == $0 AND transactionHash == $1',
        [testWalletItem.id, 'original_tx'],
      ).first;

      // 존재하는 트랜잭션만 업데이트되었는지 확인
      expect(updatedTx.replaceByTransactionHash, 'spent_tx');

      // 존재하지 않는 트랜잭션에 대한 쿼리 실행 - 결과가 없어야 함
      final nonExistentTx = realmManager.realm.query<RealmTransaction>(
        r'walletId == $0 AND transactionHash == $1',
        [testWalletItem.id, 'not_exists'],
      );

      expect(nonExistentTx.isEmpty, true);
    });

    test('3회 RBF를 시도할 때에 1,2번째 RBF 트랜잭션에 대해서 처리되어야 함', () async {
      // 원본 트랜잭션
      final originalTx = TransactionMock.createMockTransactionRecord(
        transactionHash: 'original_tx',
        blockHeight: 0, // 미확인 트랜잭션
      );

      // RBF 1회차 트랜잭션
      final rbfTx1 = TransactionMock.createMockTransactionRecord(
        transactionHash: 'rbf_tx_1',
        blockHeight: 0, // 미확인 트랜잭션
      );

      await transactionRepository.addAllTransactions(testWalletItem.id, [
        originalTx,
        rbfTx1,
      ]);

      // RBF 1회차 정보 맵 생성
      final rbfInfoMap = {
        'rbf_tx_1': TransactionMock.createMockRbfInfo(
          originalTransactionHash: 'original_tx',
          previousTransactionHash: 'original_tx',
        ),
      };

      // markAsRbfReplaced 함수 호출
      transactionRepository.markAsRbfReplaced(testWalletItem.id, rbfInfoMap);

      // RBF 1회차 트랜잭션
      final rbfTx2 = TransactionMock.createMockTransactionRecord(
        transactionHash: 'rbf_tx_2',
        blockHeight: 0, // 미확인 트랜잭션
      );

      await transactionRepository.addAllTransactions(testWalletItem.id, [
        rbfTx2,
      ]);

      // RBF 2회차 정보 맵 생성
      final rbfInfoMap2 = {
        'rbf_tx_2': TransactionMock.createMockRbfInfo(
          originalTransactionHash: 'original_tx',
          previousTransactionHash: 'rbf_tx_1',
        ),
      };

      // markAsRbfReplaced 함수 호출
      transactionRepository.markAsRbfReplaced(testWalletItem.id, rbfInfoMap2);

      // RBF 3회차 트랜잭션
      final rbfTx3 = TransactionMock.createMockTransactionRecord(
        transactionHash: 'rbf_tx_3',
        blockHeight: 0, // 미확인 트랜잭션
      );

      await transactionRepository.addAllTransactions(testWalletItem.id, [
        rbfTx3,
      ]);

      // RBF 3회차 정보 맵 생성
      final rbfInfoMap3 = {
        'rbf_tx_3': TransactionMock.createMockRbfInfo(
          originalTransactionHash: 'original_tx',
          previousTransactionHash: 'rbf_tx_2',
        ),
      };

      // markAsRbfReplaced 함수 호출
      transactionRepository.markAsRbfReplaced(testWalletItem.id, rbfInfoMap3);

      // 원본 트랜잭션 조회 및 검증
      final realmOriginalTx = realmManager.realm.query<RealmTransaction>(
        r'walletId == $0 AND transactionHash == $1',
        [testWalletItem.id, 'original_tx'],
      ).first;

      expect(realmOriginalTx.replaceByTransactionHash, 'rbf_tx_1');

      // RBF 1회차 트랜잭션 조회 및 검증
      final realmRbfTx1 = realmManager.realm.query<RealmTransaction>(
        r'walletId == $0 AND transactionHash == $1',
        [testWalletItem.id, 'rbf_tx_1'],
      ).first;

      expect(realmRbfTx1.replaceByTransactionHash, 'rbf_tx_2');

      // RBF 2회차 트랜잭션 조회 및 검증
      final realmRbfTx2 = realmManager.realm.query<RealmTransaction>(
        r'walletId == $0 AND transactionHash == $1',
        [testWalletItem.id, 'rbf_tx_2'],
      ).first;

      expect(realmRbfTx2.replaceByTransactionHash, 'rbf_tx_3');

      // RBF 3회차 트랜잭션 조회 및 검증
      final realmRbfTx3 = realmManager.realm.query<RealmTransaction>(
        r'walletId == $0 AND transactionHash == $1',
        [testWalletItem.id, 'rbf_tx_3'],
      ).first;

      expect(realmRbfTx3.replaceByTransactionHash, null);
    });
  });
}
