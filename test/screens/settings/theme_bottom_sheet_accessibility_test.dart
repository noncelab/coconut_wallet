import 'dart:ui' show Tristate;

import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/ccos/ccos_feature_runtime.dart';
import 'package:coconut_wallet/ccos/open_store/coconut_open_store_content.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/coconut_open_store_intro_screen.dart';
import 'package:coconut_wallet/screens/settings/theme_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/deletable_settings_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  _Preferences({required this.themeVariant, required this.hasCcos});

  @override
  CoconutThemeVariant themeVariant;
  final bool hasCcos;
  int changes = 0;
  int deactivations = 0;
  @override
  String get language => 'ko';
  @override
  Future<void> deactivateCcosFeature(String featureId) async {
    deactivations++;
  }

  @override
  bool get shouldShowOpenStoreIntroCard => false;

  @override
  CcosFeatureAvailability getCcosFeatureAvailability(String featureId) => CcosFeatureAvailability(
    featureId: featureId,
    isVisible: hasCcos,
    isActivated: hasCcos,
    isEntitled: hasCcos,
    isAvailable: hasCcos,
  );

  @override
  Future<void> changeThemeVariant(CoconutThemeVariant variant) async {
    themeVariant = variant;
    changes++;
    notifyListeners();
  }
}

class _Routes extends NavigatorObserver {
  final List<String?> pushed = [];
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => pushed.add(route.settings.name);
}

List<SemanticsNode> _nodes(WidgetTester tester) {
  final result = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    if (!node.isMergedIntoParent) result.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!);
  return result;
}

