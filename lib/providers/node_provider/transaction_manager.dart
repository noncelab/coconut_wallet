import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_manager.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/response/block_header.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:coconut_wallet/utils/transaction_util.dart';
import 'package:coconut_wallet/utils/utxo_util.dart';

/// NodeProvider의 트랜잭션 관련 기능을 담당하는 매니저 클래스
class TransactionManager {
  final ElectrumService _electrumService;
  final NodeStateManager _stateManager;
  final TransactionRepository _transactionRepository;
  final UtxoManager _utxoManager;
  final UtxoRepository _utxoRepository;

  TransactionManager(
    this._electrumService,
    this._stateManager,
    this._transactionRepository,
    this._utxoManager,
    this._utxoRepository,
  );

  /// 특정 스크립트의 트랜잭션을 조회하고 업데이트합니다.
  Future<void> fetchScriptTransaction(
    WalletListItemBase walletItem,
    ScriptStatus scriptStatus,
    WalletProvider walletProvider, {
    DateTime? now,
    bool inBatchProcess = false,
  }) async {
    if (!inBatchProcess) {
      // Transaction 동기화 시작 state 업데이트
      _stateManager.addWalletSyncState(
          walletItem.id, UpdateElement.transaction);
    }

    // db에 저장된 트랜잭션 조회, 네트워크 요청을 줄이기 위함.
    final knownTransactionHashes = _transactionRepository
        .getTransactions(walletItem.id)
        .where((tx) => tx.blockHeight != null && tx.blockHeight! > 0)
        .map((tx) => tx.transactionHash)
        .toSet();

    // 스크립트에 대한 트랜잭션 내역 조회, 이미 존재하는 트랜잭션은 제외함
    final txFetchResults = await getFetchTransactionResponses(
        walletItem.walletBase.addressType,
        scriptStatus,
        knownTransactionHashes);

    final unconfirmedFetchedTxHashes = txFetchResults
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
        : await getBlocksByHeight(txBlockHeightMap.values.toSet());

    // 트랜잭션 상세 정보 조회
    final fetchedTransactions = await fetchTransactions(
        txFetchResults.map((tx) => tx.transactionHash).toSet());

    // RBF 및 CPFP 감지 결과를 저장할 맵
    Map<String, RbfInfo> rbfInfoMap = {};
    Map<String, CpfpInfo> cpfpInfoMap = {};

    // 각 트랜잭션에 대해 사용된 UTXO 상태 업데이트
    for (final fetchedTx in fetchedTransactions) {
      // 언컨펌 트랜잭션의 경우 새로 브로드캐스트된 트랜잭션이므로 사용된 UTXO 상태 업데이트
      if (unconfirmedFetchedTxHashes.contains(fetchedTx.transactionHash)) {
        _utxoManager.updateUtxoStatusToOutgoingByTransaction(
            walletItem.id, fetchedTx);

        // RBF 감지 로직
        final rbfInfo = await detectRbfTransaction(walletItem.id, fetchedTx);
        if (rbfInfo != null) {
          rbfInfoMap[fetchedTx.transactionHash] = rbfInfo;
          Logger.log('RBF 트랜잭션 감지됨: ${fetchedTx.transactionHash}');
          Logger.log('  - 원본 트랜잭션: ${rbfInfo.originalTransactionHash}');
          Logger.log('  - 대체 대상 트랜잭션: ${rbfInfo.spentTransactionHash}');
        }

        // CPFP 감지 로직
        final cpfpInfo = await detectCpfpTransaction(walletItem.id, fetchedTx);
        if (cpfpInfo != null) {
          cpfpInfoMap[fetchedTx.transactionHash] = cpfpInfo;
          Logger.log('CPFP 트랜잭션 감지됨: ${fetchedTx.transactionHash}');
          Logger.log('  - 부모 트랜잭션: ${cpfpInfo.parentTransactionHash}');
        }
      }

      if (confirmedFetchedTxHashes.contains(fetchedTx.transactionHash)) {
        Logger.log('확인된 트랜잭션 처리: ${fetchedTx.transactionHash}');

        // 컨펌 트랜잭션의 경우 사용된 UTXO 삭제
        _utxoManager.deleteUtxosByTransaction(walletItem.id, fetchedTx);

        // 컨펌된 트랜잭션에 대해서만 RBF 내역 삭제
        _transactionRepository.deleteRbfHistory(walletItem.id, fetchedTx);

        // 컨펌된 트랜잭션과 연관된 CPFP 내역 삭제
        _transactionRepository.deleteCpfpHistory(walletItem.id, fetchedTx);
      }
    }

    final txRecords = await _createTransactionRecords(
        walletItem,
        fetchedTransactions,
        txBlockHeightMap,
        blockTimestampMap,
        walletProvider,
        now: now);

    _transactionRepository.addAllTransactions(walletItem.id, txRecords);

    // RBF/CPFP 내역 저장
    if (rbfInfoMap.isNotEmpty || cpfpInfoMap.isNotEmpty) {
      // 트랜잭션 해시와 레코드를 매핑하는 맵 생성
      final txRecordMap = {
        for (var record in txRecords) record.transactionHash: record
      };

      // RBF 내역 일괄 저장
      if (rbfInfoMap.isNotEmpty) {
        final rbfHistoryDtos = <RbfHistoryDto>[];

        for (final entry in rbfInfoMap.entries) {
          final txHash = entry.key;
          final rbfInfo = entry.value;
          final txRecord = txRecordMap[txHash];

          if (txRecord != null) {
            // 원본 트랜잭션 조회
            final originalTx = _transactionRepository.getTransactionRecord(
                walletItem.id, rbfInfo.originalTransactionHash);

            if (originalTx != null) {
              Logger.log(
                  'RBF 내역 등록: $txHash ← ${rbfInfo.spentTransactionHash} (원본: ${rbfInfo.originalTransactionHash})');
              Logger.log('  - 수수료율: ${txRecord.feeRate}');

              rbfHistoryDtos.add(RbfHistoryDto(
                walletId: walletItem.id,
                originalTransactionHash: rbfInfo.originalTransactionHash,
                transactionHash: txRecord.transactionHash,
                feeRate: txRecord.feeRate,
                timestamp: DateTime.now(),
              ));
            } else {
              Logger.error(
                  '원본 트랜잭션을 찾을 수 없음: ${rbfInfo.originalTransactionHash}');
            }
          }
        }

        // 일괄 저장
        if (rbfHistoryDtos.isNotEmpty) {
          await _transactionRepository.addAllRbfHistory(rbfHistoryDtos);
          Logger.log('RBF 내역 ${rbfHistoryDtos.length}개 저장 완료');
        }
      }

      // CPFP 내역 일괄 저장
      if (cpfpInfoMap.isNotEmpty) {
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
          await _transactionRepository.addAllCpfpHistory(cpfpHistoryDtos);
          Logger.log('Saved ${cpfpHistoryDtos.length} CPFP histories in batch');
        }
      }
    }

