import 'dart:async';
import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/services/model/isolate/isolate_connector_data.dart';
import 'package:coconut_wallet/services/model/isolate/isolate_manager_base.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/fetch_transaction_response.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/model/stream/base_stream_state.dart';
import 'package:coconut_wallet/services/network/node_client.dart';
import 'package:coconut_wallet/utils/logger.dart';

class IsolateManager implements IsolateManagerBase {
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort;
  late Completer<void> _isolateReady;

  @override
  bool get isInitialized => (_sendPort != null && _isolate != null);

  @override
  int gapLimit = 20;

  IsolateManager() : _receivePort = ReceivePort() {
    _isolateReady = Completer<void>();
  }

  Future<T> _send<T>(
      IsolateMessageType messageType, List<dynamic> params) async {
    if (_sendPort == null) {
      throw Exception('Isolate not initialized');
    }

    final responsePort = ReceivePort();
    _sendPort!.send([messageType, responsePort.sendPort, params]);

    var result = await responsePort.first;
    responsePort.close();

    if (result is Exception) {
      throw result;
    }

    return result;
  }

  Stream<T> _sendStream<T>(
      IsolateMessageType messageType, List<dynamic> params) async* {
    if (_sendPort == null) {
      throw Exception('Isolate not initialized');
    }

    final responsePort = ReceivePort();
    _sendPort!.send([messageType, responsePort.sendPort, params]);

    await for (var data in responsePort) {
      if (data is Exception) {
        responsePort.close();
        throw data;
      }
      yield data as T;
    }
  }

  @override
  Future<void> initialize(
      NodeClientFactory factory, String host, int port, bool ssl) async {
    late final IsolateConnectorData data;
    try {
      data =
          IsolateConnectorData(_receivePort.sendPort, factory, host, port, ssl);
    } catch (e) {
      throw Exception('Failed to create isolate data: $e');
    }

    _isolate = await Isolate.spawn<IsolateConnectorData>(_isolateEntry, data);

    _receivePort.listen(
      (message) {
        if (message is SendPort) {
          _sendPort = message;
          _isolateReady.complete();
        }
      },
      onError: (error) {
        _isolateReady.completeError(Exception('Receive port error: $error'));
      },
      cancelOnError: true,
    );

    await _isolateReady.future;
  }

  static void _isolateEntry(IsolateConnectorData data) async {
    final port = ReceivePort();
    data.sendPort.send(port.sendPort);

    port.listen((message) async {
      if (message is List && message.length == 3) {
        final nodeClient =
            await data.factory.create(data.host, data.port, ssl: data.ssl);

        IsolateMessageType messageType = message[0];
        SendPort replyPort = message[1];
        List<dynamic> params = message[2];

        try {
          switch (messageType) {
            case IsolateMessageType.broadcast:
              String rawTransaction = params[0];
              var broadcastResult = await nodeClient.broadcast(rawTransaction);
              replyPort.send(broadcastResult);
              break;

            case IsolateMessageType.getNetworkMinimumFeeRate:
              var feeRateResult = await nodeClient.getNetworkMinimumFeeRate();
              replyPort.send(feeRateResult);
              break;

            case IsolateMessageType.getLatestBlock:
              var blockResult = await nodeClient.getLatestBlock();
              replyPort.send(blockResult);
              break;

            case IsolateMessageType.getTransaction:
              String txHash = params[0];
              var transactionResult = await nodeClient.getTransaction(txHash);
              replyPort.send(transactionResult);
              break;

            case IsolateMessageType.getBalance:
              WalletBase wallet = params[0];
              int receiveUsedIndex = 0;
              int changeUsedIndex = 0;

              if (params.length == 3) {
                receiveUsedIndex = params[1];
                changeUsedIndex = params[2];
              }

              var balanceResult = await nodeClient.getBalance(wallet,
                  receiveUsedIndex: receiveUsedIndex,
                  changeUsedIndex: changeUsedIndex);

              replyPort.send(balanceResult);
              break;
            case IsolateMessageType.getRecommendedFees:
              var recommendedFeesResult = await nodeClient.getRecommendedFees();
              replyPort.send(recommendedFeesResult);
              break;

            case IsolateMessageType.fetchBlocksByHeight:
              Set<int> heights = params[0];
              var blocksStream = nodeClient.fetchBlocksByHeight(heights);
              await for (var state in blocksStream) {
                replyPort.send(state);
              }
              break;

            case IsolateMessageType.fetchTransactions:
              WalletBase wallet = params[0];
              Set<String> knownTransactionHashes = params[1];
              int receiveUsedIndex = 0;
              int changeUsedIndex = 0;

              if (params.length == 4) {
                receiveUsedIndex = params[2];
                changeUsedIndex = params[3];
              }

              var transactionsStream = nodeClient.fetchTransactions(wallet,
                  knownTransactionHashes: knownTransactionHashes,
                  receiveUsedIndex: receiveUsedIndex,
                  changeUsedIndex: changeUsedIndex);

              await for (var state in transactionsStream) {
                replyPort.send(state);
              }
              break;

            case IsolateMessageType.fetchTransactionDetails:
              Set<String> transactionHashes = params[0];
              var transactionDetailsStream =
                  nodeClient.fetchTransactionDetails(transactionHashes);
              await for (var state in transactionDetailsStream) {
                replyPort.send(state);
              }
              break;

            case IsolateMessageType.fetchUtxos:
              WalletBase wallet = params[0];
              int receiveUsedIndex = 0;
              int changeUsedIndex = 0;

              if (params.length == 3) {
                receiveUsedIndex = params[1];
                changeUsedIndex = params[2];
              }

              var utxosStream = nodeClient.fetchUtxos(wallet,
                  receiveUsedIndex: receiveUsedIndex,
                  changeUsedIndex: changeUsedIndex);
              await for (var state in utxosStream) {
                replyPort.send(state);
              }
              break;
            case IsolateMessageType.fetchPreviousTransactions:
              Transaction transaction = params[0];
              List<Transaction> existingTxList = params[1];
              var previousTransactionsStream = await nodeClient
                  .getPreviousTransactions(transaction, existingTxList);
              replyPort.send(previousTransactionsStream);
              break;
          }
          nodeClient.dispose();
        } catch (e) {
          Logger.error('Error in isolate processing: $e');
          replyPort.send(Exception('Error in isolate processing'));
        }
      }
    }, onError: (error) {
      Logger.error('Error in isolate ReceivePort: $error');
    });
  }

