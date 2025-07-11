import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/balance_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_service.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_record_service.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/utils/result.dart';

import '../providers/node_provider/transaction/rbf_service_test.mocks.dart';
import '../repository/realm/test_realm_manager.dart';

class ScriptSyncServiceMock {
  static int callSubscribeWalletCount = 0;
  static late MockElectrumService electrumService;
  static late NodeStateManager stateManager;
  static TestRealmManager? realmManager;
  static late UtxoRepository utxoRepository;
  static late UtxoSyncService utxoSyncService;
  static late ScriptCallbackService scriptCallbackService;
  static late AddressRepository addressRepository;
  static late TransactionRepository transactionRepository;
  static late WalletRepository walletRepository;
  static late TransactionSyncService transactionSyncService;
  static late TransactionRecordService transactionRecordService;
  static late BalanceSyncService balanceSyncService;

  static Future<Result<bool>> subscribeWallet(WalletListItemBase walletItem) async {
    callSubscribeWalletCount++;
    return Result.success(true);
  }

  static ScriptSyncService createMockScriptSyncService() {
    return ScriptSyncService(
      stateManager,
      balanceSyncService,
      transactionSyncService,
      utxoSyncService,
      addressRepository,
      scriptCallbackService,
    );
  }

  static void init() {
    NetworkType.setNetworkType(NetworkType.regtest);
    callSubscribeWalletCount = 0;
    electrumService = MockElectrumService();
    stateManager = NodeStateManager(
      () {},
      StreamController<NodeSyncState>.broadcast(),
      StreamController<Map<int, WalletUpdateInfo>>.broadcast(),
    );
    if (realmManager == null) {
      realmManager = TestRealmManager()..init(false);
    } else {
      realmManager!.dispose();
      realmManager = TestRealmManager()..init(false);
    }

    // 리포지토리 초기화
    addressRepository = AddressRepository(realmManager!);
    transactionRepository = TransactionRepository(realmManager!);
    walletRepository = WalletRepository(realmManager!);
    utxoRepository = UtxoRepository(realmManager!);

    // 매니저 초기화
    scriptCallbackService = ScriptCallbackService();

    // 의존성 순서를 고려한 매니저 초기화
    utxoSyncService = UtxoSyncService(
      electrumService,
      stateManager,
      utxoRepository,
      transactionRepository,
      addressRepository,
    );

    transactionRecordService = TransactionRecordService(electrumService, addressRepository);

    balanceSyncService =
        BalanceSyncService(electrumService, stateManager, addressRepository, walletRepository);

    transactionSyncService = TransactionSyncService(
      electrumService,
      transactionRepository,
      transactionRecordService,
      stateManager,
      utxoRepository,
      scriptCallbackService,
    );
  }
}
