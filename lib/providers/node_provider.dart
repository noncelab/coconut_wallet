import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/services/isolate_manager.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/model/stream/base_stream_state.dart';
import 'package:coconut_wallet/services/network/node_client.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';

class NodeProvider extends ChangeNotifier {
  final IsolateManager _isolateManager;
  Completer<void>? _syncCompleter;
  final String _host;
  final int _port;
  final bool _ssl;

  bool get isSyncing => _syncCompleter != null;
  String get host => _host;
  int get port => _port;
  bool get ssl => _ssl;

  NodeProvider(
    this._host,
    this._port,
    this._ssl,
    this._isolateManager,
  );

  static Future<NodeProvider> connectSync(
    String host,
    int port, {
    bool ssl = true,
    IsolateManager? isolateManager,
    NodeClientFactory? nodeClientFactory,
  }) async {
    final manager = isolateManager ?? IsolateManager();
    final factory = nodeClientFactory ?? ElectrumNodeClientFactory();

    await manager.initialize(factory, host, port, ssl);

    NodeProvider nodeProvider = NodeProvider(host, port, ssl, manager);

    return nodeProvider;
  }

  Future<Result<T, AppError>> _wrapResult<T>(Future<T> future) async {
    try {
      return Result.success(await future);
    } catch (e) {
      if (e is AppError) {
        return Result.failure(e);
      }

      return Result.failure(ErrorCodes.nodeUnknown);
    }
  }

  Future<Result<String, AppError>> broadcast(String rawTransaction) async {
    return _wrapResult(_isolateManager.broadcast(rawTransaction));
  }

  Future<Result<int, AppError>> getNetworkMinimumFeeRate() async {
    return _wrapResult(_isolateManager.getNetworkMinimumFeeRate());
  }

  Future<Result<BlockTimestamp, AppError>> getLatestBlock() async {
    return _wrapResult(_isolateManager.getLatestBlock());
  }

  Future<Result<String, AppError>> getTransaction(String txHash) async {
    return _wrapResult(_isolateManager.getTransaction(txHash));
  }

  Future<Result<List<Transaction>, AppError>> getPreviousTransactions(
      Transaction transaction, List<Transaction> existingTxList) async {
    return _wrapResult(
        _isolateManager.getPreviousTransactions(transaction, existingTxList));
  }

  Future<Result<RecommendedFee, AppError>> getRecommendedFees() async {
    return _wrapResult(_isolateManager.getRecommendedFees());
  }

  Future<Result<WalletBalance, AppError>> getBalance(WalletBase wallet,
      {int receiveUsedIndex = 0, int changeUsedIndex = 0}) async {
    return _wrapResult(_isolateManager.getBalance(wallet,
        receiveUsedIndex: receiveUsedIndex, changeUsedIndex: changeUsedIndex));
  }

  Stream<BaseStreamState<BlockTimestamp>> fetchBlocksByHeight(
      Set<int> heights) {
    return _isolateManager.fetchBlocksByHeight(heights);
  }

  Stream<BaseStreamState<FetchTransactionResponse>> fetchTransactions(
      WalletBase wallet,
      {Set<String>? knownTransactionHashes,
      int receiveUsedIndex = 0,
      int changeUsedIndex = 0}) {
    return _isolateManager.fetchTransactions(wallet,
        knownTransactionHashes: knownTransactionHashes,
        receiveUsedIndex: receiveUsedIndex,
        changeUsedIndex: changeUsedIndex);
  }

  Stream<BaseStreamState<Transaction>> fetchTransactionDetails(
      Set<String> transactionHashes) {
    return _isolateManager.fetchTransactionDetails(transactionHashes);
  }

  Stream<BaseStreamState<UtxoState>> fetchUtxos(WalletBase wallet,
      {int receiveUsedIndex = 0, int changeUsedIndex = 0}) {
    return _isolateManager.fetchUtxos(wallet,
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
