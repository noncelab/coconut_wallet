import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/node/rbf_history.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';

typedef RbfInfo = ({
  String originalTransactionHash, // RBF 체인의 최초 트랜잭션
  String previousTransactionHash, // 이 트랜잭션이 대체하는 직전 트랜잭션
});

/// RBF(Replace-By-Fee) 트랜잭션 처리를 담당하는 클래스
class RbfService {
  final TransactionRepository _transactionRepository;
  final UtxoRepository _utxoRepository;
  final ElectrumService _electrumService;

  RbfService(this._transactionRepository, this._utxoRepository, this._electrumService);

  /// RBF를 보내는 지갑 관점에서 이미 소비한 UTXO를 다시 소비하는지 확인
  Future<RbfInfo?> detectSendingRbfTransaction(int walletId, Transaction tx) async {
    // 이미 RBF 내역이 있는지 확인
    if (hasExistingRbfHistory(walletId, tx.transactionHash)) {
      return null; // 이미 RBF로 등록된 트랜잭션
    }

    // RBF 입력 검사
    final rbfInputInfo = await findRbfCandidate(walletId, tx);
    if (rbfInputInfo != null && rbfInputInfo.spentByTransactionHash != null) {
      final prevTxHash = rbfInputInfo.spentByTransactionHash!;
      // 원본 트랜잭션 해시 찾기
      final originalTxHash =
          await findOriginalTransactionHash(walletId, rbfInputInfo.spentByTransactionHash!);

      return (
        originalTransactionHash: originalTxHash,
        previousTransactionHash: prevTxHash,
      );
    }

    return null;
  }

  /// 이미 RBF 내역이 있는지 확인
  bool hasExistingRbfHistory(int walletId, String txHash) {
    final existingRbfHistory = _transactionRepository.getRbfHistoryList(walletId, txHash);
    return existingRbfHistory.isNotEmpty;
  }

  /// 트랜잭션의 입력들을 검사하여 RBF 조건에 해당하는 입력이 있는지 확인
  Future<UtxoState?> findRbfCandidate(int walletId, Transaction tx) async {
    for (final input in tx.inputs) {
      final utxoId = makeUtxoId(input.transactionHash, input.index);
      final utxo = _utxoRepository.getUtxoState(walletId, utxoId);
      if (utxo == null) continue;

      // 자기 참조 케이스 확인 (spentByTransactionHash가 현재 트랜잭션과 동일한 경우는 무시)
      if (utxo.spentByTransactionHash == tx.transactionHash) continue;

      // RBF 조건 확인
      if (await isRbfTransaction(walletId, utxo)) {
        return utxo;
      }
    }

    return null;
  }

  /// 해당 UTXO가 RBF를 위한 조건을 만족하는지 확인
  Future<bool> isRbfTransaction(int walletId, UtxoState utxo) async {
    if (utxo.status != UtxoStatus.outgoing || utxo.spentByTransactionHash == null) {
      return false;
    }

    // 해당 UTXO를 이미 소비한 트랜잭션 조회
    final spentTransaction =
        _transactionRepository.getTransactionRecord(walletId, utxo.spentByTransactionHash!);

    // 미확인 상태인 트랜잭션만 RBF 대상
    return spentTransaction != null && spentTransaction.blockHeight < 1;
  }

  /// 원본 트랜잭션 해시를 찾는 함수
  Future<String> findOriginalTransactionHash(int walletId, String spentTxHash) async {
    // 대체되는 트랜잭션의 RBF 내역 확인
    final previousRbfHistory = _transactionRepository.getRbfHistoryList(walletId, spentTxHash);

    if (previousRbfHistory.isNotEmpty) {
      // 이미 RBF 내역이 있는 경우, 기존 originalTransactionHash 사용
      return previousRbfHistory.first.originalTransactionHash;
    } else {
      // 첫 번째 RBF인 경우, 대체되는 트랜잭션이 originalTransactionHash
      return spentTxHash;
    }
  }