Future<void> _pump(WidgetTester tester, _Preferences preferences, _Routes routes, CoconutThemeVariant variant) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<PreferenceProvider>.value(
      value: preferences,
      child: MaterialApp(
        theme: buildCoconutThemeData(variant: variant),
        navigatorObservers: [routes],
        builder:
            (context, child) =>
                MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child!),
        home: const ThemeBottomSheet(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final variant in CoconutThemeVariant.values) {
    for (final hasCcos in [false, true]) {
      testWidgets('$variant availableCcos=$hasCcos has named actions and preserves theme selection semantics', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        final selected = !hasCcos && variant == CoconutThemeVariant.coconutTheme ? CoconutThemeVariant.dark : variant;
        final preferences = _Preferences(themeVariant: selected, hasCcos: hasCcos);
        addTearDown(preferences.dispose);
        await _pump(tester, preferences, _Routes(), variant);
        final nodes = _nodes(tester);
        for (final node in nodes) {
          final data = node.getSemanticsData();
          if (data.hasAction(SemanticsAction.tap)) {
            expect(data.label.trim(), isNotEmpty, reason: '$node');
            debugPrint(
              'EXPOSED_TAP $variant ccos=$hasCcos id=${node.id} label=${data.label} button=${data.flagsCollection.isButton} selected=${data.flagsCollection.isSelected}',
            );
          }
        }
        final options = {
          t.theme_dark: CoconutThemeVariant.dark,
          t.theme_light: CoconutThemeVariant.light,
          if (hasCcos) t.theme_coconut: CoconutThemeVariant.coconutTheme,
        };
        expect(
          nodes.where((node) => node.getSemanticsData().label.split('\n').first == t.theme_coconut),
          hasCcos ? hasLength(1) : isEmpty,
        );
        for (final option in options.entries) {
          final node = nodes.singleWhere((node) {
            final data = node.getSemanticsData();
            return data.flagsCollection.isButton && data.label.split('\n').first == option.key;
          });
          final data = node.getSemanticsData();
          expect(data.hasAction(SemanticsAction.tap), isTrue);
          expect(data.flagsCollection.isSelected, isNot(Tristate.none));
          expect(data.flagsCollection.isSelected == Tristate.isTrue, option.value == selected);
        }
        final store = nodes.singleWhere(
          (node) => node.getSemanticsData().label == CcosOpenStoreContentSource.intro.ctaLabel,
        );
        expect(store.getSemanticsData().flagsCollection.isButton, isTrue);
        expect(store.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
        debugPrint('THEME_SHEET_SEMANTICS $variant ccos=$hasCcos\n${nodes.first.toStringDeep()}');
        await tester.pumpWidget(const SizedBox());
        semantics.dispose();
      });
    }

    testWidgets('$variant semantic store activation pushes the intro route exactly once', (tester) async {
      final semantics = tester.ensureSemantics();
      final preferences = _Preferences(themeVariant: variant, hasCcos: true);
      addTearDown(preferences.dispose);
      final routes = _Routes();
      await _pump(tester, preferences, routes, variant);
      final store = _nodes(
        tester,
      ).singleWhere((node) => node.getSemanticsData().label == CcosOpenStoreContentSource.intro.ctaLabel);
      tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(store.id, SemanticsAction.tap);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(routes.pushed.where((name) => name == AnalyticsScreenNames.ccosOpenStoreIntro), hasLength(1));
      expect(find.byType(CoconutOpenStoreIntroScreen), findsOneWidget);
      expect(preferences.changes, 0);
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    });
  }

  testWidgets('closed selected Coconut row semantic dismiss opens confirmation and Cancel preserves preferences', (
    tester,
  ) async {
    for (final variant in CoconutThemeVariant.values) {
      final semantics = tester.ensureSemantics();
      final preferences = _Preferences(themeVariant: CoconutThemeVariant.coconutTheme, hasCcos: true);
      final routes = _Routes();
      await _pump(tester, preferences, routes, variant);
      expect(tester.widget<DeletableSettingsRow>(find.byType(DeletableSettingsRow)).isSwiped, isFalse);
      final row = _nodes(tester).singleWhere((node) => node.getSemanticsData().label.startsWith(t.theme_coconut));
      expect(row.getSemanticsData().hasAction(SemanticsAction.dismiss), isTrue);
      tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(row.id, SemanticsAction.dismiss);
      await tester.pumpAndSettle();
      expect(find.text(t.ccos.intro_screen.delete_popup_title), findsOneWidget);
      expect(preferences.changes, 0);
      expect(preferences.deactivations, 0);
      await tester.tap(find.text(t.cancel));
      await tester.pumpAndSettle();
      expect(find.text(t.ccos.intro_screen.delete_popup_title), findsNothing);
      expect(preferences.themeVariant, CoconutThemeVariant.coconutTheme);
      expect(preferences.hasCcos, isTrue);
      expect(preferences.changes, 0);
      expect(preferences.deactivations, 0);
      expect(routes.pushed.where((name) => name == AnalyticsScreenNames.ccosOpenStoreIntro), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      semantics.dispose();
      preferences.dispose();
    }
  });

  testWidgets('background pointer closes a swiped optional theme without selecting it', (tester) async {
    final preferences = _Preferences(themeVariant: CoconutThemeVariant.dark, hasCcos: true);
    addTearDown(preferences.dispose);
    await _pump(tester, preferences, _Routes(), CoconutThemeVariant.dark);
    final row = find.byType(DeletableSettingsRow);
    await tester.drag(row, const Offset(-220, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<DeletableSettingsRow>(row).isSwiped, isTrue);
    await tester.tapAt(tester.getRect(find.byType(ListView)).bottomRight - const Offset(24, 24));
    await tester.pumpAndSettle();
    expect(tester.widget<DeletableSettingsRow>(row).isSwiped, isFalse);
    expect(preferences.changes, 0);
  });

  testWidgets('theme list retains semantic scrolling and interactive children', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 220));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    final preferences = _Preferences(themeVariant: CoconutThemeVariant.dark, hasCcos: true);
    addTearDown(preferences.dispose);
    await _pump(tester, preferences, _Routes(), CoconutThemeVariant.dark);
    final scroll = _nodes(tester).singleWhere((node) => node.getSemanticsData().hasAction(SemanticsAction.scrollUp));
    tester.binding.renderViews.single.owner!.semanticsOwner!.performAction(scroll.id, SemanticsAction.scrollUp);
    await tester.pumpAndSettle();
    final state = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(state.position.pixels, greaterThan(0));
    final coconut = _nodes(tester).singleWhere((node) => node.getSemanticsData().label.startsWith(t.theme_coconut));
    expect(coconut.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    await tester.pumpWidget(const SizedBox());
    semantics.dispose();
  });
}
