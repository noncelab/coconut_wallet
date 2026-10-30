import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/home/home_item_ids.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/screens/home/home_item_configure_sheets.dart';
import 'package:coconut_wallet/screens/home/home_edit_screen.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:coconut_wallet/services/home/home_grid_geometry.dart';
import 'package:coconut_wallet/services/home/home_grid_layout.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Replace financial tile contents only; keep the production grid, menus, sheet,
// view model, JSON repository and reload normalization in the exercised path.
class _Tile extends HomeItemDefinition {
  const _Tile(String id)
    : super(
        id: id,
        kind: HomeItemKind.widget,
        category: HomeItemCategory.balance,
        supportedSpans: const [HomeSpan.small, HomeSpan.wide],
        settings: const HomeWidgetSettingsSpec(sizes: [HomeSpan.small, HomeSpan.wide]),
      );

  @override
  Widget build(BuildContext context, HomeItem item) => Text(item.id);
}

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  bool get isFakeBalanceActive => false;
  @override
  int? get fakeBalanceTotalAmount => null;
  @override
  FiatCode get selectedFiat => FiatCode.KRW;
}

const _definitions = [_Tile('A'), _Tile('F'), _Tile('G'), _Tile('H')];

HomeConfiguration _initial() => HomeConfiguration(
  items: [
    const HomeItem(
      id: 'A',
      definitionId: 'A',
      kind: HomeItemKind.widget,
      order: 0,
      span: HomeSpan.small,
      position: HomeGridPosition(0, 0),
    ),
    for (final (i, feature)
        in [FeatureIds.receive, FeatureIds.send, FeatureIds.calculator, FeatureIds.glossary].indexed)
      HomeItem(
        id: 'shortcut-$i',
        definitionId: HomeItemIds.shortcut(feature),
        kind: HomeItemKind.shortcut,
        order: i + 1,
        span: HomeSpan.shortcut,
        position: HomeGridPosition(2 + i % 2, i ~/ 2),
      ),
    for (final (i, id) in ['F', 'G', 'H'].indexed)
      HomeItem(
        id: id,
        definitionId: id,
        kind: HomeItemKind.widget,
        order: i + 5,
        span: HomeSpan.small,
        position: HomeGridPosition(2 * (i % 2), 2 + 2 * (i ~/ 2)),
      ),
  ],
);

void _expectValid(HomeConfiguration configuration) {
  final cells = <(int, int)>{};
  for (final item in configuration.items) {
    final position = item.position!;
    expect(position.column, greaterThanOrEqualTo(0));
    expect(position.row, greaterThanOrEqualTo(0));
    expect(position.column + item.span.width, lessThanOrEqualTo(configuration.columns));
    for (var y = position.row; y < position.row + item.span.height; y++) {
      for (var x = position.column; x < position.column + item.span.width; x++) {
        expect(cells.add((x, y)), isTrue, reason: 'Overlapping cell $x,$y');
      }
    }
  }
  expect(HomeGridLayout(configuration).positionedConfiguration, configuration);
}

