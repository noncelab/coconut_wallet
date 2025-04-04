import 'dart:async';
import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/constants/isolate_constants.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/balance_manager.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_enum.dart';
import 'package:coconut_wallet/providers/node_provider/network_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription_manager.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_manager.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_manager.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_connector_data.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_handler.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_state_manager.dart';
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

  // 매번 새로운 스트림을 생성하도록 getter 추가
  Stream<IsolateStateMessage> get stateStream {
    if (_stateController == null || _stateController!.isClosed) {
      _stateController = StreamController<IsolateStateMessage>.broadcast();
      _stateStream = _stateController!.stream;
    }
    return _stateStream!;
  }

  // 현재 활성 상태인 ReceivePort를 추적하기 위한 Set
  final Set<ReceivePort> _activeReceivePorts = {};

  static Future<IsolateHandler> entryInitialize(
    SendPort sendPort,
    ElectrumService electrumService,
  ) async {
    // TODO: isSetPin, 핀 설정/해제할 때 isolate에서도 인지할 수 있는 로직 추가
    final realmManager = RealmManager()..init(false);
    final addressRepository = AddressRepository(realmManager);
    final walletRepository = WalletRepository(realmManager);
    final utxoRepository = UtxoRepository(realmManager);
    final transactionRepository = TransactionRepository(realmManager);
    final subscribeRepository = SubscriptionRepository(realmManager);

    // IsolateStateManager 초기화
    final isolateStateManager = IsolateStateManager(sendPort);
    final BalanceManager balanceManager = BalanceManager(electrumService,
        isolateStateManager, addressRepository, walletRepository);
    final UtxoManager utxoManager = UtxoManager(
        electrumService,
        isolateStateManager,
        utxoRepository,
        transactionRepository,
        addressRepository);
    final TransactionManager transactionManager = TransactionManager(
        electrumService,
        isolateStateManager,
        transactionRepository,
        utxoManager,
        addressRepository);
    final NetworkManager networkManager = NetworkManager(electrumService);
    final SubscriptionManager subscriptionManager = SubscriptionManager(
      electrumService,
      isolateStateManager,
      balanceManager,
      transactionManager,
      utxoManager,
      addressRepository,
      subscribeRepository,
    );

    final isolateHandler = IsolateHandler(
      subscriptionManager,
      transactionManager,
      networkManager,
      isolateStateManager,
      electrumService,
    );

    Logger.log("IsolateManager.entryInitialize: Handler created successfully");
    return isolateHandler;
  }

  bool get isInitialized =>
      (_mainToIsolateSendPort != null && _isolate != null);

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

  Future<void> initialize(String host, int port, bool ssl) async {
    try {
      Logger.log('IsolateManager: initializing with $host:$port, ssl=$ssl');

      // 기존 자원 정리
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
      final data = IsolateConnectorData(isolateToMainSendPort, host, port, ssl);

      Logger.log('IsolateManager: spawning new isolate');
      _isolate = await Isolate.spawn<IsolateConnectorData>(_isolateEntry, data);

      // ReceivePort가 이미 리스닝 중인지 확인
      _setUpReceivePortListener();

      await _isolateReady.future.timeout(kIsolateInitTimeout);
      Logger.log('IsolateManager: initialization completed successfully');
    } catch (e) {
      Logger.error('IsolateManager: Failed to initialize isolate: $e');
      throw Exception('Failed to initialize isolate: $e');
    }
  }

  // StreamController를 안전하게 닫기 위한 메서드
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

  // ReceivePort 리스너 설정을 별도 메서드로 분리
  void _setUpReceivePortListener() {
    // 이미 리스닝 중인 경우 처리하지 않음
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
            _isolateReady
                .completeError(Exception('Receive port error: $error'));
          }
        },
        cancelOnError: false, // 오류가 발생해도 리스너 유지
      );
    } catch (e) {
      _receivePortListening = false;
      if (!_isolateReady.isCompleted) {
        _isolateReady.completeError(
            Exception('Failed to set up ReceivePort listener: $e'));
      }
    }
  }

  /// Isolate 내부에서 실행되는 메인 로직
  static void _isolateEntry(IsolateConnectorData data) async {
    // TODO: 메인넷/테스트넷 설정을 isolate 스레드에서도 적용해야 함. (환경변수로 등록하면 좋을듯)
    NetworkType.setNetworkType(NetworkType.regtest);

    final isolateFromMainReceivePort =
        ReceivePort('isolateFromMainReceivePort');

    // 초기화 됐음을 알리는 목적으로 사용
    try {
      data.isolateToMainSendPort.send([
        IsolateManagerMessage.initialize,
        isolateFromMainReceivePort.sendPort
      ]);
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
    final isolateHandler =
        await entryInitialize(data.isolateToMainSendPort, electrumService);

    isolateFromMainReceivePort.listen((message) async {
      if (message is List && message.length == 3) {
        IsolateHandlerMessage messageType = message[0];
        SendPort isolateToMainSendPort = message[1]; // 이 SendPort는 일회성 응답용
        List<dynamic> params = message[2];

        isolateHandler.handleMessage(
            messageType, isolateToMainSendPort, params);
      }
    }, onError: (error) {
      Logger.error("Isolate: Error in isolate ReceivePort: $error");
    });
  }

  Future<T> _send<T>(
      IsolateHandlerMessage messageType, List<dynamic> params) async {
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

      _mainToIsolateSendPort!
          .send([messageType, mainFromIsolateReceivePort.sendPort, params]);

      T result;
      try {
        // 타임아웃 설정으로 무한 대기 방지
        result = await mainFromIsolateReceivePort.first.timeout(
          kIsolateResponseTimeout,
          onTimeout: () {
            throw TimeoutException('Isolate response timeout');
          },
        );
      } finally {
        // 응답을 받았거나 예외가 발생했을 때 ReceivePort 정리
        mainFromIsolateReceivePort.close();
        _activeReceivePorts.remove(mainFromIsolateReceivePort);
      }

      if (result is Exception) {
        throw result;
      }

      return result;
    } catch (e) {
      Logger.error('IsolateManager: Error in _send: $e');
      if (e is TimeoutException) {
        throw ErrorCodes.nodeIsolateError;
      }
      rethrow;
    }
  }

  Future<Result<bool>> subscribeWallets(
    List<WalletListItemBase> walletItems,
  ) async {
    return await _send(IsolateHandlerMessage.subscribeWallets, [walletItems]);
  }

  Future<Result<bool>> subscribeWallet(WalletListItemBase walletItem) async {
    return await _send(IsolateHandlerMessage.subscribeWallet, [walletItem]);
  }

  Future<Result<bool>> unsubscribeWallet(WalletListItemBase walletItem) async {
    return await _send(IsolateHandlerMessage.unsubscribeWallet, [walletItem]);
  }

  Future<Result<String>> broadcast(Transaction signedTx) async {
    return await _send(IsolateHandlerMessage.broadcast, [signedTx]);
  }

  Future<Result<int>> getNetworkMinimumFeeRate() async {
    return await _send(IsolateHandlerMessage.getNetworkMinimumFeeRate, []);
  }

  Future<Result<BlockTimestamp>> getLatestBlock() async {
    return await _send(IsolateHandlerMessage.getLatestBlock, []);
  }

  Future<Result<String>> getTransaction(String txHash) async {
    return await _send(IsolateHandlerMessage.getTransaction, [txHash]);
  }

  Future<Result<RecommendedFee>> getRecommendedFees() async {
    return await _send(IsolateHandlerMessage.getRecommendedFees, []);
  }

  void _handleIsolateManagerMessage(List<dynamic> message) {
    if (message[0] is! IsolateManagerMessage) {
      Logger.error('Invalid message type: ${message[0]}');
      return;
    }

    final isolateManagerMessage = message[0] as IsolateManagerMessage;
    final params = message[1];

    switch (isolateManagerMessage) {
      case IsolateManagerMessage.initialize:
        if (params is SendPort) {
          _mainToIsolateSendPort = params;
          if (!_isolateReady.isCompleted) {
            _isolateReady.complete();
          }
        }
        break;

      case IsolateManagerMessage.updateState:
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

  Future<SocketConnectionStatus> getSocketConnectionStatus() async {
    try {
      return await _send(IsolateHandlerMessage.getSocketConnectionStatus, []);
    } catch (e) {
      Logger.error('IsolateManager: Error in getSocketConnectionStatus: $e');
      return SocketConnectionStatus.terminated;
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
        _isolateReady.completeError(
            Exception('Isolate was closed before initialization completed'));
      }
    } catch (e) {
      Logger.error('IsolateManager: Error closing isolate: $e');
    }
  }
}
