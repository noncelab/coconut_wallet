import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/view_model/home/home_widgets_view_model.dart';
import 'package:coconut_wallet/services/home/builtin_home_widgets.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:coconut_wallet/services/home/wallet_widget_definitions.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/wallet/menu/long_pressed_menu_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Widgets extends ChangeNotifier implements HomeWidgetsViewModel {
  @override
  bool isWalletDataLoading = false;
  @override
  List<WalletItemBase> get wallets => const [];
  bool disposed = false;
  bool get retainsListeners => hasListeners;

  @override
  void dispose() {
    disposed = true;
    super.dispose();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  for (final walletStack in [false, true]) {
    for (final withMenu in [false, true]) {
      testWidgets('drag keeps live home data: walletStack=$walletStack, menu=$withMenu', (tester) async {
        final model = _Widgets();
        addTearDown(model.dispose);
        final definition =
            walletStack
                ? WalletStackDefinition(WalletStackKind.all)
                : BuiltinHomeWidget(
                  id: 'live-data',
                  span: HomeSpan.small,
                  category: HomeItemCategory.balance,
                  name: () => 'Live data',
                  builder: (_, _, _) => const Text('Live data'),
                );
        HomeGridPosition? droppedAt;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCoconutThemeData(),
            home: ChangeNotifierProvider<HomeWidgetsViewModel>.value(
              value: model,
              child: Center(
                child: SizedBox(
                  width: 356,
                  child: HomeItemsView(
                    configuration: HomeConfiguration(
                      items: [
                        HomeItem(
                          id: 'tile',
                          definitionId: definition.id,
                          kind: HomeItemKind.widget,
                          order: 0,
                          span: HomeSpan.small,
                          position: const HomeGridPosition(0, 0),
                        ),
                      ],
                    ),
                    registry: HomeItemRegistry()..register(definition),
                    onMoveToCell: (_, position) => droppedAt = position,
                    menuItemsOf:
                        withMenu
                            ? (_) => [
                              LongPressedMenuItem(
                                title: 'Move',
                                iconPath: CommonActionIconPath.editHome,
                                onSelected: () {},
                              ),
                            ]
                            : null,
                  ),
                ),
              ),
            ),
          ),
        );
        final surface = tester.getTopLeft(find.byKey(const ValueKey('home-grid-surface')));
        final gesture = await tester.startGesture(tester.getCenter(find.byKey(const ValueKey('home-item-tile'))));
        await tester.pump(const Duration(milliseconds: 600));
        await gesture.moveTo(surface + const Offset(270, 86));
        await tester.pump();
        expect(tester.takeException(), isNull);
        model.isWalletDataLoading = true;
        model.notifyListeners();
        await tester.pump();
        expect(find.byType(HomeWidgetSkeleton), findsOneWidget);
        expect(tester.takeException(), isNull);
        model.isWalletDataLoading = false;
        model.notifyListeners();
        await tester.pump();
        await gesture.up();
        await tester.pumpAndSettle();
        expect(droppedAt, const HomeGridPosition(2, 0));
        expect(model.disposed, isFalse);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        expect(model.retainsListeners, isFalse);
        expect(model.disposed, isFalse);
      });
    }
  }
}
