import 'dart:async';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_address.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/block_explorer_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/common/tag_apply_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../repository/realm/test_realm_manager.dart';

late UtxoState _utxo;
late WalletItemBase _wallet;
late TransactionRecord _tx;

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  @override
  UtxoState? getUtxoState(int walletId, String utxoId) => _utxo;
  @override
  WalletItemBase getWalletById(int id) => _wallet;
  @override
  bool isUtxoSuspicious(UtxoState utxo, TransactionRecord? txRecord) => false;
}

class _Transactions extends Fake with ChangeNotifier implements TransactionProvider {
  @override
  TransactionRecord? getTransaction(int walletId, String txHash, {String? utxoTo}) => _tx;
  @override
  TransactionRecord? getTransactionRecord(int walletId, String txHash) => _tx;
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.sats;
  @override
  String get language => 'ko';
}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOn => true;
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  String getFiatPrice(int satoshiAmount, {FiatCode? fiatCode, bool showCurrencySymbol = true}) => '';
  @override
  int? get bitcoinPriceKrw => null;
}

class _Explorer extends Fake with ChangeNotifier implements BlockExplorerProvider {}

class _Addresses extends Fake implements AddressRepository {
  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) => false;
}

/// Same fan-out as NodeProvider.getWalletStateStream, plus a count of live listeners.
class _Node extends Fake with ChangeNotifier implements NodeProvider {
  final _wallets = StreamController<Map<int, WalletUpdateInfo>>.broadcast();
  Map<int, WalletUpdateInfo> _registered = {
    for (final id in [1, 2])
      id: WalletUpdateInfo(
        id,
        subscription: WalletSyncState.completed,
        balance: WalletSyncState.completed,
        transaction: WalletSyncState.completed,
        utxo: WalletSyncState.completed,
      ),
  };
  int active = 0;

  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int walletId) {
    return Stream.multi((controller) {
      active++;
      final initialState = _registered[walletId];
      if (initialState != null) controller.add(initialState);
      final subscription = _wallets.stream
          .map((wallets) => wallets[walletId])
          .where((state) => state != null)
          .cast<WalletUpdateInfo>()
          .listen(controller.add);
      controller.onCancel = () {
        active--;
        return subscription.cancel();
      };
    });
  }

  /// Another wallet's sync update; every listener of every wallet receives the whole map.
  void emitOtherWallet(WalletSyncState balance) {
    _registered = {..._registered, 2: WalletUpdateInfo.fromExisting(_registered[2]!, balance: balance)};
    _wallets.add(_registered);
  }
}

void main() {
  late TestRealmManager manager;

  setUpAll(() {
    NetworkType.setNetworkType(NetworkType.regtest);
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });
  setUp(() => manager = TestRealmManager());
  tearDown(() => manager.dispose());

  testWidgets('keyboard changes on the UTXO detail screen do not leave wallet-state listeners behind', (tester) async {
    final vault = SingleSignatureVault.fromEntropy(Uint8List(16));
    _wallet = SinglesigWalletItem(id: 1, name: 'QA', colorIndex: 0, iconIndex: 0, descriptor: vault.descriptor);
    _utxo = UtxoState(
      transactionHash: 'a' * 64,
      index: 0,
      amount: 100000,
      derivationPath: '${vault.derivationPath}/0/0',
      blockHeight: 100,
      to: vault.getAddress(0),
      timestamp: DateTime(2026, 10, 6),
    );
    _tx = TransactionRecord.fromTransactions(
      transactionHash: 'a' * 64,
      timestamp: DateTime(2026, 10, 6),
      blockHeight: 100,
      transactionType: TransactionType.received,
      amount: 100000,
      fee: 141,
      inputAddressList: [TransactionAddress(vault.getAddress(5), 100141)],
      outputAddressList: [TransactionAddress(vault.getAddress(0), 100000)],
      vSize: 141,
    );
    final node = _Node();
    final tags = UtxoTagProvider(UtxoRepository(manager));
    addTearDown(tags.dispose);
    addTearDown(tester.view.resetViewInsets);
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<WalletProvider>(create: (_) => _Wallets()),
          ChangeNotifierProvider<TransactionProvider>(create: (_) => _Transactions()),
          ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
          ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
          ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
          ChangeNotifierProvider<BlockExplorerProvider>(create: (_) => _Explorer()),
          ChangeNotifierProvider<NodeProvider>.value(value: node),
          ChangeNotifierProvider<UtxoTagProvider>.value(value: tags),
          Provider<AddressRepository>.value(value: _Addresses()),
        ],
        child: MaterialApp(
          navigatorKey: navigatorKey,
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: const Scaffold(body: SizedBox()),
        ),
      ),
    );

    Future<void> settle() async {
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    navigatorKey.currentState!.push(MaterialPageRoute<void>(builder: (_) => UtxoDetailScreen(id: 1, utxo: _utxo)));
    await settle();
    await tester.tap(find.text(t.edit, findRichText: true).first);
    await settle();
    expect(find.byType(TagApplyBottomSheet), findsOneWidget);

    // The keyboard rises and falls frame by frame, as when typing a tag name.
    for (final bottom in [for (var i = 1; i <= 10; i++) i * 30.0, for (var i = 9; i >= 0; i--) i * 30.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: bottom);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(node.active, lessThanOrEqualTo(2), reason: 'the screen and its view model listen once each');

    navigatorKey.currentState!.pop(); // tag sheet
    await settle();
    navigatorKey.currentState!.pop(); // UTXO detail
    await settle();
    expect(node.active, 0, reason: 'leaving the screen must cancel every wallet-state listener');

    node.emitOtherWallet(WalletSyncState.syncing);
    node.emitOtherWallet(WalletSyncState.completed);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