  /// RBF를 받는 지갑 관점에서 Incoming 상태의 UTXO 트랜잭션이 유효한지 확인,
  /// RBF 발견 시 대체된 트랜잭션의 해시를 반환
  Future<String?> detectReceivingRbfTransaction(
    int walletId,
    Transaction tx,
  ) async {
    final incomingUtxoList = _utxoRepository.getUtxosByStatus(walletId, UtxoStatus.incoming);

    // 수신 중인 UTXO가 없으면 RBF 대상이 아님
    if (incomingUtxoList.isEmpty) {
      return null;
    }

    for (final utxo in incomingUtxoList) {
      // 이미 확인된 트랜잭션은 RBF 대상이 아님
      final txRecord = _transactionRepository.getTransactionRecord(walletId, utxo.transactionHash);
      if (txRecord == null || txRecord.blockHeight > 0) {
        continue;
      }

      try {
        // 새 트랜잭션과 기존 트랜잭션이 동일한 경우 제외
        if (utxo.transactionHash == tx.transactionHash) {
          continue;
        }

        // 기존 트랜잭션 조회
        final oldTx =
            Transaction.parse(await _electrumService.getTransaction(utxo.transactionHash));

        // 인풋이 겹치는지 확인
        final oldTxInputs =
            oldTx.inputs.map((input) => '${input.transactionHash}:${input.index}').toSet();
        final newTxInputs =
            tx.inputs.map((input) => '${input.transactionHash}:${input.index}').toSet();
        final overlappingInputs = oldTxInputs.intersection(newTxInputs);

        // 겹치는 인풋이 있고 새 트랜잭션의 수수료율이 더 높다면 RBF로 간주
        if (overlappingInputs.isNotEmpty) {
          final oldTxRecord =
              _transactionRepository.getTransactionRecord(walletId, oldTx.transactionHash);
          final newTxRecord =
              _transactionRepository.getTransactionRecord(walletId, tx.transactionHash);

          if (oldTxRecord != null &&
              newTxRecord != null &&
              oldTxRecord.feeRate < newTxRecord.feeRate) {
            Logger.log(
                '[$walletId] 수신 RBF 감지: ${oldTx.transactionHash}이(가) ${tx.transactionHash}에 의해 대체됨');
            return oldTx.transactionHash;
          }
        }
      } catch (e) {
        // 기존 트랜잭션을 조회할 수 없는 경우 (이미 mempool에서 제거된 경우)
        Logger.log('트랜잭션 ${utxo.transactionHash} 조회 실패: $e');
        return null;
      }
    }

    return null;
  }

  /// RBF 내역을 일괄 저장하는 함수
  Future<void> saveRbfHistoryMap({
    required int walletId,
    required Map<String, RbfInfo> rbfInfoMap,
    required Map<String, TransactionRecord> txRecordMap,
  }) async {
    final rbfHistoryDtos = <RbfHistory>[];

    for (final entry in rbfInfoMap.entries) {
      final txRecord = txRecordMap[entry.key];

      if (txRecord != null) {
        await _processRbfEntry(walletId, entry.value, txRecord, rbfHistoryDtos);
      }
    }

    // 일괄 저장
    if (rbfHistoryDtos.isNotEmpty) {
      _transactionRepository.addAllRbfHistory(rbfHistoryDtos);
    }
  }

  /// 개별 RBF 항목을 처리하는 함수
  Future<void> _processRbfEntry(int walletId, RbfInfo rbfInfo, TransactionRecord txRecord,
      List<RbfHistory> rbfHistoryDtos) async {
    // 원본 트랜잭션 조회
    final originalTx =
        _transactionRepository.getTransactionRecord(walletId, rbfInfo.originalTransactionHash);

    if (originalTx != null) {
      final existingRbfHistory =
          _transactionRepository.getRbfHistoryList(walletId, txRecord.transactionHash);

      // 최초로 RBF 내역을 등록하는 경우 원본 트랜잭션 내역도 등록
      if (existingRbfHistory.isEmpty) {
        rbfHistoryDtos.add(RbfHistory(
          walletId: walletId,
          originalTransactionHash: rbfInfo.originalTransactionHash,
          transactionHash: rbfInfo.originalTransactionHash,
          feeRate: originalTx.feeRate,
          timestamp: originalTx.timestamp,
        ));
      }

      // 새 RBF 트랜잭션 내역 등록
      rbfHistoryDtos.add(RbfHistory(
        walletId: walletId,
        originalTransactionHash: rbfInfo.originalTransactionHash,
        transactionHash: txRecord.transactionHash,
        feeRate: txRecord.feeRate,
        timestamp: DateTime.now(),
      ));
    } else {
      Logger.error('원본 트랜잭션을 찾을 수 없음: ${rbfInfo.originalTransactionHash}');
    }
  }
}
