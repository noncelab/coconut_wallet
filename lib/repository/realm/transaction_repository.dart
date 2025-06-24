import 'package:coconut_lib/coconut_lib.dart' as lib;
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/cpfp_history.dart';
import 'package:coconut_wallet/model/node/rbf_history.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/rbf_service.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/converter/transaction.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:realm/realm.dart';
import 'package:coconut_wallet/utils/logger.dart';

class TransactionRepository extends BaseRepository {
  TransactionRepository(super._realmManager);

  /// walletId 로 트랜잭션 목록 조회, rbf/cpfp 내역 미포함, memo 미포함
  List<TransactionRecord> getTransactionRecordList(int walletId) {
    final transactions = realm.query<RealmTransaction>(
        'walletId == $walletId AND replaceByTransactionHash == null SORT(timestamp DESC)');

    if (transactions.isEmpty) return [];
    List<TransactionRecord> result = [];

    final unconfirmed = transactions.query('blockHeight = 0 SORT(createdAt DESC)');
    final confirmed = transactions.query('blockHeight != 0 SORT(timestamp DESC, createdAt DESC)');

    for (var t in unconfirmed) {
      result.add(mapRealmTransactionToTransaction(t));
    }
    for (var t in confirmed) {
      result.add(mapRealmTransactionToTransaction(t));
    }

    return result;
  }

  List<TransactionRecord> getUnconfirmedTransactionRecordList(int walletId) {
    final realmTxs = realm.query<RealmTransaction>(
        'walletId == $walletId AND (blockHeight = 0 OR blockHeight = null) SORT(createdAt DESC)');

    if (realmTxs.isEmpty) return [];
    List<TransactionRecord> result = [];

    for (var t in realmTxs) {
      result.add(mapRealmTransactionToTransaction(t));
    }

    return result;
  }

  List<RealmTransaction> getRealmTransactionListByHashes(
      int walletId, Set<String> transactionHashes) {
    return realm.query<RealmTransaction>(
      r'walletId == $0 AND transactionHash IN $1',
      [walletId, transactionHashes],
    ).toList();
  }

  /// walletId, transactionHash 로 조회된 transaction 의 메모 변경
  Result<TransactionRecord> updateTransactionMemo(int walletId, String txHash, String memo) {
    final realmMemo = realm
        .find<RealmTransactionMemo>("walletId == '$walletId' AND transactionHash == '$txHash'");

    return handleRealm<TransactionRecord>(() {
      // 메모 업데이트 또는 생성
      if (realmMemo == null) {
        realm.add(generateRealmTransactionMemo(txHash, walletId, memo));
      } else {
        realm.write(() {
          realmMemo.memo = memo;
        });
      }

      // 트랜잭션 레코드 조회 및 반환
      final txRecord = getTransactionRecord(walletId, txHash);
      if (txRecord == null) {
        throw ErrorCodes.realmNotFound;
      }

      return txRecord;
    });
  }

  /// 일시적인 브로드캐스트 시간 기록
  Future<void> recordTemporaryBroadcastTime(String txHash, DateTime createdAt) async {
    await realm.writeAsync(() {
      realm.add(TempBroadcastTimeRecord(txHash, createdAt));
    });
  }

