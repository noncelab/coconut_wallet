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

      // 명시적으로 null을 보내는 경우 스트림 종료
      if (data == null) {
        responsePort.close();
        break;
      }
      yield data as T;
    }

    responsePort.close();
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
              int? receiveUsedIndex;
              int? changeUsedIndex;

              if (params.length == 3) {
                receiveUsedIndex = params[1];
                changeUsedIndex = params[2];
              }

              var balanceResult = await nodeClient.getBalance(wallet,
                  receiveUsedIndex: receiveUsedIndex ?? -1,
                  changeUsedIndex: changeUsedIndex ?? -1);

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
              int receiveUsedIndex = -1;
              int changeUsedIndex = -1;

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
              int receiveUsedIndex = -1;
              int changeUsedIndex = -1;

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
          replyPort.send(null);
        } catch (e) {
          Logger.error('Error in isolate processing: $e');
          replyPort.send(Exception('Error in isolate processing'));
        }
      }
    }, onError: (error) {
      Logger.error('Error in isolate ReceivePort: $error');
    });
  }

  Future<String> broadcast(String rawTransaction) async {
    return _send<String>(IsolateMessageType.broadcast, [rawTransaction]);
  }

  Future<int> getNetworkMinimumFeeRate() async {
    return _send<int>(IsolateMessageType.getNetworkMinimumFeeRate, []);
  }

  Future<BlockTimestamp> getLatestBlock() {
    return _send<BlockTimestamp>(IsolateMessageType.getLatestBlock, []);
  }

  Future<String> getTransaction(String txHash) async {
    return _send<String>(IsolateMessageType.getTransaction, [txHash]);
  }

  Future<List<Transaction>> getPreviousTransactions(
      Transaction transaction, List<Transaction> existingTxList) {
    return _send<List<Transaction>>(
        IsolateMessageType.fetchPreviousTransactions,
        [transaction, existingTxList]);
  }

  Future<RecommendedFee> getRecommendedFees() {
    return _send<RecommendedFee>(IsolateMessageType.getRecommendedFees, []);
  }

  Future<
          (
            List<AddressBalance> receiveBalanceList,
            List<AddressBalance> changeBalanceList,
            Balance total
          )>
      getBalance(WalletBase wallet,
          {int receiveUsedIndex = -1, int changeUsedIndex = -1}) {
    return _send<(List<AddressBalance>, List<AddressBalance>, Balance)>(
        IsolateMessageType.getBalance,
        [wallet, receiveUsedIndex, changeUsedIndex]);
  }

  Stream<BaseStreamState<BlockTimestamp>> fetchBlocksByHeight(
      Set<int> heights) {
    return _sendStream<BaseStreamState<BlockTimestamp>>(
        IsolateMessageType.fetchBlocksByHeight, [heights]);
  }

  Stream<BaseStreamState<FetchTransactionResponse>> fetchTransactions(
      WalletBase wallet,
      {Set<String>? knownTransactionHashes,
      int receiveUsedIndex = -1,
      int changeUsedIndex = -1}) {
    return _sendStream<BaseStreamState<FetchTransactionResponse>>(
        IsolateMessageType.fetchTransactions,
        [wallet, knownTransactionHashes, receiveUsedIndex, changeUsedIndex]);
  }

  Stream<BaseStreamState<Transaction>> fetchTransactionDetails(
      Set<String> transactionHashes) {
    return _sendStream<BaseStreamState<Transaction>>(
        IsolateMessageType.fetchTransactionDetails, [transactionHashes]);
  }

  Stream<BaseStreamState<UtxoState>> fetchUtxos(WalletBase wallet,
      {int receiveUsedIndex = -1, int changeUsedIndex = -1}) {
    return _sendStream<BaseStreamState<UtxoState>>(
        IsolateMessageType.fetchUtxos,
        [wallet, receiveUsedIndex, changeUsedIndex]);
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort.close();
  }
}
