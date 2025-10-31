import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_util.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/cpfp_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/rbf_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/providers/node_provider/state/state_manager_interface.dart';

typedef FetchedTransactionDetails =
    ({
      List<Transaction> fetchedTransactions,
      Map<String, int> txBlockHeightMap,
      Map<int, BlockTimestamp> blockTimestampMap,
    });

typedef RbfCpfpDetectionResult =
    ({
      Map<String, RbfInfo> outgoingRbfInfoMap,
      Set<String> replacedTxHashSetByIncomingRbf,
      Map<String, CpfpInfo> cpfpInfoMap,
    });

/// 트랜잭션 조회를 담당하는 클래스
class TransactionSyncService {
  final ElectrumService _electrumService;
  final TransactionRepository _transactionRepository;
  final TransactionRecordService _transactionRecordService;
  final StateManagerInterface _stateManager;
  final UtxoRepository _utxoRepository;
  final RbfService _rbfService;
  final CpfpService _cpfpService;
  final ScriptCallbackService _scriptCallbackService;

  TransactionSyncService(
    this._electrumService,
    this._transactionRepository,
    this._transactionRecordService,
    this._stateManager,
    this._utxoRepository,
    this._scriptCallbackService,
  ) : _rbfService = RbfService(_transactionRepository, _utxoRepository, _electrumService),
      _cpfpService = CpfpService(_transactionRepository, _utxoRepository, _electrumService);

  /// 특정 스크립트의 트랜잭션을 조회하고 DB에 업데이트합니다.
  Future<List<String>> fetchScriptTransaction(
    WalletListItemBase walletItem,
    ScriptStatus scriptStatus, {
    DateTime? now,
    bool inBatchProcess = false,
  }) async {
    final int walletId = walletItem.id;

    // 1. 초기화 및 준비 단계
    _prepareTransactionFetch(walletId, inBatchProcess);

    final knownTransactionHashes = _transactionRepository.getConfirmedTransactionHashSet(walletId);
    final txFetchResults = await getFetchTransactionResponses(
      walletItem.walletBase.addressType,
      scriptStatus,
      knownTransactionHashes,
    );

    if (txFetchResults.isEmpty) {
      await _finalizeTransactionFetch(walletId, {}, inBatchProcess);
      if (!inBatchProcess) {
        _stateManager.addWalletCompletedState(walletId, UpdateElement.utxo);
      }
      return [];
    }

    // 언컨펌 UTXO가 사용된 트랜잭션은 블록 높이가 -1로 조회되어 '0이하' 조건이 필요함
    final unconfirmedFetchedTxHashes =
        txFetchResults.where((tx) => tx.height <= 0).map((tx) => tx.transactionHash).toSet();
    final confirmedFetchedTxHashes =
        txFetchResults.where((tx) => tx.height > 0).map((tx) => tx.transactionHash).toSet();

    // 2. 처리 대상 트랜잭션 식별 및 등록
    final Set<String> newTxHashes = _registerProcessableTransactions(walletId, txFetchResults, _scriptCallbackService);

    if (newTxHashes.isEmpty) {
      await _finalizeTransactionFetch(walletId, newTxHashes, inBatchProcess);
      return txFetchResults.map((tx) => tx.transactionHash).toList();
    }

    // 3. 트랜잭션 상세 정보 조회
    final FetchedTransactionDetails fetchedTransactionDetails = await _fetchTransactionDetails(
      newTxHashes,
      txFetchResults,
      _electrumService,
    );

    // 4. 트랜잭션 레코드 생성 및 저장
    final List<TransactionRecord> txRecords = await _transactionRecordService.createTransactionRecords(
      walletId,
      fetchedTransactionDetails,
      now: now,
    );
    await _transactionRepository.addAllTransactions(walletItem.id, txRecords);

    // 5. UTXO 상태 업데이트 및 RBF/CPFP 처리
    final RbfCpfpDetectionResult rbfCpfpResult = await _processFetchedTransactionsAndUpdateUtxos(
      walletId,
      fetchedTransactionDetails.fetchedTransactions,
      unconfirmedFetchedTxHashes,
      confirmedFetchedTxHashes,
    );

    // 6. RBF/CPFP 히스토리 저장
    await _saveRbfAndCpfpHistory(walletItem, txRecords, rbfCpfpResult);

    // 7. 대체된 언컨펌 트랜잭션 삭제
    await _cleanupOrphanedUnconfirmedTransactions(walletId, fetchedTransactionDetails.fetchedTransactions);

    // 8. 마무리 단계
    await _finalizeTransactionFetch(walletId, newTxHashes, inBatchProcess);

    return txFetchResults.map((tx) => tx.transactionHash).toList();
  }

