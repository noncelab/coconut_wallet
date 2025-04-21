import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/model/node/cpfp_info.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';

/// CPFP(Child-Pays-For-Parent) 트랜잭션 처리를 담당하는 클래스
class CpfpService {
  final TransactionRepository _transactionRepository;
  final UtxoSyncService _utxoSyncService;
  final ElectrumService _electrumService;

  CpfpService(
    this._transactionRepository,
    this._utxoSyncService,
    this._electrumService,
  );

  /// CPFP 트랜잭션을 감지합니다.
  ///
  /// CPFP는 미확인 트랜잭션의 출력을 입력으로 사용하는 새로운 트랜잭션이 발생했을 때 감지됩니다.
  Future<CpfpInfo?> detectCpfpTransaction(int walletId, Transaction tx) async {
    // 이미 CPFP 내역이 있는지 확인
    final existingCpfpHistory = _transactionRepository.getCpfpHistory(walletId, tx.transactionHash);
    if (existingCpfpHistory != null) {
      return null; // 이미 CPFP로 등록된 트랜잭션
    }

    // 트랜잭션의 입력이 미확인 트랜잭션의 출력을 사용하는지 확인
    bool isCpfp = false;
    String? parentTxHash;
    double originalFee = 0.0;

    for (final input in tx.inputs) {
      // 입력으로 사용된 트랜잭션이 미확인 상태인지 확인
      final parentTxRecord =
          _transactionRepository.getTransactionRecord(walletId, input.transactionHash);
      // 입력 트랜잭션이 언컨펌이면서
      if (parentTxRecord != null && parentTxRecord.blockHeight == 0) {
        final utxo =
            _utxoSyncService.getUtxoState(walletId, makeUtxoId(input.transactionHash, input.index));
        // 입력 트랜잭션에 사용된 UTXO가 내 UTXO라면 CPFP로 간주
        if (utxo != null) {
          isCpfp = true;
          parentTxHash = parentTxRecord.transactionHash;
          originalFee = parentTxRecord.feeRate;
          break;
        }
      }
    }

    if (isCpfp && parentTxHash != null) {
      // 수수료 계산을 위한 정보 수집
      final prevTxs = await _electrumService.getPreviousTransactions(tx);

      return CpfpInfo(
        parentTransactionHash: parentTxHash,
        originalFee: originalFee,
        previousTransactions: prevTxs,
      );
    }

    return null;
  }

  Future<void> saveCpfpHistoryMap(WalletListItemBase walletItem, Map<String, CpfpInfo> cpfpInfoMap,
      Map<String, TransactionRecord> txRecordMap, int walletId) async {
    final cpfpHistoryDtos = <CpfpHistoryDto>[];

    for (final entry in cpfpInfoMap.entries) {
      final txHash = entry.key;
      final cpfpInfo = entry.value;
      final txRecord = txRecordMap[txHash];

      if (txRecord != null) {
        cpfpHistoryDtos.add(CpfpHistoryDto(
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