  @override
  Future<String> broadcast(String rawTransaction) async {
    return _send<String>(IsolateMessageType.broadcast, [rawTransaction]);
  }

  @override
  Future<int> getNetworkMinimumFeeRate() async {
    return _send<int>(IsolateMessageType.getNetworkMinimumFeeRate, []);
  }

  @override
  Future<BlockTimestamp> getLatestBlock() {
    return _send<BlockTimestamp>(IsolateMessageType.getLatestBlock, []);
  }

  @override
  Future<String> getTransaction(String txHash) async {
    return _send<String>(IsolateMessageType.getTransaction, [txHash]);
  }

  @override
  Future<List<Transaction>> getPreviousTransactions(
      Transaction transaction, List<Transaction> existingTxList) {
    return _send<List<Transaction>>(
        IsolateMessageType.fetchPreviousTransactions,
        [transaction, existingTxList]);
  }

  @override
  Future<RecommendedFee> getRecommendedFees() {
    return _send<RecommendedFee>(IsolateMessageType.getRecommendedFees, []);
  }

  @override
  Future<WalletBalance> getBalance(WalletBase wallet,
      {int receiveUsedIndex = 0, int changeUsedIndex = 0}) {
    return _send<WalletBalance>(IsolateMessageType.getBalance,
        [wallet, receiveUsedIndex, changeUsedIndex]);
  }

  @override
  Stream<BaseStreamState<BlockTimestamp>> fetchBlocksByHeight(
      Set<int> heights) {
    return _sendStream<BaseStreamState<BlockTimestamp>>(
        IsolateMessageType.fetchBlocksByHeight, [heights]);
  }

  @override
  Stream<BaseStreamState<FetchTransactionResponse>> fetchTransactions(
      WalletBase wallet,
      {Set<String>? knownTransactionHashes,
      int receiveUsedIndex = 0,
      int changeUsedIndex = 0}) {
    return _sendStream<BaseStreamState<FetchTransactionResponse>>(
        IsolateMessageType.fetchTransactions,
        [wallet, knownTransactionHashes, receiveUsedIndex, changeUsedIndex]);
  }

  @override
  Stream<BaseStreamState<Transaction>> fetchTransactionDetails(
      Set<String> transactionHashes) {
    return _sendStream<BaseStreamState<Transaction>>(
        IsolateMessageType.fetchTransactionDetails, [transactionHashes]);
  }

  @override
  Stream<BaseStreamState<UtxoState>> fetchUtxos(WalletBase wallet,
      {int receiveUsedIndex = 0, int changeUsedIndex = 0}) {
    return _sendStream<BaseStreamState<UtxoState>>(
        IsolateMessageType.fetchUtxos,
        [wallet, receiveUsedIndex, changeUsedIndex]);
  }

  @override
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort.close();
  }
}
