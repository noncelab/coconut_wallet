import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/node_provider_state.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/transaction_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/move_to_vault_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/wallet/card/wallet_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../mock/wallet_mock.dart';

WalletUpdateInfo syncedInfo(int id) => WalletUpdateInfo(
  id,
  subscription: WalletSyncState.completed,
  balance: WalletSyncState.completed,
  utxo: WalletSyncState.completed,
  transaction: WalletSyncState.completed,
);

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  String get language => 'ko';
  @override
  List<int> get walletOrder => [];
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.sats;
}

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  _Wallets(this.wallet);
  final WalletItemBase wallet;
  @override
  List<WalletItemBase> get walletItemList => [wallet];
  @override
  Balance getWalletBalance(int id) => Balance(0, 0);
  @override
  int getWatchedAddressCount(int id) => 0;
}

class _Node extends Fake with ChangeNotifier implements NodeProvider {
  _Node(this.info);
  WalletUpdateInfo info;
  @override
  NodeProviderState get state =>
      NodeProviderState(nodeSyncState: NodeSyncState.syncing, registeredWallets: {info.walletId: info});
}

class _Transactions extends Fake implements TransactionRepository {
  _Transactions(this.history);
  final bool history;
  int reads = 0;
  @override
  bool hasTransactionHistory(int id) {
    reads++;
    return history;
  }
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleSync(AppLocale.ko));
  test('only a fully synchronized selected wallet is eligible', () {
    expect(isVaultSelectionSyncComplete(null, NodeSyncState.completed), isFalse);
    expect(isVaultSelectionSyncComplete(WalletUpdateInfo(1), NodeSyncState.syncing), isFalse);
    expect(isVaultSelectionSyncComplete(syncedInfo(1), NodeSyncState.failed), isFalse);
    expect(isVaultSelectionSyncComplete(syncedInfo(1), NodeSyncState.syncing), isTrue);
    for (final info in [
      WalletUpdateInfo.fromExisting(syncedInfo(1), subscription: WalletSyncState.waiting),
      WalletUpdateInfo.fromExisting(syncedInfo(1), balance: WalletSyncState.syncing),
      WalletUpdateInfo.fromExisting(syncedInfo(1), utxo: WalletSyncState.syncing),
      WalletUpdateInfo.fromExisting(syncedInfo(1), transaction: WalletSyncState.syncing),
    ]) {
      expect(isVaultSelectionSyncComplete(info, NodeSyncState.syncing), isFalse);
    }
  });

  Future<void> pumpSheet(
    WidgetTester tester, {
    required _Node node,
    required _Transactions transactions,
    required ValueChanged<int?> onSelected,
  }) async {
    final wallet = WalletMock.createSingleSigWalletItem();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
          ChangeNotifierProvider<WalletProvider>(create: (_) => _Wallets(wallet)),
          ChangeNotifierProvider<NodeProvider>.value(value: node),
          Provider<TransactionRepository>.value(value: transactions),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      final id = await showModalBottomSheet<int>(
                        context: context,
                        builder: (_) => ShowVaultSelectWalletBottomSheet(walletId: 2, watchOnlyWallets: [wallet]),
                      );
                      onSelected(id);
                    },
                    child: const Text('open'),
                  ),
                ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(WalletItemCard));
    await tester.pumpAndSettle();
  }

  testWidgets('unused vault requires explicit confirmation and supports cancellation', (tester) async {
    int? selected;
    await pumpSheet(
      tester,
      node: _Node(syncedInfo(1)),
      transactions: _Transactions(false),
      onSelected: (id) => selected = id,
    );
    expect(find.text(t.wallet_detail_screen.vault_unused_title), findsOneWidget);
    expect(selected, isNull);
    await tester.tap(find.text(t.cancel));
    await tester.pumpAndSettle();
    expect(find.byType(WalletItemCard), findsOneWidget);
    await tester.tap(find.byType(WalletItemCard));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.wallet_detail_screen.vault_unused_continue));
    await tester.pumpAndSettle();
    expect(selected, 1);
  });
  testWidgets('used vault proceeds without the warning', (tester) async {
    int? selected;
    await pumpSheet(
      tester,
      node: _Node(syncedInfo(1)),
      transactions: _Transactions(true),
      onSelected: (id) => selected = id,
    );
    expect(selected, 1);
    expect(find.text(t.wallet_detail_screen.vault_unused_title), findsNothing);
  });
  testWidgets('unfinished synchronization is blocked before checking empty history', (tester) async {
    final transactions = _Transactions(false);
    await pumpSheet(
      tester,
      node: _Node(WalletUpdateInfo(1)),
      transactions: transactions,
      onSelected: (_) => fail('must not proceed'),
    );
    expect(find.text(t.wallet_detail_screen.vault_sync_required_title), findsOneWidget);
    expect(find.text(t.wallet_detail_screen.vault_unused_title), findsNothing);
    expect(transactions.reads, 0);
  });
  testWidgets('sync state is rechecked after confirmation', (tester) async {
    final node = _Node(syncedInfo(1));
    await pumpSheet(
      tester,
      node: node,
      transactions: _Transactions(false),
      onSelected: (_) => fail('must not proceed'),
    );
    node.info = WalletUpdateInfo(1);
    await tester.tap(find.text(t.wallet_detail_screen.vault_unused_continue));
    await tester.pumpAndSettle();
    expect(find.text(t.wallet_detail_screen.vault_sync_required_title), findsOneWidget);
  });
}
