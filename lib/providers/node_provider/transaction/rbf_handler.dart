import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/models/rbf_info.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_manager.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';

/// RBF(Replace-By-Fee) 트랜잭션 처리를 담당하는 클래스
class RbfHandler {
  final TransactionRepository _transactionRepository;
  final UtxoManager _utxoManager;

  RbfHandler(this._transactionRepository, this._utxoManager);

  /// RBF 트랜잭션을 감지합니다.
  ///
  /// RBF는 같은 UTXO를 소비하는 새로운 트랜잭션이 발생했을 때 감지됩니다.
  /// 이 메서드는 새로운 트랜잭션이 기존의 outgoing 상태인 UTXO를 소비하는지 확인합니다.
  Future<RbfInfo?> detectRbfTransaction(
      int walletId,
      Transaction tx,
      Future<List<Transaction>> Function(Transaction, List<Transaction>)
          getPreviousTransactions) async {
    Logger.log('===== RBF 감지 프로세스 시작 =====');
    Logger.log('트랜잭션 확인: ${tx.transactionHash}');

    // 이미 RBF 내역이 있는지 확인
    final existingRbfHistory =
        _transactionRepository.getRbfHistoryList(walletId, tx.transactionHash);
    if (existingRbfHistory.isNotEmpty) {
      Logger.log('이미 RBF 내역이 있는 트랜잭션: ${tx.transactionHash}');
      Logger.log('===== RBF 감지 프로세스 종료 (중복 내역) =====');
      return null; // 이미 RBF로 등록된 트랜잭션
    }

    // 트랜잭션의 입력이 outgoing 상태인 UTXO를 사용하는지 확인
    bool isRbf = false;
    String? spentTxHash; // 이 트랜잭션이 대체하는 직전 트랜잭션

    Logger.log('입력 UTXO 분석 시작 (입력 개수: ${tx.inputs.length})');
    for (final input in tx.inputs) {
      final utxoId = makeUtxoId(input.transactionHash, input.index);
      final utxo = _utxoManager.getUtxoState(walletId, utxoId);

      if (utxo != null) {
        Logger.log(
            'UTXO 검사: $utxoId, 상태: ${utxo.status}, spentByTx: ${utxo.spentByTransactionHash}');

        // 자기 참조 케이스 확인 (spentByTransactionHash가 현재 트랜잭션과 동일한 경우는 무시)
        if (utxo.spentByTransactionHash == tx.transactionHash) {
          Logger.log('자기 참조 케이스 감지: spentByTransactionHash가 현재 트랜잭션과 동일함');
          continue;
        }
      } else {
        Logger.log('UTXO 없음: $utxoId');
        continue;
      }

      if (utxo.status == UtxoStatus.outgoing &&
          utxo.spentByTransactionHash != null) {
        // 최초 트랜잭션과 RBF를 구분하기 위한 로직
        final spentTransaction = _transactionRepository.getTransactionRecord(
            walletId, utxo.spentByTransactionHash!);

        Logger.log(
            'spentTransaction 검사: ${utxo.spentByTransactionHash}, 존재: ${spentTransaction != null}, 블록높이: ${spentTransaction?.blockHeight}');

        // spentTransaction이 존재하지 않는 경우 처리 (트랜잭션이 아직 DB에 없을 수 있음)
        if (spentTransaction == null) {
          Logger.log(
              'spentTransaction이 존재하지 않음. UTXO의 outgoing 상태를 기반으로 RBF로 간주합니다.');
          isRbf = true;
          spentTxHash = utxo.spentByTransactionHash;
          break;
        }

        // spentTransaction이 존재하고, 해당 트랜잭션이 미확인 상태일 때만 RBF로 간주
        if (spentTransaction.blockHeight != null &&
            spentTransaction.blockHeight! < 1) {
          Logger.log(
              'RBF 조건 충족: $utxoId, spentTx: ${utxo.spentByTransactionHash}');
          isRbf = true;
          spentTxHash = utxo.spentByTransactionHash;
          break;
        }
      }
    }

    if (isRbf && spentTxHash != null) {
      // 대체되는 트랜잭션의 RBF 내역 확인
      final previousRbfHistory =
          _transactionRepository.getRbfHistoryList(walletId, spentTxHash);

      String originalTxHash;
      if (previousRbfHistory.isNotEmpty) {
        // 이미 RBF 내역이 있는 경우, 기존 originalTransactionHash 사용
        originalTxHash = previousRbfHistory.first.originalTransactionHash;
        Logger.log('연속된 RBF 감지: 원본 트랜잭션 해시 유지 $originalTxHash');
      } else {
        // 첫 번째 RBF인 경우, 대체되는 트랜잭션이 originalTransactionHash
        originalTxHash = spentTxHash;
        Logger.log('첫 번째 RBF 감지: 원본 트랜잭션 해시 설정 $originalTxHash');
      }

      // 수수료 계산을 위한 정보 수집
      final prevTxs = await getPreviousTransactions(tx, []);

      Logger.log('===== RBF 감지 프로세스 종료 (RBF 감지됨) =====');
      return RbfInfo(
        originalTransactionHash: originalTxHash,
        spentTransactionHash: spentTxHash,
        previousTransactions: prevTxs,
      );
    }

    Logger.log('===== RBF 감지 프로세스 종료 (RBF 감지 안됨) =====');
    return null;
  }

  Future<void> saveRbfHistoryMap(
      WalletListItemBase walletItem,
      Map<String, RbfInfo> rbfInfoMap,
      Map<String, TransactionRecord> txRecordMap,
      int walletId) async {
    final rbfHistoryDtos = <RbfHistoryDto>[];

    for (final entry in rbfInfoMap.entries) {
      final txHash = entry.key;
      final rbfInfo = entry.value;
      final txRecord = txRecordMap[txHash];

      if (txRecord != null) {
        // 원본 트랜잭션 조회
        final originalTx = _transactionRepository.getTransactionRecord(
            walletItem.id, rbfInfo.originalTransactionHash);

        if (originalTx != null) {
          Logger.log(
              'RBF 내역 등록: $txHash ← ${rbfInfo.spentTransactionHash} (원본: ${rbfInfo.originalTransactionHash})');
          Logger.log('  - 수수료율: ${txRecord.feeRate}');

          rbfHistoryDtos.add(RbfHistoryDto(
            walletId: walletItem.id,
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

    // 일괄 저장
    if (rbfHistoryDtos.isNotEmpty) {
      await _transactionRepository.addAllRbfHistory(rbfHistoryDtos);
      Logger.log('RBF 내역 ${rbfHistoryDtos.length}개 저장 완료');
    }
  }
}
