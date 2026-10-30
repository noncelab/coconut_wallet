import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_parameter_names.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/analytics/analytics_screen_observer.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/balance.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/transaction_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_overview_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/utils/utxo_tier_theme.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../repository/realm/test_realm_manager.dart';

class _Analytics extends AnalyticsService {
  _Analytics() : super(null, false);

  /// (screen name, segment parameter)
  final screens = <(String, Object?)>[];

  @override
  Future<void> logScreenView({required String screenName, Map<String, Object>? parameters}) {
    screens.add((screenName, parameters?[AnalyticsParameterNames.segment]));
    return super.logScreenView(screenName: screenName, parameters: parameters);
  }
}

class _Wallets extends Fake with ChangeNotifier implements WalletProvider {
  _Wallets(this.wallet);
  final WalletItemBase wallet;

  @override
  List<WalletItemBase> get walletItemList => [wallet];
  @override
  WalletItemBase getWalletById(int id) => wallet;
  @override
  Balance getWalletBalance(int walletId) => Balance(0, 0);
  @override
  List<UtxoState> getUtxoList(int walletId) => []; // the view model sorts it in place
}

class _Transactions extends Fake with ChangeNotifier implements TransactionProvider {}

class _Connectivity extends Fake with ChangeNotifier implements ConnectivityProvider {}

class _Prices extends Fake with ChangeNotifier implements PriceProvider {
  @override
  int? get bitcoinPriceKrw => null;
  @override
  String getFiatPrice(int satoshiAmount, {FiatCode? fiatCode, bool showCurrencySymbol = true}) => '';
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.sats;
  @override
  String get language => 'ko';
  @override
  UtxoOrder get utxoSortOrder => UtxoOrder.byAmountDesc;
  @override
  UtxoTierTheme get utxoTierTheme => UtxoTierThemes.pastelWallet;
}

class _Nodes extends Fake with ChangeNotifier implements NodeProvider {
  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int walletId) => const Stream.empty();
}

void main() {
  late TestRealmManager manager;

  setUpAll(() {
    NetworkType.setNetworkType(NetworkType.regtest);
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });
  setUp(() => manager = TestRealmManager());
  tearDown(() => manager.dispose());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('UTXO overview logs /utxo-overview with its segment, again only after a named route above it', (
    tester,
  ) async {
    final analytics = _Analytics();
    final vault = SingleSignatureVault.fromEntropy(Uint8List(16));
    final wallet = SinglesigWalletItem(id: 1, name: 'QA', colorIndex: 0, iconIndex: 0, descriptor: vault.descriptor);
    final tags = UtxoTagProvider(UtxoRepository(manager));
    addTearDown(tags.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AnalyticsService>.value(value: analytics),
          Provider<SendInfoProvider>.value(value: SendInfoProvider()),
          ChangeNotifierProvider<WalletProvider>(create: (_) => _Wallets(wallet)),
          ChangeNotifierProvider<TransactionProvider>(create: (_) => _Transactions()),
          ChangeNotifierProvider<UtxoTagProvider>.value(value: tags),
          ChangeNotifierProvider<ConnectivityProvider>(create: (_) => _Connectivity()),
          ChangeNotifierProvider<PriceProvider>(create: (_) => _Prices()),
          ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
          ChangeNotifierProvider<NodeProvider>(create: (_) => _Nodes()),
        ],
        child: MaterialApp(
          navigatorKey: navigator,
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          // The app's observer and name rule (app.dart): real routes, real screen names.
          navigatorObservers: [
            AnalyticsScreenObserver(
              logScreenView: (name) => analytics.logScreenView(screenName: name),
              nameExtractor: analyticsRouteScreenName,
            ),
          ],
          onGenerateRoute:
              (settings) => MaterialPageRoute<void>(
                settings: settings,
                builder:
                    (_) =>
                        settings.name == AppRouteNames.utxoOverview
                            ? const UtxoOverviewScreen(id: 1)
                            : Scaffold(body: Text(settings.name ?? '')),
              ),
          initialRoute: AppRouteNames.walletDetail,
        ),
      ),
    );
    await settle(tester);
    expect(analytics.screens, [(AppRouteNames.walletDetail, null)]);

    navigator.currentState!.pushNamed(AppRouteNames.utxoOverview);
    await settle(tester);
    expect(analytics.screens.last, (AppRouteNames.utxoOverview, 'overview'), reason: 'first shown: overview tab');
    final overview = tester.element(find.byType(UtxoOverviewScreen));
    final shown = analytics.screens.length;

    Future<void> tapTab(String label) async {
      await tester.tap(find.descendant(of: find.byType(UtxoOverviewScreen), matching: find.text(label)).first);
      await settle(tester);
    }

    await tapTab(t.utxo_overview_screen.list);

    // A named sheet and a named page above the overview, then an unnamed dialog.
    CommonBottomSheets.showBottomSheet<void>(
      context: overview,
      title: 'sheet',
      screenName: AnalyticsScreenNames.utxoOverviewTierThemeSheet,
      child: const SizedBox(height: 120),
    );
    await settle(tester);
    navigator.currentState!.pop();
    await settle(tester);
    navigator.currentState!.pushNamed(AppRouteNames.utxoDetail);
    await settle(tester);
    navigator.currentState!.pop();
    await settle(tester);
    showDialog<void>(context: overview, builder: (_) => const AlertDialog(content: Text('unnamed')));
    await settle(tester);
    navigator.currentState!.pop();
    await settle(tester);

    await tapTab(t.utxo_overview_screen.overview);
    navigator.currentState!.pop(); // leave the overview
    await settle(tester);

    // ignore: avoid_print
    print({'screen_views': analytics.screens});
    expect(analytics.screens.sublist(shown - 1), [
      (AppRouteNames.utxoOverview, 'overview'),
      (AppRouteNames.utxoOverview, 'list'), // _selectPrimaryTab: same name, new segment
      (AnalyticsScreenNames.utxoOverviewTierThemeSheet, null), // observer: named sheet
      (AppRouteNames.utxoOverview, 'list'), // on top again after the sheet
      (AppRouteNames.utxoDetail, null), // observer: named page
      (AppRouteNames.utxoOverview, 'list'), // on top again after the page; nothing after the unnamed dialog
      (AppRouteNames.utxoOverview, 'overview'),
      (AppRouteNames.walletDetail, null),
    ]);
  });
}
