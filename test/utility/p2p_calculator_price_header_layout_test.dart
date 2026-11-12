import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/tools/p2p_calculator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'p2p_calculator_test.dart'
    show FakePreferenceProvider, FakeConnectivityProvider, FakePriceProvider, FakeWalletProvider;

void main() {
  setUpAll(() async {
    final font =
        FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.ttf'));
    await font.load();
    final numberFont = FontLoader('SpaceGrotesk')..addFont(rootBundle.load('assets/fonts/SpaceGrotesk-Regular.ttf'));
    await numberFont.load();
  });

  const longPrices = {FiatCode.KRW: 140000000, FiatCode.VND: 3000000000, FiatCode.IDR: 1600000000};

  for (final entry in longPrices.entries) {
    testWidgets('1 BTC price of ${entry.key.code} fits the price header at 320 width', (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PreferenceProvider>.value(value: FakePreferenceProvider(selectedFiat: entry.key)),
            ChangeNotifierProvider<ConnectivityProvider>.value(value: FakeConnectivityProvider()),
            ChangeNotifierProvider<PriceProvider>.value(value: FakePriceProvider(defaultPrice: entry.value)),
            ChangeNotifierProvider<WalletProvider>.value(value: FakeWalletProvider()),
          ],
          child: MaterialApp(theme: buildCoconutThemeData(), home: const P2PCalculatorScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(entry.key.name), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
