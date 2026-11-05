// "Endless updating": a failed transaction fetch must not leave WalletFetchProgress.isFetching true forever.
// The transaction list shows its spinner while completed < dispatched (transaction_list_view_model.dart).
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../mock/script_status_mock.dart';
import '../../../../mock/script_sync_service_mock.dart';
import '../../../../mock/wallet_mock.dart';

void main() {
  setUp(ScriptSyncServiceMock.init);
  tearDown(() {
    ScriptSyncServiceMock.realmManager?.dispose();
    ScriptSyncServiceMock.realmManager = null;
  });

  Future<void> addWallet(int id, {int addresses = 30}) async {
    final wallet = WalletMock.createSingleSigWalletItem(id: id);
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
    final repository = ScriptSyncServiceMock.addressRepository;
    await repository.ensureAddressesInit(walletItemBase: wallet);
    await repository.ensureAddressesExist(walletItemBase: wallet, cursor: 0, count: addresses, isChange: false);
    ScriptSyncServiceMock.walletRepository.updateWalletBalance(wallet.id, Balance(0, 0));
  }

  /// get_history of [failingAddress] throws once; everything else is an empty, healthy wallet.
  void serveEmptyWallet({required String failingAddress}) {
    final electrum = ScriptSyncServiceMock.electrumService;
    var failed = false;
    when(electrum.getBalance(any, any)).thenAnswer((_) async => GetBalanceRes(confirmed: 0, unconfirmed: 0));
    when(electrum.getUnspentList(any, any)).thenAnswer((_) async => <ListUnspentRes>[]);
    when(electrum.getHistory(any, any)).thenAnswer((call) async {
      if (!failed && call.positionalArguments[1] == failingAddress) {
        failed = true;
        throw StateError('injected get_history timeout');
      }
      return <GetTxHistoryRes>[];
    });
  }

  void expectNotFetching(int walletId, String label) {
    final progress = ScriptSyncServiceMock.stateManager.fetchProgressByWallet[walletId]!;
    // ignore: avoid_print
    print('FETCH_PROGRESS_OBS $label dispatched=${progress.dispatched} completed=${progress.completed}');
    expect(
      progress.isFetching,
      isFalse,
      reason: 'after the queue drained: dispatched ${progress.dispatched}, completed ${progress.completed}',
    );
  }

  test('a failed live transaction fetch does not leave the wallet fetching after a later success', () async {
    const walletId = 903;
    await addWallet(walletId);
    final wallet = WalletMock.createSingleSigWalletItem(id: walletId);
    final script = ScriptStatusMock.createMockScriptStatus(wallet, 0);
    serveEmptyWallet(failingAddress: script.address);
    final sync =
        ScriptSyncServiceMock.createMockScriptSyncService()
          ..subscribeWallet = ScriptSyncServiceMock.subscribeWallet
          ..unsubscribeAddress = ScriptSyncServiceMock.unsubscribeAddress
          ..subscribeAddress = ScriptSyncServiceMock.subscribeAddress;
    final push = SubscribeScriptStreamDto(walletItem: wallet, scriptStatus: script, updateUsedIndex: false);

    await sync.syncScriptStatus(push); // get_history times out inside fetchScriptTransaction
    await sync.syncScriptStatus(push); // the same script syncs successfully

    expectNotFetching(walletId, 'live');
  });

  test('a failed batch chunk does not leave the wallet fetching after a later success', () async {
    const walletId = 904;
    await addWallet(walletId);
    final wallet = WalletMock.createSingleSigWalletItem(id: walletId);
    final scripts = List.generate(25, (i) => ScriptStatusMock.createMockScriptStatus(wallet, i)); // 2 chunks of 20
    serveEmptyWallet(failingAddress: scripts.first.address);
    final sync =
        ScriptSyncServiceMock.createMockScriptSyncService()
          ..subscribeWallet = ScriptSyncServiceMock.subscribeWallet
          ..unsubscribeAddress = ScriptSyncServiceMock.unsubscribeAddress
          ..subscribeAddress = ScriptSyncServiceMock.subscribeAddress;

    await expectLater(
      sync.syncBatchScriptStatusList(walletItem: wallet, scriptStatuses: scripts),
      throwsA(isA<StateError>()),
    );
    await sync.syncBatchScriptStatusList(walletItem: wallet, scriptStatuses: scripts);

    expectNotFetching(walletId, 'batch');
  });
}
