import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/repository/realm/wallet_data_manager.dart';
import 'package:coconut_wallet/services/isolate_manager.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/model/stream/base_stream_state.dart';
import 'package:coconut_wallet/services/network/node_client.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';

class NodeProvider extends ChangeNotifier {
  final IsolateManager _isolateManager;
  final WalletDataManager _walletDataManager;
  final String _host;
  final int _port;
  final bool _ssl;
  Completer<void>? _initCompleter;
  Completer<void>? _syncCompleter;

  bool get isInitialized => _initCompleter?.isCompleted ?? false;
  bool get isSyncing => _syncCompleter != null;
  String get host => _host;
  int get port => _port;
  bool get ssl => _ssl;

  NodeProvider(
    this._host,
    this._port,
    this._ssl,
    this._walletDataManager, {
    IsolateManager? isolateManager,
    NodeClientFactory? nodeClientFactory,
  }) : _isolateManager = isolateManager ?? IsolateManager() {
    _initCompleter = Completer<void>();
    _initialize(nodeClientFactory);
  }

  Future<void> _initialize(NodeClientFactory? nodeClientFactory) async {
    try {
      final factory = nodeClientFactory ?? ElectrumNodeClientFactory();
      await _isolateManager.initialize(factory, _host, _port, _ssl);
      _initCompleter?.complete();
    } catch (e) {
      _initCompleter?.completeError(e);
    }
  }

  Future<Result<T>> _wrapResult<T>(Future<T> future) async {
    if (!isInitialized) {
      try {
        await _initCompleter?.future;
      } catch (e) {
        return Result.failure(e is AppError ? e : ErrorCodes.nodeIsolateError);
      }
    }

    try {
      return Result.success(await future);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  Future<Result<String>> broadcast(Transaction signedTx) async {
    final result =
        await _wrapResult(_isolateManager.broadcast(signedTx.serialize()));

    if (result.isFailure) {
      return result;
    }

    _walletDataManager
        .recordTemporaryBroadcastTime(signedTx.transactionHash, DateTime.now())
        .catchError((_) {
      Logger.error(_);
    });

    return result;
  }

  Future<Result<int>> getNetworkMinimumFeeRate() async {
    return _wrapResult(_isolateManager.getNetworkMinimumFeeRate());
  }

  Future<Result<BlockTimestamp>> getLatestBlock() async {
    return _wrapResult(_isolateManager.getLatestBlock());
  }

  Future<Result<String>> getTransaction(String txHash) async {
    return _wrapResult(_isolateManager.getTransaction(txHash));
  }

  Future<Result<List<Transaction>>> getPreviousTransactions(
      Transaction transaction, List<Transaction> existingTxList) async {
    return _wrapResult(
        _isolateManager.getPreviousTransactions(transaction, existingTxList));
  }

  Future<Result<RecommendedFee>> getRecommendedFees() async {
    return _wrapResult(_isolateManager.getRecommendedFees());
  }

  Future<
      Result<
          (
            List<AddressBalance> receiveBalanceList,
            List<AddressBalance> changeBalanceList,
            Balance total
          )>> getBalance(WalletListItemBase walletItem) async {
    final result = await _wrapResult(_isolateManager.getBalance(
        walletItem.walletBase,
        receiveUsedIndex: walletItem.receiveUsedIndex,
        changeUsedIndex: walletItem.changeUsedIndex));

    if (result.isSuccess) {
      _walletDataManager.updateWalletBalance(walletItem.id, result.value.$3);
      notifyListeners();
    }

    return result;
  }

  Stream<BaseStreamState<BlockTimestamp>> fetchBlocksByHeight(
      Set<int> heights) {
    return _isolateManager.fetchBlocksByHeight(heights);
  }

  Stream<BaseStreamState<FetchTransactionResponse>> fetchTransactions(
      WalletListItemBase walletItemBase,
      {Set<String>? knownTransactionHashes}) {
    return _isolateManager.fetchTransactions(
      walletItemBase.walletBase,
      knownTransactionHashes: knownTransactionHashes,
      receiveUsedIndex: walletItemBase.receiveUsedIndex,
      changeUsedIndex: walletItemBase.changeUsedIndex,
    );
  }

  Stream<BaseStreamState<Transaction>> fetchTransactionDetails(
      Set<String> transactionHashes) {
    return _isolateManager.fetchTransactionDetails(transactionHashes);
  }

  Stream<BaseStreamState<UtxoState>> fetchUtxos(
    WalletListItemBase wallet,
  ) {
    final receiveUsedIndex = wallet.receiveUsedIndex;
    final changeUsedIndex = wallet.changeUsedIndex;

    return _isolateManager.fetchUtxos(wallet.walletBase,
        receiveUsedIndex: receiveUsedIndex, changeUsedIndex: changeUsedIndex);
  }

  void stopFetching() {
    if (_syncCompleter != null && !_syncCompleter!.isCompleted) {
      _syncCompleter?.completeError(ErrorCodes.nodeConnectionError);
    }
    dispose();
  }

  @override
  void dispose() {
    super.dispose();
    _syncCompleter = null;
    _isolateManager.dispose();
  }
}
