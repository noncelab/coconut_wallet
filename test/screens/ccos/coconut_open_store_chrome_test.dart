import 'package:coconut_wallet/ccos/ccos_feature_runtime.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_navigation.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_intro_screen.dart';
import 'package:coconut_wallet/utils/system_chrome_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  for (final variant in CoconutThemeVariant.values) {
    testWidgets(
      'CCOS loading/story chrome follows pale canvas and pop restores $variant',
      (tester) async {
        tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
        addTearDown(tester.view.resetPadding);
        final preferences = _Preferences(variant);
        addTearDown(preferences.dispose);
        final navigator = GlobalKey<NavigatorState>();
        final theme = buildCoconutThemeData(variant: variant);
        final rootStyle = buildSystemBarStyle(
          backgroundColor: theme.scaffoldBackgroundColor,
          brightness: theme.brightness,
        );
        await tester.pumpWidget(
          ChangeNotifierProvider<PreferenceProvider>.value(
            value: preferences,
            child: MaterialApp(
              navigatorKey: navigator,
              theme: theme,
              builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(value: rootStyle, child: child!),
              home: Builder(
                builder:
                    (context) => Scaffold(
                      body: TextButton(
                        onPressed: () => openCoconutOpenStoreIntroScreen(context),
                        child: const Text('Open Store'),
                      ),
                    ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        void expectChrome(Brightness brightness, Color background) {
          final style = SystemChrome.latestStyle!;
          expect(style.statusBarBrightness, brightness);
          expect(style.statusBarIconBrightness, brightness == Brightness.light ? Brightness.dark : Brightness.light);
          expect(style.statusBarColor, Colors.transparent);
          if (Theme.of(tester.element(find.byType(Scaffold).last)).platform == TargetPlatform.android) {
            expect(style.systemNavigationBarColor, background);
            expect(
              style.systemNavigationBarIconBrightness,
              brightness == Brightness.light ? Brightness.dark : Brightness.light,
            );
          }
        }

        expectChrome(theme.brightness, theme.scaffoldBackgroundColor);
        await tester.tap(find.text('Open Store'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expectChrome(Brightness.light, const Color(0xFFF9F8F6));
        await tester.pump(const Duration(seconds: 6));
        await tester.pump(const Duration(seconds: 2));
        expectChrome(Brightness.light, const Color(0xFFCDD4D7));
        final regions = tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.descendant(
            of: find.byType(CoconutOpenStoreIntroScreen),
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          ),
        );
        expect(regions.length, greaterThanOrEqualTo(2));
        for (final region in regions) {
          expect(region.value.statusBarBrightness, Brightness.light);
          expect(region.value.statusBarIconBrightness, Brightness.dark);
        }
        expect(
          tester.layers.whereType<AnnotatedRegionLayer<SystemUiOverlayStyle>>().any(
            (layer) =>
                layer.value.systemNavigationBarColor == const Color(0xFFCDD4D7) &&
                layer.value.statusBarBrightness == Brightness.light,
          ),
          isTrue,
        );
        navigator.currentState!.pop();
        await tester.pumpAndSettle();
        expect(find.byType(CoconutOpenStoreIntroScreen), findsNothing);
        expectChrome(theme.brightness, theme.scaffoldBackgroundColor);
        expect(tester.takeException(), isNull);
      },
      variant: const TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.android}),
    );
  }
}
