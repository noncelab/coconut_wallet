import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/cpfp_handler.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/models/cpfp_info.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/models/rbf_info.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/rbf_handler.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_processor.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_manager.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager_interface.dart';

/// 트랜잭션 조회를 담당하는 클래스
class TransactionFetcher {
  final ElectrumService _electrumService;
  final TransactionRepository _transactionRepository;
  final TransactionProcessor _transactionProcessor;
  final StateManagerInterface _stateManager;
  final UtxoManager _utxoManager;
  final RbfHandler _rbfHandler;
  final CpfpHandler _cpfpHandler;

  TransactionFetcher(
    this._electrumService,
    this._transactionRepository,
    this._transactionProcessor,
    this._stateManager,
    this._utxoManager,
  )   : _rbfHandler =
            RbfHandler(_transactionRepository, _utxoManager, _electrumService),
        _cpfpHandler = CpfpHandler(_transactionRepository, _utxoManager);

  /// 특정 스크립트의 트랜잭션을 조회하고 업데이트합니다.
  Future<void> fetchScriptTransaction(
    WalletListItemBase walletItem,
    ScriptStatus scriptStatus, {
    DateTime? now,
    bool inBatchProcess = false,
  }) async {
    if (!inBatchProcess) {
      // Transaction 동기화 시작 state 업데이트
      _stateManager.addWalletSyncState(
          walletItem.id, UpdateElement.transaction);
    }

    // db에 저장된 트랜잭션 조회, 네트워크 요청을 줄이기 위함.
    final knownTransactionHashes =
        _transactionRepository.getConfirmedTransactionHashSet(walletItem.id);

    // 스크립트에 대한 트랜잭션 내역 조회, 이미 존재하는 트랜잭션은 제외함
    final txFetchResults = await getFetchTransactionResponses(
        walletItem.walletBase.addressType,
        scriptStatus,
        knownTransactionHashes);

    final unconfirmedFetchedTxHashes = txFetchResults
        // 언컨펌 UTXO가 사용된 트랜잭션은 블록 높이가 -1로 조회되어 '0이하' 조건이 필요함
        .where((tx) => tx.height <= 0)
        .map((tx) => tx.transactionHash)
        .toSet();

    final confirmedFetchedTxHashes = txFetchResults
        .where((tx) => tx.height > 0)
        .map((tx) => tx.transactionHash)
        .toSet();

    // 트랜잭션 조회 결과가 없는 경우 state 변경 후 종료
    if (txFetchResults.isEmpty) {
      if (!inBatchProcess) {
        _stateManager.addWalletCompletedState(
            walletItem.id, UpdateElement.transaction);
      }
      return;
    }

    // 트랜잭션에 타임스탬프를 기록하기 위해 해당 트랜잭션이 속한 블록 조회
    final txBlockHeightMap = Map<String, int>.fromEntries(txFetchResults
        .where((tx) => tx.height > 0)
        .map((tx) => MapEntry(tx.transactionHash, tx.height)));

    final blockTimestampMap = txBlockHeightMap.isEmpty
        ? <int, BlockTimestamp>{}
        : await _electrumService
            .fetchBlocksByHeight(txBlockHeightMap.values.toSet());

    // 트랜잭션 상세 정보 조회
    final fetchedTransactions = await fetchTransactions(
        txFetchResults.map((tx) => tx.transactionHash).toSet());

    // RBF 및 CPFP 감지 결과를 저장할 맵
    Map<String, RbfInfo> sendingRbfInfoMap = {};
    Set<String> receivingRbfTxHashSet = {};
    Map<String, CpfpInfo> cpfpInfoMap = {};

    // 각 트랜잭션에 대해 사용된 UTXO 상태 업데이트
    for (final fetchedTx in fetchedTransactions) {
      // 언컨펌 트랜잭션의 경우 새로 브로드캐스트된 트랜잭션이므로 사용된 UTXO 상태 업데이트
      if (unconfirmedFetchedTxHashes.contains(fetchedTx.transactionHash)) {
        // RBF 및 CPFP 감지
        final sendingRbfInfo = await _rbfHandler.detectSendingRbfTransaction(
          walletItem.id,
          fetchedTx,
          _transactionProcessor.getPreviousTransactions,
        );
        if (sendingRbfInfo != null) {
          sendingRbfInfoMap[fetchedTx.transactionHash] = sendingRbfInfo;
          Logger.log(
              '[${walletItem.name}] 보내는 RBF 트랜잭션 감지됨: ${fetchedTx.transactionHash}');
        }

        final receivingRbfTxHash =
            await _rbfHandler.detectReceivingRbfTransaction(
          walletItem.id,
          fetchedTx,
        );
        if (receivingRbfTxHash != null) {
          receivingRbfTxHashSet.add(receivingRbfTxHash);
          Logger.log(
              '[${walletItem.name}] 받는 RBF 트랜잭션 감지됨: ${fetchedTx.transactionHash}');
        }

        final cpfpInfo = await _cpfpHandler.detectCpfpTransaction(
          walletItem.id,
          fetchedTx,
          _transactionProcessor.getPreviousTransactions,
        );
        if (cpfpInfo != null) {
          cpfpInfoMap[fetchedTx.transactionHash] = cpfpInfo;
          Logger.log('CPFP 트랜잭션 감지됨: ${fetchedTx.transactionHash}');
        }

        _utxoManager.updateUtxoStatusToOutgoingByTransaction(
            walletItem.id, fetchedTx);
      }

      if (confirmedFetchedTxHashes.contains(fetchedTx.transactionHash)) {
        // 컨펌 트랜잭션의 경우 사용된 UTXO 삭제
        _utxoManager.deleteUtxosByTransaction(walletItem.id, fetchedTx);

        // 컨펌된 트랜잭션에 대해서만 RBF 내역 삭제
        _transactionRepository.deleteRbfHistory(walletItem.id, fetchedTx);

        // 컨펌된 트랜잭션과 연관된 CPFP 내역 삭제
        _transactionRepository.deleteCpfpHistory(walletItem.id, fetchedTx);
      }
    }

    final txRecords = await _transactionProcessor.createTransactionRecords(
      walletItem,
      fetchedTransactions,
      txBlockHeightMap,
      blockTimestampMap,
      getTransactionHex: (txHash) => _electrumService.getTransaction(txHash),
      now: now,
    );

    _transactionRepository.addAllTransactions(walletItem.id, txRecords);

    // RBF/CPFP 내역 저장
    if (sendingRbfInfoMap.isNotEmpty ||
        receivingRbfTxHashSet.isNotEmpty ||
        cpfpInfoMap.isNotEmpty) {
      // 트랜잭션 해시와 레코드를 매핑하는 맵 생성
      final txRecordMap = {
        for (var record in txRecords) record.transactionHash: record
      };

      if (sendingRbfInfoMap.isNotEmpty) {
        await _rbfHandler.saveRbfHistoryMap(
            walletItem, sendingRbfInfoMap, txRecordMap, walletItem.id);

        _transactionRepository.markAsRbfReplaced(
            walletItem.id, sendingRbfInfoMap);

        // 대체되어 사라지는 트랜잭션의 UTXO 삭제
        _utxoManager.deleteUtxosByReplacedTransactionHashSet(
            walletItem.id,
            sendingRbfInfoMap.values
                .map((rbfInfo) => rbfInfo.spentTransactionHash)
                .toSet());
      }

      if (receivingRbfTxHashSet.isNotEmpty) {
        _utxoManager.deleteUtxosByReplacedTransactionHashSet(
            walletItem.id, receivingRbfTxHashSet);
      }

      if (cpfpInfoMap.isNotEmpty) {
        await _cpfpHandler.saveCpfpHistoryMap(
            walletItem, cpfpInfoMap, txRecordMap, walletItem.id);
      }
    }

    // 대체되었으나 RBF이력 없이 DB에 존재하는 언컨펌 트랜잭션 내역 삭제
    final unconfirmedTxs = _transactionRepository
        .getUnconfirmedTransactionRecordList(walletItem.id);

    final toDeleteTxs = <String>[];
    for (final tx in unconfirmedTxs) {
      try {
        await _electrumService.getTransaction(tx.transactionHash,
            verbose: true);
      } catch (e) {
        // 대체되어 존재하지 않는 트랜잭션은 삭제
        toDeleteTxs.add(tx.transactionHash);
      }
    }

    if (toDeleteTxs.isNotEmpty) {
      _transactionRepository.deleteTransaction(walletItem.id, toDeleteTxs);
    }

    if (!inBatchProcess) {
      // Transaction 업데이트 완료 state 업데이트
      _stateManager.addWalletCompletedState(
          walletItem.id, UpdateElement.transaction);
    }
  }

