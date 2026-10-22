import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    for (final entry
        in {
          'Pretendard': ['Pretendard-Regular.ttf', 'Pretendard-Bold.ttf'],
          'SpaceGrotesk': [
            'SpaceGrotesk-Light.ttf',
            'SpaceGrotesk-Regular.ttf',
            'SpaceGrotesk-Medium.ttf',
            'SpaceGrotesk-Bold.ttf',
          ],
        }.entries) {
      final loader = FontLoader(entry.key);
      for (final file in entry.value) {
        loader.addFont(
          Future.value(
            ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync()),
          ),
        );
      }
      await loader.load();
    }
    LocaleSettings.setLocaleSync(AppLocale.ko);
    NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
  });

  for (final diameter in [124.0, 168.0, 240.0]) {
    for (final unit in BitcoinUnit.values) {
      for (final textScale in [1.0, 2.0]) {
        testWidgets(
          'donut label stays inside $diameter circle in ${unit.name} at ${textScale}x',
          (tester) async {
            tester.view.devicePixelRatio = 1;
            tester.view.physicalSize = Size(diameter > 168 ? 800 : 390, 844);
            addTearDown(tester.view.reset);
            final semantics = tester.ensureSemantics();
            try {
              for (final sats in [4999, 0, 1, 123456789, 2100000000000000]) {
                final number = unit.displayBitcoinAmount(sats);
                final boundary = GlobalKey();
                await tester.pumpWidget(
                  MaterialApp(
                    theme: buildCoconutThemeData(
                      variant: CoconutThemeVariant.dark,
                    ),
                    themeAnimationDuration: Duration.zero,
                    builder:
                        (context, child) => MediaQuery(
                          data: MediaQuery.of(
                            context,
                          ).copyWith(textScaler: TextScaler.linear(textScale)),
                          child: child!,
                        ),
                    home: Scaffold(
                      body: Center(
                        child: RepaintBoundary(
                          key: boundary,
                          child: SizedBox(
                            width: diameter > 168 ? 540 : 358,
                            height: diameter + 52,
                            child: BalanceByWalletView(
                              shares: [
                                HomeBalanceShare(
                                  walletId: 11,
                                  name: 'Scope A',
                                  balance: sats,
                                  colorIndex: 0,
                                ),
                              ],
                              total: HomeAmount(
                                number,
                                unit.symbol,
                                unitFirst: unit.isPrefixSymbol,
                              ),
                              amountText: unit.displayBitcoinAmount,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                await tester.pump(const Duration(milliseconds: 200));
                expect(tester.takeException(), isNull);
                final total = find.byKey(const Key('balance-by-wallet-total'));
                final labels = find.descendant(
                  of: total,
                  matching: find.byType(Text),
                );
                expect(
                  tester.widgetList<Text>(labels).map((text) => text.data),
                  [number, unit.symbol],
                );
                expect(find.bySemanticsLabel(number), findsWidgets);
                final ring = tester.renderObject<RenderBox>(
                  find.descendant(
                    of: find.byType(BalanceByWalletView),
                    matching: find.byType(CustomPaint),
                  ),
                );
                expect(ring.size, Size.square(diameter));
                final center = ring.localToGlobal(
                  ring.size.center(Offset.zero),
                );
                // The unchanged ring's stroke is 20% of its diameter; its inner radius is 30%.
                final innerRadius =
                    (ring.localToGlobal(Offset(diameter * .8, diameter / 2)) -
                            center)
                        .distance;
                final distances = <double>[];
                for (final element in labels.evaluate()) {
                  final label = element.renderObject! as RenderBox;
                  for (final corner in [
                    Offset.zero,
                    Offset(label.size.width, 0),
                    Offset(0, label.size.height),
                    label.size.bottomRight(Offset.zero),
                  ]) {
                    distances.add(
                      (label.localToGlobal(corner) - center).distance,
                    );
                  }
                }
                const evidence = String.fromEnvironment(
                  'DONUT_LAYOUT_EVIDENCE_DIR',
                );
                if (evidence.isNotEmpty &&
                    diameter < 200 &&
                    unit == BitcoinUnit.btc &&
                    textScale == 1 &&
                    sats == 4999) {
                  final png = await tester.runAsync(() async {
                    final image = await (boundary.currentContext!
                                .findRenderObject()!
                            as RenderRepaintBoundary)
                        .toImage(pixelRatio: 1);
                    try {
                      return (await image.toByteData(
                        format: ui.ImageByteFormat.png,
                      ))!.buffer.asUint8List();
                    } finally {
                      image.dispose();
                    }
                  });
                  final file = File('$evidence/donut-${diameter.toInt()}.png');
                  expect(
                    file.existsSync(),
                    isFalse,
                    reason: 'Never overwrite an original capture.',
                  );
                  file.parent.createSync(recursive: true);
                  file.writeAsBytesSync(png!, flush: true);
                  File(
                    '$evidence/donut-${diameter.toInt()}.json',
                  ).writeAsStringSync(
                    jsonEncode({
                      'captured_at_utc':
                          DateTime.now().toUtc().toIso8601String(),
                      'diameter': diameter,
                      'viewport': [390, 844],
                      'widget': [358, diameter + 52],
                      'dpr': 1,
                      'text_scale': textScale,
                      'sats': sats,
                      'number': number,
                      'unit': unit.symbol,
                      'settled_ms': 200,
                      'inner_radius': innerRadius,
                      'painted_corner_distances': distances,
                    }),
                    flush: true,
                  );
                }
                expect(
                  distances,
                  everyElement(lessThanOrEqualTo(innerRadius + .001)),
                  reason:
                      '$sats sats; actual transformed label corners must clear the ring.',
                );
              }
            } finally {
              semantics.dispose();
            }
          },
        );
      }
    }
  }
}
