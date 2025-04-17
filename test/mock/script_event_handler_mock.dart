import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/wallet/wallet_list_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/balance_manager.dart';
import 'package:coconut_wallet/providers/node_provider/state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_callback_manager.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_event_handler.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_manager.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_manager.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/utils/logger.dart';
import 'package:coconut_wallet/utils/result.dart';

import '../providers/node_provider/transaction_manager_test.mocks.dart';
import '../repository/realm/test_realm_manager.dart';

void printState(NodeProviderState state) {
  // UpdateStatus를 심볼로 변환하는 함수
  String statusToSymbol(UpdateStatus status) {
    switch (status) {
      case UpdateStatus.waiting:
        return '⏳'; // 대기 중
      case UpdateStatus.syncing:
        return '🔄'; // 동기화 중
      case UpdateStatus.completed:
        return '✅'; // 완료됨
    }
  }

  // ConnectionState를 심볼로 변환하는 함수
  String connectionStateToSymbol(MainClientState state) {
    switch (state) {
      case MainClientState.syncing:
        return '🔄 동기화 중';
      case MainClientState.waiting:
        return '🟢 대기 중ㅤ';
      case MainClientState.disconnected:
        return '🔴 연결 끊김';
    }
  }

  final connectionState = state.connectionState;
  final connectionStateSymbol = connectionStateToSymbol(connectionState);
  final buffer = StringBuffer();

  if (state.registeredWallets.isEmpty) {
    buffer.writeln('--> 등록된 지갑이 없습니다.');
    buffer.writeln('--> connectionState: $connectionState');
    Logger.log(buffer.toString());
    return;
  }

  // 등록된 지갑의 키 목록 얻기
  final walletKeys = state.registeredWallets.keys.toList();

  // 테이블 헤더 출력 (connectionState 포함)
  buffer.writeln('\n');
  buffer.writeln('┌───────────────────────────────────────┐');
  buffer.writeln('│ 연결 상태: $connectionStateSymbol${' ' * (23 - connectionStateSymbol.length)}│');
  buffer.writeln('├─────────┬─────────┬─────────┬─────────┤');
  buffer.writeln('│ 지갑 ID │  잔액   │  거래   │  UTXO   │');
  buffer.writeln('├─────────┼─────────┼─────────┼─────────┤');

  // 각 지갑 상태 출력
  for (int i = 0; i < walletKeys.length; i++) {
    final key = walletKeys[i];
    final value = state.registeredWallets[key]!;

    final balanceSymbol = statusToSymbol(value.balance);
    final transactionSymbol = statusToSymbol(value.transaction);
    final utxoSymbol = statusToSymbol(value.utxo);

    buffer.writeln(
        '│ ${key.toString().padRight(7)} │   $balanceSymbol    │   $transactionSymbol    │   $utxoSymbol    │');

    // 마지막 행이 아니면 행 구분선 추가
    if (i < walletKeys.length - 1) {
      buffer.writeln('├─────────┼─────────┼─────────┼─────────┤');
    }
  }

  buffer.writeln('└─────────┴─────────┴─────────┴─────────┘');
  Logger.log(buffer.toString());
}

class ScriptEventHandlerMock {
  static int callSubscribeWalletCount = 0;
  static final MockElectrumService electrumService = MockElectrumService();
  static final NodeStateManager stateManager = NodeStateManager(() {
    printState(stateManager.state);
  });
  static final TestRealmManager realmManager = TestRealmManager()..init(false);
  static final UtxoRepository utxoRepository = UtxoRepository(realmManager);
  static final UtxoManager utxoManager = UtxoManager(
    electrumService,
    stateManager,
    utxoRepository,
    transactionRepository,
    addressRepository,
  );
  static final ScriptCallbackManager scriptCallbackManager = ScriptCallbackManager();
  static final AddressRepository addressRepository = AddressRepository(realmManager);
  static final TransactionRepository transactionRepository = TransactionRepository(realmManager);
  static final WalletRepository walletRepository = WalletRepository(realmManager);
  static final TransactionManager transactionManager = TransactionManager(
    electrumService,
    stateManager,
    transactionRepository,
    utxoManager,
    addressRepository,
    scriptCallbackManager,
  );
  static final BalanceManager balanceManager =
      BalanceManager(electrumService, stateManager, addressRepository, walletRepository);
  static Future<Result<bool>> subscribeWallet(WalletListItemBase walletItem) async {
    callSubscribeWalletCount++;
    return Result.success(true);
  }

  static ScriptEventHandler createMockScriptEventHandler() {
    return ScriptEventHandler(
      stateManager,
      balanceManager,
      transactionManager,
      utxoManager,
      addressRepository,
      subscribeWallet,
      scriptCallbackManager,
    );
  }
}
