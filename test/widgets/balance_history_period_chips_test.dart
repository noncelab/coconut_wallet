import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/balance_history_period_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const _captureKey = Key('period-chips-capture');

Finder _chip(HomeWidgetPeriod period) => find.byKey(ValueKey('hodl-insights-period-${period.name}'));

Future<ValueNotifier<HomeWidgetPeriod>> _show(
  WidgetTester tester, {
  CoconutThemeVariant variant = CoconutThemeVariant.dark,
  double scale = 1,
  bool disableAnimations = false,
  bool accessibleNavigation = false,
  TextDirection direction = TextDirection.ltr,
}) async {
  final selected = ValueNotifier(HomeWidgetPeriod.week);
  addTearDown(selected.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(variant: variant),
      home: MediaQuery(
        data: MediaQueryData(
          textScaler: TextScaler.linear(scale),
          disableAnimations: disableAnimations,
          accessibleNavigation: accessibleNavigation,
        ),
        child: Directionality(
          textDirection: direction,
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: _captureKey,
              child: ValueListenableBuilder<HomeWidgetPeriod>(
                valueListenable: selected,
                builder:
                    (context, period, _) => BalanceHistoryPeriodChips(
                      selected: period,
                      onSelected: (value) => selected.value = value,
                      backgroundColor: context.coconutColors.surface,
                      itemBackgroundColor: context.coconutColors.background,
                    ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return selected;
}

Future<Rect> _paintedSelection(WidgetTester tester, {String? capture}) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_captureKey));
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
  final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
  final color = tester.element(find.byType(BalanceHistoryPeriodChips)).coconutColors.primaryText.toARGB32();
  final bytes = data.buffer.asUint8List();
  var left = image.width;
  var top = image.height;
  var right = -1;
  var bottom = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final i = (y * image.width + x) * 4;
      final pixel = bytes[i + 3] << 24 | bytes[i] << 16 | bytes[i + 1] << 8 | bytes[i + 2];
      if (pixel != color) continue;
      if (x < left) left = x;
      if (x > right) right = x;
      if (y < top) top = y;
      if (y > bottom) bottom = y;
    }
  }
  final directory = Platform.environment['PERIOD_CHIP_CAPTURE_DIR'];
  if (capture != null && directory != null) {
    final png = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.png)))!;
    await tester.runAsync(() async {
      await Directory(directory).create(recursive: true);
      await File('$directory/$capture.png').writeAsBytes(png.buffer.asUint8List());
    });
  }
  image.dispose();
  expect(right, greaterThanOrEqualTo(left), reason: 'The selected background must actually be painted.');
  return Rect.fromLTRB(left.toDouble(), top.toDouble(), right + 1.0, bottom + 1.0);
}

Rect _localChipRect(WidgetTester tester, HomeWidgetPeriod period) =>
    tester.getRect(_chip(period)).shift(-tester.getTopLeft(find.byKey(_captureKey)));

void _expectOnChip(Rect painted, Rect chip) {
  expect(painted.left, closeTo(chip.left, 1));
  expect(painted.right, closeTo(chip.right, 1));
  expect(painted.top, closeTo(chip.top, 1));
  expect(painted.bottom, closeTo(chip.bottom, 1));
}

void main() {
  final initialLocale = LocaleSettings.currentLocale;
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.en));
  tearDown(() => LocaleSettings.setLocaleSync(initialLocale));

  testWidgets('painted selection slides and rapid taps retarget without moving any chip', (tester) async {
    final selected = await _show(tester);
    final geometry = [for (final period in HomeWidgetPeriod.values) tester.getRect(_chip(period))];
    final start = await _paintedSelection(tester, capture: 'initial');
    final target = _localChipRect(tester, HomeWidgetPeriod.all);
    await tester.tap(_chip(HomeWidgetPeriod.all));
    await tester.pump();
    expect(selected.value, HomeWidgetPeriod.all);
    _expectOnChip(await _paintedSelection(tester), _localChipRect(tester, HomeWidgetPeriod.week));
    await tester.pump(const Duration(milliseconds: 70));
    final midway = await _paintedSelection(tester, capture: 'mid-slide');
    expect(midway.left, greaterThan(start.left + 1));
    expect(midway.left, lessThan(target.left - 1));
    await tester.tap(_chip(HomeWidgetPeriod.month));
    await tester.pump();
    expect(selected.value, HomeWidgetPeriod.month);
    expect((await _paintedSelection(tester)).left, closeTo(midway.left, 1));
    await tester.pumpAndSettle();
    _expectOnChip(
      await _paintedSelection(tester, capture: 'retargeted'),
      _localChipRect(tester, HomeWidgetPeriod.month),
    );
    expect([for (final period in HomeWidgetPeriod.values) tester.getRect(_chip(period))], geometry);
    expect(tester.takeException(), isNull);
  });

  for (final locale in [AppLocale.en, AppLocale.ko]) {
    for (final variant in CoconutThemeVariant.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('selection fits actual chip bounds for ${locale.name}, ${variant.name}, scale $scale', (
          tester,
        ) async {
          LocaleSettings.setLocaleSync(locale);
          await _show(tester, variant: variant, scale: scale);
          final geometry = [for (final period in HomeWidgetPeriod.values) tester.getRect(_chip(period))];
          _expectOnChip(await _paintedSelection(tester), _localChipRect(tester, HomeWidgetPeriod.week));
          await tester.tap(_chip(HomeWidgetPeriod.threeMonths));
          await tester.pumpAndSettle();
          _expectOnChip(await _paintedSelection(tester), _localChipRect(tester, HomeWidgetPeriod.threeMonths));
          expect([for (final period in HomeWidgetPeriod.values) tester.getRect(_chip(period))], geometry);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final accessibleNavigation in [false, true]) {
    testWidgets(
      'selection settles immediately with ${accessibleNavigation ? 'accessible navigation' : 'reduced motion'}',
      (tester) async {
        await _show(tester, disableAnimations: !accessibleNavigation, accessibleNavigation: accessibleNavigation);
        await tester.tap(_chip(HomeWidgetPeriod.all));
        await tester.pump();
        _expectOnChip(await _paintedSelection(tester), _localChipRect(tester, HomeWidgetPeriod.all));
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );
  }

  testWidgets('selection follows actual RTL positions while sliding', (tester) async {
    await _show(tester, direction: TextDirection.rtl);
    final start = await _paintedSelection(tester);
    final target = _localChipRect(tester, HomeWidgetPeriod.all);
    await tester.tap(_chip(HomeWidgetPeriod.all));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final midway = await _paintedSelection(tester);
    expect(midway.left, lessThan(start.left - 1));
    expect(midway.left, greaterThan(target.left + 1));
    await tester.pumpAndSettle();
    _expectOnChip(await _paintedSelection(tester), target);
  });
}
