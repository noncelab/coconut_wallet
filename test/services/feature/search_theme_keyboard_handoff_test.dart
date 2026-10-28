import 'dart:async';

import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/ccos_feature_runtime.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_navigation_target.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/home/all_features_screen.dart';
import 'package:coconut_wallet/screens/settings/app_settings/app_settings_screen.dart';
import 'package:coconut_wallet/screens/settings/theme_bottom_sheet.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/feature/feature_launcher.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/widgets/features/home/home_cube_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  CoconutThemeVariant get themeVariant => CoconutThemeVariant.dark;

  @override
  bool get shouldShowOpenStoreIntroCard => false;

  @override
  CcosFeatureAvailability getCcosFeatureAvailability(String featureId) => CcosFeatureAvailability(
    featureId: featureId,
    isVisible: false,
    isActivated: false,
    isEntitled: false,
    isAvailable: false,
  );
}

class _Routes extends NavigatorObserver {
  final double Function() keyboardInset;
  final List<double> themePushInsets = [];
  final List<ModalRoute<dynamic>> themeRoutes = [];

  _Routes(this.keyboardInset);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name != AnalyticsScreenNames.appSettingsThemeSheet) return;
    themePushInsets.add(keyboardInset());
    themeRoutes.add(route as ModalRoute<dynamic>);
  }
}

class _Host {
  final _Routes routes;
  final _Preferences preferences;
  final navigator = GlobalKey<NavigatorState>();
  final pager = GlobalKey<HomeCubePagerState>();
  late VoidCallback showHome;

  _Host(this.routes, this.preferences);
}

final _search = find.byKey(const Key('all-features-search'));
final _themeResult = find.byKey(const ValueKey('all-features-item-app_settings'));

EditableText _input(WidgetTester tester) =>
    tester.widget<EditableText>(find.descendant(of: _search, matching: find.byType(EditableText)));

Future<_Host> _pumpHost(WidgetTester tester, {CoconutThemeVariant? highlight}) async {
  tester.view.physicalSize = const Size(414, 896);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final preferences = _Preferences();
  addTearDown(preferences.dispose);
  final host = _Host(_Routes(() => tester.view.viewInsets.bottom), preferences);
  final registry = FeatureRegistry.builtin();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
        Provider<AnalyticsService>.value(value: AnalyticsService(null, true)),
      ],
      child: MaterialApp(
        navigatorKey: host.navigator,
        theme: buildCoconutThemeData(),
        navigatorObservers: [host.routes],
        home: Scaffold(
          body: HomeCubePager(
            key: host.pager,
            home: const ColoredBox(color: Colors.black, child: SizedBox.expand(child: Text('Home'))),
            allFeaturesBuilder: (showHome) {
              host.showHome = showHome;
              return AllFeaturesScreen(
                registry: FeatureRegistry([
                  registry.byId(FeatureIds.appSettings)!,
                  registry.byId('${FeatureIds.appSettings}.theme')!,
                ]),
                onLaunch:
                    (context, item) => unawaited(
                      highlight != null
                          ? AppSettingsScreen.open(context, AppSettingsTarget.theme, highlightTheme: highlight)
                          : FeatureLauncher(wallets: () => [], pickWallet: (_, __) async => null).launch(context, item),
                    ),
              );
            },
          ),
        ),
      ),
    ),
  );
  host.pager.currentState!.showAllFeatures();
  await tester.pumpAndSettle();
  await tester.enterText(_search, '테마');
  await tester.pump();
  return host;
}

Future<void> _beginWithKeyboard(WidgetTester tester) async {
  tester.view.viewInsets = const FakeViewPadding(bottom: 320);
  await tester.pump();
  expect(tester.testTextInput.isVisible, isTrue);
  await tester.tap(_themeResult);
  await tester.pump();
}

Future<void> _closeKeyboard(WidgetTester tester) async {
  tester.view.viewInsets = FakeViewPadding.zero;
  await tester.pump();
  await tester.pump();
}

Future<List<double>> _finishThemeEntrance(WidgetTester tester, _Host host) async {
  final route = host.routes.themeRoutes.single;
  final tops = <double>[];
  for (var frame = 0; frame < 60 && route.animation!.status != AnimationStatus.completed; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    tops.add(tester.getTopLeft(find.byType(ThemeBottomSheet)).dy);
  }
  expect(route.animation!.status, AnimationStatus.completed);
  return tops;
}