void main() {
  for (final configureRoute in ['sheet', 'edit']) {
    for (final (columns, width, inset, initialWidth) in [
      (4, 414.0, 0.0, 414.0),
      (6, 600.0, 0.0, 600.0),
      (8, 800.0, 0.0, 800.0),
      (4, 600.0, 24.0, 600.0),
      (6, 800.0, 32.0, 800.0),
      (6, 600.0, 0.0, 414.0),
      (8, 800.0, 0.0, 414.0),
    ]) {
      testWidgets('$configureRoute agrees with menu at $columns columns, width $initialWidth->$width, inset $inset', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.padding = FakeViewPadding(left: inset, right: inset);
        addTearDown(tester.view.reset);
        SharedPreferences.setMockInitialValues({});
        final prefs = SharedPrefsRepository();
        await prefs.init();
        final repository = HomeConfigurationRepository(prefs);
        final preferences = _Preferences();
        addTearDown(preferences.dispose);
        HomeViewModel create() => HomeViewModel(
          repository: repository,
          wallets: () => [],
          onShortcutTap: (_, __) {},
          widgetDefinitions: _definitions,
        );
        final results = <HomeConfiguration>[];
        for (final route in ['menu', configureRoute]) {
          tester.view.physicalSize = Size(initialWidth, 1200);
          await repository.save(_initial());
          final model = create();
          addTearDown(model.dispose);
          expect(model.configuration, _initial());
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<PreferenceProvider>.value(value: preferences),
                ChangeNotifierProvider<HomeViewModel>.value(value: model),
              ],
              child: MaterialApp(
                theme: buildCoconutThemeData(),
                home:
                    route == 'edit'
                        ? const HomeEditScreen(initialTab: HomeEditTab.widgets)
                        : Scaffold(
                          body: SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Builder(
                                builder:
                                    (context) => AnimatedBuilder(
                                      animation: model,
                                      builder:
                                          (_, __) => HomeItemsView(
                                            configuration: model.configuration,
                                            registry: model.registry,
                                            onMoveToCell:
                                                (id, position) => model.moveToCell(id, position, columns: columns),
                                            onResize: (item, span) => model.resizeItem(item.id, span, columns: columns),
                                            menuItemsOf:
                                                (item) => [
                                                  LongPressedMenuItem(
                                                    title: 'configure',
                                                    iconPath: CommonActionIconPath.command,
                                                    onSelected:
                                                        () => HomeItemConfigureSheets.configure(
                                                          context,
                                                          model,
                                                          _definitions.first,
                                                          item,
                                                          columns: columns,
                                                        ),
                                                  ),
                                                ],
                                          ),
                                    ),
                              ),
                            ),
                          ),
                        ),
              ),
            ),
          );
          tester.view.physicalSize = Size(width, 1200);
          await tester.pumpAndSettle();
          if (route == 'edit') {
            await tester.tap(find.byKey(const ValueKey('home-edit-widget-tap-A')));
          } else {
            final grid = tester.getRect(find.byKey(const ValueKey('home-grid-surface')));
            expect(HomeGridGeometry.columnsForWidth(grid.width), columns);
            await tester.longPress(find.byKey(const ValueKey('home-item-A')));
            for (var frame = 0; frame < 5; frame++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
            if (route == 'sheet') await tester.tap(find.text('configure'));
          }
          if (route != 'menu') {
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey('widget-configure-size-4x2')));
            await tester.pumpAndSettle();
            expect(model.configuration, _initial(), reason: 'Size preview must not save');
            await tester.tap(find.byKey(const Key('widget-configure-submit')));
          } else {
            await tester.tap(find.byKey(const ValueKey('home-item-size-A-4x2')));
          }
          await tester.pumpAndSettle();
          final saved = model.configuration;
          expect(saved.columns, columns);
          expect(saved.items.first.span, HomeSpan.wide);
          expect(repository.load(), saved);
          final reloaded = create();
          expect(reloaded.configuration, saved);
          reloaded.dispose();
          _expectValid(saved);
          results.add(HomeGridLayout(saved).reflow(columns));
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(
          {for (final item in results.last.items) item.id: item.position},
          {for (final item in results.first.items) item.id: item.position},
          reason: '$configureRoute Save must use the same visible grid as the resize menu',
        );
        expect(results.last, results.first);
        if (columns > 4) {
          final positions = {for (final item in results.last.items) item.id: item.position};
          expect(positions['shortcut-0'], const HomeGridPosition(4, 0));
          expect(positions['shortcut-1'], const HomeGridPosition(5, 0));
          expect(positions['shortcut-2'], const HomeGridPosition(4, 1));
          expect(positions['shortcut-3'], const HomeGridPosition(5, 1));
          final phone = HomeGridLayout(results.last).reflow(4);
          _expectValid(phone);
          final phonePositions = {for (final item in phone.items) item.id: item.position};
          expect(phonePositions['shortcut-0'], const HomeGridPosition(0, 2));
          expect(phonePositions['shortcut-1'], const HomeGridPosition(1, 2));
          expect(phonePositions['shortcut-2'], const HomeGridPosition(0, 3));
          expect(phonePositions['shortcut-3'], const HomeGridPosition(1, 3));
        }
      });
    }
  }
}
