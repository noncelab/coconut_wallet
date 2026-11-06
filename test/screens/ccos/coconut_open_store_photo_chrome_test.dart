import 'dart:io';

import 'package:coconut_wallet/ccos/ccos_feature_registry.dart';
import 'package:coconut_wallet/ccos/ccos_feature_runtime.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_first_pow_scene.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/utils/system_chrome_util.dart';
import 'package:coconut_wallet/widgets/common/side_safe_area.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  _Preferences(this.themeVariant);

  @override
  final CoconutThemeVariant themeVariant;

  @override
  CcosFeatureAvailability getCcosFeatureAvailability(String featureId) => CcosFeatureAvailability(
    featureId: featureId,
    isVisible: false,
    isActivated: false,
    isEntitled: false,
    isAvailable: false,
  );
}

void main() {
  setUpAll(() async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    for (final family in ['Pretendard', 'SpaceGrotesk']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Bold']) {
        loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$family-$weight.ttf').readAsBytesSync())));
      }
      await loader.load();
    }
  });
  for (final variant in CoconutThemeVariant.values) {
    for (final (name, size, top, side) in [
      ('iPhone 17', const Size(402, 874), 62.0, 0.0),
      ('Duo closed', const Size(466, 678), 0.0, 84.0),
      ('Duo open', const Size(951, 669), 0.0, 84.0),
    ]) {
      testWidgets(
        'photo pages use dark status icons and pop restores $name ${variant.name}',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          final padding = FakeViewPadding(top: top, right: side, bottom: 34);
          tester.view.padding = padding;
          tester.view.viewPadding = padding;
          addTearDown(tester.view.reset);
          final preferences = _Preferences(variant);
          addTearDown(preferences.dispose);
          final theme = buildCoconutThemeData(variant: variant).copyWith(platform: defaultTargetPlatform);
          final rootStyle = buildSystemBarStyle(
            backgroundColor: theme.scaffoldBackgroundColor,
            brightness: theme.brightness,
          );
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
                Provider<AnalyticsService>.value(value: AnalyticsService(null, true)),
              ],
              child: MaterialApp(
                theme: theme,
                builder:
                    (context, child) =>
                        AnnotatedRegion<SystemUiOverlayStyle>(value: rootStyle, child: SideSafeArea(child: child!)),
                home: Scaffold(
                  body: FirstPowSceneBody(
                    animation: const AlwaysStoppedAnimation(1),
                    sceneDurationMs: 20000,
                    listing: CcosFeatureRegistrySource.featuredListing,
                    isAdded: false,
                    isApplied: false,
                    isCurrentScene: false,
                    onAdd: () {},
                    onRemove: () {},
                  ),
                ),
              ),
            ),
          );
          await tester.pump();
          expect(SystemChrome.latestStyle!.statusBarBrightness, theme.brightness);
          final photo = find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName == 'assets/images/ccos/feature.png',
          );
          await tester.ensureVisible(photo);
          await tester.tap(photo.hitTestable());
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 700));
          await tester.pump(const Duration(seconds: 5));
          for (final label in ['FEATURE', 'CREATOR', 'DELIVERY']) {
            if (label != 'FEATURE') {
              await tester.tap(find.text(label).hitTestable());
              await tester.pump();
              await tester.pump(const Duration(seconds: 1));
              await tester.pump(const Duration(milliseconds: 700));
              await tester.pump(const Duration(seconds: 5));
            }
            expect(SystemChrome.latestStyle!.statusBarBrightness, Brightness.light, reason: label);
            expect(SystemChrome.latestStyle!.statusBarIconBrightness, Brightness.dark, reason: label);
            expect(SystemChrome.latestStyle!.statusBarColor, rootStyle.statusBarColor);
            if (defaultTargetPlatform == TargetPlatform.android) {
              expect(SystemChrome.latestStyle!.systemNavigationBarColor, rootStyle.systemNavigationBarColor);
              expect(
                SystemChrome.latestStyle!.systemNavigationBarDividerColor,
                rootStyle.systemNavigationBarDividerColor,
              );
              expect(
                SystemChrome.latestStyle!.systemNavigationBarIconBrightness,
                rootStyle.systemNavigationBarIconBrightness,
              );
            }
            expect(tester.takeException(), isNull);
          }
          await tester.tap(find.byIcon(Icons.arrow_back_rounded).hitTestable());
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(SystemChrome.latestStyle!.statusBarBrightness, rootStyle.statusBarBrightness);
          expect(SystemChrome.latestStyle!.statusBarIconBrightness, rootStyle.statusBarIconBrightness);
          expect(tester.takeException(), isNull);
        },
        variant: const TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}),
      );
    }
  }
}
