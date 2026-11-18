import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_server_config.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_home_widget.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_home_screen.dart';
import 'package:coconut_wallet/app/router/feature_entry_routes.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../ccos_store_test_fakes.dart';
import 'ark_test_fakes.dart';

void main() {
  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    ArkServerConfig.isConfiguredOverride = true;
  });
  tearDown(() => ArkServerConfig.isConfiguredOverride = null);

  test('the ark listing offers its home widget', () {
    final definition = ArkFeature.listing.homeWidget!.definition();

    expect(definition, isA<ArkWalletHomeWidget>());
    expect(definition.ccosFeatureId, ArkFeature.id);
    expect(definition.supportedSpans, [HomeSpan.small, HomeSpan.wide]);
  });

  Future<void> pump(WidgetTester tester, ArkWalletProvider wallet) async {
    final definition = ArkWalletHomeWidget();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: FakeStorePreferences()),
          ChangeNotifierProvider<ArkWalletProvider>.value(value: wallet),
          ...fakeArkPriceProviders(),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          navigatorObservers: [FeatureEntryRoutes.instance],
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 170,
                height: 170,
                child: Builder(
                  builder:
                      (context) => definition.build(
                        context,
                        HomeItem(
                          id: 'ark',
                          definitionId: definition.id,
                          kind: HomeItemKind.widget,
                          order: 0,
                          span: HomeSpan.small,
                        ),
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('without a wallet it invites to create one', (tester) async {
    await pump(tester, await fakeArkWalletProvider());

    expect(find.text(t.ark_wallet.widget_create), findsOneWidget);
  });

  testWidgets('with a wallet it shows the balance and opens the wallet', (tester) async {
    final wallet = await fakeArkWalletProvider();
    await wallet.restore(Uint8List.fromList(utf8.encode('${'abandon ' * 11}about')));
    await pump(tester, wallet);

    expect(find.textContaining(BitcoinUnit.sats.displayBitcoinAmount(0)), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('ark-wallet-home-widget')));
    await tester.pumpAndSettle();
    expect(find.byType(ArkWalletHomeScreen), findsOneWidget);
    Finder icon(String path) => find.byWidgetPredicate(
      (widget) =>
          widget is SvgPicture &&
          widget.bytesLoader is SvgAssetLoader &&
          (widget.bytesLoader as SvgAssetLoader).assetName == path,
    );
    expect(icon(CommonActionIconPath.close), findsWidgets);
    expect(icon(CommonNavigationIconPath.arrowBack), findsNothing);
  });
}
