import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_entrance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../ccos/ccos_store_test_fakes.dart';
import '../../../ccos/features/ark/ark_test_fakes.dart';

class _Auth extends Fake implements AuthProvider {
  @override
  bool get isAuthEnabled => false;
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  Future<void> open(WidgetTester tester, ArkWalletProvider wallet) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: FakeStorePreferences()),
          ChangeNotifierProvider<ArkWalletProvider>.value(value: wallet),
          InheritedProvider<AuthProvider>.value(value: _Auth()),
          ...fakeArkPriceProviders(),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: Builder(
            builder:
                (context) => TextButton(onPressed: () => ArkFeature.openWallet(context), child: const Text('open')),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  final splash = find.byKey(const Key('ark-splash'));

  testWidgets('without a wallet, the splash image settles onto the start screen image', (tester) async {
    await open(tester, await fakeArkWalletProvider(backend: FakeArkBackend()));

    expect(splash, findsOneWidget);
    expect(find.byKey(const Key('ark-splash-image')), findsOneWidget);
    expect(tester.widget<Opacity>(find.byKey(const Key('ark-welcome-image'))).opacity, 0);

    await tester.pump(const Duration(milliseconds: 450));
    final moving = tester.getRect(find.byKey(const Key('ark-splash-image')));
    final target = tester.getRect(find.byKey(const Key('ark-welcome-image')));
    expect(moving, isNot(target));

    await tester.pumpAndSettle();
    expect(splash, findsNothing);
    expect(tester.widget<Opacity>(find.byKey(const Key('ark-welcome-image'))).opacity, 1);
    expect(find.text(t.ark_wallet.create_new), findsOneWidget);
  });

  testWidgets('with a wallet, the splash fades away into the wallet home', (tester) async {
    final wallet = await fakeArkWalletProvider(backend: FakeArkBackend());
    await wallet.restore(Uint8List.fromList(utf8.encode('${'abandon ' * 11}about')));
    await open(tester, wallet);

    expect(splash, findsOneWidget);
    await tester.pumpAndSettle();
    expect(splash, findsNothing);
    expect(find.byKey(const Key('ark-wallet-receive')), findsOneWidget);
  });

  testWidgets('the wallet opens with a fade, not a slide', (tester) async {
    await open(tester, await fakeArkWalletProvider(backend: FakeArkBackend()));

    expect(find.byType(ArkWalletEntrance), findsOneWidget);
    expect(tester.getTopLeft(find.byType(ArkWalletEntrance)).dx, 0);
  });
}