  /// 트랜잭션 상태 업데이트
  Future<void> updateTransactionStates(
    int walletId,
    List<String> txsToUpdate,
    List<String> txsToDelete,
    Map<String, FetchTransactionResponse> fetchedTxMap,
    Map<int, BlockTimestamp> blockTimestampMap,
  ) async {
    final realmWalletBase = realm.find<RealmWalletBase>(walletId);
    if (realmWalletBase == null) {
      throw StateError('[updateTransactionStates] Wallet not found');
    }

    RealmResults<RealmTransaction>? txsToDeleteRealm;
    RealmResults<RealmTransaction>? txsToUpdateRealm;

    if (txsToDelete.isNotEmpty) {
      txsToDeleteRealm = realm.query<RealmTransaction>(
          'walletId == $walletId AND transactionHash IN \$0', [txsToDelete]);
    }

    if (txsToUpdate.isNotEmpty) {
      txsToUpdateRealm = realm.query<RealmTransaction>(
          'walletId == $walletId AND transactionHash IN \$0', [txsToUpdate]);
    }

    await realm.writeAsync(() {
      // 1. 삭제할 트랜잭션 처리
      if (txsToDeleteRealm != null && txsToDeleteRealm.isNotEmpty) {
        realm.deleteMany(txsToDeleteRealm);
      }

      // 2. 업데이트할 트랜잭션 처리
      if (txsToUpdateRealm != null && txsToUpdateRealm.isNotEmpty) {
        for (final tx in txsToUpdateRealm) {
          final fetchedTx = fetchedTxMap[tx.transactionHash]!;
          tx.blockHeight = fetchedTx.height;
          tx.timestamp = blockTimestampMap[fetchedTx.height]!.timestamp;
        }
      }
    });
  }

  /// 확인된 트랜잭션 해시 목록 가져오기
  Set<String> getExistingConfirmedTxHashes(int walletId) {
    final realmTxs = realm.query<RealmTransaction>('walletId == $walletId AND blockHeight > 0');
    return realmTxs.map((tx) => tx.transactionHash).toSet();
  }

  /// 모든 트랜잭션 추가
  Future<void> addAllTransactions(int walletId, List<TransactionRecord> txList) async {
    final realmWalletBase = realm.find<RealmWalletBase>(walletId);
    if (realmWalletBase == null) {
      throw StateError('[addAllTransactions] Wallet not found');
    }

    // 기존 트랜잭션 정보 맵 조회
    final existingTxs = realm.query<RealmTransaction>('walletId == $walletId');
    final existingTxMap = {for (var tx in existingTxs) tx.transactionHash: tx};

    // 새 트랜잭션과 업데이트할 트랜잭션을 분리
    List<RealmTransaction> newTxsToAdd = [];
    List<MapEntry<RealmTransaction, TransactionRecord>> txsToUpdate = [];

    for (var tx in txList) {
      final existingTx = existingTxMap[tx.transactionHash];

      if (existingTx == null) {
        newTxsToAdd.add(mapTransactionToRealmTransaction(
          tx,
          walletId,
          Object.hash(walletId, tx.transactionHash),
        ));
      } else if (existingTx.blockHeight == 0 && tx.blockHeight > 0) {
        // 미확인 -> 확인 상태로 변경된 트랜잭션 - 업데이트
        txsToUpdate.add(MapEntry(existingTx, tx));
      }
      // 이미 확인된 트랜잭션이거나 여전히 미확인 상태인 트랜잭션은 무시
    }

    await realm.writeAsync(() {
      // 새 트랜잭션 추가
      if (newTxsToAdd.isNotEmpty) {
        realm.addAll<RealmTransaction>(newTxsToAdd);
      }

      // 기존 미확인 트랜잭션 업데이트
      for (var entry in txsToUpdate) {
        final existingTx = entry.key;
        final newTx = entry.value;

        existingTx.blockHeight = newTx.blockHeight;
        existingTx.timestamp = newTx.timestamp;
      }
    });
  }

  /// 해당 지갑에 존재하는 트랜잭션 해시 set 조회
  Set<String> getConfirmedTransactionHashSet(int walletId) {
    return realm
        .query<RealmTransaction>('walletId == $walletId AND blockHeight > 0')
        .map((tx) => tx.transactionHash)
        .toSet();
  }

  /// 특정 트랜잭션 조회
  TransactionRecord? getTransactionRecord(int walletId, String transactionHash) {
    final realmTransaction = realm.query<RealmTransaction>(
      r'walletId == $0 AND transactionHash == $1',
      [walletId, transactionHash],
    ).firstOrNull;

    if (realmTransaction == null) {
      return null;
    }

    final realmTransactionMemo = realm.find<RealmTransactionMemo>(
      getTransactionMemoId(transactionHash, walletId),
    );

    if (realmTransaction.blockHeight == 0) {
      final realmRbfHistoryList = getRbfHistoryList(walletId, transactionHash);
      final realmCpfpHistory = getCpfpHistory(walletId, transactionHash);

      return mapRealmTransactionToTransaction(realmTransaction,
          realmRbfHistoryList: realmRbfHistoryList,
          realmCpfpHistory: realmCpfpHistory,
          memo: realmTransactionMemo?.memo);
    }

    return mapRealmTransactionToTransaction(realmTransaction, memo: realmTransactionMemo?.memo);
  }

