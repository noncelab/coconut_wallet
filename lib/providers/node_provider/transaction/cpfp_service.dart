import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/node/cpfp_history.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';

typedef CpfpInfo = ({
  String parentTransactionHash,
  double originalFee,
  List<Transaction> previousTransactions,
});

/// CPFP(Child-Pays-For-Parent) 트랜잭션 처리를 담당하는 클래스
class CpfpService {
  final TransactionRepository _transactionRepository;
  final UtxoRepository _utxoRepository;
  final ElectrumService _electrumService;

  CpfpService(
    this._transactionRepository,
    this._utxoRepository,
    this._electrumService,
  );

  /// 기존 CPFP 내역이 있는지 확인
  bool hasExistingCpfpHistory(int walletId, String txHash) {
    final existingCpfpHistory = _transactionRepository.getCpfpHistory(walletId, txHash);
    return existingCpfpHistory != null;
  }

  /// CPFP 트랜잭션을 감지하는 함수
  Future<CpfpInfo?> detectCpfpTransaction(int walletId, Transaction tx) async {
    // 이미 CPFP 내역이 있는지 확인
    if (hasExistingCpfpHistory(walletId, tx.transactionHash)) {
      return null;
    }

    // 트랜잭션의 입력이 미확인 트랜잭션의 출력을 사용하는지 확인
    bool isCpfp = false;
    String? parentTxHash;
    double originalFee = 0.0;

    for (final input in tx.inputs) {
      final parentTxRecord =
          _transactionRepository.getTransactionRecord(walletId, input.transactionHash);

      if (parentTxRecord != null && parentTxRecord.blockHeight == 0) {
        final utxo =
            _utxoRepository.getUtxoState(walletId, makeUtxoId(input.transactionHash, input.index));
        if (utxo != null) {
          isCpfp = true;
          parentTxHash = parentTxRecord.transactionHash;
          originalFee = parentTxRecord.feeRate;
          break;
        }
      }
    }

    if (isCpfp && parentTxHash != null) {
      final prevTxs = await _electrumService.getPreviousTransactions(tx);
      return (
        parentTransactionHash: parentTxHash,
        originalFee: originalFee,
        previousTransactions: prevTxs,
      );
    }

    return null;
  }

  /// CPFP 내역을 저장하는 함수
  Future<void> saveCpfpHistoryMap(
    WalletListItemBase walletItem,
    Map<String, CpfpInfo> cpfpInfoMap,
    Map<String, TransactionRecord> txRecordMap,
    int walletId,
  ) async {
    final cpfpHistoryDtos = <CpfpHistory>[];

    for (final entry in cpfpInfoMap.entries) {
      final txHash = entry.key;
      final cpfpInfo = entry.value;
      final txRecord = txRecordMap[txHash];

      if (txRecord != null) {
        cpfpHistoryDtos.add(CpfpHistory(
          walletId: walletItem.id,
          parentTransactionHash: cpfpInfo.parentTransactionHash,
          childTransactionHash: txRecord.transactionHash,
          originalFee: cpfpInfo.originalFee,
          newFee: txRecord.feeRate,
          timestamp: DateTime.now(),
        ));
      }
    }

    // 일괄 저장
    if (cpfpHistoryDtos.isNotEmpty) {
      _transactionRepository.addAllCpfpHistory(cpfpHistoryDtos);
      Logger.log('Saved ${cpfpHistoryDtos.length} CPFP histories in batch');
    }
  }
}
