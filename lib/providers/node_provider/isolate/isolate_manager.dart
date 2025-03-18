import 'dart:async';
import 'dart:isolate';

import 'package:coconut_lib/coconut_lib.dart';
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
  final ReceivePort _mainFromIsolateReceivePort;
  late Completer<void> _isolateReady;
  final _stateController = StreamController<IsolateStateMessage>.broadcast();
  Stream<IsolateStateMessage> get stateStream => _stateController.stream;

  // 콜백 함수 등록을 위한 변수 추가
  void Function(IsolateStateMessage)? _stateMessageCallback;

  // 콜백 등록 메서드
  void registerStateCallback(void Function(IsolateStateMessage) callback) {
    _stateMessageCallback = callback;
  }

  // 콜백 제거 메서드
  void unregisterStateCallback() {
    _stateMessageCallback = null;
  }

  static IsolateHandler entryInitialize(
    SendPort sendPort,
    ElectrumService electrumService,
  ) {
    final realmManager = RealmManager();
    final addressRepository = AddressRepository(realmManager);
    final walletRepository = WalletRepository(realmManager);
    final utxoRepository = UtxoRepository(realmManager);
    final transactionRepository = TransactionRepository(realmManager);
    final subscribeRepository = SubscriptionRepository(realmManager);

    // IsolateStateManager 초기화 - 중요: 올바른 SendPort 전달
    final isolateStateManager = IsolateStateManager(sendPort);
    final BalanceManager balanceManager = BalanceManager(electrumService,
        isolateStateManager, addressRepository, walletRepository);
    final UtxoManager utxoManager =
        UtxoManager(electrumService, isolateStateManager, utxoRepository);
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
    );

    Logger.log("IsolateManager.entryInitialize: Handler created successfully");
    return isolateHandler;
  }

  bool get isInitialized =>
      (_mainToIsolateSendPort != null && _isolate != null);

  IsolateManager() : _mainFromIsolateReceivePort = ReceivePort() {
    _isolateReady = Completer<void>();
  }

  Future<void> initialize(String host, int port, bool ssl) async {
    try {
      final isolateToMainSendPort = _mainFromIsolateReceivePort.sendPort;
      final data = IsolateConnectorData(isolateToMainSendPort, host, port, ssl);

      _isolate = await Isolate.spawn<IsolateConnectorData>(_isolateEntry, data);

      _mainFromIsolateReceivePort.listen(
        (message) {
          if (message is List && message.length > 1) {
            _handleIsolateManagerMessage(message);
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

  /// Isolate 내부에서 실행되는 메인 로직
  static void _isolateEntry(IsolateConnectorData data) async {
    // TODO: 메인넷/테스트넷 설정을 isolate 스레드에서도 적용해야 함. (환경변수로 등록하면 좋을듯)
    NetworkType.setNetworkType(NetworkType.regtest);

    final isolateFromMainReceivePort = ReceivePort();

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
        entryInitialize(data.isolateToMainSendPort, electrumService);

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
    if (!isInitialized) {
      throw ErrorCodes.nodeIsolateError;
    }

    final mainFromIsolateReceivePort = ReceivePort();
    _mainToIsolateSendPort!
        .send([messageType, mainFromIsolateReceivePort.sendPort, params]);

    var result = await mainFromIsolateReceivePort.first;
    mainFromIsolateReceivePort.close();

    if (result is Exception) {
      throw result;
    }

    return result;
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
          _isolateReady.complete();
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
          _stateController.add(stateMessage);

          // 콜백으로 전달
          if (_stateMessageCallback != null) {
            _stateMessageCallback!(stateMessage);
          }
        }
        break;
    }
  }

  void dispose() {
    _isolate?.kill(priority: Isolate.immediate);
    _mainFromIsolateReceivePort.close();
    _stateController.close();
    _stateMessageCallback = null;
  }
}
