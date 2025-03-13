import 'dart:async';

import 'package:coconut_wallet/model/error/app_error.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/balance_manager.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_event_handler.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_subscriber.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_manager.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_manager.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/services/electrum_service.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

/// NodeProvider의 스크립트 구독 관련 기능을 담당하는 매니저 클래스
class SubscriptionManager {
  final ElectrumService _electrumService;
  final NodeStateManager _stateManager;
  final BalanceManager _balanceManager;
  final TransactionManager _transactionManager;
  final UtxoManager _utxoManager;
  final AddressRepository _addressRepository;
  final SubscriptionRepository _subscriptionRepository;

  // 구독중인 스크립트 상태 변경을 인지하는 컨트롤러
  late StreamController<SubscribeScriptStreamDto> _scriptStatusController;
  late ScriptSubscriber _scriptSubscriber;
  late ScriptEventHandler _scriptEventHandler;

  Stream<SubscribeScriptStreamDto> get scriptStatusStream =>
      _scriptStatusController.stream;

  SubscriptionManager(
    this._electrumService,
    this._stateManager,
    this._balanceManager,
    this._transactionManager,
    this._utxoManager,
    this._addressRepository,
    this._subscriptionRepository,
  ) {
    _scriptStatusController =
        StreamController<SubscribeScriptStreamDto>.broadcast();

    _scriptSubscriber = ScriptSubscriber(
      _electrumService,
      _scriptStatusController,
      _subscriptionRepository,
      _addressRepository,
    );

    _scriptEventHandler = ScriptEventHandler(
      _stateManager,
      _balanceManager,
      _transactionManager,
      _utxoManager,
      _addressRepository,
      subscribeWallet,
    );

    _scriptStatusController.stream
        .listen(_scriptEventHandler.handleScriptStatusChanged);
  }

  /// 스크립트 구독
  /// [walletItem] 지갑 아이템
  /// [walletProvider] 지갑 프로바이더
  Future<Result<bool>> subscribeWallet(
      WalletListItemBase walletItem, WalletProvider walletProvider) async {
    try {
      final result = await _scriptSubscriber.subscribeWallet(
        walletItem,
        walletProvider,
      );

      final changedScriptStatuses = result.scriptStatuses
          .where((status) => status.status != null)
          .toList();

      if (changedScriptStatuses.isNotEmpty) {
        await _scriptEventHandler.handleBatchScriptStatusChanged(
          walletItem: walletItem,
          scriptStatuses: changedScriptStatuses,
          walletProvider: walletProvider,
        );
      }

      return Result.success(true);
    } catch (e) {
      Logger.error('SubscribeWallet: ${walletItem.name} - failed');
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  /// 스크립트 구독 해제
  /// [walletItem] 지갑 아이템
  Future<Result<bool>> unsubscribeWallet(WalletListItemBase walletItem) async {
    try {
      await _scriptSubscriber.unsubscribeWallet(walletItem);
      return Result.success(true);
    } catch (e) {
      return Result.failure(e is AppError ? e : ErrorCodes.nodeUnknown);
    }
  }

  /// 리소스 해제
  void dispose() {
    _scriptStatusController.close();
  }
}
