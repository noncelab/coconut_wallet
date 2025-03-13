import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/services/isolate_manager.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/recommended_fee.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/result.dart';
import 'package:flutter/foundation.dart';
import 'package:coconut_wallet/providers/node_provider/balance_manager.dart';
import 'package:coconut_wallet/providers/node_provider/network_manager.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription_manager.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_manager.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_manager.dart';

class NodeProvider extends ChangeNotifier {
  final IsolateManager _isolateManager;
  final AddressRepository _addressRepository;
  final TransactionRepository _transactionRepository;
  final UtxoRepository _utxoRepository;
  final SubscriptionRepository _subscribeRepository;
  final WalletRepository _walletRepository;
  final String _host;
  final int _port;
  final bool _ssl;
  Completer<void>? _initCompleter;
  Completer<void>? _syncCompleter;

  late NodeStateManager _stateManager;
  late BalanceManager _balanceManager;
  late UtxoManager _utxoManager;
  late TransactionManager _transactionManager;
  late NetworkManager _networkManager;
  late SubscriptionManager _subscriptionManager;

  late ElectrumService _electrumService;

  NodeProviderState get state => _stateManager.state;

  bool get isInitialized => _initCompleter?.isCompleted ?? false;
  String get host => _host;
  int get port => _port;
  bool get ssl => _ssl;

  Stream<SubscribeScriptStreamDto> get scriptStatusStream =>
      _subscriptionManager.scriptStatusStream;

  NodeProvider(
    this._host,
    this._port,
    this._ssl,
    this._addressRepository,
    this._transactionRepository,
    this._utxoRepository,
    this._subscribeRepository,
    this._walletRepository, {
    IsolateManager? isolateManager,
    ElectrumService? electrumService,
  }) : _isolateManager = isolateManager ?? IsolateManager() {
    _initCompleter = Completer<void>();
    _stateManager = NodeStateManager(() => notifyListeners());
    _initialize(electrumService).then((_) {
      _isolateManager.initialize(_electrumService, host, port, ssl);
    });
  }

  Future<void> _initialize(ElectrumService? electrumService) async {
    try {
      if (electrumService != null) {
        _electrumService = electrumService;
      } else {
        _electrumService = ElectrumService();
        await _electrumService.connect(_host, _port, ssl: _ssl);
      }

      _networkManager = NetworkManager(_electrumService);
      _balanceManager = BalanceManager(_electrumService, _stateManager,
          _addressRepository, _walletRepository, _isolateManager);
      _utxoManager =
          UtxoManager(_electrumService, _stateManager, _utxoRepository);
      _transactionManager = TransactionManager(_electrumService, _stateManager,
          _transactionRepository, _utxoManager, _utxoRepository);
      _subscriptionManager = SubscriptionManager(
        _electrumService,
        _stateManager,
        _balanceManager,
        _transactionManager,
        _utxoManager,
        _addressRepository,
        _subscribeRepository,
      );

      _initCompleter?.complete();
    } catch (e) {
      _initCompleter?.completeError(e);
      rethrow;
    } finally {
      notifyListeners();
    }
  }

  Future<Result<T>> _handleResult<T>(Future<T> future) async {
    if (!isInitialized) {
      try {
        await _initCompleter?.future;
      } catch (e) {
        return Result.failure(e is AppError ? e : ErrorCodes.nodeIsolateError);
      }
    }

    try {
      return Result.success(await future);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  Future<Result<bool>> subscribeWallets(List<WalletListItemBase> walletItems,
      WalletProvider walletProvider) async {
    // 지갑별 status 초기화
    for (var walletItem in walletItems) {
      _stateManager.initWalletUpdateStatus(walletItem.id);
    }

    // 동기화 중 state 업데이트
    _stateManager.setState(newConnectionState: MainClientState.syncing);
    for (var walletItem in walletItems) {
      final result = await subscribeWallet(walletItem, walletProvider);
      if (result.isFailure) {
        return result;
      }
    }

    // 동기화 완료 state 업데이트
    _stateManager.setState(newConnectionState: MainClientState.waiting);
    return Result.success(true);
  }

  Future<Result<bool>> subscribeWallet(
      WalletListItemBase walletItem, WalletProvider walletProvider) async {
    if (!isInitialized) {
      return Result.failure(ErrorCodes.nodeIsolateError);
    }
    return await _subscriptionManager.subscribeWallet(
        walletItem, walletProvider);
  }

  Future<Result<bool>> unsubscribeWallet(WalletListItemBase walletItem) async {
    return _handleResult(() async {
      return (await _subscriptionManager.unsubscribeWallet(walletItem)).value;
    }());
  }

  Future<Result<String>> broadcast(Transaction signedTx) async {
    return await _transactionManager.broadcast(signedTx);
  }

  Future<Result<int>> getNetworkMinimumFeeRate() async {
    return await _networkManager.getNetworkMinimumFeeRate();
  }

  Future<Result<BlockTimestamp>> getLatestBlock() async {
    return await _networkManager.getLatestBlock();
  }

  Future<Result<String>> getTransaction(String txHash) async {
    return await _transactionManager.getTransaction(txHash);
  }

  Future<Result<RecommendedFee>> getRecommendedFees() async {
    return await _networkManager.getRecommendedFees();
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
    _electrumService.close();
    _subscriptionManager.dispose();
    _isolateManager.dispose();
  }
}