Future<void> _dismissTheme(WidgetTester tester, _Host host) async {
  host.navigator.currentState!.pop();
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  testWidgets(
    'theme search closes the IME before an animated sheet entrance with no position reversal',
    (tester) async {
      final host = await _pumpHost(tester);
      await _beginWithKeyboard(tester);
      expect(host.routes.themePushInsets, isEmpty);
      for (final inset in [240.0, 80.0]) {
        tester.view.viewInsets = FakeViewPadding(bottom: inset);
        await tester.pump(const Duration(milliseconds: 16));
        expect(host.routes.themePushInsets, isEmpty);
      }
      await _closeKeyboard(tester);
      expect(host.routes.themePushInsets, [0]);
      expect(host.routes.themeRoutes.single.transitionDuration, greaterThan(Duration.zero));
      final tops = await _finishThemeEntrance(tester, host);
      expect(tops.length, greaterThan(2));
      for (var index = 1; index < tops.length; index++) {
        expect(tops[index], lessThanOrEqualTo(tops[index - 1] + 0.5));
      }
      expect(host.preferences.themeVariant, CoconutThemeVariant.dark);
      expect(tester.takeException(), isNull);
      await _dismissTheme(tester, host);
      expect(_input(tester).controller.text, '테마');
      expect(_input(tester).focusNode.hasFocus, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
    },
    variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS}),
  );

  testWidgets('a closed keyboard starts the sheet without a timed wait', (tester) async {
    final host = await _pumpHost(tester);
    await tester.tap(_themeResult);
    await tester.pump();
    expect(host.routes.themePushInsets, [0]);
    await _finishThemeEntrance(tester, host);
    await _dismissTheme(tester, host);
  });

  testWidgets('repeated result taps while the keyboard closes open only one sheet', (tester) async {
    final host = await _pumpHost(tester);
    await _beginWithKeyboard(tester);
    await tester.tap(_themeResult);
    await tester.pump();
    await _closeKeyboard(tester);
    expect(host.routes.themePushInsets, [0]);
    await _finishThemeEntrance(tester, host);
    await _dismissTheme(tester, host);
    await tester.tap(_themeResult);
    await tester.pump();
    expect(host.routes.themePushInsets, [0, 0]);
    await _dismissTheme(tester, host);
  });

  testWidgets('disposing search before IME closure cancels its pending sheet', (tester) async {
    final host = await _pumpHost(tester);
    await _beginWithKeyboard(tester);
    await tester.pumpWidget(const SizedBox());
    await _closeKeyboard(tester);
    expect(host.routes.themePushInsets, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('another destination keeps its new input focus and cancels the pending sheet', (tester) async {
    final destinationFocus = FocusNode();
    addTearDown(destinationFocus.dispose);
    final host = await _pumpHost(tester);
    await _beginWithKeyboard(tester);
    unawaited(
      host.navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => Scaffold(body: TextField(focusNode: destinationFocus, autofocus: true))),
      ),
    );
    await tester.pump();
    await _closeKeyboard(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(host.routes.themePushInsets, isEmpty);
    expect(destinationFocus.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving the retained pager face cancels without losing the query', (tester) async {
    final host = await _pumpHost(tester);
    await _beginWithKeyboard(tester);
    host.showHome();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    await _closeKeyboard(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(host.routes.themePushInsets, isEmpty);
    expect(tester.widget<PageView>(find.byType(PageView)).controller!.page, 0);
    host.pager.currentState!.showAllFeatures();
    await tester.pumpAndSettle();
    expect(_input(tester).controller.text, '테마');
    expect(host.routes.themePushInsets, isEmpty);
  });

  testWidgets('a new search focus cancels the old pending result', (tester) async {
    final host = await _pumpHost(tester);
    await _beginWithKeyboard(tester);
    await tester.tap(_search);
    await tester.pump();
    await _closeKeyboard(tester);
    expect(host.routes.themePushInsets, isEmpty);
    expect(_input(tester).focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  });

  testWidgets('a public settings entry releases only its original focused input', (tester) async {
    final host = await _pumpHost(tester);
    tester.view.viewInsets = const FakeViewPadding(bottom: 320);
    await tester.pump();
    unawaited(AppSettingsScreen.open(tester.element(find.byType(AllFeaturesScreen)), AppSettingsTarget.theme));
    await tester.pump();
    await tester.pump();
    expect(_input(tester).focusNode.hasFocus, isFalse);
    expect(host.routes.themePushInsets, isEmpty);
    await _closeKeyboard(tester);
    await _finishThemeEntrance(tester, host);
    await _dismissTheme(tester, host);
  });

  testWidgets('missing keyboard metrics cancel safely and release the next launch', (tester) async {
    final host = await _pumpHost(tester);
    await _beginWithKeyboard(tester);
    await tester.pump(const Duration(seconds: 3));
    expect(host.routes.themePushInsets, isEmpty);
    await _closeKeyboard(tester);
    expect(host.routes.themePushInsets, isEmpty);
    await tester.tap(_themeResult);
    await tester.pump();
    expect(host.routes.themePushInsets, [0]);
    await _finishThemeEntrance(tester, host);
    await _dismissTheme(tester, host);
  });

  testWidgets('app interruption cancels a pending sheet', (tester) async {
    final host = await _pumpHost(tester);
    await _beginWithKeyboard(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await _closeKeyboard(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(host.routes.themePushInsets, isEmpty);
  });

  testWidgets('theme row highlight still waits for the sheet route transition', (tester) async {
    final host = await _pumpHost(tester, highlight: CoconutThemeVariant.dark);
    await _beginWithKeyboard(tester);
    expect(find.byKey(const ValueKey('theme-search-focus-dark')), findsNothing);
    await _closeKeyboard(tester);
    await tester.pump();
    final target = find.byKey(const ValueKey('theme-search-focus-dark'));
    final opacity = find.descendant(of: target, matching: find.byType(AnimatedOpacity));
    expect(tester.widget<AnimatedOpacity>(opacity).opacity, 0);
    await _finishThemeEntrance(tester, host);
    for (var frame = 0; frame < 30 && tester.widget<AnimatedOpacity>(opacity).opacity == 0; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(tester.widget<AnimatedOpacity>(opacity).opacity, 1);
    expect(host.preferences.themeVariant, CoconutThemeVariant.dark);
    await _dismissTheme(tester, host);
  });
}
