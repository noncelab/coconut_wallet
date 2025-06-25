import 'dart:async';
import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/isolate_constants.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
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
  SendPort? _mainToIsolateSendPort;
  ReceivePort? _mainFromIsolateReceivePort;
  Completer<void>? _isolateReady;
  StreamController<IsolateStateMessage>? _stateController;
  Stream<IsolateStateMessage>? _stateStream;
  bool _receivePortListening = false;
  bool _isInitializing = false;

  bool get isInitialized => (_mainToIsolateSendPort != null && _isolate != null);

  Stream<IsolateStateMessage> get stateStream {
    if (_stateController == null || _stateController!.isClosed) {
      _stateController = StreamController<IsolateStateMessage>.broadcast();
      _stateStream = _stateController!.stream;
    }
    return _stateStream!;
  }

  final Set<ReceivePort> _activeReceivePorts = {};

  IsolateManager();

  void _createReceivePort() {
    if (_mainFromIsolateReceivePort != null) {
      _mainFromIsolateReceivePort!.close();
    }
    _mainFromIsolateReceivePort = ReceivePort('mainFromIsolateReceivePort');
    _receivePortListening = false;
  }

  void _createIsolateCompleter() {
    if (_isolateReady != null && !_isolateReady!.isCompleted && _isInitializing) {
      try {
        _isolateReady!
            .completeError(Exception('IsolateManager: Previous initialization was cancelled'));
      } catch (e) {
        // 이미 완료된 경우 무시
      }
    }
    _isolateReady = Completer<void>();
  }

  Future<void> initialize(String host, int port, bool ssl, NetworkType networkType) async {
    // 이미 초기화 중인 경우 기존 작업 완료 대기
    if (_isInitializing) {
      Logger.log('IsolateManager: Already initializing, waiting for completion');
      if (_isolateReady != null && !_isolateReady!.isCompleted) {
        await _isolateReady!.future;
        return;
      }
      return; // 이미 성공적으로 완료된 경우
    }
    _isInitializing = true;

    try {
      await _forceCleanup();

      _createReceivePort();
      _closeStateController();
      _createIsolateCompleter();

      final isolateToMainSendPort = _mainFromIsolateReceivePort!.sendPort;
      final data = SpawnIsolateDto(isolateToMainSendPort, host, port, ssl, networkType);

      _isolate = await Isolate.spawn<SpawnIsolateDto>(_isolateEntry, data);
      _setUpReceivePortListener();

      // 초기화 완료 대기
      await _isolateReady!.future.timeout(
        kIsolateInitTimeout,
        onTimeout: () {
          Logger.error(
              'IsolateManager: Initialize timeout after ${kIsolateInitTimeout.inSeconds} seconds');
          throw TimeoutException('Isolate initialization timeout', kIsolateInitTimeout);
        },
      );

      Logger.log('IsolateManager: Initialization completed successfully');
    } catch (e) {
      Logger.error('IsolateManager: Failed to initialize isolate: $e');
      // 실패 시 상태 정리
      await _forceCleanup();
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _forceCleanup() async {
    try {
      // 기존 isolate 즉시 종료
      if (_isolate != null) {
        _isolate!.kill(priority: Isolate.immediate);
        _isolate = null;
      }

      // 기존 연결 정리
      _mainToIsolateSendPort = null;

      // 활성 ReceivePort들 정리
      for (final port in _activeReceivePorts) {
        try {
          port.close();
        } catch (e) {
          // 이미 닫힌 포트 무시
        }
      }
      _activeReceivePorts.clear();

      // StateController 정리
      _closeStateController();

      // isolate 정리 시간 확보
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      Logger.error('IsolateManager: Error during force cleanup: $e');
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
          Logger.error('IsolateManager: ReceivePort error: $error');
          if (_isolateReady != null && !_isolateReady!.isCompleted) {
            try {
              _isolateReady!.completeError(Exception('Receive port error: $error'));
            } catch (e) {
              // 이미 완료된 경우 무시
            }
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      _receivePortListening = false;
      Logger.error('IsolateManager: Failed to set up ReceivePort listener: $e');
      if (_isolateReady != null && !_isolateReady!.isCompleted) {
        try {
          _isolateReady!.completeError(Exception('Failed to set up ReceivePort listener: $e'));
        } catch (e) {
          // 이미 완료된 경우 무시
        }
      }
    }
  }

  void _handleIsolateManagerMessage(List<dynamic> message) {
    if (message[0] is! IsolateManagerCommand) {
      Logger.error('IsolateManager: Invalid message type: ${message[0]}');
      return;
    }

    final isolateManagerMessage = message[0] as IsolateManagerCommand;
    final params = message[1];

    switch (isolateManagerMessage) {
      case IsolateManagerCommand.initialize:
        if (params is SendPort) {
          _mainToIsolateSendPort = params;

          // scheduleMicrotask를 사용하여 메시지 처리 완료 후 초기화 완료 신호 전송
          if (_isolateReady != null && !_isolateReady!.isCompleted) {
            try {
              _isolateReady!.complete();
            } catch (e) {
              Logger.error('IsolateManager: Error completing initialization: $e');
            }
          }
        }
        break;

      case IsolateManagerCommand.updateState:
        IsolateStateMessage? stateMessage;

        if (params is List && params.isNotEmpty) {
          try {
            if (params[0] is IsolateStateMethod) {
              final methodName = params[0] as IsolateStateMethod;
              final methodParams = params.length > 1 ? params.sublist(1) : [];
              stateMessage = IsolateStateMessage(methodName, methodParams);
            }
          } catch (e) {
            Logger.error('IsolateManager: Error processing state message: $e');
          }
        }

        if (stateMessage != null) {
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
    final electrumService = ElectrumService();

    try {
      final isConnected = await electrumService.connect(data.host, data.port, ssl: data.ssl);

      if (!isConnected) {
        Logger.error("Isolate: Failed to connect to Electrum server");
        return;
      }

      final isolateController =
          IsolateInitializer.entryInitialize(data.isolateToMainSendPort, electrumService);

      // 모든 초기화 완료 후 메시지 전송
      data.isolateToMainSendPort
          .send([IsolateManagerCommand.initialize, isolateFromMainReceivePort.sendPort]);

      isolateFromMainReceivePort.listen((message) async {
        if (message is List && message.length == 3) {
          IsolateControllerCommand messageType = message[0];
          SendPort isolateToMainSendPort = message[1];
          List<dynamic> params = message[2];

          isolateController.executeNetworkCommand(messageType, isolateToMainSendPort, params);
        }
      }, onError: (error) {
        Logger.error("Isolate: ReceivePort error: $error");
      });
    } catch (e) {
      Logger.error("Isolate: ERROR during parallel initialization: $e");
      return;
    }
  }

  Future<Result<T>> _send<T>(IsolateControllerCommand messageType, List<dynamic> params) async {
    try {
      // 초기화 상태 확인 및 대기
      if (!isInitialized) {
        if (_isolateReady != null && !_isolateReady!.isCompleted) {
          await _isolateReady!.future.timeout(
            kIsolateInitTimeout,
            onTimeout: () => throw TimeoutException('Isolate not ready', kIsolateInitTimeout),
          );
        } else if (!isInitialized) {
          throw ErrorCodes.nodeIsolateError;
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

        final timeLimit = isSocketConnectionStatusMessage
            ? const Duration(milliseconds: 100)
            : kIsolateResponseTimeout;

        result = await mainFromIsolateReceivePort.first.timeout(
          timeLimit,
          onTimeout: () {
            Logger.error('IsolateManager: Command timeout: $messageType');
            if (isSocketConnectionStatusMessage) {
              return Result.success(SocketConnectionStatus.terminated);
            }
            return Result.failure(ErrorCodes.nodeIsolateError);
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

  Future<Result<TransactionRecord>> getTransactionRecord(
      int walletId, String addressTypeString, String txHash) {
    return _send(
        IsolateControllerCommand.getTransactionRecord, [walletId, addressTypeString, txHash]);
  }

  /// isolate 연결만 종료하는 메서드
  Future<void> closeIsolate() async {
    Logger.log('IsolateManager: Closing isolate');

    try {
      // StateController 정리
      _closeStateController();

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
      _receivePortListening = false;
      _isInitializing = false;

      // isolateReady가 완료되지 않았다면 에러로 완료 처리
      if (_isolateReady != null && !_isolateReady!.isCompleted) {
        try {
          _isolateReady!
              .completeError(Exception('Isolate was closed before initialization completed'));
        } catch (e) {
          // 이미 완료된 경우 무시
        }
      }
      _isolateReady = null; // null로 설정하여 상태 초기화
    } catch (e) {
      Logger.error('IsolateManager: Error closing isolate: $e');
    }
  }
}
