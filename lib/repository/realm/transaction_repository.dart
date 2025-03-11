import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/repository/realm/base_repository.dart';
import 'package:coconut_wallet/repository/realm/converter/transaction.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:realm/realm.dart';

class TransactionRepository extends BaseRepository {
  TransactionRepository(super._realmManager);

  /// walletId 로 트랜잭션 목록 조회
  List<TransactionRecord> getTransactionRecordList(int walletId) {
    final transactions = realm
        .query<RealmTransaction>('walletId == $walletId SORT(timestamp DESC)');

    if (transactions.isEmpty) return [];
    List<TransactionRecord> result = [];

    final unconfirmed =
        transactions.query('blockHeight = 0 SORT(createdAt DESC)');
    final confirmed = transactions
        .query('blockHeight != 0 SORT(timestamp DESC, createdAt DESC)');

    for (var t in unconfirmed) {
      result.add(mapRealmTransactionToTransaction(t));
    }
    for (var t in confirmed) {
      result.add(mapRealmTransactionToTransaction(t));
    }

    return result;
  }

  /// 미확인 트랜잭션 조회
  RealmResults<RealmTransaction> getUnconfirmedTransactions(int walletId) {
    return realm.query<RealmTransaction>(
        r'walletId = $0 AND blockHeight = 0', [walletId]);
  }

  /// 트랜잭션 CRUD 관련 함수
  /// walletID, txHash 로 transaction 조회
  Result<TransactionRecord> loadTransaction(int walletId, String txHash) {
    final transactions = realm.query<RealmTransaction>(
        "walletId == '$walletId' AND transactionHash == '$txHash'");

    return handleRealm<TransactionRecord>(
      () => transactions.isEmpty
          ? throw ErrorCodes.realmNotFound
          : mapRealmTransactionToTransaction(transactions.first),
    );
  }

  /// walletId, transactionHash 로 조회된 transaction 의 메모 변경
  Result<TransactionRecord> updateTransactionMemo(
      int walletId, String txHash, String memo) {
    final transactions = realm.query<RealmTransaction>(
        "walletId == '$walletId' AND transactionHash == '$txHash'");

    return handleRealm<TransactionRecord>(
      () {
        final transaction = transactions.first;
        realm.write(() {
          transaction.memo = memo;
        });
        return mapRealmTransactionToTransaction(transaction);
      },
    );
  }

