import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/node/wallet_update_info.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/model/wallet/taproot_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/transaction_record.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/node_provider/node_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/taproot_setup_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/taproot_spend_type_bottom_sheet.dart';
import 'package:coconut_wallet/screens/wallet_detail/wallet_info/wallet_info_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/features/wallet/taproot/taproot_spend_type_selector.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mock/wallet_mock.dart';

class _WalletProvider extends ChangeNotifier implements WalletProvider {
  _WalletProvider(this.wallet);

  TaprootWalletItem wallet;
  final updatedSpendTypes = <TaprootSpendType>[];

  @override
  List<WalletItemBase> get walletItemList => [wallet];
  @override
  WalletItemBase getWalletById(int id) => wallet;
  @override
  int getWatchedAddressCount(int id) => 0;
  @override
  List<TransactionRecord> getTransactionRecordList(int walletId) => [];
  @override
  Future<void> updateTaprootSpendType(int walletId, TaprootSpendType spendType) async {
    updatedSpendTypes.add(spendType);
    wallet = TaprootWalletItem(
      id: wallet.id,
      name: wallet.name,
      colorIndex: wallet.colorIndex,
      iconIndex: wallet.iconIndex,
      descriptor: wallet.descriptor,
      keyPathSeedInfos: wallet.keyPathSeedInfos,
      scriptPathSeedInfos: wallet.scriptPathSeedInfos,
      userSelectedSpendType: spendType,
    );
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AuthProvider extends Fake implements AuthProvider {}

class _NodeProvider extends Fake implements NodeProvider {
  @override
  Stream<WalletUpdateInfo> getWalletStateStream(int id) => const Stream.empty();
}

class _PreferenceProvider extends Fake implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
}

class _UtxoTagProvider extends Fake implements UtxoTagProvider {
  @override
  List<UtxoTag> getUtxoTagList(int id) => [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    SharedPreferences.setMockInitialValues({});
    await SharedPrefsRepository().init();
  });

  Future<_WalletProvider> pumpInfo(WidgetTester tester, TaprootWalletItem wallet) async {
    final walletProvider = _WalletProvider(wallet);
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          InheritedProvider<AuthProvider>.value(value: _AuthProvider()),
          InheritedProvider<WalletProvider>.value(value: walletProvider),
          InheritedProvider<NodeProvider>.value(value: _NodeProvider()),
          InheritedProvider<PreferenceProvider>.value(value: _PreferenceProvider()),
          InheritedProvider<UtxoTagProvider>.value(value: _UtxoTagProvider()),
          Provider<AnalyticsService>.value(value: AnalyticsService(null, true)),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          scrollBehavior: const CupertinoScrollBehavior(),
          home: const LoaderOverlay(child: WalletInfoScreen(id: 1, walletType: WalletType.taproot)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return walletProvider;
  }

  testWidgets('a taproot wallet lists the descriptor with the details and groups the rest under inheritance setup', (
    tester,
  ) async {
    await pumpInfo(tester, WalletMock.createTaprootWalletItem());

    expect(find.text(t.wallet_signer_section.view_details), findsNothing);
    final descriptor = tester.getTopLeft(find.text(t.wallet_info_screen.descriptor));
    final addresses = tester.getTopLeft(find.text(t.wallet_info_screen.all_addresses));
    final header = tester.getTopLeft(find.text(t.wallet_info_screen.inheritance_setup));
    final signing = tester.getTopLeft(find.text(t.wallet_signer_section.title));
    final participants = tester.getTopLeft(find.text(t.wallet_info_screen.taproot_participants));
    final backup = tester.getTopLeft(find.text(t.wallet_info_screen.backup_data));
    final rows = [descriptor.dy, addresses.dy, header.dy, signing.dy, participants.dy, backup.dy];
    expect(rows, orderedEquals([...rows]..sort()));
    expect(descriptor.dx, addresses.dx);
    expect(signing.dx, greaterThan(header.dx));
    expect(backup.dx, signing.dx);
    expect(find.text(t.wallet_signer_section.segmented_control.parent_key), findsOneWidget);
    expect(find.text(t.wallet_info_screen.taproot_participant_count(parent: 1, child: 1)), findsOneWidget);
  });

  testWidgets('the signing method sheet switches the default path and the row follows', (tester) async {
    final walletProvider = await pumpInfo(tester, WalletMock.createTaprootWalletItem());

    await tester.tap(find.text(t.wallet_signer_section.title));
    await tester.pumpAndSettle();
    expect(find.byType(TaprootSpendTypeBottomSheet), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(TaprootSpendTypeSegmentedControl),
        matching: find.text(t.wallet_signer_section.segmented_control.child_key),
      ),
    );
    await tester.pumpAndSettle();
    expect(walletProvider.updatedSpendTypes, [TaprootSpendType.scriptPath]);

    Navigator.of(tester.element(find.byType(TaprootSpendTypeBottomSheet))).pop();
    await tester.pumpAndSettle();
    expect(find.text(t.wallet_signer_section.segmented_control.child_key), findsOneWidget);
  });

  testWidgets('a wallet with only one path shows its signing method without opening a sheet', (tester) async {
    await pumpInfo(tester, WalletMock.createTaprootWalletItem(hasKeyPathSeedInfo: false));

    expect(find.text(t.wallet_signer_section.segmented_control.child_key), findsOneWidget);
    await tester.tap(find.text(t.wallet_signer_section.title));
    await tester.pumpAndSettle();
    expect(find.byType(TaprootSpendTypeBottomSheet), findsNothing);
  });

  testWidgets('the participants row opens the inheritance setup screen', (tester) async {
    await pumpInfo(tester, WalletMock.createTaprootWalletItem());

    await tester.tap(find.text(t.wallet_info_screen.taproot_participants));
    await tester.pumpAndSettle();
    expect(find.byType(TaprootSetupScreen), findsOneWidget);
  });
}
