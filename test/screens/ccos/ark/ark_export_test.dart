import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_export_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../ccos/ccos_store_test_fakes.dart';
import '../../../ccos/features/ark/ark_test_fakes.dart';

const _mine = 'bcrt1qw508d6qejxtdg4y5r3zarvary0c5xw7kygt080';
const _other = 'bcrt1q7kcrvjzszlxme7fgs2euvv6lkgf99jdu8zjnus';

void main() {
  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    NetworkType.setNetworkType(NetworkType.regtest);
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend =
        FakeArkBackend()
          ..currentBalance = const ArkBalance(
            spendable: 100000,
            pendingInRound: 0,
            pendingBoard: 0,
            pendingExit: 0,
            pendingLightningSend: 0,
            claimableLightningReceive: 0,
          );
    final wallet = await fakeArkWalletProvider(backend: backend);
    await wallet.restore(Uint8List.fromList(utf8.encode('${'abandon ' * 11}about')));
    final wallets =
        FakeArkWallets()
          ..wallets = [FakeArkWalletItem(1, '비상금')]
          ..receiveAddresses[1] = WalletAddress(_mine, "m/84'/1'/0'/0/3", 3, false, false, 0, 0, 0);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: FakeStorePreferences()),
          ChangeNotifierProvider<ArkWalletProvider>.value(value: wallet),
          ...fakeArkPriceProviders(wallets: wallets),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: const ArkExportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field() =>
      find.descendant(of: find.byKey(const Key('ark-export-address')), matching: find.byType(EditableText));

  testWidgets('focusing the address shows my addresses, and picking one fills it in with its wallet', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('ark-export-my-addresses')), findsNothing);

    await tester.tap(field());
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ark-export-my-addresses')), findsOneWidget);

    await tester.tap(find.byKey(const Key('ark-export-my-address-1')));
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(field()).controller.text, _mine);
    expect(find.byKey(const Key('ark-export-my-addresses')), findsNothing);
    expect(find.textContaining('비상금'), findsOneWidget);
  });

  testWidgets('an address typed in works without picking a wallet', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('ark-export-switch')), findsNothing);

    await tester.enterText(field(), _other);
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    expect(find.text(t.errors.address_error.invalid), findsNothing);
    expect(find.textContaining('비상금'), findsNothing);
  });
}