  /// 일시적인 브로드캐스트 시간 기록
  Future<void> recordTemporaryBroadcastTime(
      String txHash, DateTime createdAt) async {
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

      // 3. 지갑의 최신 트랜잭션 상태 업데이트
      realmWalletBase.isLatestTxBlockHeightZero =
          fetchedTxMap.values.any((tx) => tx.height == 0);
    });
  }

  /// 확인된 트랜잭션 해시 목록 가져오기
  Set<String> getExistingConfirmedTxHashes(int walletId) {
    final realmTxs = realm
        .query<RealmTransaction>('walletId == $walletId AND blockHeight > 0');
    return realmTxs.map((tx) => tx.transactionHash).toSet();
  }

  /// 모든 트랜잭션 추가
  void addAllTransactions(int walletId, List<TransactionRecord> txList) {
    final realmWalletBase = realm.find<RealmWalletBase>(walletId);
    if (realmWalletBase == null) {
      throw StateError('[addAllTransactions] Wallet not found');
    }

    // 기존 트랜잭션 정보 맵 조회
    final existingTxs = realm.query<RealmTransaction>('walletId == $walletId');
    final existingTxMap = {for (var tx in existingTxs) tx.transactionHash: tx};

    final now = DateTime.now();
    int lastId = getLastId(realm, (RealmTransaction).toString());

    // 새 트랜잭션과 업데이트할 트랜잭션을 분리
    List<RealmTransaction> newTxsToAdd = [];
    List<MapEntry<RealmTransaction, TransactionRecord>> txsToUpdate = [];

    for (var tx in txList) {
      final existingTx = existingTxMap[tx.transactionHash];

      // 기존 트랜잭션이 없거나, 모든 경우에 중복 저장 방지
      if (existingTx == null) {
        // 완전 새로운 트랜잭션 - 추가
        newTxsToAdd.add(mapTransactionToRealmTransaction(
          tx,
          walletId,
          ++lastId,
          now,
        ));
      } else if (existingTx.blockHeight == 0 && (tx.blockHeight ?? 0) > 0) {
        // 미확인 -> 확인 상태로 변경된 트랜잭션 - 업데이트
        txsToUpdate.add(MapEntry(existingTx, tx));
      }
      // 이미 확인된 트랜잭션이거나 여전히 미확인 상태인 트랜잭션은 무시
    }

    realm.write(() {
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

    if (newTxsToAdd.isNotEmpty) {
      saveLastId(realm, (RealmTransaction).toString(), lastId);
    }
  }

  /// 트랜잭션 목록 가져오기
  RealmResults<RealmTransaction> getTransactions(int walletId) {
    return realm.query<RealmTransaction>('walletId == $walletId');
  }

  /// 특정 트랜잭션 조회
  TransactionRecord? getTransactionRecord(
      int walletId, String transactionHash) {
    final realmTransaction = realm.query<RealmTransaction>(
      r'walletId == $0 AND transactionHash == $1',
      [walletId, transactionHash],
    ).firstOrNull;

    if (realmTransaction == null) {
      return null;
    }

    if (realmTransaction.blockHeight == 0) {
      final realmRbfHistoryList = getRbfHistoryList(walletId, transactionHash);
      final realmCpfpHistory = getCpfpHistory(walletId, transactionHash);

      return mapRealmTransactionToTransaction(realmTransaction,
          realmRbfHistoryList: realmRbfHistoryList,
          realmCpfpHistory: realmCpfpHistory);
    }

    return mapRealmTransactionToTransaction(realmTransaction);
  }

  /// RBF 내역을 일괄 저장합니다.
  ///
  /// 중복 체크를 수행하여 이미 저장된 내역은 다시 저장하지 않습니다.
  Future<void> addAllRbfHistory(List<RbfHistoryDto> rbfHistoryList) async {
    if (rbfHistoryList.isEmpty) return;

    // 중복 체크를 위한 기존 ID 목록 생성
    final existingIds = <int>{};
    for (final dto in rbfHistoryList) {
      final id = Object.hash(
          dto.walletId, dto.originalTransactionHash, dto.transactionHash);

      // 이미 존재하는지 확인
      final existing = realm.find<RealmRbfHistory>(id);
      if (existing != null) {
        existingIds.add(id);
      }
    }

    // 새로 추가할 RBF 내역 생성
    final newRbfHistories = <RealmRbfHistory>[];

    for (final dto in rbfHistoryList) {
      final id = Object.hash(
          dto.walletId, dto.originalTransactionHash, dto.transactionHash);

      // 이미 존재하는 내역은 건너뜀
      if (existingIds.contains(id)) continue;

      // 순서 계산
      final existingRbfHistoryList =
          getRbfHistoryList(dto.walletId, dto.originalTransactionHash);
      int order = existingRbfHistoryList.length + 1;

      newRbfHistories.add(RealmRbfHistory(
        id,
        dto.walletId,
        dto.originalTransactionHash,
        dto.transactionHash,
        order,
        dto.feeRate,
        dto.timestamp,
      ));
    }

    // 일괄 저장
    if (newRbfHistories.isNotEmpty) {
      await realm.writeAsync(() {
        realm.addAll<RealmRbfHistory>(newRbfHistories);
      });
    }
  }

  /// CPFP 내역을 일괄 저장합니다.
  ///
  /// 중복 체크를 수행하여 이미 저장된 내역은 다시 저장하지 않습니다.
  Future<void> addAllCpfpHistory(List<CpfpHistoryDto> cpfpHistoryList) async {
    if (cpfpHistoryList.isEmpty) return;

    // 중복 체크를 위한 기존 ID 목록 생성
    final existingIds = <int>{};
    for (final dto in cpfpHistoryList) {
      final id = Object.hash(
          dto.walletId, dto.parentTransactionHash, dto.childTransactionHash);

      // 이미 존재하는지 확인
      final existing = realm.find<RealmCpfpHistory>(id);
      if (existing != null) {
        existingIds.add(id);
      }
    }

    // 새로 추가할 CPFP 내역 생성
    final newCpfpHistories = <RealmCpfpHistory>[];

    for (final dto in cpfpHistoryList) {
      final id = Object.hash(
          dto.walletId, dto.parentTransactionHash, dto.childTransactionHash);

      // 이미 존재하는 내역은 건너뜀
      if (existingIds.contains(id)) continue;

      newCpfpHistories.add(RealmCpfpHistory(
        id,
        dto.walletId,
        dto.parentTransactionHash,
        dto.childTransactionHash,
        dto.originalFee,
        dto.newFee,
        dto.timestamp,
      ));
    }

    // 일괄 저장
    if (newCpfpHistories.isNotEmpty) {
      await realm.writeAsync(() {
        realm.addAll<RealmCpfpHistory>(newCpfpHistories);
      });
    }
  }

  List<RealmRbfHistory> getRbfHistoryList(
      int walletId, String transactionHash) {
    final realmRbfHistory = realm.query<RealmRbfHistory>(
      r'walletId == $0 AND transactionHash == $1',
      [walletId, transactionHash],
    ).firstOrNull;

    if (realmRbfHistory == null) {
      return [];
    }

    final realmRbfHistoryList = realm.query<RealmRbfHistory>(
      r'walletId == $0 AND originalTransactionHash == $1 SORT(order ASC)',
      [walletId, realmRbfHistory.originalTransactionHash],
    ).toList();

    return realmRbfHistoryList;
  }

  RealmCpfpHistory? getCpfpHistory(int walletId, String transactionHash) {
    final realmCpfpHistory = realm.query<RealmCpfpHistory>(
      r'walletId == $0 AND (parentTransactionHash == $1 OR childTransactionHash == $1)',
      [walletId, transactionHash],
    ).firstOrNull;

    return realmCpfpHistory;
  }
}

/// RBF 내역 일괄 저장을 위한 DTO 클래스
class RbfHistoryDto {
  final int walletId;
  final String originalTransactionHash;
  final String transactionHash;
  final double feeRate;
  final DateTime timestamp;

  RbfHistoryDto({
    required this.walletId,
    required this.originalTransactionHash,
    required this.transactionHash,
    required this.feeRate,
    required this.timestamp,
  });
}

/// CPFP 내역 일괄 저장을 위한 DTO 클래스
class CpfpHistoryDto {
  final int walletId;
  final String parentTransactionHash;
  final String childTransactionHash;
  final double originalFee;
  final double newFee;
  final DateTime timestamp;

  CpfpHistoryDto({
    required this.walletId,
    required this.parentTransactionHash,
    required this.childTransactionHash,
    required this.originalFee,
    required this.newFee,
    required this.timestamp,
  });
}
