import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_draft.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/transaction_draft_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/send/send_screen.dart';
import 'package:coconut_wallet/widgets/features/send/vault_receiving_address_field.dart';
import 'package:coconut_wallet/providers/view_model/send/send_view_model.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';

import '../../../mock/utxo_mock.dart';
import '../../../repository/realm/test_realm_manager.dart';

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  _Wallets(this.wallet, this.vault);
  final WalletItemBase wallet;
  final SingleSignatureVault vault;

  WalletAddress _address(int index, bool change) => WalletAddress(
    vault.getAddress(index, isChange: change),
    '${vault.derivationPath}/${change ? 1 : 0}/$index',
    index,
    change,
    false,
    0,
    0,
    0,
  );

  @override
  List<WalletItemBase> get walletItemList => [wallet];
  @override
  WalletItemBase getWalletById(int id) => wallet;
  @override
  bool containsAddress(int walletId, String address, {bool? isChange}) => false;
  @override
  Map<int, WalletAddress> getReceiveAddressMap() => {wallet.id: _address(0, false)};
  @override
  WalletAddress getReceiveAddress(int walletId) => _address(0, false);
  @override
  WalletAddress getChangeAddress(int walletId) => _address(1, true);
  @override
  Future<List<WalletAddress>> getWalletAddressList(
    WalletItemBase wallet,
    int cursor,
    int count,
    bool isChange,
    bool showOnlyUnusedAddresses,
  ) async => List.generate(3, (index) => _address(index, false));
  @override
  List<UtxoState> getUtxoList(int walletId) => const [];
  @override
  List<UtxoState> getUtxoListByStatus(int walletId, UtxoStatus utxoStatus) => const [];
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  _Preferences(this.manual);
  final bool manual;
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.sats;
  @override
  String get language => 'ko';
  @override
  List<int> get walletOrder => const [1];
  @override
  bool get isManualUtxoSelectionMode => manual;
  @override
  bool get hasSeenAddRecipientCard => true;
  @override
  UtxoOrder get utxoSortOrder => UtxoOrder.byAmountDesc;
}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {
  @override
  bool get isInternetOn => true;
}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  int? get bitcoinPriceKrw => null;
  @override
  String getFiatPrice(int satoshiAmount, {FiatCode? fiatCode, bool showCurrencySymbol = true}) => '';
}

class _Pushes extends NavigatorObserver {
  final names = <String?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => names.add(route.settings.name);
}