  bool hasTransactionConfirmed(int walletId, String transactionHash) {
    final realmTransaction = realm.query<RealmTransaction>(
      r'walletId == $0 AND transactionHash == $1',
      [walletId, transactionHash],
    ).firstOrNull;

    if (realmTransaction == null) {
      return false;
    }

    return realmTransaction.blockHeight > 0;
  }

  /// RBF 내역을 일괄 저장합니다.
  ///
  /// 중복 체크를 수행하여 이미 저장된 내역은 다시 저장하지 않습니다.
  void addAllRbfHistory(List<RbfHistory> rbfHistoryList) {
    if (rbfHistoryList.isEmpty) return;

    try {
      // 중복 체크를 위한 기존 ID 목록 생성
      final existingIds = <int>{};
      final idsToAdd = rbfHistoryList.map((dto) => dto.id).toList();
      final existingRbfHistory = realm.query<RealmRbfHistory>(r'id IN $0', [idsToAdd]);

      if (existingRbfHistory.isNotEmpty) {
        existingIds.addAll(existingRbfHistory.map((rbf) => rbf.id));
      }

      // 새로 추가할 RBF 내역 생성
      final newRbfHistories = rbfHistoryList
          .where((dto) => !existingIds.contains(dto.id))
          .map((dto) => mapRbfHistoryToRealmRbfHistory(dto))
          .toList();

      // 일괄 저장
      if (newRbfHistories.isNotEmpty) {
        realm.write(() {
          realm.addAll<RealmRbfHistory>(newRbfHistories);
        });
      }
    } catch (e, stackTrace) {
      Logger.error('addAllRbfHistory error: $e');
      Logger.error('stackTrace: $stackTrace');
    }
  }

  /// CPFP 내역을 일괄 저장합니다.
  ///
  /// 중복 체크를 수행하여 이미 저장된 내역은 다시 저장하지 않습니다.
  void addAllCpfpHistory(List<CpfpHistory> cpfpHistoryList) {
    if (cpfpHistoryList.isEmpty) return;

    // 중복 체크를 위한 기존 ID 목록 생성
    final existingIds = <int>{};
    final idsToAdd = cpfpHistoryList.map((dto) => dto.id).toList();
    final existingCpfpHistory = realm.query<RealmCpfpHistory>(r'id IN $0', [idsToAdd]);

    if (existingCpfpHistory.isNotEmpty) {
      existingIds.addAll(existingCpfpHistory.map((cpfp) => cpfp.id));
    }

    // 새로 추가할 CPFP 내역 생성
    final newCpfpHistories = cpfpHistoryList
        .where((dto) => !existingIds.contains(dto.id))
        .map((dto) => mapCpfpHistoryToRealmCpfpHistory(dto))
        .toList();

    // 일괄 저장
    if (newCpfpHistories.isNotEmpty) {
      realm.write(() {
        realm.addAll<RealmCpfpHistory>(newCpfpHistories);
      });
    }
  }

  List<RealmRbfHistory> getRbfHistoryList(int walletId, String transactionHash) {
    final realmRbfHistory = realm.query<RealmRbfHistory>(
      r'walletId == $0 AND transactionHash == $1',
      [walletId, transactionHash],
    ).firstOrNull;

    if (realmRbfHistory == null) {
      return [];
    }

    final realmRbfHistoryList = realm.query<RealmRbfHistory>(
      r'walletId == $0 AND originalTransactionHash == $1 SORT(feeRate DESC)',
      [walletId, realmRbfHistory.originalTransactionHash],
    ).toList();

    // transactionHash를 기준으로 중복 제거
    final uniqueTransactionHashes = <String>{};
    final uniqueRbfHistoryList = <RealmRbfHistory>[];

    for (final rbfHistory in realmRbfHistoryList) {
      if (!uniqueTransactionHashes.contains(rbfHistory.transactionHash)) {
        uniqueTransactionHashes.add(rbfHistory.transactionHash);
        uniqueRbfHistoryList.add(rbfHistory);
      }
    }

    return uniqueRbfHistoryList;
  }

