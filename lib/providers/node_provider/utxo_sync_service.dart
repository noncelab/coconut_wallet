import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';
import 'package:coconut_wallet/providers/node_provider/state/state_manager_interface.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';

/// NodeProvider의 UTXO 관련 기능을 담당하는 서비스 클래스
class UtxoSyncService {
  final ElectrumService _electrumService;
  final StateManagerInterface _stateManager;
  final UtxoRepository _utxoRepository;
  final TransactionRepository _transactionRepository;
  final AddressRepository _addressRepository;

  UtxoSyncService(
    this._electrumService,
    this._stateManager,
    this._utxoRepository,
    this._transactionRepository,
    this._addressRepository,
  );

  /// 스크립트의 UTXO를 조회하고 업데이트합니다.
  /// TransactionRecord 데이터를 사용하므로 트랜잭션 fetch 이후 호출되어야 합니다.
  Future<void> fetchScriptUtxo(
    WalletListItemBase walletItem,
    ScriptStatus scriptStatus, {
    bool inBatchProcess = false,
  }) async {
    // UTXO 목록 조회
    final utxos = await fetchUtxoStateList(walletItem, scriptStatus);

    await _utxoRepository.addAllUtxos(walletItem.id, utxos);

    if (!inBatchProcess) {
      // UTXO 업데이트 완료 state 업데이트
      _stateManager.addWalletCompletedState(walletItem.id, UpdateElement.utxo);
    }
  }

  /// 스크립트에 대한 UTXO 목록을 가져옵니다.
  Future<List<UtxoState>> fetchUtxoStateList(
      WalletListItemBase walletItem, ScriptStatus scriptStatus) async {
    try {
      final unspentResList = await _electrumService.getUnspentList(
          walletItem.walletBase.addressType, scriptStatus.address);

      final realmTransactions = _transactionRepository.getRealmTransactionListByHashes(
          walletItem.id, unspentResList.map((unspentRes) => unspentRes.txHash).toSet());
      final transactionMap = {
        for (var realmTx in realmTransactions) realmTx.transactionHash: realmTx
      };

      return unspentResList
          // 이미 사용된 UTXO는 필터링하여 제외
          .map((e) => UtxoState(
                transactionHash: e.txHash,
                index: e.txPos,
                amount: e.value,
                derivationPath: scriptStatus.derivationPath,
                blockHeight: e.height,
                to: scriptStatus.address,
                status: e.height > 0 ? UtxoStatus.unspent : UtxoStatus.incoming,
                timestamp: transactionMap[e.txHash]!.timestamp,
              ))
          .toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to get UTXO list: $e');
      Logger.error('Stack trace: $stackTrace');
      return [];
    }
  }

  // 디버깅용
  void printUtxoStateList(int walletId) {
    List<UtxoState> utxoStateList = _utxoRepository.getUtxoStateList(walletId);

    Logger.log('---------------- utxoStateList: ${utxoStateList.length} ----------------');
    for (var utxo in utxoStateList) {
      Logger.log(
          '${utxo.transactionHash.substring(0, 10)}:${utxo.index} - ${utxo.status} isRbfable: ${utxo.isRbfable} isCpfpable: ${utxo.isCpfpable} amount: ${utxo.amount} spentByTransactionHash: ${utxo.spentByTransactionHash?.substring(0, 10)}');
    }
    Logger.log('---------------- utxoStateList end ----------------');
  }

  /// 언컨펌 출금 트랜잭션에 대한 UTXO를 생성합니다.
  /// 지갑 추가 시 기존 UTXO가 조회되지 않는 경우를 대비하여 필요한 UTXO를 추가합니다.
  Future<void> createOutgoingUtxos(WalletListItemBase walletItem) async {
    try {
      // 1. 언컨펌 출금 트랜잭션 목록 조회
      final unconfirmedTransactions =
          _transactionRepository.getUnconfirmedTransactionRecordList(walletItem.id);
      final sentTransactions = unconfirmedTransactions
          .where((tx) => tx.transactionType == TransactionType.sent)
          .toList();

      // 언컨펌 sent 트랜잭션이 없으면 처리 필요 없음
      if (sentTransactions.isEmpty) {
        return;
      }

      final newUtxoList = <UtxoState>[];

      // 2. 현재 DB에 있는 UTXO 목록 조회 (ID 기준 맵으로 변환)
      final existingUtxos = _utxoRepository.getUtxoStateList(walletItem.id);
      final existingUtxoIds = existingUtxos.map((utxo) => utxo.utxoId).toSet();

      // 3. 각 트랜잭션에 대해 트랜잭션 상세 정보 조회
      for (final txRecord in sentTransactions) {
        final txHex = await _electrumService.getTransaction(txRecord.transactionHash);
        final transaction = Transaction.parse(txHex);

        // 4. 이전 트랜잭션 조회 (트랜잭션의 입력으로 사용된 트랜잭션)
        final previousTxs = await _electrumService.getPreviousTransactions(transaction);

        if (previousTxs.isEmpty) {
          continue; // 이전 트랜잭션을 찾을 수 없으면 처리 불가
        }

        // 5. 트랜잭션 입력 분석하여 내 지갑의 UTXO인지 확인
        for (int i = 0; i < transaction.inputs.length; i++) {
          final input = transaction.inputs[i];
          final utxoId = makeUtxoId(input.transactionHash, input.index);

          if (existingUtxoIds.contains(utxoId)) {
            continue;
          }

          Transaction? previousTx;
          try {
            previousTx =
                previousTxs.firstWhere((prevTx) => prevTx.transactionHash == input.transactionHash);
          } catch (_) {
            continue;
          }

          if (input.index >= previousTx.outputs.length) {
            continue;
          }

          final previousOutput = previousTx.outputs[input.index];
          final address = previousOutput.scriptPubKey.getAddress();

          if (!_addressRepository.containsAddress(walletItem.id, address)) {
            continue;
          }

          final newUtxo = UtxoState(
            transactionHash: input.transactionHash,
            index: input.index,
            amount: previousOutput.amount,
            derivationPath: _addressRepository.getDerivationPath(walletItem.id, address),
            blockHeight: 0,
            to: address,
            status: UtxoStatus.outgoing,
            spentByTransactionHash: transaction.transactionHash,
            // 언컨펌 상태이므로 블록 높이나 타임스탬프 값 대신 createdAt 값 사용
            timestamp: txRecord.createdAt,
          );
          newUtxoList.add(newUtxo);
        }
      }

      // 생성한 UTXO 추가
      await _utxoRepository.addAllUtxos(walletItem.id, newUtxoList);
    } catch (e, stackTrace) {
      Logger.error('Failed to create outgoing UTXOs: $e');
      Logger.error('Stack trace: $stackTrace');
    }
  }
}
