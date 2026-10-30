import 'dart:async';
import 'package:coconut_wallet/app.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/wallet_detail_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/resync_progress.dart';
import 'package:coconut_wallet/model/node/wallet_fetch_progress.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/node/subscribe_stream_dto.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/providers/node_provider/balance_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/state/node_state_manager.dart';
import 'package:coconut_wallet/providers/node_provider/transaction/transaction_sync_service.dart';
import 'package:coconut_wallet/providers/node_provider/utxo_sync_service.dart';
import 'package:coconut_wallet/repository/realm/model/coconut_wallet_model.dart';
import 'package:coconut_wallet/repository/realm/service/realm_id_service.dart';
import 'package:coconut_wallet/repository/realm/wallet_repository.dart';
import 'package:coconut_wallet/services/model/response/block_timestamp.dart';
import 'package:coconut_wallet/services/model/response/electrum_response_types.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../../../../mock/script_sync_service_mock.dart';
import '../../../../mock/script_status_mock.dart';
import '../../../../mock/wallet_mock.dart';

class _Node extends Fake with ChangeNotifier implements NodeProvider {
  final nodeEvents = StreamController<NodeSyncState>.broadcast();
  final walletEvents = StreamController<Map<int, WalletUpdateInfo>>.broadcast();
  final resyncEvents = StreamController<Map<int, ResyncProgress>>.broadcast();
  final fetchEvents = StreamController<Map<int, WalletFetchProgress>>.broadcast();
  late final manager = NodeStateManager(notifyListeners, nodeEvents, walletEvents, resyncEvents, fetchEvents);
  @override
  NodeProviderState get state => manager.state;
  @override
  Stream<NodeSyncState> get syncStateStream => nodeEvents.stream;
  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int walletId) => walletEvents.stream.map((e) => e[walletId]!);
  Future<void> close() async {
    await Future.wait([nodeEvents.close(), walletEvents.close(), resyncEvents.close(), fetchEvents.close()]);
    dispose();
  }
}

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  final WalletItemBase wallet;
  final WalletRepository repository;
  _Wallets(this.wallet, this.repository);
  @override
  WalletItemBase getWalletById(int id) => wallet;
  @override
  Balance getWalletBalance(int id) {
    final balance = repository.getWalletBalance(id)!;
    return Balance(balance.confirmed, balance.unconfirmed);
  }
}

class _Transactions extends Fake with ChangeNotifier implements TransactionProvider {
  @override
  void initTxList(int id) {}
}