  /// 1. 초기화 및 준비 단계: 상태 업데이트
  void _prepareTransactionFetch(int walletId, bool inBatchProcess) {
    if (!inBatchProcess) {
      _stateManager.addWalletSyncState(walletId, UpdateElement.transaction);
    }
  }

  /// 2. 처리 대상 트랜잭션 식별 및 등록
  Set<String> _registerProcessableTransactions(
    int walletId,
    List<FetchTransactionResponse> txFetchResults,
    ScriptCallbackService scriptCallbackManager,
  ) {
    final Set<String> newTxHashes = {};
    for (final txFetchResult in txFetchResults) {
      bool isConfirmed = txFetchResult.height > 0;
      if (scriptCallbackManager.isTransactionProcessable(
        txHashKey: getTxHashKey(walletId, txFetchResult.transactionHash),
        isConfirmed: isConfirmed,
      )) {
        scriptCallbackManager.registerTransactionProcessing(walletId, txFetchResult.transactionHash, isConfirmed);
        newTxHashes.add(txFetchResult.transactionHash);
      }
    }
    return newTxHashes;
  }

  /// 3. 트랜잭션 상세 정보 조회
  Future<FetchedTransactionDetails> _fetchTransactionDetails(
    Set<String> newTxHashes,
    List<FetchTransactionResponse> allTxFetchResults,
    ElectrumService electrumService,
  ) async {
    final filteredTxFetchResults = allTxFetchResults.where((tx) => newTxHashes.contains(tx.transactionHash)).toList();

    final txBlockHeightMap = Map<String, int>.fromEntries(
      filteredTxFetchResults.where((tx) => tx.height > 0).map((tx) => MapEntry(tx.transactionHash, tx.height)),
    );

    final blockTimestampMap =
        txBlockHeightMap.isEmpty
            ? <int, BlockTimestamp>{}
            : await electrumService.fetchBlocksByHeight(txBlockHeightMap.values.toSet());

    final fetchedTransactions = await fetchTransactions(newTxHashes);

    return (
      fetchedTransactions: fetchedTransactions,
      txBlockHeightMap: txBlockHeightMap,
      blockTimestampMap: blockTimestampMap,
    );
  }

