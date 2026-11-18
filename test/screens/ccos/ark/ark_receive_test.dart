import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_receive_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../ccos/ccos_store_test_fakes.dart';
import '../../../ccos/features/ark/ark_test_fakes.dart';

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  Future<ArkWalletProvider> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wallet = await fakeArkWalletProvider();
    await wallet.createNew();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: FakeStorePreferences()),
          ChangeNotifierProvider<ArkWalletProvider>.value(value: wallet),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: const ArkReceiveScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return wallet;
  }

  testWidgets('it opens on the Ark address', (tester) async {
    await pump(tester);

    expect(find.byKey(const ValueKey('ark-receive-qr-arkAddress')), findsOneWidget);
    expect(find.text(t.ark_wallet.format_ark_caption), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('without an amount the invoice ways are dimmed', (tester) async {
    await pump(tester);

    await tester.tap(find.byKey(const Key('ark-receive-ways')));
    await tester.pumpAndSettle();

    expect(find.text(t.ark_wallet.format_lightning_needs_amount), findsNWidgets(2));
    expect(find.byKey(const ValueKey('ark-receive-way-arkAddress')), findsOneWidget);
  });
}
