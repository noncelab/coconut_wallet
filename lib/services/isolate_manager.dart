import 'dart:async';
import 'dart:isolate';

import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/isolate/isolate_connector_data.dart';
import 'package:coconut_wallet/services/model/isolate/isolate_manager_base.dart';
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

  @override
  Future<void> initialize(
      ElectrumService electrumService, String host, int port, bool ssl) async {
    try {
      final data = IsolateConnectorData(
          _receivePort.sendPort, electrumService, host, port, ssl);
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
    } catch (e) {
      throw Exception('Failed to initialize isolate: $e');
    }
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

      if (data == null) {
        responsePort.close();
        break;
      }
      yield data as T;
    }

    responsePort.close();
  }

  static void _isolateEntry(IsolateConnectorData data) async {
    final port = ReceivePort();
    data.sendPort.send(port.sendPort);

    await data.electrumService.connect(data.host, data.port, ssl: data.ssl);

    port.listen((message) async {
      if (message is List && message.length == 3) {
        IsolateMessageType messageType = message[0];
        SendPort replyPort = message[1];
        List<dynamic> params = message[2];

        try {
          switch (messageType) {
            case IsolateMessageType.getBalance:
            // TODO: Handle this case.
            case IsolateMessageType.fetchTransactionRecords:
            // TODO: Handle this case.
            case IsolateMessageType.getUtxoStates:
            // TODO: Handle this case.
          }
        } catch (e, stack) {
          Logger.error('Error in isolate processing: $e');
          Logger.error(stack);
          replyPort.send(Exception('Error in isolate processing: $e'));
        }
      }
    }, onError: (error) {
      Logger.error('Error in isolate ReceivePort: $error');
    });
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _receivePort.close();
  }
}
