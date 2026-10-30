import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:coconut_wallet/widgets/features/utxo/header/selected_utxo_amount_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _SheetFixture {
  late DraggableScrollableController sheet;
  late ScrollController scroll;
  final orderKey = GlobalKey();
  bool selected = true;
  int selectTaps = 0;
  int unselectTaps = 0;
  int rowTaps = 0;
}

Future<_SheetFixture> _openSheet(WidgetTester tester, {bool initiallySelected = true}) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  LocaleSettings.setLocaleSync(AppLocale.en);
  final fixture = _SheetFixture()..selected = initiallySelected;
  await tester.pumpWidget(
    Provider<AnalyticsService>.value(
      value: AnalyticsService(null, true),
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        home: Builder(
          builder:
              (context) => Scaffold(
                body: TextButton(
                  onPressed:
                      () => CommonBottomSheets.showDraggableBottomSheet<void>(
                        context: context,
                        screenName: 'test_draggable_sheet',
                        title: 'Sheet title',
                        minChildSize: 0.6,
                        initialChildSize: 0.6,
                        maxChildSize: 0.9,
                        onControllerReady: (controller) => fixture.sheet = controller,
                        childBuilder: (scrollController) {
                          fixture.scroll = scrollController;
                          return StatefulBuilder(
                            builder:
                                (context, setState) => Column(
                                  children: [
                                    SelectedUtxoAmountHeader(
                                      orderDropdownButtonKey: fixture.orderKey,
                                      orderText: 'Order',
                                      selectedUtxoCount: fixture.selected ? 2 : 0,
                                      selectedUtxoAmountSum: fixture.selected ? 50000 : 0,
                                      currentUnit: BitcoinUnit.sats,
                                      onSelectAll:
                                          () => setState(() {
                                            fixture.selected = true;
                                            fixture.selectTaps++;
                                          }),
                                      onUnselectAll:
                                          () => setState(() {
                                            fixture.selected = false;
                                            fixture.unselectTaps++;
                                          }),
                                      onToggleOrderDropdown: () {},
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        key: const ValueKey('sheet-list'),
                                        controller: scrollController,
                                        itemExtent: 60,
                                        itemCount: 30,
                                        itemBuilder:
                                            (_, index) =>
                                                ListTile(title: Text('Row $index'), onTap: () => fixture.rowTaps++),
                                      ),
                                    ),
                                  ],
                                ),
                          );
                        },
                      ),
                  child: const Text('Open'),
                ),
              ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  expect(fixture.sheet.size, closeTo(0.6, 0.000001));
  return fixture;
}

Finder _dragTarget(String region) {
  if (region == 'body header') return find.text(t.utxo_total);
  if (region == 'title') return find.text('Sheet title');
  return find.byWidgetPredicate(
    (widget) => widget is Container && widget.constraints?.maxWidth == 55 && widget.constraints?.maxHeight == 4,
  );
}

Future<TestGesture> _startAcceptedDrag(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(target));
  await gesture.moveBy(const Offset(0, -30));
  await tester.pump();
  await gesture.moveBy(const Offset(0, -180));
  await tester.pump();
  return gesture;
}

void main() {
  for (final selectAll in [true, false]) {
    testWidgets('real header ${selectAll ? 'select' : 'unselect'} all tap does not resize', (tester) async {
      final fixture = await _openSheet(tester, initiallySelected: !selectAll);
      final before = fixture.sheet.size;
      await tester.tap(find.text(selectAll ? t.select_all : t.unselect_all));
      await tester.pumpAndSettle();

      expect(fixture.selectTaps, selectAll ? 1 : 0);
      expect(fixture.unselectTaps, selectAll ? 0 : 1);
      expect(fixture.selected, selectAll);
      expect(fixture.sheet.size, closeTo(before, 0.000001));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('simple title and handle taps do not snap', (tester) async {
    final fixture = await _openSheet(tester);
    for (final region in ['title', 'handle']) {
      final before = fixture.sheet.size;
      await tester.tap(_dragTarget(region));
      await tester.pumpAndSettle();
      expect(fixture.sheet.size, closeTo(before, 0.000001), reason: region);
    }
    expect(tester.takeException(), isNull);
  });

  for (final region in ['body header', 'title', 'handle']) {
    testWidgets('$region drag resizes before release and snaps afterward', (tester) async {
      final fixture = await _openSheet(tester);
      final gesture = await _startAcceptedDrag(tester, _dragTarget(region));
      expect(fixture.sheet.size, greaterThan(0.75));
      expect(fixture.sheet.size, lessThan(0.9));
      await gesture.up();
      await tester.pumpAndSettle();

      expect(fixture.sheet.size, closeTo(0.9, 0.000001));
      expect(fixture.scroll.offset, 0);
      expect(fixture.selectTaps + fixture.unselectTaps + fixture.rowTaps, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancelling an accepted body drag snaps and leaves controls usable', (tester) async {
    final fixture = await _openSheet(tester);
    final gesture = await _startAcceptedDrag(tester, _dragTarget('body header'));
    expect(fixture.sheet.size, greaterThan(0.75));
    expect(fixture.sheet.size, lessThan(0.9));
    await gesture.cancel();
    await tester.pumpAndSettle();

    expect(fixture.sheet.size, closeTo(0.9, 0.000001));
    await tester.tap(find.text(t.unselect_all));
    await tester.pumpAndSettle();
    expect(fixture.unselectTaps, 1);
    expect(fixture.sheet.size, closeTo(0.9, 0.000001));
    expect(tester.takeException(), isNull);
  });

  testWidgets('inner list scroll and row tap keep the expanded sheet stable', (tester) async {
    final fixture = await _openSheet(tester);
    final gesture = await _startAcceptedDrag(tester, _dragTarget('body header'));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fixture.sheet.size, closeTo(0.9, 0.000001));

    await tester.drag(find.byKey(const ValueKey('sheet-list')), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(fixture.scroll.offset, greaterThan(0));
    expect(fixture.sheet.size, closeTo(0.9, 0.000001));
    expect(fixture.rowTaps, 0);

    final offset = fixture.scroll.offset;
    final visibleRow = find.byType(ListTile).hitTestable().first;
    await tester.tap(visibleRow);
    await tester.pumpAndSettle();
    expect(fixture.rowTaps, 1);
    expect(fixture.scroll.offset, closeTo(offset, 0.000001));
    expect(fixture.sheet.size, closeTo(0.9, 0.000001));
    expect(tester.takeException(), isNull);
  });
}