void main() {
  late TestRealmManager manager;

  setUpAll(() {
    NetworkType.setNetworkType(NetworkType.regtest);
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });
  setUp(() => manager = TestRealmManager());
  tearDown(() => manager.dispose());

  Future<bool> opensUtxoSelectionSheetOnEntry(
    WidgetTester tester, {
    required bool manualMode,
    bool withSelectedUtxos = false,
    int? transactionDraftId,
    bool vaultEntry = false,
  }) async {
    final vault = SingleSignatureVault.fromEntropy(Uint8List(16));
    final wallet = SinglesigWalletItem(id: 1, name: 'Test', colorIndex: 0, iconIndex: 0, descriptor: vault.descriptor);
    final selectedUtxos =
        withSelectedUtxos
            ? [
              UtxoState(
                transactionHash: 'a' * 64,
                index: 0,
                amount: 100000,
                derivationPath: '${vault.derivationPath}/0/0',
                blockHeight: 100,
                to: vault.getAddress(0),
                timestamp: DateTime(2026, 10, 6),
              ),
            ]
            : null;
    final repository = UtxoRepository(manager);
    final tags = UtxoTagProvider(repository);
    addTearDown(tags.dispose);
    final pushes = _Pushes();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<SendInfoProvider>.value(value: SendInfoProvider()),
          ChangeNotifierProvider<WalletProvider>(create: (_) => _Wallets(wallet, vault)),
          ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences(manualMode)),
          ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
          ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
          ChangeNotifierProvider<UtxoTagProvider>.value(value: tags),
          Provider<UtxoRepository>.value(value: repository),
          Provider<TransactionDraftRepository>.value(value: TransactionDraftRepository(manager)),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          navigatorObservers: [pushes],
          home: LoaderOverlay(
            child: SendScreen(
              walletId: 1,
              isMoveToVault: vaultEntry,
              receivingVaultWalletId: vaultEntry ? 1 : null,
              sendEntryPoint: SendEntryPoint.walletDetail,
              selectedUtxoList: selectedUtxos,
              transactionDraftId: transactionDraftId,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800)); // the sheet opens 500 ms after entry
    await tester.pump(const Duration(milliseconds: 500));
    final opened = pushes.names.contains(AnalyticsScreenNames.sendSelectUtxoSheet);
    if (vaultEntry) {
      final fieldFinder = find.byType(VaultReceivingAddressField);
      final field = tester.widget<VaultReceivingAddressField>(fieldFinder);
      expect(field.address, vault.getAddress(0));
      final viewModel = tester.element(fieldFinder).read<SendViewModel>();
      expect(viewModel.recipientList.first.address, vault.getAddress(0));
      await tester.tap(fieldFinder);
      await tester.pump();
      expect(find.text(t.send_screen.vault_addresses(name: 'Test')), findsOneWidget);
      expect(find.text(t.view_more), findsNothing);
      expect(viewModel.showAddressBoard, isTrue);
      await tester.tap(find.text(shortenAddress(vault.getAddress(1), head: 12, tail: 14)));
      await tester.pump();
      await tester.pump(); // address selection updates the view model after the frame
      expect(tester.widget<VaultReceivingAddressField>(fieldFinder).address, vault.getAddress(1));
      expect(viewModel.recipientList.first.address, vault.getAddress(1));
      expect(viewModel.showAddressBoard, isFalse);
      tester.widget<PageView>(find.byType(PageView)).controller!.jumpToPage(1);
      await tester.pump();
      await tester.tap(find.text(t.send_screen.add_recipient));
      await tester.pump();
      await tester.pump();
      viewModel.setAmountText(10000, 1);
      viewModel.validateAllFieldsOnFocusLost();
      await tester.tap(find.byType(VaultReceivingAddressField).hitTestable());
      await tester.pump();
      expect(find.text(shortenAddress(vault.getAddress(1), head: 12, tail: 14)), findsNothing);
      expect(find.text(shortenAddress(vault.getAddress(0), head: 12, tail: 14)), findsOneWidget);
      await tester.tap(find.text(shortenAddress(vault.getAddress(0), head: 12, tail: 14)));
      await tester.pump();
      await tester.pump();
      expect(viewModel.recipientList[1].address, vault.getAddress(0));
      expect(viewModel.recipientList[1].amount, '10000');
      expect(viewModel.recipientList[1].addressError.isNotError, isTrue);
      expect(viewModel.validRecipientList, contains(viewModel.recipientList[1]));
      expect(viewModel.showFeeBoard, isTrue);
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    return opened;
  }

  testWidgets('automatic UTXO selection does not open the UTXO selection sheet on entry', (tester) async {
    expect(await opensUtxoSelectionSheetOnEntry(tester, manualMode: false), isFalse);
  });
  testWidgets('vault entry prefills a read-only recipient and opens the vault address board', (tester) async {
    expect(await opensUtxoSelectionSheetOnEntry(tester, manualMode: false, vaultEntry: true), isFalse);
  });

  testWidgets('manual UTXO selection entered with chosen UTXOs does not open the sheet again', (tester) async {
    expect(await opensUtxoSelectionSheetOnEntry(tester, manualMode: true, withSelectedUtxos: true), isFalse);
  });

  testWidgets('opening a draft with manually chosen UTXOs does not open the UTXO selection sheet', (tester) async {
    final vault = SingleSignatureVault.fromEntropy(Uint8List(16));
    manager.realm.write(() {
      manager.realm.add(
        UtxoMock.createUnspentRealmUtxo(walletId: 1, address: vault.getAddress(0), transactionHash: 'b' * 64),
      );
    });
    final draft =
        (await tester.runAsync(
          () => TransactionDraftRepository(manager).saveUnsignedDraft(
            walletId: 1,
            feeRate: 1,
            isMaxMode: false,
            isFeeSubtractedFromSendAmount: false,
            recipients: [RecipientDraft(address: vault.getAddress(5), amount: 10000)],
            bitcoinUnit: BitcoinUnit.sats,
            selectedUtxoIds: ['${'b' * 64}0'],
          ),
        ))!.value;
    expect(await opensUtxoSelectionSheetOnEntry(tester, manualMode: false, transactionDraftId: draft.id), isFalse);
  });

  testWidgets('manual UTXO selection without chosen UTXOs opens the UTXO selection sheet on entry', (tester) async {
    expect(await opensUtxoSelectionSheetOnEntry(tester, manualMode: true), isTrue);
  });
}