  /// 스크립트에 대한 트랜잭션 응답을 가져옵니다.
  Future<List<FetchTransactionResponse>> getFetchTransactionResponses(
      AddressType addressType,
      ScriptStatus scriptStatus,
      Set<String> knownTransactionHashes) async {
    try {
      final historyList =
          await _electrumService.getHistory(addressType, scriptStatus.address);

      if (historyList.isEmpty) {
        return [];
      }

      final filteredHistoryList = historyList.where((history) {
        if (knownTransactionHashes.contains(history.txHash)) return false;
        knownTransactionHashes.add(history.txHash);
        return true;
      });

      return filteredHistoryList
          .map((history) => FetchTransactionResponse(
                transactionHash: history.txHash,
                height: history.height,
                addressIndex: scriptStatus.index,
                isChange: scriptStatus.isChange,
              ))
          .toList();
    } catch (e) {
      Logger.error('Failed to get fetch transaction responses: $e');
      return [];
    }
  }

  /// 트랜잭션 목록을 가져옵니다.
  Future<List<Transaction>> fetchTransactions(
      Set<String> transactionHashes) async {
    List<Transaction> results = [];

    final futures = transactionHashes.map((txHash) async {
      try {
        final txHex = await _electrumService.getTransaction(txHash);
        return Transaction.parse(txHex);
      } catch (e) {
        Logger.error('Failed to fetch transaction $txHash: $e');
        return null;
      }
    });

    final transactions = await Future.wait(futures);
    results.addAll(transactions.whereType<Transaction>());

    return results;
  }
}
