import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager_interface.dart';

/// NodeProvider의 UTXO 관련 기능을 담당하는 매니저 클래스
class UtxoManager {
  final ElectrumService _electrumService;
  final StateManagerInterface _stateManager;
  final UtxoRepository _utxoRepository;

  UtxoManager(
    this._electrumService,
    this._stateManager,
    this._utxoRepository,
  );

  /// 스크립트의 UTXO를 조회하고 업데이트합니다.
  Future<void> fetchScriptUtxo(
    WalletListItemBase walletItem,
    ScriptStatus scriptStatus, {
    bool inBatchProcess = false,
  }) async {
    if (!inBatchProcess) {
      // UTXO 동기화 시작 state 업데이트
      _stateManager.addWalletSyncState(walletItem.id, UpdateElement.utxo);
    }

    // UTXO 목록 조회
    final utxos = await fetchUtxoStateList(
        walletItem.walletBase.addressType, scriptStatus);

    final utxoBlockHeightSet = utxos
        .map((utxo) => utxo.blockHeight)
        .where((height) => height > 0)
        .toSet();

    final blockTimestampMap =
        await _electrumService.fetchBlocksByHeight(utxoBlockHeightSet);

    UtxoState.updateTimestampFromBlocks(utxos, blockTimestampMap);

    for (var utxo in utxos) {
      if (utxo.blockHeight == 0) {
        utxo.status = UtxoStatus.incoming;
      }
    }

    _utxoRepository.addAllUtxos(walletItem.id, utxos);

    if (!inBatchProcess) {
      // UTXO 업데이트 완료 state 업데이트
      _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.utxo);
    }
  }

  /// 스크립트에 대한 UTXO 목록을 가져옵니다.
  Future<List<UtxoState>> fetchUtxoStateList(
      AddressType addressType, ScriptStatus scriptStatus) async {
    try {
      final utxos = await _electrumService.getUnspentList(
          addressType, scriptStatus.address);
      return utxos
          .map((e) => UtxoState(
                transactionHash: e.txHash,
                index: e.txPos,
                amount: e.value,
                derivationPath: scriptStatus.derivationPath,
                blockHeight: e.height,
                to: scriptStatus.address,
                status: UtxoStatus.unspent,
              ))
          .toList();
    } catch (e) {
      Logger.error('Failed to get UTXO list: $e');
      return [];
    }
  }

  /// 트랜잭션에 사용된 UTXO의 상태를 업데이트합니다.
  void updateUtxoStatusToOutgoingByTransaction(
    int walletId,
    Transaction transaction,
  ) {
    Logger.log('UTXO 상태 업데이트 (outgoing): ${transaction.transactionHash}');
    // 트랜잭션 입력을 순회하며 사용된 UTXO를 pending 상태로 변경
    for (var input in transaction.inputs) {
      // UTXO 소유 지갑 ID 찾기
      final utxoId = makeUtxoId(input.transactionHash, input.index);
      final utxo = _utxoRepository.getUtxoState(walletId, utxoId);

      // UTXO가 자기 자신을 참조하지 않는지 확인
      if (utxo?.spentByTransactionHash == transaction.transactionHash) {
        Logger.log('자기 참조 UTXO 감지: $utxoId는 현재 트랜잭션에 의해 사용됨');
        continue;
      }

      if (utxo == null) {
        continue;
      }

      // UTXO를 outgoing 상태로 표시하고 RBF 관련 정보 저장
      _utxoRepository.markUtxoAsOutgoing(
        walletId,
        utxoId,
        transaction.transactionHash,
      );
      Logger.log(
          'UTXO를 outgoing으로 표시: $utxoId (spentBy: ${transaction.transactionHash})');
    }
  }

  UtxoState? getUtxoState(int walletId, String utxoId) {
    return _utxoRepository.getUtxoState(walletId, utxoId);
  }

  void deleteUtxosByTransaction(
    int walletId,
    Transaction transaction,
  ) {
    final utxoIds = transaction.inputs
        .map((input) => makeUtxoId(input.transactionHash, input.index))
        .toList();

    _utxoRepository.deleteUtxoList(walletId, utxoIds);
  }

  // 디버깅용
  void printUtxoStateList(int walletId) {
    List<UtxoState> utxoStateList = _utxoRepository.getUtxoStateList(walletId);

    Logger.log(
        '---------------- utxoStateList: ${utxoStateList.length} ----------------');
    for (var utxo in utxoStateList) {
      Logger.log(
          '${utxo.transactionHash.substring(0, 10)}:${utxo.index} - ${utxo.status} isRbfable: ${utxo.isRbfable} isCpfpable: ${utxo.isCpfpable} amount: ${utxo.amount} spentByTransactionHash: ${utxo.spentByTransactionHash?.substring(0, 10)}');
    }
    Logger.log('---------------- utxoStateList end ----------------');
  }

  void deleteUtxosByReplacedTransactionHashSet(
      int walletId, Set<String> replacedTxHashs) {
    _utxoRepository.deleteUtxosByReplacedTransactionHashSet(
        walletId, replacedTxHashs);
  }
}
