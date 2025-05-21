import 'dart:async';
import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/isolate_constants.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_initializer.dart';
import 'package:coconut_wallet/model/node/isolate_state_message.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/model/node/spawn_isolate_dto.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

class IsolateManager {
  Isolate? _isolate;
  SendPort? _mainToIsolateSendPort; // isolate 스레드에서 메인스레드로 보내는 포트
  ReceivePort? _mainFromIsolateReceivePort;
  late Completer<void> _isolateReady;
  StreamController<IsolateStateMessage>? _stateController;
  Stream<IsolateStateMessage>? _stateStream;
  bool _receivePortListening = false;
  bool get isInitialized => (_mainToIsolateSendPort != null && _isolate != null);

  Stream<IsolateStateMessage> get stateStream {
    if (_stateController == null || _stateController!.isClosed) {
      _stateController = StreamController<IsolateStateMessage>.broadcast();
      _stateStream = _stateController!.stream;
    }
    return _stateStream!;
  }

  final Set<ReceivePort> _activeReceivePorts = {};

  IsolateManager() {
    _isolateReady = Completer<void>();
  }

  void _createReceivePort() {
    if (_mainFromIsolateReceivePort != null) {
      _mainFromIsolateReceivePort!.close();
    }
    _mainFromIsolateReceivePort = ReceivePort('mainFromIsolateReceivePort');
    _receivePortListening = false;
  }

  Future<void> initialize(String host, int port, bool ssl, NetworkType networkType) async {
    try {
      Logger.log(
          'IsolateManager: initializing with $host:$port, ssl=$ssl, networkType=$networkType');

      if (_isolate != null) {
        Logger.log('IsolateManager: killing existing isolate');
        _isolate!.kill(priority: Isolate.immediate);
        _isolate = null;
      }
      _mainToIsolateSendPort = null;
      _createReceivePort();
      _closeStateController();
      _isolateReady = Completer<void>();

      final isolateToMainSendPort = _mainFromIsolateReceivePort!.sendPort;
      final data = SpawnIsolateDto(isolateToMainSendPort, host, port, ssl, networkType);

      Logger.log('IsolateManager: spawning new isolate');
      _isolate = await Isolate.spawn<SpawnIsolateDto>(_isolateEntry, data);

      _setUpReceivePortListener();

      await _isolateReady.future.timeout(kIsolateInitTimeout);
      Logger.log('IsolateManager: initialization completed successfully');
    } catch (e) {
      Logger.error('IsolateManager: Failed to initialize isolate: $e');
      throw Exception('Failed to initialize isolate: $e');
    }
  }

  void _closeStateController() {
    if (_stateController != null && !_stateController!.isClosed) {
      try {
        _stateController!.close();
      } catch (e) {
        Logger.error('IsolateManager: Error closing state controller: $e');
      }
      _stateController = null;
      _stateStream = null;
    }
  }

  void _setUpReceivePortListener() {
    if (_receivePortListening || _mainFromIsolateReceivePort == null) {
      return;
    }

    _receivePortListening = true;

    try {
      _mainFromIsolateReceivePort!.listen(
        (message) {
          if (message is List && message.length > 1) {
            _handleIsolateManagerMessage(message);
          }
        },
        onError: (error) {
          if (!_isolateReady.isCompleted) {
            _isolateReady.completeError(Exception('Receive port error: $error'));
          }
        },
        cancelOnError: false, // 오류가 발생해도 리스너 유지
      );
    } catch (e) {
      _receivePortListening = false;
      if (!_isolateReady.isCompleted) {
        _isolateReady.completeError(Exception('Failed to set up ReceivePort listener: $e'));
      }
    }
  }

