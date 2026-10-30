import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/home/home_item_configure_sheets.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Exercise the production grid/menu/sheet without rendering financial widget data.
class _LabelDefinition extends HomeItemDefinition {
  _LabelDefinition(HomeItemDefinition definition)
    : super(
        id: definition.id,
        kind: definition.kind,
        supportedSpans: definition.supportedSpans,
        category: definition.category,
        settings: definition.settings,
      );

  @override
  Widget build(BuildContext context, HomeItem item) => Text(item.span.toJson());
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  bool get isFakeBalanceActive => false;
  @override
  int? get fakeBalanceTotalAmount => null;
  @override
  FiatCode get selectedFiat => FiatCode.KRW;
}

class _PreviewData extends Fake with ChangeNotifier implements HomeWidgetsViewModel {}

HomeConfiguration _configuration(HomeItemDefinition definition, HomeSpan span) => HomeConfiguration(
  items: [
    HomeItem(
      id: 'target',
      definitionId: definition.id,
      kind: HomeItemKind.widget,
      order: 0,
      span: span,
      position: const HomeGridPosition(0, 0),
      configuration: definition.settings.period ? const {'period': 'month'} : const {},
    ),
    for (final (i, feature)
        in [FeatureIds.receive, FeatureIds.send, FeatureIds.calculator, FeatureIds.glossary].indexed)
      HomeItem(
        id: 'shortcut-$i',
        definitionId: HomeItemIds.shortcut(feature),
        kind: HomeItemKind.shortcut,
        order: i + 1,
        span: HomeSpan.shortcut,
        position: span == HomeSpan.small ? HomeGridPosition(2 + i % 2, i ~/ 2) : HomeGridPosition(i, 2),
      ),
  ],
);

Future<void> _settleMenu(WidgetTester tester) async {
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late HomeConfigurationRepository repository;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPrefsRepository();
    await prefs.init();
    repository = HomeConfigurationRepository(prefs);
  });

  for (final definition in builtinHomeWidgets().where((definition) => definition.supportedSpans.length > 1)) {
    for (final from in definition.supportedSpans) {
      final to = definition.supportedSpans.firstWhere((span) => span != from);
      for (final width in [288.0, 414.0]) {
        testWidgets('${definition.id} menu ${from.toJson()} to ${to.toJson()} at width $width', (tester) async {
          await repository.save(_configuration(definition, from));
          final model = HomeViewModel(repository: repository, wallets: () => [], onShortcutTap: (_, __) {});
          addTearDown(model.dispose);
          final registry = HomeItemRegistry();
          for (final original in model.registry.all) {
            registry.register(_LabelDefinition(original));
          }
          await tester.pumpWidget(
            MaterialApp(
              theme: buildCoconutThemeData(),
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: width,
                    child: AnimatedBuilder(
                      animation: model,
                      builder:
                          (_, __) => HomeItemsView(
                            configuration: model.configuration,
                            registry: registry,
                            onMoveToCell: model.moveToCell,
                            onResize: (item, span) => model.resizeItem(item.id, span),
                            menuItemsOf:
                                (_) => [
                                  LongPressedMenuItem(
                                    title: 'configure',
                                    iconPath: CommonActionIconPath.editHome,
                                    onSelected: () {},
                                  ),
                                ],
                          ),
                    ),
                  ),
                ),
              ),
            ),
          );
          final before = model.configuration;
          await tester.longPress(find.byKey(const ValueKey('home-item-target')));
          await _settleMenu(tester);
          expect(find.byKey(ValueKey('home-item-size-target-${to.toJson()}')), findsOneWidget);
          await tester.binding.handlePopRoute();
          await _settleMenu(tester);
          expect(model.configuration, before);
          expect(repository.load(), before);

          await tester.longPress(find.byKey(const ValueKey('home-item-target')));
          await _settleMenu(tester);
          await tester.tap(find.byKey(ValueKey('home-item-size-target-${to.toJson()}')));
          await _settleMenu(tester);
          final after = model.configuration;
          expect(after.items.first.span, to);
          expect(repository.load(), after);
          expect(find.byKey(const Key('long-pressed-menu-box')), findsNothing);
          final grid = tester.getRect(find.byKey(const ValueKey('home-grid-surface')));
          final cell = (grid.width - HomeItemsView.gap * 3) / 4;
          for (final item in after.items) {
            final expectedPosition =
                item.id == 'target'
                    ? const HomeGridPosition(0, 0)
                    : to == HomeSpan.small
                    ? HomeGridPosition(2 + (item.order - 1) % 2, (item.order - 1) ~/ 2)
                    : HomeGridPosition(item.order - 1, 2);
            expect(item.position, expectedPosition);
            final actual = tester.getRect(find.byKey(ValueKey('home-item-content-${item.id}')));
            expect(actual.left, closeTo(grid.left + expectedPosition.column * (cell + HomeItemsView.gap), .01));
            expect(actual.top, closeTo(grid.top + expectedPosition.row * (cell + HomeItemsView.gap), .01));
            expect(actual.width, closeTo(cell * item.span.width + HomeItemsView.gap * (item.span.width - 1), .01));
            expect(actual.height, closeTo(cell * item.span.height + HomeItemsView.gap * (item.span.height - 1), .01));
          }
          expect(after.items.first.configuration, before.items.first.configuration);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 200));
        });
      }
    }

    testWidgets('${definition.id} settings preview can cancel or persist the selected size', (tester) async {
      await repository.save(_configuration(definition, HomeSpan.wide));
      final model = HomeViewModel(repository: repository, wallets: () => [], onShortcutTap: (_, __) {});
      final preferences = _Preferences();
      final previewData = _PreviewData();
      addTearDown(model.dispose);
      addTearDown(preferences.dispose);
      addTearDown(previewData.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
            ChangeNotifierProvider<HomeWidgetsViewModel>.value(value: previewData),
          ],
          child: MaterialApp(
            theme: buildCoconutThemeData(),
            home: Scaffold(
              body: Builder(
                builder:
                    (context) => TextButton(
                      key: const Key('open-settings'),
                      onPressed:
                          () => HomeItemConfigureSheets.configure(
                            context,
                            model,
                            _LabelDefinition(definition),
                            model.configuration.items.first,
                            columns: 4,
                          ),
                      child: const Text('configure'),
                    ),
              ),
            ),
          ),
        ),
      );
      final before = model.configuration;
      for (final cancel in [true, false]) {
        await tester.tap(find.byKey(const Key('open-settings')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('widget-configure-size-2x2')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('widget-configure-preview-2x2')), findsOneWidget);
        final preview = tester.getSize(find.byKey(const ValueKey('widget-configure-preview-2x2')));
        expect(preview.width, closeTo(preview.height, .01));
        expect(model.configuration, before, reason: 'Preview is local to the sheet until Save');
        expect(repository.load(), before);
        if (cancel) {
          await tester.binding.handlePopRoute();
        } else {
          await tester.tap(find.byKey(const Key('widget-configure-submit')));
        }
        await tester.pumpAndSettle();
        expect(model.configuration.items.first.span, cancel ? HomeSpan.wide : HomeSpan.small);
        expect(model.configuration.items.first.configuration, before.items.first.configuration);
        expect(repository.load(), model.configuration);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 200));
    });
  }
}
