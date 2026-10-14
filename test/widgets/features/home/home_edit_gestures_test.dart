import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/providers/view_model/home/home_view_model.dart';
import 'package:coconut_wallet/repository/shared_preference/home_configuration_repository.dart';
import 'package:coconut_wallet/repository/shared_preference/shared_prefs_repository.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestWidget extends HomeItemDefinition {
  _TestWidget(String id)
    : super(id: id, kind: HomeItemKind.widget, supportedSpans: [HomeSpan.small], category: HomeItemCategory.wallets);

  @override
  Widget build(BuildContext context, HomeItem item) => ColoredBox(color: Colors.blue, child: Text(id));
}

void main() {
  late HomeConfigurationRepository repository;
  late HomeViewModel model;
  late GlobalKey<HomeItemsViewState> gridKey;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = SharedPrefsRepository()..setSharedPreferencesForTest(await SharedPreferences.getInstance());
    repository = HomeConfigurationRepository(prefs);
    await repository.save(
      HomeConfiguration(
        items: [
          for (var index = 0; index < 3; index++)
            HomeItem(
              id: '${index + 1}',
              definitionId: '${index + 1}',
              kind: HomeItemKind.widget,
              span: HomeSpan.small,
              order: index,
            ),
        ],
      ),
    );
    model = HomeViewModel(
      repository: repository,
      wallets: () => [],
      onShortcutTap: (_, __) {},
      widgetDefinitions: [
        for (final id in ['1', '2', '3']) _TestWidget(id),
      ],
    );
    gridKey = GlobalKey<HomeItemsViewState>();
  });

  tearDown(() => model.dispose());

  Future<void> pumpGrid(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 4 * HomeItemsView.cell + 3 * HomeItemsView.gap,
          child: ListenableBuilder(
            listenable: model,
            builder:
                (context, _) => HomeItemsView(
                  key: gridKey,
                  configuration: model.configuration,
                  registry: model.registry,
                  onMoveToCell: model.moveToCell,
                  onInsertBefore: model.insertBefore,
                  isArranging: model.isArranging,
                  onArrangeStart: model.startArranging,
                  onArrangeDone: model.finishArranging,
                  menuItemsOf:
                      (item) => [
                        LongPressedMenuItem(
                          title: 'Edit ${item.id}',
                          iconPath: CommonActionIconPath.editHome,
                          onSelected: model.startArranging,
                        ),
                      ],
                ),
          ),
        ),
      ),
    ),
  );

  Future<TestGesture> dragOver(WidgetTester tester, String draggedId, String targetId, {bool hold = false}) async {
    final target = tester.getCenter(find.byKey(ValueKey('home-item-$targetId')));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(ValueKey('home-item-$draggedId'))));
    if (hold) await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 300));
    return gesture;
  }

  testWidgets('canceling a live drag restores the preview and a late release cannot save it', (tester) async {
    model.startArranging();
    await pumpGrid(tester);
    final original = model.configuration;
    final firstItem = find.byKey(const ValueKey('home-item-1'));
    final originalPosition = tester.getTopLeft(firstItem);
    final gesture = await dragOver(tester, '3', '1');
    expect(tester.getTopLeft(firstItem), isNot(originalPosition));
    expect(repository.load(), original);

    expect(gridKey.currentState!.cancelActiveDrag(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.getTopLeft(firstItem), originalPosition);
    expect(model.isArranging, isTrue);
    expect(gridKey.currentState!.cancelActiveDrag(), isFalse);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(model.configuration, original);
    expect(repository.load(), original);
    expect(find.text('Edit 3'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('canceling a later drag and finishing preserves the earlier saved move', (tester) async {
    await pumpGrid(tester);
    final original = model.configuration;
    final first = await dragOver(tester, '3', '1', hold: true);
    await first.up();
    await tester.pump(const Duration(milliseconds: 400));
    final saved = model.configuration;
    expect(saved, isNot(original));
    expect(repository.load(), saved);
    expect(model.isArranging, isTrue);

    final second = await dragOver(tester, '2', '3');
    expect(gridKey.currentState!.cancelActiveDrag(), isTrue);
    await tester.pump();
    await second.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(model.configuration, saved);
    expect(repository.load(), saved);
    expect(model.isArranging, isTrue);

    expect(gridKey.currentState!.cancelActiveDrag(), isFalse);
    model.finishArranging();
    await tester.pump(const Duration(milliseconds: 400));
    expect(model.isArranging, isFalse);
    expect(tester.widget<HomeItemsView>(find.byType(HomeItemsView)).isArranging, isFalse);
    expect(repository.load(), saved);

    model.startArranging();
    await tester.pump();
    expect(model.configuration, saved);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('canceling before the hover delay cannot leave a delayed preview behind', (tester) async {
    model.startArranging();
    await pumpGrid(tester);
    final original = model.configuration;
    final item = find.byKey(const ValueKey('home-item-1'));
    final originalPosition = tester.getTopLeft(item);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-3'))));
    await gesture.moveTo(tester.getCenter(item));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(gridKey.currentState!.cancelActiveDrag(), isTrue);
    await tester.pump(const Duration(seconds: 1));
    await gesture.up();
    await tester.pump();

    expect(tester.getTopLeft(item), originalPosition);
    expect(repository.load(), original);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a second finger cannot replace the active drag or save another widget', (tester) async {
    model.startArranging();
    await pumpGrid(tester);
    final original = model.configuration;
    final secondStart = tester.getCenter(find.byKey(const ValueKey('home-item-2')));
    final secondTarget = tester.getCenter(find.byKey(const ValueKey('home-item-3')));
    final first = await dragOver(tester, '3', '1');

    final second = await tester.startGesture(secondStart, pointer: 42);
    await second.moveTo(secondTarget);
    await tester.pump(const Duration(milliseconds: 400));
    await second.up();
    await tester.pump();
    expect(model.configuration, original);
    expect(repository.load(), original);

    await first.up();
    await tester.pump(const Duration(milliseconds: 400));
    expect(model.configuration.items.map((item) => item.id), ['3', '1', '2']);
    expect(repository.load(), model.configuration);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('an interrupted app cancels the held drag without discarding earlier layout', (tester) async {
    model.startArranging();
    await pumpGrid(tester);
    final original = model.configuration;
    final gesture = await dragOver(tester, '3', '1');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 400));

    expect(model.configuration, original);
    expect(repository.load(), original);
    expect(model.isArranging, isTrue);
    expect(gridKey.currentState!.cancelActiveDrag(), isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final heldFor in [const Duration(milliseconds: 300), const Duration(milliseconds: 600)]) {
    testWidgets('interrupting a ${heldFor.inMilliseconds}ms hold cannot leave a menu on resume', (tester) async {
      await pumpGrid(tester);
      final original = model.configuration;
      final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-3'))));
      await tester.pump(heldFor);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump(const Duration(milliseconds: 600));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await gesture.up();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Edit 3'), findsNothing);
      expect(model.isArranging, isFalse);
      expect(repository.load(), original);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('an interruption before the next frame cancels a deferred quick drop', (tester) async {
    await pumpGrid(tester);
    final original = model.configuration;
    final target = tester.getCenter(find.byKey(const ValueKey('home-item-1')));
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-3'))));
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveTo(target);
    await gesture.up();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump(const Duration(milliseconds: 400));

    expect(model.configuration, original);
    expect(repository.load(), original);
    expect(gridKey.currentState!.cancelActiveDrag(), isFalse);
    expect(find.text('Edit 3'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
