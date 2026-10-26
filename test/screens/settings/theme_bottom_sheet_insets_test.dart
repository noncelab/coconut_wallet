import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/ccos_feature_runtime.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/feature/feature_navigation_target.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/settings/app_settings/app_settings_screen.dart';
import 'package:coconut_wallet/screens/settings/theme_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/deletable_settings_row.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selectable_settings_row.dart';
import 'package:coconut_wallet/widgets/features/ccos/card/coconut_open_store_intro_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  _Preferences(this.themeVariant, this.shouldShowOpenStoreIntroCard, this.available);
  @override
  CoconutThemeVariant themeVariant;
  @override
  final bool shouldShowOpenStoreIntroCard;
  final bool available;
  int changes = 0;
  @override
  CcosFeatureAvailability getCcosFeatureAvailability(String featureId) => CcosFeatureAvailability(
    featureId: featureId,
    isVisible: available,
    isActivated: available,
    isEntitled: available,
    isAvailable: available,
  );
  @override
  Future<void> changeThemeVariant(CoconutThemeVariant variant) async {
    themeVariant = variant;
    changes++;
    notifyListeners();
  }
}

class _Routes extends NavigatorObserver {
  final names = <String?>[];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => names.add(route.settings.name);
}

Future<void> _capture(WidgetTester tester, GlobalKey boundary, String name) async {
  const directory = String.fromEnvironment('THEME_INSET_ARTIFACT_DIR');
  if (directory.isEmpty) return;
  await tester.runAsync(() async {
    await Directory(directory).create(recursive: true);
    final image = await (boundary.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('$directory/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

void main() {
  setUpAll(() async {
    for (final family in ['Pretendard', 'SpaceGrotesk']) {
      final loader = FontLoader(family);
      for (final weight in ['Regular', 'Bold']) {
        loader.addFont(Future.value(ByteData.sublistView(File('assets/fonts/$family-$weight.ttf').readAsBytesSync())));
      }
      await loader.load();
    }
  });
  final profiles = [
    (
      name: 'android-buttons',
      size: const Size(344.38, 746.21),
      top: 24.0,
      bottom: 54.0,
      platform: TargetPlatform.android,
    ),
    (
      name: 'android-gesture',
      size: const Size(344.38, 746.21),
      top: 24.0,
      bottom: 24.0,
      platform: TargetPlatform.android,
    ),
    (name: 'ios-safearea', size: const Size(390, 844), top: 47.0, bottom: 34.0, platform: TargetPlatform.iOS),
  ];
  for (final profile in profiles) {
    for (final variant in CoconutThemeVariant.values) {
      for (final intro in [false, true]) {
        for (final available in [false, true]) {
          for (final scale in [1.0, 2.0]) {
            final name = '${profile.name}-${variant.name}-intro$intro-ccos$available-${scale}x';
            testWidgets('$name actual settings modal keeps last row above system inset', (tester) async {
              tester.view.devicePixelRatio = 1;
              tester.view.physicalSize = profile.size;
              tester.view.padding = FakeViewPadding(top: profile.top, bottom: profile.bottom);
              tester.view.viewPadding = FakeViewPadding(top: profile.top, bottom: profile.bottom);
              tester.view.viewInsets = FakeViewPadding.zero;
              addTearDown(tester.view.reset);
              final locale = LocaleSettings.currentLocale;
              LocaleSettings.setLocaleSync(AppLocale.ko);
              addTearDown(() => LocaleSettings.setLocaleSync(locale));
              final preferences = _Preferences(variant, intro, available);
              addTearDown(preferences.dispose);
              final routes = _Routes();
              final boundary = GlobalKey();
              await tester.pumpWidget(
                ChangeNotifierProvider<PreferenceProvider>.value(
                  value: preferences,
                  child: RepaintBoundary(
                    key: boundary,
                    child: MaterialApp(
                      theme: buildCoconutThemeData(variant: variant).copyWith(platform: profile.platform),
                      navigatorObservers: [routes],
                      builder:
                          (context, child) => MediaQuery(
                            data: MediaQuery.of(
                              context,
                            ).copyWith(textScaler: TextScaler.linear(scale), disableAnimations: true),
                            child: child!,
                          ),
                      home: Scaffold(
                        body: Builder(
                          builder:
                              (context) => Center(
                                child: TextButton(
                                  onPressed: () => unawaited(AppSettingsScreen.open(context, AppSettingsTarget.theme)),
                                  child: const Text('open settings', style: TextStyle(fontFamily: 'Pretendard')),
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.tap(find.text('open settings'));
              await tester.pumpAndSettle();
              expect(routes.names.where((name) => name == AnalyticsScreenNames.appSettingsThemeSheet), hasLength(1));
              expect(find.byType(ThemeBottomSheet), findsOneWidget);
              final sheetContext = tester.element(find.byType(ThemeBottomSheet));
              expect(MediaQuery.textScalerOf(sheetContext).scale(10), scale * 10);
              expect(MediaQuery.viewPaddingOf(sheetContext).bottom, profile.bottom);
              expect(MediaQuery.viewInsetsOf(sheetContext).bottom, 0);
              if (intro) {
                expect(tester.getSize(find.byType(CoconutOpenStoreIntroCard)).height, greaterThan(0));
              }
              final list = find.descendant(of: find.byType(ThemeBottomSheet), matching: find.byType(ListView));
              final scrollable = find.descendant(of: list, matching: find.byType(Scrollable)).first;
              final position = tester.state<ScrollableState>(scrollable).position;
              position.jumpTo(position.maxScrollExtent);
              await tester.pumpAndSettle();
              final lastRow =
                  available
                      ? find.byType(DeletableSettingsRow)
                      : find.byWidgetPredicate(
                        (widget) => widget is SelectableSettingsRow && widget.title == t.theme_light,
                      );
              final rect = tester.getRect(lastRow);
              final safeBottom = profile.size.height - profile.bottom;
              final metrics = {
                'name': name,
                'rowTop': rect.top,
                'rowBottom': rect.bottom,
                'rowCenter': rect.center.dy,
                'safeBottom': safeBottom,
                'listBottom': tester.getRect(list).bottom,
                'maxScrollExtent': position.maxScrollExtent,
                'sheetTop': tester.getTopLeft(find.byType(ThemeBottomSheet)).dy,
              };
              debugPrint('THEME_MODAL_INSETS ${jsonEncode(metrics)}');
              if (intro && !available) await _capture(tester, boundary, name);
              expect(tester.takeException(), isNull);
              expect(rect.bottom, lessThanOrEqualTo(safeBottom + 0.01));
              expect(rect.top, greaterThanOrEqualTo(tester.getRect(list).top));
              expect(rect.center.dy, lessThan(safeBottom));
              await tester.tapAt(rect.center);
              await tester.pumpAndSettle();
              expect(preferences.changes, 1);
              expect(
                preferences.themeVariant,
                available ? CoconutThemeVariant.coconutTheme : CoconutThemeVariant.light,
              );
              expect(tester.takeException(), isNull);
              await tester.pumpWidget(const SizedBox.shrink());
            });
          }
        }
      }
    }
  }
}