    if (!inBatchProcess) {
      // Transaction 업데이트 완료 state 업데이트
      _stateManager.addWalletCompletedState(
          walletItem.id, UpdateElement.transaction);
    }

    if (fetchedTransactions.isNotEmpty) {
      final tx = _transactionRepository.getTransactionRecord(
          walletItem.id, fetchedTransactions.first.transactionHash);

      if (tx == null || tx.rbfHistoryList == null) {
        return;
      }

      if (tx.rbfHistoryList!.isNotEmpty) {
        Logger.log(
            '-----------------------------------------------------------');
        Logger.log('RBF History List');
        for (final rbfHistory in tx.rbfHistoryList!) {
          Logger.log('${rbfHistory.transactionHash} : ${rbfHistory.feeRate}');
        }
        Logger.log(
            '-----------------------------------------------------------');
      }
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

  /// 블록 높이를 통해 블록 타임스탬프를 조회합니다.
  Future<Map<int, BlockTimestamp>> getBlocksByHeight(Set<int> heights) async {
    final futures = heights.map((height) async {
      try {
        final blockTimestamp = await _electrumService.getBlockTimestamp(height);
        return MapEntry(height, blockTimestamp);
      } catch (e) {
        Logger.error('Error fetching block header for height $height: $e');
        return null;
      }
    });

    final results = await Future.wait(futures);
    return Map.fromEntries(results.whereType<MapEntry<int, BlockTimestamp>>());
  }

  /// 트랜잭션 목록을 가져옵니다. (Future 방식으로 구현)
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

  /// 이전 트랜잭션을 조회합니다.
  Future<List<Transaction>> getPreviousTransactions(
      Transaction transaction, List<Transaction> existingTxList) async {
    if (transaction.inputs.isEmpty) {
      return [];
    }

    if (TransactionUtil.isCoinbaseTransaction(transaction)) {
      return [];
    }

    Set<String> toFetchTransactionHashes = {};

    final existingTxHashes =
        existingTxList.map((tx) => tx.transactionHash).toSet();

    toFetchTransactionHashes = transaction.inputs
        .map((input) => input.transactionHash)
        .where((hash) => !existingTxHashes.contains(hash))
        .toSet();

    var futures = toFetchTransactionHashes.map((transactionHash) async {
      try {
        var inputTx = await _electrumService.getTransaction(transactionHash);
        return Transaction.parse(inputTx);
      } catch (e) {
        Logger.error('Failed to get previous transaction $transactionHash: $e');
        return null;
      }
    });

    try {
      List<Transaction?> fetchedTransactionsNullable =
          await Future.wait(futures);
      List<Transaction> fetchedTransactions =
          fetchedTransactionsNullable.whereType<Transaction>().toList();

      fetchedTransactions.addAll(existingTxList);

      List<Transaction> previousTransactions = [];

      for (var input in transaction.inputs) {
        final matchingTx = fetchedTransactions
            .where((tx) => tx.transactionHash == input.transactionHash)
            .toList();

        if (matchingTx.isNotEmpty) {
          previousTransactions.add(matchingTx.first);
        }
      }

      return previousTransactions;
    } catch (e) {
      Logger.error('Failed to process previous transactions: $e');
      return [];
    }
  }

  /// 트랜잭션 레코드를 생성합니다.
  Future<List<TransactionRecord>> _createTransactionRecords(
    WalletListItemBase walletItemBase,
    List<Transaction> txs,
    Map<String, int> txBlockHeightMap,
    Map<int, BlockTimestamp> blockTimestampMap,
    WalletProvider walletProvider, {
    ElectrumService? nodeClient,
    List<Transaction> previousTxs = const [],
    DateTime? now,
  }) async {
    return Future.wait(txs.map((tx) async {
      return _createTransactionRecord(
        walletItemBase,
        tx,
        txBlockHeightMap,
        blockTimestampMap,
        walletProvider,
        nodeClient: nodeClient,
        previousTxs: previousTxs,
        now: now,
      );
    }));
  }

  /// 단일 트랜잭션 레코드를 생성합니다.
  Future<TransactionRecord> _createTransactionRecord(
    WalletListItemBase walletItemBase,
    Transaction tx,
    Map<String, int> txBlockHeightMap,
    Map<int, BlockTimestamp> blockTimestampMap,
    WalletProvider walletProvider, {
    ElectrumService? nodeClient,
    List<Transaction> previousTxs = const [],
    DateTime? now,
  }) async {
    now ??= DateTime.now();
    nodeClient ??= _electrumService;

    final prevTxs = await getPreviousTransactions(tx, previousTxs);

    int blockHeight = txBlockHeightMap[tx.transactionHash] ?? 0;
    final txDetails =
        _processTransactionDetails(tx, prevTxs, walletItemBase, walletProvider);

    return TransactionRecord.fromTransactions(
      transactionHash: tx.transactionHash,
      timestamp: blockTimestampMap[blockHeight]?.timestamp ?? now,
      blockHeight: blockHeight,
      inputAddressList: txDetails.inputAddressList,
      outputAddressList: txDetails.outputAddressList,
      transactionType: txDetails.txType.name,
      amount: txDetails.amount,
      fee: txDetails.fee,
      vSize: tx.getVirtualByte().ceil(),
    );
  }

  /// 트랜잭션의 입출력 상세 정보를 처리합니다.
  _TransactionDetails _processTransactionDetails(
    Transaction tx,
    List<Transaction> previousTxs,
    WalletListItemBase walletItemBase,
    WalletProvider walletProvider,
  ) {
    List<TransactionAddress> inputAddressList = [];
    int selfInputCount = 0;
    int selfOutputCount = 0;
    int fee = 0;
    int amount = 0;

    // 입력 처리
    for (int i = 0; i < tx.inputs.length; i++) {
      final input = tx.inputs[i];

      // 이전 트랜잭션에서 해당 입력에 대응하는 출력 찾기
      Transaction? previousTx;
      try {
        previousTx = previousTxs.firstWhere(
            (prevTx) => prevTx.transactionHash == input.transactionHash);
      } catch (_) {
        // 해당 트랜잭션을 찾지 못한 경우 스킵
        continue;
      }

      // 유효한 인덱스인지 확인
      if (input.index >= previousTx.outputs.length) {
        continue; // 유효하지 않은 인덱스인 경우 스킵
      }

      final previousOutput = previousTx.outputs[input.index];
      final inputAddress = TransactionAddress(
          previousOutput.scriptPubKey.getAddress(), previousOutput.amount);
      inputAddressList.add(inputAddress);

      fee += inputAddress.amount;

      if (walletProvider.containsAddress(
          walletItemBase.id, inputAddress.address)) {
        selfInputCount++;
        amount -= inputAddress.amount;
      }
    }

    // 출력 처리
    List<TransactionAddress> outputAddressList = [];
    for (int i = 0; i < tx.outputs.length; i++) {
      final output = tx.outputs[i];
      final outputAddress =
          TransactionAddress(output.scriptPubKey.getAddress(), output.amount);
      outputAddressList.add(outputAddress);

      fee -= outputAddress.amount;

      if (walletProvider.containsAddress(
          walletItemBase.id, outputAddress.address)) {
        selfOutputCount++;
        amount += outputAddress.amount;
      }
    }

    // 트랜잭션 유형 결정
    TransactionType txType;
    if (selfInputCount > 0 &&
        selfOutputCount == tx.outputs.length &&
        selfInputCount == tx.inputs.length) {
      txType = TransactionType.self;
    } else if (selfInputCount > 0 && selfOutputCount < tx.outputs.length) {
      txType = TransactionType.sent;
    } else {
      txType = TransactionType.received;
    }

    return _TransactionDetails(
      inputAddressList: inputAddressList,
      outputAddressList: outputAddressList,
      txType: txType,
      amount: amount,
      fee: fee,
    );
  }

  /// 트랜잭션을 브로드캐스트합니다.
  Future<Result<String>> broadcast(Transaction signedTx) async {
    try {
      final txHash = await _electrumService.broadcast(signedTx.serialize());

      // 브로드캐스트 시간 기록
      _transactionRepository
          .recordTemporaryBroadcastTime(
              signedTx.transactionHash, DateTime.now())
          .catchError((e) {
        Logger.error(e);
      });

      return Result.success(txHash);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  /// 특정 트랜잭션을 조회합니다.
  Future<Result<String>> getTransaction(String txHash) async {
    try {
      final tx = await _electrumService.getTransaction(txHash);
      return Result.success(tx);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  /// RBF 트랜잭션을 감지합니다.
  ///
  /// RBF는 같은 UTXO를 소비하는 새로운 트랜잭션이 발생했을 때 감지됩니다.
  /// 이 메서드는 새로운 트랜잭션이 기존의 outgoing 상태인 UTXO를 소비하는지 확인합니다.
  Future<RbfInfo?> detectRbfTransaction(int walletId, Transaction tx) async {
    Logger.log('===== RBF 감지 프로세스 시작 =====');
    Logger.log('트랜잭션 확인: ${tx.transactionHash}');

    // 이미 RBF 내역이 있는지 확인
    final existingRbfHistory =
        _transactionRepository.getRbfHistoryList(walletId, tx.transactionHash);
    if (existingRbfHistory.isNotEmpty) {
      Logger.log('이미 RBF 내역이 있는 트랜잭션: ${tx.transactionHash}');
      Logger.log('===== RBF 감지 프로세스 종료 (중복 내역) =====');
      return null; // 이미 RBF로 등록된 트랜잭션
    }

    // 트랜잭션의 입력이 outgoing 상태인 UTXO를 사용하는지 확인
    bool isRbf = false;
    String? spentTxHash; // 이 트랜잭션이 대체하는 직전 트랜잭션

    Logger.log('입력 UTXO 분석 시작 (입력 개수: ${tx.inputs.length})');
    for (final input in tx.inputs) {
      final utxoId = makeUtxoId(input.transactionHash, input.index);
      final utxo = _utxoRepository.getUtxoState(walletId, utxoId);

      if (utxo != null) {
        Logger.log(
            'UTXO 검사: $utxoId, 상태: ${utxo.status}, spentByTx: ${utxo.spentByTransactionHash}');

        // 자기 참조 케이스 확인 (spentByTransactionHash가 현재 트랜잭션과 동일한 경우는 무시)
        if (utxo.spentByTransactionHash == tx.transactionHash) {
          Logger.log('자기 참조 케이스 감지: spentByTransactionHash가 현재 트랜잭션과 동일함');
          continue;
        }
      } else {
        Logger.log('UTXO 없음: $utxoId');
        continue;
      }

      if (utxo.status == UtxoStatus.outgoing &&
          utxo.spentByTransactionHash != null) {
        // 최초 트랜잭션과 RBF를 구분하기 위한 로직
        final spentTransaction = _transactionRepository.getTransactionRecord(
            walletId, utxo.spentByTransactionHash!);

        Logger.log(
            'spentTransaction 검사: ${utxo.spentByTransactionHash}, 존재: ${spentTransaction != null}, 블록높이: ${spentTransaction?.blockHeight}');

        // spentTransaction이 존재하지 않는 경우 처리 (트랜잭션이 아직 DB에 없을 수 있음)
        if (spentTransaction == null) {
          Logger.log(
              'spentTransaction이 존재하지 않음. UTXO의 outgoing 상태를 기반으로 RBF로 간주합니다.');
          isRbf = true;
          spentTxHash = utxo.spentByTransactionHash;
          break;
        }

        // spentTransaction이 존재하고, 해당 트랜잭션이 미확인 상태일 때만 RBF로 간주
        if (spentTransaction.blockHeight == 0) {
          Logger.log(
              'RBF 조건 충족: $utxoId, spentTx: ${utxo.spentByTransactionHash}');
          isRbf = true;
          spentTxHash = utxo.spentByTransactionHash;
          break;
        } else {
          Logger.log(
              'RBF 조건 불충족: spentTransaction 블록높이가 0이 아님 ${spentTransaction.blockHeight}');
        }
      } else {
        if (utxo.status != UtxoStatus.outgoing) {
          Logger.log('RBF 조건 불충족: UTXO 상태가 outgoing이 아님 (${utxo.status})');
        } else if (utxo.spentByTransactionHash == null) {
          Logger.log('RBF 조건 불충족: spentByTransactionHash가 없음');
        }
      }
    }

    if (isRbf && spentTxHash != null) {
      // 대체되는 트랜잭션의 RBF 내역 확인
      final previousRbfHistory =
          _transactionRepository.getRbfHistoryList(walletId, spentTxHash);

      String originalTxHash;
      if (previousRbfHistory.isNotEmpty) {
        // 이미 RBF 내역이 있는 경우, 기존 originalTransactionHash 사용
        originalTxHash = previousRbfHistory.first.originalTransactionHash;
        Logger.log('연속된 RBF 감지: 원본 트랜잭션 해시 유지 $originalTxHash');
      } else {
        // 첫 번째 RBF인 경우, 대체되는 트랜잭션이 originalTransactionHash
        originalTxHash = spentTxHash;
        Logger.log('첫 번째 RBF 감지: 원본 트랜잭션 해시 설정 $originalTxHash');
      }

      // 수수료 계산을 위한 정보 수집
      final prevTxs = await getPreviousTransactions(tx, []);

      Logger.log('===== RBF 감지 프로세스 종료 (RBF 감지됨) =====');
      return RbfInfo(
        originalTransactionHash: originalTxHash,
        spentTransactionHash: spentTxHash,
        previousTransactions: prevTxs,
      );
    }

    Logger.log('===== RBF 감지 프로세스 종료 (RBF 감지 안됨) =====');
    return null;
  }

  /// CPFP 트랜잭션을 감지합니다.
  ///
  /// CPFP는 미확인 트랜잭션의 출력을 입력으로 사용하는 새로운 트랜잭션이 발생했을 때 감지됩니다.
  Future<CpfpInfo?> detectCpfpTransaction(int walletId, Transaction tx) async {
    // 이미 CPFP 내역이 있는지 확인
    final existingCpfpHistory =
        _transactionRepository.getCpfpHistory(walletId, tx.transactionHash);
    if (existingCpfpHistory != null) {
      return null; // 이미 CPFP로 등록된 트랜잭션
    }

    // 트랜잭션의 입력이 미확인 트랜잭션의 출력을 사용하는지 확인
    bool isCpfp = false;
    String? parentTxHash;
    double originalFee = 0.0;

    for (final input in tx.inputs) {
      // 입력으로 사용된 트랜잭션이 미확인 상태인지 확인
      final parentTx = _transactionRepository.getTransactionRecord(
          walletId, input.transactionHash);
      if (parentTx != null && parentTx.blockHeight == 0) {
        isCpfp = true;
        parentTxHash = parentTx.transactionHash;
        originalFee = parentTx.feeRate;
        break;
      }
    }

    if (isCpfp && parentTxHash != null) {
      // 수수료 계산을 위한 정보 수집
      final prevTxs = await getPreviousTransactions(tx, []);

      return CpfpInfo(
        parentTransactionHash: parentTxHash,
        originalFee: originalFee,
        previousTransactions: prevTxs,
      );
    }

    return null;
  }
}

/// RBF 트랜잭션 정보를 담는 클래스
class RbfInfo {
  final String originalTransactionHash; // RBF 체인의 최초 트랜잭션
  final String spentTransactionHash; // 이 트랜잭션이 대체하는 직전 트랜잭션
  final List<Transaction> previousTransactions; // 이전 트랜잭션 목록

  RbfInfo({
    required this.originalTransactionHash,
    required this.spentTransactionHash,
    required this.previousTransactions,
  });
}

/// CPFP 트랜잭션 정보를 담는 클래스
class CpfpInfo {
  final String parentTransactionHash; // 부모 트랜잭션
  final double originalFee; // 원본 수수료율
  final List<Transaction> previousTransactions; // 이전 트랜잭션 목록

  CpfpInfo({
    required this.parentTransactionHash,
    required this.originalFee,
    required this.previousTransactions,
  });
}

/// 트랜잭션 상세 정보를 담는 클래스
class _TransactionDetails {
  final List<TransactionAddress> inputAddressList;
  final List<TransactionAddress> outputAddressList;
  final TransactionType txType;
  final int amount;
  final int fee;

  _TransactionDetails({
    required this.inputAddressList,
    required this.outputAddressList,
    required this.txType,
    required this.amount,
    required this.fee,
  });
}
