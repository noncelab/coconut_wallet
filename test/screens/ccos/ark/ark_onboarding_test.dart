import 'dart:async';

import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_home_screen.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../ccos/ccos_store_test_fakes.dart';
import '../../../ccos/features/ark/ark_test_fakes.dart';

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  Future<void> pump(WidgetTester tester, Widget home, {ArkWalletProvider? wallet}) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: FakeStorePreferences()),
          if (wallet != null) ChangeNotifierProvider<ArkWalletProvider>.value(value: wallet),
          ...fakeArkPriceProviders(),
        ],
        child: MaterialApp(theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark), home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder text(String value) => find.text(TextUtils.preventLineBreakInsideWords(value), skipOffstage: false);

  testWidgets('without a wallet the start view offers two ways', (tester) async {
    final wallet = await fakeArkWalletProvider();
    await pump(tester, const ArkWalletHomeScreen(), wallet: wallet);

    expect(find.text(t.ark_wallet.create_new), findsOneWidget);
    expect(find.text(t.ark_wallet.restore), findsOneWidget);
  });

  testWidgets('creating asks first, shows real progress, then opens the wallet', (tester) async {
    final backend = FakeArkBackend()..createGate = Completer<void>();
    final wallet = await fakeArkWalletProvider(backend: backend);
    await pump(tester, const ArkWalletHomeScreen(), wallet: wallet);

    await tester.tap(find.text(t.ark_wallet.create_new));
    await tester.pumpAndSettle();
    expect(text(t.ark_wallet.consent_same_words), findsOneWidget);

    await tester.tap(find.text(t.ark_wallet.consent_confirm));
    await tester.pump();
    await tester.pump();
    expect(find.text(t.ark_wallet.step_connecting), findsOneWidget);

    backend.createGate!.complete();
    await tester.pumpAndSettle();
    expect(wallet.hasWallet, isTrue);
    expect(find.text(t.ark_wallet.create_new), findsNothing);
  });

  testWidgets('closing the consent sheet creates nothing', (tester) async {
    final wallet = await fakeArkWalletProvider();
    await pump(tester, const ArkWalletHomeScreen(), wallet: wallet);

    await tester.tap(find.text(t.ark_wallet.create_new));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    expect(wallet.hasWallet, isFalse);
    expect(find.text(t.ark_wallet.create_new), findsOneWidget);
  });
}