void main() {
  CoconutWalletApp.kFaucetHost = 'http://localhost';
  test('a failed address keeps the previous balance until that address is retried successfully', () async {
    final network = NetworkType.currentNetworkType;
    ScriptSyncServiceMock.init();
    final realm = ScriptSyncServiceMock.realmManager!;
    addTearDown(() {
      realm.dispose();
      ScriptSyncServiceMock.realmManager = null;
      NetworkType.setNetworkType(network);
    });
    final wallet = WalletMock.createSingleSigWalletItem(id: 901);
    final scripts = List.generate(2, (i) => ScriptStatusMock.createMockScriptStatus(wallet, i));
    realm.realm.write(() {
      realm.realm.add(
        RealmWalletBase(
          wallet.id,
          wallet.colorIndex,
          wallet.iconIndex,
          wallet.descriptor,
          wallet.name,
          WalletType.singleSignature.name,
        ),
      );
      for (final script in scripts) {
        realm.realm.add(
          RealmWalletAddress(
            getWalletAddressId(wallet.id, script.index, script.address),
            wallet.id,
            script.address,
            script.index,
            false,
            script.derivationPath,
            true,
            50000,
            0,
            50000,
          ),
        );
      }
    });
    final wallets = ScriptSyncServiceMock.walletRepository;
    wallets.updateWalletBalance(wallet.id, Balance(100000, 0));
    final state = ScriptSyncServiceMock.stateManager;
    final sync = ScriptSyncServiceMock.createMockScriptSyncService();
    final balances = ScriptSyncServiceMock.balanceSyncService;
    final electrum = ScriptSyncServiceMock.electrumService;
    when(
      electrum.getBalance(any, scripts[0].address),
    ).thenAnswer((_) async => GetBalanceRes(confirmed: 0, unconfirmed: 0));
    when(electrum.getBalance(any, scripts[1].address)).thenThrow(Exception('connection interrupted'));

    await sync.runQueued(wallet.id, () => balances.fetchScriptBalanceBatch(wallet, scripts));
    expect(wallets.getWalletBalance(wallet.id)!.total, 50000);
    expect(state.state.registeredWallets[wallet.id]!.balanceSnapshot, 100000);
    expect(state.state.nodeSyncState, NodeSyncState.failed);

    // An unrelated successful address must not publish the incomplete aggregate.
    await sync.runQueued(wallet.id, () => balances.fetchScriptBalance(wallet, scripts[0]));
    expect(state.state.registeredWallets[wallet.id]!.balanceSnapshot, 100000);
    expect(state.state.nodeSyncState, NodeSyncState.failed);

    when(
      electrum.getBalance(any, scripts[1].address),
    ).thenAnswer((_) async => GetBalanceRes(confirmed: 99000, unconfirmed: 0));
    await sync.runQueued(wallet.id, () => balances.fetchScriptBalance(wallet, scripts[1]));
    expect(state.state.registeredWallets[wallet.id]!.balanceSnapshot, 99000);
    expect(state.state.nodeSyncState, NodeSyncState.completed);
  });

  for (final split in [false, true]) {
    for (final confirmed in [false, true]) {
      test(
        'publishes only the final balance for 50 ${split ? 'split outputs' : 'merged inputs'} (${confirmed ? 'confirmed' : 'pending'})',
        () async {
          final network = NetworkType.currentNetworkType;
          ScriptSyncServiceMock.init();
          final manager = ScriptSyncServiceMock.realmManager!;
          addTearDown(() {
            manager.dispose();
            ScriptSyncServiceMock.realmManager = null;
            NetworkType.setNetworkType(network);
          });
          final wallet = WalletMock.createSingleSigWalletItem(id: 900);
          final inputs = List.generate(split ? 1 : 50, (i) => ScriptStatusMock.createMockScriptStatus(wallet, i));
          final outputs = List.generate(
            split ? 50 : 1,
            (i) => ScriptStatusMock.createMockScriptStatus(wallet, i, isChange: true),
          );
          final initialAmount = split ? 1000000 : 20000;
          final outputAmount = split ? 19980 : 999000;
          final height = confirmed ? 850001 : 0;
          manager.realm.write(() {
            manager.realm.add(
              RealmWalletBase(
                wallet.id,
                wallet.colorIndex,
                wallet.iconIndex,
                wallet.descriptor,
                wallet.name,
                WalletType.singleSignature.name,
              ),
            );
            for (final script in [...inputs, ...outputs]) {
              final amount = script.isChange ? 0 : initialAmount;
              manager.realm.add(
                RealmWalletAddress(
                  getWalletAddressId(wallet.id, script.index, script.address),
                  wallet.id,
                  script.address,
                  script.index,
                  script.isChange,
                  script.derivationPath,
                  true,
                  amount,
                  0,
                  amount,
                ),
              );
            }
          });
          final wallets = ScriptSyncServiceMock.walletRepository;
          wallets.updateWalletBalance(wallet.id, Balance(1000000, 0));
          final node = _Node();
          node.manager.addWalletCompletedAllStates(wallet.id);
          final walletProvider = _Wallets(wallet, wallets);
          final transactions = _Transactions();
          final detail = WalletDetailViewModel(
            wallet.id,
            walletProvider,
            transactions,
            node,
            initialUnit: BitcoinUnit.btc,
          );
          final displayedBalances = [detail.balance];
          detail.addListener(() {
            if (displayedBalances.last != detail.balance) displayedBalances.add(detail.balance);
          });
          final syncStates = [node.state.nodeSyncState];
          final nodeSubscription = node.syncStateStream.distinct().listen(syncStates.add);
          addTearDown(() async {
            detail.dispose();
            walletProvider.dispose();
            transactions.dispose();
            await nodeSubscription.cancel();
            await node.close();
          });
          ScriptSyncServiceMock.stateManager = node.manager;
          ScriptSyncServiceMock.utxoSyncService = UtxoSyncService(
            ScriptSyncServiceMock.electrumService,
            node.manager,
            ScriptSyncServiceMock.utxoRepository,
            ScriptSyncServiceMock.transactionRepository,
            ScriptSyncServiceMock.addressRepository,
          );
          ScriptSyncServiceMock.transactionSyncService = TransactionSyncService(
            ScriptSyncServiceMock.electrumService,
            ScriptSyncServiceMock.transactionRepository,
            ScriptSyncServiceMock.transactionRecordService,
            node.manager,
            ScriptSyncServiceMock.utxoRepository,
            ScriptSyncServiceMock.scriptCallbackService,
          );
          ScriptSyncServiceMock.balanceSyncService = BalanceSyncService(
            ScriptSyncServiceMock.electrumService,
            ScriptSyncServiceMock.stateManager,
            ScriptSyncServiceMock.addressRepository,
            wallets,
          );
          final funding = Transaction.withInputsAndOutputs(
            [TransactionInput.forPayment(List.filled(64, 'a').join(), 0)],
            inputs.map((s) => TransactionOutput.forPayment(initialAmount, s.address)).toList(),
            AddressType.p2wpkh,
          );
          final tx = Transaction.withInputsAndOutputs(
            List.generate(inputs.length, (i) => TransactionInput.forPayment(funding.transactionHash, i)),
            outputs.map((s) => TransactionOutput.forPayment(outputAmount, s.address)).toList(),
            AddressType.p2wpkh,
          );
          await ScriptSyncServiceMock.utxoRepository.addAllUtxos(
            wallet.id,
            List.generate(
              inputs.length,
              (i) => UtxoState(
                transactionHash: funding.transactionHash,
                index: i,
                amount: initialAmount,
                derivationPath: inputs[i].derivationPath,
                blockHeight: 850000,
                timestamp: DateTime.now(),
                to: inputs[i].address,
              ),
            ),
          );
          final electrum = ScriptSyncServiceMock.electrumService;
          when(electrum.getTransaction(tx.transactionHash)).thenAnswer((_) async => tx.serialize());
          when(electrum.getTransaction(funding.transactionHash)).thenAnswer((_) async => funding.serialize());
          when(
            electrum.getPreviousTransactions(any, existingTxList: anyNamed('existingTxList')),
          ).thenAnswer((_) async => [funding]);
          when(
            electrum.fetchBlocksByHeight(any),
          ).thenAnswer((_) async => {height: BlockTimestamp(height, DateTime.now())});
          for (final script in [...inputs, ...outputs]) {
            when(
              electrum.getHistory(any, script.address),
            ).thenAnswer((_) async => [GetTxHistoryRes(height: height, txHash: tx.transactionHash)]);
            when(electrum.getBalance(any, script.address)).thenAnswer(
              (_) async =>
                  script.isChange
                      ? GetBalanceRes(
                        confirmed: confirmed ? outputAmount : 0,
                        unconfirmed: confirmed ? 0 : outputAmount,
                      )
                      : GetBalanceRes(
                        confirmed: confirmed ? 0 : initialAmount,
                        unconfirmed: confirmed ? 0 : -initialAmount,
                      ),
            );
            when(electrum.getUnspentList(any, script.address)).thenAnswer(
              (_) async =>
                  script.isChange
                      ? [
                        ListUnspentRes(
                          height: height,
                          txHash: tx.transactionHash,
                          txPos: script.index,
                          value: outputAmount,
                        ),
                      ]
                      : [],
            );
          }
          final sync = ScriptSyncServiceMock.createMockScriptSyncService();
          sync.subscribeWallet = ScriptSyncServiceMock.subscribeWallet;
          sync.unsubscribeAddress = ScriptSyncServiceMock.unsubscribeAddress;
          await Future.wait(
            [...outputs, ...inputs].map(
              (script) => sync.syncScriptStatus(
                SubscribeScriptStreamDto(walletItem: wallet, scriptStatus: script, updateUsedIndex: false),
              ),
            ),
          );
          await Future<void>.delayed(Duration.zero);
          expect(wallets.getWalletBalance(wallet.id)!.total, 999000);
          expect(displayedBalances, [1000000, 999000]);
          expect(syncStates, [NodeSyncState.completed, NodeSyncState.syncing, NodeSyncState.completed]);
        },
      );
    }
  }
}
