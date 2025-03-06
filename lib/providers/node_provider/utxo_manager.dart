import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/network/node_client.dart';

/// NodeProvider의 UTXO 관련 기능을 담당하는 매니저 클래스
class UtxoManager {
  final NodeClient _nodeClient;
  final NodeStateManager _stateManager;
  final UtxoRepository _utxoRepository;

  UtxoManager(
    this._nodeClient,
    this._stateManager,
    this._utxoRepository,
  );

  /// 스크립트의 UTXO를 조회하고 업데이트합니다.
  Future<void> fetchScriptUtxo(
    WalletListItemBase walletItem,
    ScriptStatus scriptStatus,
  ) async {
    // UTXO 동기화 시작 state 업데이트
    _stateManager.addWalletSyncState(walletItem.id, UpdateElement.utxo);

    // UTXO 목록 조회
    final utxos = await _nodeClient.getUtxoStateList(scriptStatus);

    final blockTimestampMap = await _nodeClient
        .getBlocksByHeight(utxos.map((utxo) => utxo.blockHeight).toSet());

    UtxoState.updateTimestampFromBlocks(utxos, blockTimestampMap);

    for (var utxo in utxos) {
      if (utxo.blockHeight == 0) {
        utxo.status = UtxoStatus.incoming;
      }
    }

    _utxoRepository.addAllUtxos(walletItem.id, utxos);

    // UTXO 업데이트 완료 state 업데이트
    _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.utxo);
  }

  /// 트랜잭션에 사용된 UTXO의 상태를 업데이트합니다.
  void updateUtxoStatusToOutgoingByTransaction(
    int walletId,
    Transaction transaction,
  ) {
    // 트랜잭션 입력을 순회하며 사용된 UTXO를 pending 상태로 변경
    for (var input in transaction.inputs) {
      // UTXO 소유 지갑 ID 찾기
      final inputTxHash = input.transactionHash;
      final inputIndex = input.index;

      // UTXO를 pending 상태로 표시하고 RBF 관련 정보 저장
      _utxoRepository.markUtxoAsOutgoing(
        walletId,
        inputTxHash,
        inputIndex,
        transaction.transactionHash,
      );
    }
  }
}
