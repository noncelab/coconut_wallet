import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/node/transaction_processing_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_util.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/cpfp_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/rbf_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
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
      Set<String> coSpentAddresses,
    });

/// fetchScriptTransaction의 결과
/// [coSpentAddresses]는 이번 이벤트를 트리거한 주소가 아니면서,
/// 컨펌된 트랜잭션에 의해 UTXO가 함께 소비(삭제)된 다른 지갑 주소 목록이다.
/// 주소들은 자신의 구독 이벤트 없이 UTXO만 사라졌을 수 있으므로, 잔액 재조회가 필요한지는 호출자가 판단해야 한다.
typedef FetchScriptTransactionResult = ({List<String> txHashes, Set<String> coSpentAddresses});

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
  Future<FetchScriptTransactionResult> fetchScriptTransaction(
    WalletItemBase walletItem,
    ScriptStatus scriptStatus, {
    DateTime? now,
    bool inBatchProcess = false,
  }) async {
    final int walletId = walletItem.id;

    // 1. 초기화 및 준비 단계
    _prepareTransactionFetch(walletId, inBatchProcess);

    // walletId의 트랜잭션 조회
    final knownTransactionHashes = _transactionRepository.getConfirmedTransactionHashSet(walletId);
    final txFetchResults = await getFetchTransactionResponses(
      walletItem.walletBase.addressType,
      scriptStatus,
      knownTransactionHashes,
    );

    // 트랜잭션 조회 결과가 없으면 종료
    if (txFetchResults.isEmpty) {
      await _finalizeTransactionFetch(walletId, {}, inBatchProcess);
      if (!inBatchProcess) {
        _stateManager.addWalletCompletedState(walletId, UpdateElement.utxo);
      }
      return (txHashes: <String>[], coSpentAddresses: <String>{});
    }

    // 언컨펌 UTXO가 사용된 트랜잭션은 블록 높이가 -1로 조회되어 '0이하' 조건이 필요함
    final unconfirmedFetchedTxHashes =
        txFetchResults.where((tx) => tx.height <= 0).map((tx) => tx.transactionHash).toSet();
    final confirmedFetchedTxHashes =
        txFetchResults.where((tx) => tx.height > 0).map((tx) => tx.transactionHash).toSet();

    // 2. 처리 대상 트랜잭션 식별 및 등록
    final processingStates = _registerProcessableTransactions(walletId, txFetchResults, _scriptCallbackService);
    final newTxHashes = processingStates.keys.toSet();

    if (newTxHashes.isEmpty) {
      await _finalizeTransactionFetch(walletId, newTxHashes, inBatchProcess);
      return (txHashes: txFetchResults.map((tx) => tx.transactionHash).toList(), coSpentAddresses: <String>{});
    }

    try {
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
      final unconfirmedRecords = txRecords.where((record) => record.blockHeight <= 0).toList();
      if (unconfirmedRecords.isNotEmpty) {
        await _transactionRepository.addAllTransactions(walletId, unconfirmedRecords);
      }

      // 5. UTXO 상태 업데이트 및 RBF/CPFP 처리
      final RbfCpfpDetectionResult rbfCpfpResult = await _processFetchedTransactionsAndUpdateUtxos(
        walletId,
        fetchedTransactionDetails.fetchedTransactions,
        unconfirmedFetchedTxHashes,
        confirmedFetchedTxHashes,
        triggeringAddress: scriptStatus.address,
        inBatchProcess: inBatchProcess,
      );

      // 6. RBF/CPFP 히스토리 저장
      await _saveRbfAndCpfpHistory(walletItem, txRecords, rbfCpfpResult);

      // 7. 대체된 언컨펌 트랜잭션 삭제
      await _cleanupOrphanedUnconfirmedTransactions(
        walletId,
        fetchedTransactionDetails.fetchedTransactions,
        preparedRecords: {for (final record in txRecords) record.transactionHash: record},
        confirmedTxHashes: confirmedFetchedTxHashes,
      );

      final confirmedRecords = txRecords.where((record) => record.blockHeight > 0).toList();
      if (confirmedRecords.isNotEmpty) {
        await _transactionRepository.addAllTransactions(walletId, confirmedRecords);
      }

      // 8. 마무리 단계
      await _finalizeTransactionFetch(walletId, newTxHashes, inBatchProcess, processingStates: processingStates);

      return (
        txHashes: txFetchResults.map((tx) => tx.transactionHash).toList(),
        coSpentAddresses: rbfCpfpResult.coSpentAddresses,
      );
    } finally {
      _scriptCallbackService.releaseTransactionProcessing(walletId, processingStates);
    }
  }

  /// 1. 초기화 및 준비 단계: 상태 업데이트
  void _prepareTransactionFetch(int walletId, bool inBatchProcess) {
    if (!inBatchProcess) {
      _stateManager.addWalletSyncState(walletId, UpdateElement.transaction);
    }
  }

  /// 2. 처리 대상 트랜잭션 식별 및 등록
  Map<String, TransactionProcessingState> _registerProcessableTransactions(
    int walletId,
    List<FetchTransactionResponse> txFetchResults,
    ScriptCallbackService scriptCallbackManager,
  ) {
    final processingStates = <String, TransactionProcessingState>{};
    for (final txFetchResult in txFetchResults) {
      bool isConfirmed = txFetchResult.height > 0;
      if (scriptCallbackManager.isTransactionProcessable(
        txHashKey: getTxHashKey(walletId, txFetchResult.transactionHash),
        isConfirmed: isConfirmed,
      )) {
        processingStates[txFetchResult.transactionHash] = scriptCallbackManager.registerTransactionProcessing(
          walletId,
          txFetchResult.transactionHash,
          isConfirmed,
        );
      }
    }
    return processingStates;
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

    if (txBlockHeightMap.values.any((height) => !blockTimestampMap.containsKey(height))) {
      throw StateError('Missing block metadata for confirmed transaction history');
    }

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
    Set<String> confirmedFetchedTxHashes, {
    required String triggeringAddress,
    bool inBatchProcess = false,
  }) async {
    Map<String, RbfInfo> outgoingingRbfInfoMap = {}; // fetchedTxHash -> RbfInfo
    Set<String> replacedTxHashSetByIncomingRbf = {};
    Map<String, CpfpInfo> cpfpInfoMap = {};
    final Set<String> coSpentAddresses = {};

    final orderedTransactions = [
      ...fetchedTransactions.where((tx) => confirmedFetchedTxHashes.contains(tx.transactionHash)),
      ...fetchedTransactions.where((tx) => !confirmedFetchedTxHashes.contains(tx.transactionHash)),
    ];
    for (final fetchedTx in orderedTransactions) {
      Logger.log('Processing transaction: ${fetchedTx.transactionHash}');
      if (unconfirmedFetchedTxHashes.contains(fetchedTx.transactionHash)) {
        final outgoingRbfInfo = await _rbfService.detectOutgoingRbfTransaction(walletId, fetchedTx);
        if (outgoingRbfInfo != null) {
          outgoingingRbfInfoMap[fetchedTx.transactionHash] = outgoingRbfInfo;
        }

        final replacedTxHashByIncomingRbf = await _rbfService.detectIncomingRbfTransaction(
          walletId,
          fetchedTx,
          confirmedTxHashes: confirmedFetchedTxHashes,
        );
        if (replacedTxHashByIncomingRbf != null) {
          replacedTxHashSetByIncomingRbf.add(replacedTxHashByIncomingRbf);
        }

        final cpfpInfo = await _cpfpService.detectCpfpTransaction(
          walletId,
          fetchedTx,
          confirmedTxHashes: confirmedFetchedTxHashes,
        );
        if (cpfpInfo != null) cpfpInfoMap[fetchedTx.transactionHash] = cpfpInfo;

        await _utxoRepository.markUtxoAsOutgoing(walletId, fetchedTx);
      }

      if (confirmedFetchedTxHashes.contains(fetchedTx.transactionHash)) {
        // UTXO를 지우기 전에, 이 tx가 함께 소비한 다른 지갑 주소(co-spent address)가 있는지 파악해둔다.
        // 그 주소들은 자신의 구독 이벤트 없이 UTXO만 사라질 수 있으므로, 잔액 재조회가 필요할 수 있다.
        // 실제 재조회는 호출자(ScriptSyncService)에게 결과로 전달한다.
        if (!inBatchProcess) {
          coSpentAddresses.addAll(_findCoSpentAddresses(walletId, fetchedTx, triggeringAddress));
        }

        await _utxoRepository.deleteUtxosByTransaction(walletId, fetchedTx);
        await _transactionRepository.deleteRbfHistory(walletId, fetchedTx);
        await _transactionRepository.deleteCpfpHistory(walletId, fetchedTx);
      }
    }

    return (
      outgoingRbfInfoMap: outgoingingRbfInfoMap,
      replacedTxHashSetByIncomingRbf: replacedTxHashSetByIncomingRbf,
      cpfpInfoMap: cpfpInfoMap,
      coSpentAddresses: coSpentAddresses,
    );
  }

  /// 컨펌된 트랜잭션의 input UTXO들 중, 이번 이벤트를 트리거한 주소가 아닌 다른 지갑 주소를 찾는다.
  /// UTXO를 삭제하기 전에 호출해야 소유 주소를 알 수 있다.
  Set<String> _findCoSpentAddresses(int walletId, Transaction transaction, String triggeringAddress) {
    final addresses = <String>{};

    for (final input in transaction.inputs) {
      final utxo = _utxoRepository.getUtxoState(
        walletId,
        getUtxoId(input.transactionHash, input.index),
        includeDeleted: true,
      );
      if (utxo == null || utxo.to == triggeringAddress) {
        continue;
      }
      addresses.add(utxo.to);
    }

    return addresses;
  }

  /// 6. RBF/CPFP 히스토리 저장
  Future<void> _saveRbfAndCpfpHistory(
    WalletItemBase walletItem,
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
        rbfCpfpResult.outgoingRbfInfoMap.values.map((rbf) => rbf.previousTransactionHash).toSet(),
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
  Future<void> _cleanupOrphanedUnconfirmedTransactions(
    int walletId,
    List<Transaction> newTxs, {
    required Map<String, TransactionRecord> preparedRecords,
    required Set<String> confirmedTxHashes,
  }) async {
    final unconfirmedTxs = _transactionRepository.getUnconfirmedTransactionRecordList(walletId);
    final toDeleteTxs = <String>[];

    for (final localUnconfirmedTxRecord in unconfirmedTxs) {
      if (confirmedTxHashes.contains(localUnconfirmedTxRecord.transactionHash)) continue;
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
            final newTxRecord =
                preparedRecords[newTx.transactionHash] ??
                _transactionRepository.getTransactionRecord(walletId, newTx.transactionHash);

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
  Future<void> _finalizeTransactionFetch(
    int walletId,
    Set<String> newTxHashes,
    bool inBatchProcess, {
    Map<String, TransactionProcessingState>? processingStates,
  }) async {
    if (!inBatchProcess) {
      _stateManager.addWalletCompletedState(walletId, UpdateElement.transaction);
    }
    if (newTxHashes.isNotEmpty) {
      await _scriptCallbackService.registerTransactionCompletion(
        walletId,
        newTxHashes,
        processingStates: processingStates,
      );
    }
  }

  /// 일렉트럼으로 부터 스크립트에 대한 트랜잭션 응답을 가져옵니다.
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
      rethrow;
    }
  }

  /// 휴면 재확인용. 쉬고 있는 주소와 구멍의 거래 이력을 50개씩 병렬로 조회해, 다시 동기화할 주소를 고른다.
  /// 받고 다 쓴 주소는 잔액이 0이라 잔액 대신 이력으로 본다. 아래 중 하나면 고른다.
  /// - 사용 표시가 없는데 이력이 있는 주소(구멍)
  /// - 기록에 없거나 미확정으로 기록된 거래, 또는 서버에서 미확정인 거래가 이력에 있는 주소
  /// - 기록된 거래로 계산한 주소 잔액이 저장된 잔액과 다른 주소(다른 내 주소의 거래로 먼저 기록된 입금 등)
  /// - 입력 없이 기록된 거래가 있어 기록으로 잔액을 셀 수 없으면, 서버 잔액을 한 번 더 물어 저장된 잔액과 다른 주소
  /// [toResync]의 값은 그 주소 이력의 지문이다. 조회에 실패한 주소는 [failed]에 담고, 이력이 없는 것으로 보지 않는다.
  Future<({Map<String, String> toResync, Set<String> failed})> findDormantAddressesToResync(
    WalletItemBase walletItem,
    List<WalletAddress> addresses,
  ) async {
    final addressType = walletItem.walletBase.addressType;
    final histories = <String, List<GetTxHistoryRes>>{};
    final failed = <String>{};
    await _inBatches(addresses, (address) async {
      try {
        histories[address.address] = await _electrumService.getHistory(addressType, address.address);
      } catch (e) {
        failed.add(address.address);
        Logger.error('TransactionSyncService: Error fetching history for ${address.address}: $e');
      }
    });

    final records = _transactionRepository.getTransactionRecordMapByHashes(walletItem.id, {
      for (final history in histories.values)
        for (final item in history) item.txHash,
    });

    final toResync = <String, String>{};
    final balanceUnknown = <WalletAddress>[];
    for (final address in addresses) {
      final history = histories[address.address];
      if (history == null || history.isEmpty) continue;
      final inSync = address.isUsed ? _isInSync(address, history, records) : false;
      if (inSync == false) {
        toResync[address.address] = _historyFingerprint(history);
      } else if (inSync == null) {
        balanceUnknown.add(address);
      }
    }

    await _inBatches(balanceUnknown, (address) async {
      try {
        final balance = await _electrumService.getBalance(addressType, address.address);
        if (balance.confirmed != address.confirmed || balance.unconfirmed != address.unconfirmed) {
          toResync[address.address] = _historyFingerprint(histories[address.address]!);
        }
      } catch (e) {
        failed.add(address.address);
        Logger.error('TransactionSyncService: Error fetching balance for ${address.address}: $e');
      }
    });
    return (toResync: toResync, failed: failed);
  }

  /// 이력의 거래가 모두 확정으로 기록돼 있고 기록으로 계산한 이 주소의 잔액이 저장된 잔액과 같으면 true, 다르면 false다.
  /// 이전 거래를 받지 못해 입력 없이 기록된 거래가 있으면 이 주소에서 나간 돈을 셀 수 없어 null이다(서버 잔액으로 확인).
  /// 그런 기록은 다시 동기화해도 다시 만들지 않으므로, 기록만 보고 고르면 실행할 때마다 같은 주소를 다시 동기화하게 된다.
  bool? _isInSync(WalletAddress address, List<GetTxHistoryRes> history, Map<String, TransactionRecord> records) {
    var balance = 0;
    var inputsKnown = true;
    for (final item in history) {
      final record = records[item.txHash];
      if (item.height <= 0 || record == null || record.blockHeight <= 0) return false;
      if (record.inputAddressList.isEmpty) inputsKnown = false;
      for (final output in record.outputAddressList) {
        if (output.address == address.address) balance += output.amount;
      }
      for (final input in record.inputAddressList) {
        if (input.address == address.address) balance -= input.amount;
      }
    }
    if (!inputsKnown) return null;
    return balance == address.total;
  }

  String _historyFingerprint(List<GetTxHistoryRes> history) =>
      (history.map((item) => '${item.txHash}:${item.height}').toList()..sort()).join(',');

  /// [items]를 50개씩 나눠, 묶음 안에서는 병렬로 처리한다.
  Future<void> _inBatches<T>(List<T> items, Future<void> Function(T item) task) async {
    const batchSize = 50;
    for (var start = 0; start < items.length; start += batchSize) {
      final end = start + batchSize < items.length ? start + batchSize : items.length;
      await Future.wait(items.sublist(start, end).map(task));
    }
  }

  /// 일렉트럼으로 부터 트랜잭션 목록을 가져옵니다.
  Future<List<Transaction>> fetchTransactions(Set<String> transactionHashes) {
    return Future.wait(
      transactionHashes.map((txHash) async {
        final txHex = await _electrumService.getTransaction(txHash);
        return Transaction.parse(txHex);
      }),
    );
  }
}
