// A batch fails only for its own work: an earlier balance failure elsewhere in the wallet must not abort it.
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/script_status.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/node_provider/subscription/script_sync_service.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../mock/script_status_mock.dart';
import '../../../../mock/script_sync_service_mock.dart';
import '../../../../mock/wallet_mock.dart';

void main() {
  const walletId = 905;
  final wallet = WalletMock.createSingleSigWalletItem(id: walletId);
  late ScriptSyncService sync;
  late List<String> historyRequests;

  setUp(() async {
    ScriptSyncServiceMock.init();
    final realm = ScriptSyncServiceMock.realmManager!.realm;
    realm.write(() {
      realm.add(
        RealmWalletBase(
          wallet.id,
          wallet.colorIndex,
          wallet.iconIndex,
          wallet.descriptor,
          wallet.name,
          WalletType.singleSignature.name,
        ),
      );
    });
    final addresses = ScriptSyncServiceMock.addressRepository;
    await addresses.ensureAddressesInit(walletItemBase: wallet);
    await addresses.ensureAddressesExist(walletItemBase: wallet, cursor: 0, count: 50, isChange: false);
    ScriptSyncServiceMock.walletRepository.updateWalletBalance(wallet.id, Balance(0, 0));

    historyRequests = [];
    final electrum = ScriptSyncServiceMock.electrumService;
    when(electrum.getBalance(any, any)).thenAnswer((_) async => GetBalanceRes(confirmed: 0, unconfirmed: 0));
    when(electrum.getUnspentList(any, any)).thenAnswer((_) async => <ListUnspentRes>[]);
    when(electrum.getHistory(any, any)).thenAnswer((call) async {
      historyRequests.add(call.positionalArguments[1] as String);
      return <GetTxHistoryRes>[];
    });
    sync =
        ScriptSyncServiceMock.createMockScriptSyncService()
          ..subscribeWallet = ScriptSyncServiceMock.subscribeWallet
          ..unsubscribeAddress = ScriptSyncServiceMock.unsubscribeAddress
          ..subscribeAddress = ScriptSyncServiceMock.subscribeAddress;
  });
  tearDown(() {
    ScriptSyncServiceMock.realmManager?.dispose();
    ScriptSyncServiceMock.realmManager = null;
  });

  List<ScriptStatus> scripts(int from, int count) =>
      List.generate(count, (i) => ScriptStatusMock.createMockScriptStatus(wallet, from + i));

  /// A dormant-address balance check (app resume) times out for [address].
  Future<void> failBalanceOnce(String address) async {
    final electrum = ScriptSyncServiceMock.electrumService;
    when(electrum.getBalance(any, address)).thenThrow(StateError('injected get_balance timeout'));
    await ScriptSyncServiceMock.balanceSyncService.fetchScriptBalanceBatch(wallet, scripts(40, 1));
    when(electrum.getBalance(any, address)).thenAnswer((_) async => GetBalanceRes(confirmed: 0, unconfirmed: 0));
    expect(ScriptSyncServiceMock.balanceSyncService.hasBalanceFetchFailures(walletId), isTrue);
  }

  test('an earlier balance failure on an address outside the batch does not abort it', () async {
    await failBalanceOnce(scripts(40, 1).single.address);

    await sync.syncBatchScriptStatusList(walletItem: wallet, scriptStatuses: scripts(0, 2));

    expect(historyRequests, hasLength(2), reason: 'the batch synced its own transactions');
    expect(ScriptSyncServiceMock.balanceSyncService.hasBalanceFetchFailures(walletId), isTrue);
  });

  test('a failed 20-script chunk does not skip the later chunks; the first error is rethrown after them', () async {
    final batch = scripts(0, 45); // chunks of 20, 20 and 5
    final electrum = ScriptSyncServiceMock.electrumService;
    when(electrum.getHistory(any, batch.first.address)).thenAnswer((call) async {
      historyRequests.add(call.positionalArguments[1] as String);
      throw StateError('injected get_history timeout');
    });

    await expectLater(
      sync.syncBatchScriptStatusList(walletItem: wallet, scriptStatuses: batch),
      throwsA(isA<StateError>().having((e) => e.message, 'message', contains('get_history'))),
    );

    expect(historyRequests.toSet(), batch.map((s) => s.address).toSet());
    verifyNever(electrum.getUnspentList(any, any));
    final progress = ScriptSyncServiceMock.stateManager.fetchProgressByWallet[walletId]!;
    expect((progress.dispatched, progress.completed), (45, 45));
  });

  test('a balance failure on an address inside the batch still aborts it', () async {
    final batch = scripts(0, 2);
    final electrum = ScriptSyncServiceMock.electrumService;
    when(electrum.getBalance(any, batch.last.address)).thenThrow(StateError('injected get_balance timeout'));

    await expectLater(sync.syncBatchScriptStatusList(walletItem: wallet, scriptStatuses: batch), throwsStateError);
    expect(historyRequests, isEmpty);
  });
}
