import 'package:coconut_wallet/model/home/home_configuration.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/model/home/home_item_definition.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:coconut_wallet/widgets/features/home/home_items_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Match LiveTestWidgetsFlutterBinding's filtering of queued device-source cancels.
class _FilteredCancelBinding extends AutomatedTestWidgetsFlutterBinding {
  int filteredCancels = 0;

  @override
  void handlePointerEvent(PointerEvent event) {
    if (event is PointerCancelEvent && pointerEventSource == TestBindingEventSource.device) {
      filteredCancels++;
      return;
    }
    super.handlePointerEvent(event);
  }
}

class _Tile extends HomeItemDefinition {
  _Tile()
    : super(
        id: 'tile',
        kind: HomeItemKind.widget,
        supportedSpans: const [HomeSpan.small],
        category: HomeItemCategory.wallets,
      );

  @override
  Widget build(BuildContext context, HomeItem item) => const ColoredBox(color: Color(0xff0000ff));
}

void main() {
  final binding = _FilteredCancelBinding();
  testWidgets('configuration replacement cancels feedback without queued pointer delivery', (tester) async {
    final registry = HomeItemRegistry()..register(_Tile());
    final original = HomeConfiguration(
      items: [
        for (var index = 0; index < 2; index++)
          HomeItem(id: '$index', definitionId: 'tile', kind: HomeItemKind.widget, order: index, span: HomeSpan.small),
      ],
    );
    var configuration = original;
    late StateSetter update;
    final drops = <HomeGridPosition>[];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder:
                    (_) => Align(
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: 356,
                        child: StatefulBuilder(
                          builder: (context, setState) {
                            update = setState;
                            return HomeItemsView(
                              configuration: configuration,
                              registry: registry,
                              isArranging: true,
                              onMoveToCell: (_, position) => drops.add(position),
                            );
                          },
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
    final source = find.byKey(const ValueKey('home-item-0'));
    final gesture = await tester.startGesture(tester.getCenter(source));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    expect(find.byType(Opacity), findsOneWidget);
    update(() => configuration = original.removeItem('1'));
    await tester.pump();
    await tester.pump();
    expect(binding.filteredCancels, greaterThan(0));
    expect(find.byType(Opacity), findsNothing);
    update(() => configuration = original);
    await tester.pump();
    await gesture.moveBy(const Offset(30, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(drops, isEmpty);
    expect(find.byType(Opacity), findsNothing);
    expect(tester.takeException(), isNull);
    final second = await tester.startGesture(tester.getCenter(source));
    await second.moveBy(const Offset(30, 0));
    // Unmount before the captured feedback gets its first build.
    await tester.pumpWidget(const SizedBox());
    await second.cancel();
    tester.binding.handleMetricsChanged();
    await tester.pump();
    expect(find.byType(Opacity), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
