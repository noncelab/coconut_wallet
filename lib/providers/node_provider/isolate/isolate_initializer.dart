import 'dart:isolate';

import 'package:coconut_wallet/providers/node_provider/balance_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/isolate/isolate_controller.dart';
import 'package:coconut_wallet/providers/node_provider/state/isolate_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/network_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/subscription_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/realm_manager.dart';
import 'package:coconut_wallet/repository/realm/subscription_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/services/chain_source.dart';

class IsolateInitializer {
  static IsolateController entryInitialize(SendPort sendPort, ChainSource chainSource) {
    // TODO: isSetPin, 핀 설정/해제할 때 isolate에서도 인지할 수 있는 로직 추가
    final realmManager = RealmManager();
    final addressRepository = AddressRepository(realmManager);
    final transactionDraftRepository = TransactionDraftRepository(realmManager);
    final walletRepository = WalletRepository(realmManager, transactionDraftRepository);
    final utxoRepository = UtxoRepository(realmManager);
    final transactionRepository = TransactionRepository(realmManager);
    final subscribeRepository = SubscriptionRepository(realmManager);
    // IsolateStateManager 초기화
    final transactionRecordService = TransactionRecordService(chainSource, addressRepository);
    final isolateStateManager = IsolateStateManager(sendPort);
    final BalanceSyncService balanceSyncService = BalanceSyncService(
      chainSource,
      isolateStateManager,
      addressRepository,
      walletRepository,
    );
    final UtxoSyncService utxoSyncService = UtxoSyncService(
      chainSource,
      isolateStateManager,
      utxoRepository,
      transactionRepository,
      addressRepository,
    );
    final ScriptCallbackService scriptCallbackService = ScriptCallbackService();
    final TransactionSyncService transactionSyncService = TransactionSyncService(
      chainSource,
      transactionRepository,
      transactionRecordService,
      isolateStateManager,
      utxoRepository,
      scriptCallbackService,
    );
    final NetworkService networkManager = NetworkService(chainSource, transactionRepository);
    final ScriptSyncService scriptSyncService = ScriptSyncService(
      isolateStateManager,
      balanceSyncService,
      transactionSyncService,
      utxoSyncService,
      addressRepository,
      scriptCallbackService,
    );

    final SubscriptionService subscriptionService = SubscriptionService(
      chainSource,
      isolateStateManager,
      addressRepository,
      subscribeRepository,
      scriptSyncService,
    );

    final isolateController = IsolateController(
      subscriptionService,
      networkManager,
      isolateStateManager,
      chainSource,
      transactionRecordService,
    );

    // 소켓 연결 종료 시 상태 콜백
    chainSource.setOnConnectionLostCallback(() {
      isolateStateManager.setNodeSyncStateToFailed();
    });

    return isolateController;
  }
}