  RealmCpfpHistory? getCpfpHistory(int walletId, String transactionHash) {
    final realmCpfpHistory = realm.query<RealmCpfpHistory>(
      r'walletId == $0 AND (parentTransactionHash == $1 OR childTransactionHash == $1)',
      [walletId, transactionHash],
    ).firstOrNull;

    return realmCpfpHistory;
  }

  /// RBF 내역 삭제, 트랜잭션이 컨펌되면 RBF내역은 불필요하므로 연관된 내역도 함께 삭제함
  Future<void> deleteRbfHistory(int walletId, lib.Transaction fetchedTx) async {
    final realmRbfHistory = realm.query<RealmRbfHistory>(
      r'walletId == $0 AND transactionHash == $1',
      [walletId, fetchedTx.transactionHash],
    ).firstOrNull;

    if (realmRbfHistory != null) {
      final relatedRbfHistoryList = realm.query<RealmRbfHistory>(
        r'walletId == $0 AND originalTransactionHash == $1',
        [walletId, realmRbfHistory.originalTransactionHash],
      );

      if (relatedRbfHistoryList.isNotEmpty) {
        await realm.writeAsync(() {
          realm.deleteMany(relatedRbfHistoryList);
        });
      }
    }
  }

  /// CPFP 내역 삭제, 트랜잭션이 컨펌되면 CPFP내역은 불필요하므로 연관된 내역도 함께 삭제하
  Future<void> deleteCpfpHistory(int walletId, lib.Transaction fetchedTx) async {
    final realmCpfpHistory = realm.query<RealmCpfpHistory>(
      r'walletId == $0 AND (parentTransactionHash == $1 OR childTransactionHash == $1)',
      [walletId, fetchedTx.transactionHash],
    ).firstOrNull;

    if (realmCpfpHistory != null) {
      await realm.writeAsync(() {
        realm.delete(realmCpfpHistory);
      });
    }
  }

  /// rbfInfoMap - {key(fetchedTxHash): value(RbfInfo)}
  /// 기존 트랜잭션을 찾아서 rbf로 대체되었다는 표시를 하기 위한 메서드
  Future<void> markAsRbfReplaced(int walletId, Map<String, RbfInfo> rbfInfoMap) async {
    final txListToReplce = realm.query<RealmTransaction>(
      r'walletId == $0 AND transactionHash IN $1',
      [walletId, rbfInfoMap.values.map((rbf) => rbf.previousTransactionHash).toList()],
    );

    final prevToCurrentTxMap = <String, String>{};
    for (var rbfInfo in rbfInfoMap.entries) {
      prevToCurrentTxMap[rbfInfo.value.previousTransactionHash] = rbfInfo.key;
    }

    await realm.writeAsync(() {
      for (final realmPrevTx in txListToReplce) {
        realmPrevTx.replaceByTransactionHash = prevToCurrentTxMap[realmPrevTx.transactionHash];
      }
    });
  }

  Result<bool> deleteTransaction(int walletId, List<String> transactionHashes) {
    final realmTransactions = realm
        .query<RealmTransaction>(
          r'walletId == $0 AND transactionHash IN $1',
          [walletId, transactionHashes],
        )
        .where((tx) => tx.replaceByTransactionHash == null)
        .toList();

    if (realmTransactions.isNotEmpty) {
      realm.write(() {
        realm.deleteMany(realmTransactions);
      });
      return Result.success(true);
    }

    return Result.failure(ErrorCodes.realmNotFound);
  }
}