  void _handleIsolateManagerMessage(List<dynamic> message) {
    if (message[0] is! IsolateManagerCommand) {
      Logger.error('Invalid message type: ${message[0]}');
      return;
    }

    final isolateManagerMessage = message[0] as IsolateManagerCommand;
    final params = message[1];

    switch (isolateManagerMessage) {
      case IsolateManagerCommand.initialize:
        if (params is SendPort) {
          _mainToIsolateSendPort = params;
          if (!_isolateReady.isCompleted) {
            _isolateReady.complete();
          }
        }
        break;

      case IsolateManagerCommand.updateState:
        IsolateStateMessage? stateMessage;

        // List 타입인 경우 - 실제로 사용되는 형식
        if (params is List && params.isNotEmpty) {
          try {
            if (params[0] is IsolateStateMethod) {
              final methodName = params[0] as IsolateStateMethod;
              final methodParams = params.length > 1 ? params.sublist(1) : [];
              stateMessage = IsolateStateMessage(methodName, methodParams);
            }
          } catch (e) {
            Logger.error('Error processing List: $e');
          }
        }

        // stateMessage가 생성되었으면 콜백과 스트림으로 전달
        if (stateMessage != null) {
          // 스트림으로 전달
          if (_stateController != null && !_stateController!.isClosed) {
            _stateController!.add(stateMessage);
          }
        }
        break;
    }
  }

  /// Isolate 내부에서 실행되는 메인 로직
  static void _isolateEntry(SpawnIsolateDto data) async {
    NetworkType.setNetworkType(data.networkType);

    final isolateFromMainReceivePort = ReceivePort('isolateFromMainReceivePort');

    // 초기화 됐음을 알리는 목적으로 사용
    try {
      data.isolateToMainSendPort
          .send([IsolateManagerCommand.initialize, isolateFromMainReceivePort.sendPort]);
    } catch (e) {
      Logger.error("Isolate: ERROR sending initialization message: $e");
    }

    final electrumService = ElectrumService();
    try {
      await electrumService.connect(data.host, data.port, ssl: data.ssl);
    } catch (e) {
      Logger.error("Isolate: ERROR connecting to ElectrumService: $e");
      return; // 연결 실패 시 Isolate 종료
    }

    // IsolateStateManager에 올바른 SendPort 전달
    final isolateController =
        await IsolateInitializer.entryInitialize(data.isolateToMainSendPort, electrumService);

    isolateFromMainReceivePort.listen((message) async {
      if (message is List && message.length == 3) {
        IsolateControllerCommand messageType = message[0];
        SendPort isolateToMainSendPort = message[1]; // 이 SendPort는 일회성 응답용
        List<dynamic> params = message[2];

        isolateController.executeNetworkCommand(messageType, isolateToMainSendPort, params);
      }
    }, onError: (error) {
      Logger.error("Isolate: Error in isolate ReceivePort: $error");
    });
  }

  Future<Result<T>> _send<T>(IsolateControllerCommand messageType, List<dynamic> params) async {
    // 초기화가 진행 중인지 확인하고 완료될 때까지 대기
    try {
      if (!isInitialized) {
        // 초기화가 진행 중인 경우 (isolateReady가 완료되지 않은 경우)
        if (!_isolateReady.isCompleted) {
          // 초기화가 완료될 때까지 대기
          await _isolateReady.future.timeout(kIsolateInitTimeout);
        } else {
          // 초기화가 완료되지 않았고 진행 중이지도 않음 (실패한 상태)
          // 재연결이 비동기로 실행되어 VM의 eventListener에서 먼저 호출되는 가능성이 있어 대기
          await _isolateReady.future.timeout(kIsolateInitTimeout);
        }
      }

      // 여전히 초기화되지 않았으면 에러 발생
      if (!isInitialized) {
        throw ErrorCodes.nodeIsolateError;
      }

      final mainFromIsolateReceivePort = ReceivePort(messageType.name);

      // 활성 ReceivePort 집합에 추가
      _activeReceivePorts.add(mainFromIsolateReceivePort);

      _mainToIsolateSendPort!.send([messageType, mainFromIsolateReceivePort.sendPort, params]);

      Result<T> result;
      try {
        bool isSocketConnectionStatusMessage =
            messageType == IsolateControllerCommand.getSocketConnectionStatus;
        // 소켓 연결 상태 확인 요청은 타임아웃 시간을 빠르게 처리
        final timeLimit = isSocketConnectionStatusMessage
            ? const Duration(milliseconds: 100)
            : kIsolateResponseTimeout;

        result = await mainFromIsolateReceivePort.first.timeout(
          timeLimit,
          onTimeout: () {
            if (isSocketConnectionStatusMessage) {
              return SocketConnectionStatus.terminated;
            }
            throw TimeoutException('Isolate response timeout');
          },
        );
      } finally {
        // 응답을 받았거나 예외가 발생했을 때 ReceivePort 정리
        mainFromIsolateReceivePort.close();
        _activeReceivePorts.remove(mainFromIsolateReceivePort);
      }

      if (result is Exception) {
        return Result.failure(ErrorCodes.nodeUnknown);
      }

      return result;
    } catch (e) {
      Logger.error('IsolateManager: Error in _send: $e');
      if (e is TimeoutException) {
        return Result.failure(ErrorCodes.nodeIsolateError);
      }
      return Result.failure(ErrorCodes.nodeUnknown);
    }
  }

