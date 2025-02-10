import 'dart:async';
import 'dart:isolate';

import 'package:coconut_wallet/services/model/isolate/isolate_connector_data.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/network/node_client.dart';
import 'package:coconut_wallet/utils/logger.dart';

abstract class IsolateManager {
  bool get isInitialized;
  Future<void> initialize(
      NodeClientFactory factory, String host, int port, bool ssl);
  Future<String> broadcast(String rawTransaction);
  Future<int> getNetworkMinimumFeeRate();
  Future<BlockTimestamp> getBlock();
  Future<String> getTransaction(String txHash);
  void dispose();
}

class DefaultIsolateManager implements IsolateManager {
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort;
  late Completer<void> _isolateReady;

  DefaultIsolateManager() : _receivePort = ReceivePort() {
    _isolateReady = Completer<void>();
  }

  Future<T> _send<T>(IsolateMessageType messageType, message) async {
    if (_sendPort == null) {
      throw Exception('Isolate not initialized');
    }

    final responsePort = ReceivePort();
    _sendPort!.send([messageType, responsePort.sendPort, message]);

    var result = await responsePort.first;
    responsePort.close();

    return result;
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

  @override
  Future<String> broadcast(String rawTransaction) async {
    return await _send<String>(IsolateMessageType.broadcast, rawTransaction);
  }

  @override
  Future<int> getNetworkMinimumFeeRate() async {
    return await _send<int>(IsolateMessageType.getNetworkMinimumFeeRate, null);
  }

  @override
  Future<BlockTimestamp> getBlock() async {
    return await _send<BlockTimestamp>(IsolateMessageType.getLatestBlock, null);
  }

  @override
  Future<String> getTransaction(String txHash) async {
    return await _send<String>(IsolateMessageType.getTransaction, txHash);
  }

  @override
  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort.close();
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

        try {
          switch (messageType) {
            case IsolateMessageType.broadcast:
              String rawTransaction = message[2];
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
              String txHash = message[2];
              var transactionResult = await nodeClient.getTransaction(txHash);
              replyPort.send(transactionResult);
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
  bool get isInitialized => (_sendPort != null && _isolate != null);
}
