import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';

typedef RbfInfo = ({
  String originalTransactionHash,
  String spentTransactionHash,
});

/// RBF 내역 저장 요청을 위한 DTO 클래스
class RbfSaveRequest {
  final WalletListItemBase walletItem;
  final Map<String, RbfInfo> rbfInfoMap;
  final Map<String, TransactionRecord> txRecordMap;

  RbfSaveRequest({
    required this.walletItem,
    required this.rbfInfoMap,
    required this.txRecordMap,
  });
}

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
      final spentTxHash = tx.transactionHash;
      // 원본 트랜잭션 해시 찾기
      final originalTxHash =
          await findOriginalTransactionHash(walletId, rbfInputInfo.spentByTransactionHash!);

      return (
        originalTransactionHash: originalTxHash,
        spentTransactionHash: spentTxHash,
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
      if (await isRbfTransaction(walletId, tx, utxo)) {
        return utxo;
      }
    }

    return null;
  }

  /// 해당 UTXO가 RBF를 위한 조건을 만족하는지 확인
  Future<bool> isRbfTransaction(int walletId, Transaction tx, UtxoState utxo) async {
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

    for (final utxo in incomingUtxoList) {
      if (await _isTransactionReplaced(utxo.transactionHash)) {
        return utxo.transactionHash;
      }
    }
    return null;
  }

  /// 트랜잭션이 대체되었는지 확인
  Future<bool> _isTransactionReplaced(String transactionHash) async {
    try {
      // 대체된 트랜잭션인지 확인, 대체된 트랜잭션은 mempool에 존재하지 않아 예외 발생
      await _electrumService.getTransaction(transactionHash, verbose: true);
      return false; // 예외가 발생하지 않으면 트랜잭션이 유효함
    } catch (e) {
      // 예외 발생 시 트랜잭션이 대체된 것으로 판단
      return true;
    }
  }

  /// RBF 내역을 일괄 저장하는 함수
  Future<void> saveRbfHistoryMap(RbfSaveRequest request, int walletId) async {
    await _processRbfSaveRequest(request, walletId);
  }

  /// RBF 저장 요청을 처리하는 내부 함수
  Future<void> _processRbfSaveRequest(RbfSaveRequest request, int walletId) async {
    final rbfHistoryDtos = <RbfHistoryDto>[];
    final walletItem = request.walletItem;

    for (final entry in request.rbfInfoMap.entries) {
      final txHash = entry.key;
      final rbfInfo = entry.value;
      final txRecord = request.txRecordMap[txHash];

      if (txRecord != null) {
        await _processRbfEntry(walletItem.id, rbfInfo, txRecord, rbfHistoryDtos);
      }
    }

    // 일괄 저장
    if (rbfHistoryDtos.isNotEmpty) {
      _transactionRepository.addAllRbfHistory(rbfHistoryDtos);
    }
  }

  /// 개별 RBF 항목을 처리하는 함수
  Future<void> _processRbfEntry(int walletId, RbfInfo rbfInfo, TransactionRecord txRecord,
      List<RbfHistoryDto> rbfHistoryDtos) async {
    // 원본 트랜잭션 조회
    final originalTx =
        _transactionRepository.getTransactionRecord(walletId, rbfInfo.originalTransactionHash);

    if (originalTx != null) {
      final existingRbfHistory =
          _transactionRepository.getRbfHistoryList(walletId, txRecord.transactionHash);

      // 최초로 RBF 내역을 등록하는 경우 원본 트랜잭션 내역도 등록
      if (existingRbfHistory.isEmpty) {
        rbfHistoryDtos.add(RbfHistoryDto(
          walletId: walletId,
          originalTransactionHash: rbfInfo.originalTransactionHash,
          transactionHash: rbfInfo.originalTransactionHash,
          feeRate: originalTx.feeRate,
          timestamp: originalTx.timestamp,
        ));
      }

      // 새 RBF 트랜잭션 내역 등록
      rbfHistoryDtos.add(RbfHistoryDto(
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
