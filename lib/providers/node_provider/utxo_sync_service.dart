import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
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
    WalletItemBase walletItem,
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
  Future<List<UtxoState>> fetchUtxoStateList(WalletItemBase walletItem, ScriptStatus scriptStatus) async {
    try {
      final unspentResList = await _electrumService.getUnspentList(
        walletItem.walletBase.addressType,
        scriptStatus.address,
      );

      final realmTransactions = _transactionRepository.getRealmTransactionListByHashes(
        walletItem.id,
        unspentResList.map((unspentRes) => unspentRes.txHash).toSet(),
      );
      final transactionMap = {for (var realmTx in realmTransactions) realmTx.transactionHash: realmTx};
      final realmLockedUtxos = _utxoRepository.getUtxosByStatus(walletItem.id, UtxoStatus.locked);
      final lockedUtxoMap = {for (final utxo in realmLockedUtxos) getUtxoId(utxo.transactionHash, utxo.index): utxo};
      return unspentResList
      // 이미 사용된 UTXO는 필터링하여 제외
      .map((e) {
        // 정상적으로는 이 UTXO를 만든 트랜잭션이 바로 앞의 트랜잭션 fetch 단계에서 이미
        // RealmTransaction으로 저장돼 있어야 하지만, 대량 콜드 스캔(전체 재동기화 등) 상황에서
        // 드물게 아직 반영되지 않은 채로 조회되는 경우가 있다. 이 하나 때문에 해당 주소의
        // UTXO 전체를(리스트 전체가 catch로 빠지며) 잃지 않도록 timestamp만 임시값으로
        // 대체하고 UTXO 자체(잔액에 직결되는 데이터)는 그대로 반환한다.
        final realmTx = transactionMap[e.txHash];
        if (realmTx == null) {
          Logger.error(
            'fetchUtxoStateList: RealmTransaction not found for ${e.txHash} '
            '(${scriptStatus.derivationPath}-${scriptStatus.address}) - timestamp를 임시값으로 대체',
          );
        }

        return UtxoState(
          transactionHash: e.txHash,
          index: e.txPos,
          amount: e.value,
          derivationPath: scriptStatus.derivationPath,
          blockHeight: e.height,
          to: scriptStatus.address,
          status: () {
            if (e.height <= 0) return UtxoStatus.incoming;

            final lockedUtxo = lockedUtxoMap[getUtxoId(e.txHash, e.txPos)];
            if (lockedUtxo == null || lockedUtxo.status == UtxoStatus.unspent) {
              return UtxoStatus.unspent;
            } else {
              return UtxoStatus.locked;
            }
          }(),
          timestamp: realmTx?.timestamp ?? DateTime.now(),
        );
      }).toList();
    } catch (e, stackTrace) {
      Logger.error('Failed to get UTXO list - [${scriptStatus.derivationPath}-${scriptStatus.address}}] $e');
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
        '${utxo.transactionHash.substring(0, 10)}:${utxo.index} - ${utxo.status} isRbfable: ${utxo.isRbfable} isCpfpable: ${utxo.isCpfpable} amount: ${utxo.amount} spentByTransactionHash: ${utxo.spentByTransactionHash?.substring(0, 10)}',
      );
    }
    Logger.log('---------------- utxoStateList end ----------------');
  }

  /// 언컨펌 출금 트랜잭션에 대한 UTXO를 생성합니다.
  /// 지갑 추가 시 기존 UTXO가 조회되지 않는 경우를 대비하여 필요한 UTXO를 추가합니다.
  Future<void> createOutgoingUtxos(WalletItemBase walletItem) async {
    try {
      // 1. 언컨펌 출금 트랜잭션 목록 조회
      final unconfirmedTransactions = _transactionRepository.getUnconfirmedTransactionRecordList(walletItem.id);
      final sentTransactions =
          unconfirmedTransactions.where((tx) => tx.transactionType == TransactionType.sent).toList();

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
          final utxoId = getUtxoId(input.transactionHash, input.index);

          if (existingUtxoIds.contains(utxoId)) {
            continue;
          }

          Transaction? previousTx;
          try {
            previousTx = previousTxs.firstWhere((prevTx) => prevTx.transactionHash == input.transactionHash);
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

  /// orphaned UTXO를 정리합니다.
  Future<void> cleanupOrphanedUtxos(WalletItemBase walletItem) async {
    final pendingUtxos = _utxoRepository.getUtxoStateList(walletItem.id).where((utxo) => utxo.isPending).toList();

    final orphanUtxoSet = <UtxoState>{};
    for (final utxo in pendingUtxos) {
      if (utxo.status == UtxoStatus.outgoing && utxo.spentByTransactionHash != null) {
        final tx = _transactionRepository.getTransactionRecord(walletItem.id, utxo.spentByTransactionHash!);
        if (tx == null || tx.blockHeight > 0) {
          orphanUtxoSet.add(utxo);
        }
      } else if (utxo.status == UtxoStatus.incoming) {
        final tx = _transactionRepository.getTransactionRecord(walletItem.id, utxo.transactionHash);
        if (tx == null || tx.blockHeight > 0) {
          orphanUtxoSet.add(utxo);
        }
      }
    }

    if (orphanUtxoSet.isNotEmpty) {
      await _utxoRepository.deleteUtxoList(walletItem.id, orphanUtxoSet.map((utxo) => utxo.utxoId).toList());
    }
  }
}
