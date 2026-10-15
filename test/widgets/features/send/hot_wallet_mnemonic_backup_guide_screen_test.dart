import 'package:coconut_wallet/constants/lottie_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/home/wallet_add/hot_wallet/hot_wallet_mnemonic_backup_guide_screen.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/ui/coconut/coconut_overlays.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

class _Analytics extends Fake implements AnalyticsService {}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  String get language => 'ko';
}

void main() {
  testWidgets('created intro proceeds directly to the backup preparation guide', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AnalyticsService>.value(value: _Analytics()),
          ChangeNotifierProvider<PreferenceProvider>(create: (_) => _Preferences()),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          initialRoute: '/guide',
          routes: {
            AppRouteNames.walletDetail: (_) => const Scaffold(body: Text('wallet detail')),
            '/guide': (_) => const HotWalletMnemonicBackupGuideScreen(walletId: 1, enterPassphraseWhenSigning: false),
          },
          home: const Scaffold(),
        ),
      ),
    );
    final composition = await tester.runAsync(() => AssetLottie(StateLottiePath.checkComplete).load());
    tester.widget<LottieBuilder>(find.byType(LottieBuilder)).onLoaded!(composition!);
    for (var i = 0; i < 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final strings = t.wallet_home_screen.hot_wallet_setup;
    expect(find.text(strings.backup_preparation_title), findsOneWidget);
    expect(find.text('지갑을 복구할 수 있도록\n니모닉 문구를 백업해 주세요'), findsNothing);
    expect(tester.widget<FixedBottomButton>(find.byType(FixedBottomButton)).text, strings.backup_start);
    expect(find.text(strings.skip), findsOneWidget);
    await tester.tap(find.text(strings.skip));
    await tester.pumpAndSettle();
    expect(find.byType(CoconutPopup), findsOneWidget);
    expect(find.text(strings.backup_later_description), findsOneWidget);
    expect(find.text('wallet detail'), findsNothing);
    Navigator.of(tester.element(find.byType(CoconutPopup))).pop();
    await tester.pumpAndSettle();
    expect(find.text('wallet detail'), findsNothing);
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    await tester.tap(find.byWidget(appBar.leading!));
    await tester.pumpAndSettle();
    expect(find.byType(CoconutPopup), findsOneWidget);
    await tester.tap(find.text(t.OK));
    await tester.pumpAndSettle();
    expect(find.text('wallet detail'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('backup entry shows the writing guide with skip above start', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    await tester.pumpWidget(
      Provider<AnalyticsService>.value(
        value: _Analytics(),
        child: MaterialApp(
          theme: buildCoconutThemeData(),
          home: const HotWalletMnemonicBackupGuideScreen(
            walletId: 1,
            enterPassphraseWhenSigning: false,
            showWalletCreatedIntro: false,
          ),
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final strings = t.wallet_home_screen.hot_wallet_setup;
    expect(find.text(strings.backup_preparation_title), findsOneWidget);
    expect(find.text(strings.backup_preparation_description), findsOneWidget);
    expect(find.text(strings.wallet_created_title), findsNothing);
    expect(find.byType(FixedBottomButton), findsOneWidget);
    expect(tester.widget<FixedBottomButton>(find.byType(FixedBottomButton)).text, strings.backup_start);
    expect(
      tester.getCenter(find.text(strings.skip)).dy,
      lessThan(tester.getCenter(find.text(strings.backup_start)).dy),
    );
    expect(
      tester.widget<LottieBuilder>(find.byType(LottieBuilder)).lottie,
      isA<AssetLottie>().having((asset) => asset.assetName, 'asset', ActionLottiePath.noteWriting),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
