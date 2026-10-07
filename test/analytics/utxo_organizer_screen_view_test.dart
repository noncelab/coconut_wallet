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
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/wallet/singlesig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_organizer_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loader_overlay/loader_overlay.dart';
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
  WalletAddress getReceiveAddress(int walletId) => _address(0, false);
  @override
  WalletAddress getChangeAddress(int walletId) => _address(1, true);
  @override
  List<UtxoState> getUtxoList(int walletId) => const [];
  @override
  List<UtxoState> getUtxoListByStatus(int walletId, UtxoStatus utxoStatus) => const [];
}

class _Addresses extends Fake implements AddressRepository {
  _Addresses(this.wallets);
  final _Wallets wallets;
  @override
  WalletAddress getReceiveAddress(int walletId, {WalletBase? wallet}) => wallets.getReceiveAddress(walletId);
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.sats;
  @override
  String get language => 'ko';
  @override
  List<int> get walletOrder => const [1];
  @override
  UtxoOrder get utxoSortOrder => UtxoOrder.byAmountDesc;
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

  testWidgets('UTXO organizer logs /utxo-organizer with its segment, again only after a named route above it', (
    tester,
  ) async {
    final analytics = _Analytics();
    final vault = SingleSignatureVault.fromEntropy(Uint8List(16));
    final wallet = SinglesigWalletItem(id: 1, name: 'QA', colorIndex: 0, iconIndex: 0, descriptor: vault.descriptor);
    final wallets = _Wallets(wallet, vault);
    final utxos = UtxoRepository(manager);
    final tags = UtxoTagProvider(utxos);
    addTearDown(tags.dispose);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AnalyticsService>.value(value: analytics),
          Provider<SendInfoProvider>.value(value: SendInfoProvider()),
          ChangeNotifierProvider<WalletProvider>.value(value: wallets),
          ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
          ChangeNotifierProvider<UtxoTagProvider>.value(value: tags),
          Provider<UtxoRepository>.value(value: utxos),
          Provider<AddressRepository>.value(value: _Addresses(wallets)),
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
                    (_) => LoaderOverlay(
                      child:
                          settings.name == AppRouteNames.utxoOrganizer
                              ? const UtxoOrganizerScreen(id: 1)
                              : Scaffold(body: Text(settings.name ?? '')),
                    ),
              ),
          initialRoute: AppRouteNames.walletDetail,
        ),
      ),
    );
    await settle(tester);
    expect(analytics.screens, [(AppRouteNames.walletDetail, null)]);

    navigator.currentState!.pushNamed(AppRouteNames.utxoOrganizer);
    await settle(tester);
    expect(analytics.screens.last, (AppRouteNames.utxoOrganizer, 'merge'), reason: 'first shown: merge segment');
    final organizer = tester.element(find.byType(UtxoOrganizerScreen));
    final shown = analytics.screens.length;

    Future<void> tapSegment(String label) async {
      await tester.tap(find.descendant(of: find.byType(UtxoOrganizerScreen), matching: find.text(label)).first);
      await settle(tester);
    }

    await tapSegment(t.utxo_organizer_screen.split);
    await tapSegment(t.utxo_organizer_screen.merge);

    // A named sheet and a named page above the organizer, then an unnamed dialog.
    CommonBottomSheets.showBottomSheet<void>(
      context: organizer,
      title: 'sheet',
      screenName: AnalyticsScreenNames.mergeUtxosSelectMethodSheet,
      child: const SizedBox(height: 120),
    );
    await settle(tester);
    navigator.currentState!.pop();
    await settle(tester);
    navigator.currentState!.pushNamed(AppRouteNames.sendConfirm);
    await settle(tester);
    navigator.currentState!.pop();
    await settle(tester);
    showDialog<void>(context: organizer, builder: (_) => const AlertDialog(content: Text('unnamed')));
    await settle(tester);
    navigator.currentState!.pop();
    await settle(tester);

    navigator.currentState!.pop(); // leave the organizer
    await settle(tester);

    // ignore: avoid_print
    print({'screen_views': analytics.screens});
    expect(analytics.screens.sublist(shown - 1), [
      (AppRouteNames.utxoOrganizer, 'merge'),
      (AppRouteNames.utxoOrganizer, 'split'), // segment change: same name, new segment
      (AppRouteNames.utxoOrganizer, 'merge'),
      (AnalyticsScreenNames.mergeUtxosSelectMethodSheet, null), // observer: named sheet
      (AppRouteNames.utxoOrganizer, 'merge'), // on top again after the sheet
      (AppRouteNames.sendConfirm, null), // observer: named page
      (AppRouteNames.utxoOrganizer, 'merge'), // on top again after the page; nothing after the unnamed dialog
      (AppRouteNames.walletDetail, null),
    ]);
    final names = analytics.screens.map((view) => view.$1);
    expect(names, isNot(contains(AppRouteNames.mergeUtxos)));
    expect(names, isNot(contains(AppRouteNames.splitUtxo)));
  });
}