  /// 4. UTXO 상태 업데이트 및 RBF/CPFP 처리
  Future<RbfCpfpDetectionResult> _processFetchedTransactionsAndUpdateUtxos(
    int walletId,
    List<Transaction> fetchedTransactions,
    Set<String> unconfirmedFetchedTxHashes,
    Set<String> confirmedFetchedTxHashes,
  ) async {
    Map<String, RbfInfo> outgoingingRbfInfoMap = {}; // fetchedTxHash -> RbfInfo
    Set<String> replacedTxHashSetByIncomingRbf = {};
    Map<String, CpfpInfo> cpfpInfoMap = {};

    for (final fetchedTx in fetchedTransactions) {
      Logger.log('Processing transaction: ${fetchedTx.transactionHash}');
      if (unconfirmedFetchedTxHashes.contains(fetchedTx.transactionHash)) {
        final outgoingRbfInfo = await _rbfService.detectOutgoingRbfTransaction(walletId, fetchedTx);
        if (outgoingRbfInfo != null) {
          outgoingingRbfInfoMap[fetchedTx.transactionHash] = outgoingRbfInfo;
        }

        final replacedTxHashByIncomingRbf = await _rbfService.detectIncomingRbfTransaction(walletId, fetchedTx);
        if (replacedTxHashByIncomingRbf != null) {
          replacedTxHashSetByIncomingRbf.add(replacedTxHashByIncomingRbf);
        }

        final cpfpInfo = await _cpfpService.detectCpfpTransaction(walletId, fetchedTx);
        if (cpfpInfo != null) cpfpInfoMap[fetchedTx.transactionHash] = cpfpInfo;

        await _utxoRepository.markUtxoAsOutgoing(walletId, fetchedTx);
      }

      if (confirmedFetchedTxHashes.contains(fetchedTx.transactionHash)) {
        await _utxoRepository.deleteUtxosByTransaction(walletId, fetchedTx);
        await _transactionRepository.deleteRbfHistory(walletId, fetchedTx);
        await _transactionRepository.deleteCpfpHistory(walletId, fetchedTx);
      }
    }

    return (
      outgoingRbfInfoMap: outgoingingRbfInfoMap,
      replacedTxHashSetByIncomingRbf: replacedTxHashSetByIncomingRbf,
      cpfpInfoMap: cpfpInfoMap,
    );
  }

  /// 6. RBF/CPFP 히스토리 저장
  Future<void> _saveRbfAndCpfpHistory(
    WalletListItemBase walletItem,
    List<TransactionRecord> txRecords,
    RbfCpfpDetectionResult rbfCpfpResult,
  ) async {
    if (rbfCpfpResult.outgoingRbfInfoMap.isEmpty &&
        rbfCpfpResult.replacedTxHashSetByIncomingRbf.isEmpty &&
        rbfCpfpResult.cpfpInfoMap.isEmpty) {
      return;
    }

    final txRecordMap = {for (var record in txRecords) record.transactionHash: record};
    final int walletId = walletItem.id;

    if (rbfCpfpResult.outgoingRbfInfoMap.isNotEmpty) {
      await _rbfService.saveRbfHistoryMap(
        walletId: walletId,
        rbfInfoMap: rbfCpfpResult.outgoingRbfInfoMap,
        txRecordMap: txRecordMap,
      );
      await _transactionRepository.markAsRbfReplaced(walletId, rbfCpfpResult.outgoingRbfInfoMap);
      await _utxoRepository.deleteUtxosByReplacedTransactionHashSet(
        walletId,
        rbfCpfpResult.outgoingRbfInfoMap.keys.toSet(),
      );
    }

    if (rbfCpfpResult.replacedTxHashSetByIncomingRbf.isNotEmpty) {
      await _transactionRepository.deleteOrphanedCpfpTransaction(
        walletId,
        rbfCpfpResult.replacedTxHashSetByIncomingRbf,
      );
      await _utxoRepository.deleteUtxosByReplacedTransactionHashSet(
        walletId,
        rbfCpfpResult.replacedTxHashSetByIncomingRbf,
      );
    }

    if (rbfCpfpResult.cpfpInfoMap.isNotEmpty) {
      await _cpfpService.saveCpfpHistoryMap(walletItem, rbfCpfpResult.cpfpInfoMap, txRecordMap, walletId);
    }
  }