  Future<Result<bool>> subscribeWallets(
    List<WalletListItemBase> walletItems,
  ) async {
    return _send(IsolateControllerCommand.subscribeWallets, [walletItems]);
  }

  Future<Result<bool>> subscribeWallet(WalletListItemBase walletItem) async {
    return _send(IsolateControllerCommand.subscribeWallet, [walletItem]);
  }

  Future<Result<bool>> unsubscribeWallet(WalletListItemBase walletItem) async {
    return _send(IsolateControllerCommand.unsubscribeWallet, [walletItem]);
  }

  Future<Result<String>> broadcast(Transaction signedTx) async {
    return _send(IsolateControllerCommand.broadcast, [signedTx]);
  }

  Future<Result<int>> getNetworkMinimumFeeRate() async {
    return _send(IsolateControllerCommand.getNetworkMinimumFeeRate, []);
  }

  Future<Result<BlockTimestamp>> getLatestBlock() async {
    return _send(IsolateControllerCommand.getLatestBlock, []);
  }

  Future<Result<String>> getTransaction(String txHash) async {
    return _send(IsolateControllerCommand.getTransaction, [txHash]);
  }

  Future<Result<RecommendedFee>> getRecommendedFees() async {
    return _send(IsolateControllerCommand.getRecommendedFees, []);
  }

  Future<Result<SocketConnectionStatus>> getSocketConnectionStatus() async {
    try {
      return _send(IsolateControllerCommand.getSocketConnectionStatus, []);
    } catch (e) {
      Logger.error('IsolateManager: Error in getSocketConnectionStatus: $e');
      return Result.success(SocketConnectionStatus.terminated);
    }
  }

  /// isolate 연결만 종료하는 메서드 (완전 dispose는 아님)
  Future<void> closeIsolate() async {
    Logger.log('IsolateManager: Closing isolate');

    try {
      // 모든 활성 ReceivePort 닫기
      for (final port in _activeReceivePorts) {
        try {
          port.close();
        } catch (e) {
          Logger.error('IsolateManager: Error closing ReceivePort: $e');
        }
      }
      _activeReceivePorts.clear();

      // isolate 종료
      if (_isolate != null) {
        _isolate!.kill(priority: Isolate.immediate);
        _isolate = null;
      }

      // 메인 ReceivePort 닫기
      if (_mainFromIsolateReceivePort != null) {
        _mainFromIsolateReceivePort!.close();
        _mainFromIsolateReceivePort = null;
      }

      _mainToIsolateSendPort = null;

      // isolateReady가 완료되지 않았다면 에러로 완료 처리
      if (!_isolateReady.isCompleted) {
        _isolateReady
            .completeError(Exception('Isolate was closed before initialization completed'));
      }
    } catch (e) {
      Logger.error('IsolateManager: Error closing isolate: $e');
    }
  }
}
