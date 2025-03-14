import 'dart:async';
import 'dart:isolate';

import 'package:coconut_wallet/model/node/address_balance_update_dto.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/services/model/isolate/isolate_connector_data.dart';
import 'package:coconut_wallet/services/model/isolate/isolate_handler.dart';
import 'package:coconut_wallet/services/model/isolate/isolate_manager_base.dart';
import 'package:coconut_wallet/utils/logger.dart';

class IsolateManager implements IsolateManagerBase {
  Isolate? _isolate;
  SendPort? _sendPort;
  final ReceivePort _receivePort;
  late Completer<void> _isolateReady;
  static final IsolateHandler _isolateHandler = IsolateHandler();

  @override
  bool get isInitialized => (_sendPort != null && _isolate != null);

  IsolateManager() : _receivePort = ReceivePort() {
    _isolateReady = Completer<void>();
  }

  @override
  Future<void> initialize(
      ElectrumService electrumService, String host, int port, bool ssl) async {
    try {
      final data = IsolateConnectorData(_receivePort.sendPort, host, port, ssl);

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

  /// 여러 스크립트의 잔액을 한번에 가져오고 DTO 형태로 반환합니다.
  Future<List<AddressBalanceUpdateDto>> getBalanceBatch(
      WalletListItemBase wallet, List<ScriptStatus> scriptStatuses) async {
    if (scriptStatuses.isEmpty) {
      return [];
    }

    final results = await _send<List<AddressBalanceUpdateDto>>(
        IsolateMessageType.getBalanceBatch,
        [wallet.walletBase.addressType, scriptStatuses]);

    return results;
  }

  /// Isolate 내부에서 실행되는 메인 로직
  static void _isolateEntry(IsolateConnectorData data) async {
    final port = ReceivePort();
    data.sendPort.send(port.sendPort);

    final electrumService = ElectrumService();
    await electrumService.connect(data.host, data.port, ssl: data.ssl);

    Logger.log('Isolate: ElectrumService connected and ready');

    port.listen((message) async {
      if (message is List && message.length == 3) {
        IsolateMessageType messageType = message[0];
        SendPort replyPort = message[1];
        List<dynamic> params = message[2];

        try {
          switch (messageType) {
            case IsolateMessageType.getBalanceBatch:
              await _isolateHandler.handleGetBalanceBatch(
                  electrumService, params, replyPort);
              break;
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