  /// 7. 대체된 언컨펌 트랜잭션 삭제
  Future<void> _cleanupOrphanedUnconfirmedTransactions(int walletId, List<Transaction> newTxs) async {
    final unconfirmedTxs = _transactionRepository.getUnconfirmedTransactionRecordList(walletId);
    final toDeleteTxs = <String>[];

    for (final localUnconfirmedTxRecord in unconfirmedTxs) {
      Transaction? unconfirmedTx;
      try {
        unconfirmedTx = Transaction.parse(
          await _electrumService.getTransaction(localUnconfirmedTxRecord.transactionHash),
        );
      } catch (e) {
        // 언컨펌 트랜잭션을 다시 조회해서 실패한 경우 대체된 것으로 간주
        Logger.log('Transaction ${localUnconfirmedTxRecord.transactionHash} not found, marking for deletion.');
        toDeleteTxs.add(localUnconfirmedTxRecord.transactionHash);
        continue;
      }

      // 새로운 트랜잭션들을 순회하면서 인풋이 겹치는 것이 있는지 확인
      final unconfirmedInputs = unconfirmedTx.inputs.map((input) => '${input.transactionHash}:${input.index}').toSet();
      for (final newTx in newTxs) {
        final newTxInputs = newTx.inputs.map((input) => '${input.transactionHash}:${input.index}').toSet();
        final overlappingInputs = unconfirmedInputs.intersection(newTxInputs);

        // 겹치는 인풋이 있으면서 새 트랜잭션의 수수료율이 더 높다면 로컬의 언컨펌 트랜잭션은 대체된 것으로 간주
        if (overlappingInputs.isNotEmpty) {
          if (unconfirmedTx.transactionHash != newTx.transactionHash) {
            final newTxRecord = _transactionRepository.getTransactionRecord(walletId, newTx.transactionHash);

            if (newTxRecord != null && localUnconfirmedTxRecord.feeRate < newTxRecord.feeRate) {
              toDeleteTxs.add(localUnconfirmedTxRecord.transactionHash);
              Logger.log(
                '[$walletId] Transaction ${localUnconfirmedTxRecord.transactionHash} is replaced by ${newTx.transactionHash}',
              );
            }
            continue;
          }
          // 대체된 것으로 확인되면 다른 새 트랜잭션과 비교 불필요
          break;
        }
      }
    }

    if (toDeleteTxs.isNotEmpty) {
      final deleted = _transactionRepository.deleteTransaction(walletId, toDeleteTxs);
      if (deleted.isSuccess) {
        Logger.log('[$walletId] Deleted orphaned unconfirmed transactions: $toDeleteTxs');
      }
    }
  }

  /// 8. 마무리 단계: 상태 업데이트 및 완료 등록
  Future<void> _finalizeTransactionFetch(int walletId, Set<String> newTxHashes, bool inBatchProcess) async {
    if (!inBatchProcess) {
      _stateManager.addWalletCompletedState(walletId, UpdateElement.transaction);
    }
    if (newTxHashes.isNotEmpty) {
      await _scriptCallbackService.registerTransactionCompletion(walletId, newTxHashes);
    }
  }

  /// 스크립트에 대한 트랜잭션 응답을 가져옵니다.
  Future<List<FetchTransactionResponse>> getFetchTransactionResponses(
    AddressType addressType,
    ScriptStatus scriptStatus,
    Set<String> knownTransactionHashes,
  ) async {
    try {
      final historyList = await _electrumService.getHistory(addressType, scriptStatus.address);

      if (historyList.isEmpty) {
        return [];
      }

      final filteredHistoryList = historyList.where((history) {
        if (knownTransactionHashes.contains(history.txHash)) return false;
        knownTransactionHashes.add(history.txHash);
        return true;
      });

      return filteredHistoryList
          .map(
            (history) => FetchTransactionResponse(
              transactionHash: history.txHash,
              height: history.height,
              addressIndex: scriptStatus.index,
              isChange: scriptStatus.isChange,
            ),
          )
          .toList();
    } catch (e) {
      Logger.error('Failed to get fetch transaction responses: $e');
      return [];
    }
  }

  /// 트랜잭션 목록을 가져옵니다.
  Future<List<Transaction>> fetchTransactions(Set<String> transactionHashes) async {
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
