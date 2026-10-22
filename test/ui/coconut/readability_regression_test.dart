import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/features/wallet/address/address_list_address_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _phase = String.fromEnvironment('READABILITY_PHASE', defaultValue: 'current');

Rect _paintedRect(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);
}

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance() + .05;
  final b = background.computeLuminance() + .05;
  return a > b ? a / b : b / a;
}

Future<void> _record(WidgetTester tester, GlobalKey key, String name, Map<String, Object?> metrics) async {
  await tester.runAsync(() async {
    final directory = Directory('.omo/evidence/readability-fix/$_phase');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.json').writeAsString(jsonEncode(metrics));
    final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('${directory.path}/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    } finally {
      image.dispose();
    }
  });
}

Widget _host(GlobalKey key, Widget child, CoconutThemeVariant variant, double scale) => MaterialApp(
  theme: buildCoconutThemeData(variant: variant),
  builder:
      (context, child) =>
          MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
  home: Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: RepaintBoundary(key: key, child: Column(mainAxisSize: MainAxisSize.min, children: [child])),
      ),
    ),
  ),
);

void main() {
  setUpAll(() async {
    for (final family in ['Pretendard', 'SpaceGrotesk']) {
      final loader =
          FontLoader(family)
            ..addFont(rootBundle.load('assets/fonts/$family-Regular.ttf'))
            ..addFont(rootBundle.load('assets/fonts/$family-Bold.ttf'));
      await loader.load();
    }
  });
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.de));
  tearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  for (final variant in CoconutThemeVariant.values) {
    for (final scale in [1.0, 2.0]) {
      for (final width in [320.0, 443.077, 851.692]) {
        final id = '${variant.name}-$scale-$width';
        testWidgets('active address contrast and tap $id', (tester) async {
          tester.view.physicalSize = Size(width, 994.462);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final key = GlobalKey();
          var taps = 0;
          for (final used in [false, true]) {
            await tester.pumpWidget(
              _host(
                key,
                AddressItemCard(
                  onPressed: () => taps++,
                  address: 'bcrt1qpublicreadabilityfixture000000000000000',
                  derivationPath: "m/84'/1'/0'/0/0",
                  isUsed: used,
                  isWatched: false,
                  currentUnit: BitcoinUnit.btc,
                  balanceInSats: used ? 100 : 0,
                ),
                variant,
                scale,
              ),
            );
            await tester.pumpAndSettle();
            final address = find.textContaining('bcrt1qpubl');
            final amount = find.text(BitcoinUnit.btc.displayBitcoinAmount(used ? 100 : 0, withUnit: true));
            final surface = resolveCoconutThemeExtension(variant: variant).colors.surface;
            final ratios = [
              for (final finder in [address, amount]) _contrast(tester.widget<Text>(finder).style!.color!, surface),
            ];
            await tester.tap(address);
            await tester.pumpAndSettle();
            await _record(tester, key, 'address-$id-$used', {
              'used': used,
              'contrasts': ratios,
              'taps': taps,
              'address_rect': _paintedRect(tester, address).toString(),
              'amount_rect': _paintedRect(tester, amount).toString(),
            });
            expect(
              ratios.every((ratio) => ratio >= 4.5),
              isTrue,
              reason: 'active address and amount must have normal-text contrast',
            );
            expect(taps, used ? 2 : 1);
            expect(tester.takeException(), isNull);
          }
        });

        testWidgets('German settings value stays separated and actionable $id', (tester) async {
          tester.view.physicalSize = Size(width, 994.462);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final key = GlobalKey();
          var taps = 0;
          final title = t.settings_screen.number_format;
          final value = NumberFormatPreset.dotDecimal.displayLabel;
          await tester.pumpWidget(
            _host(
              key,
              SingleButton(
                title: title,
                subtitle: value,
                enableShrinkAnim: true,
                animationEndValue: .97,
                onPressed: () => taps++,
              ),
              variant,
              scale,
            ),
          );
          await tester.pumpAndSettle();
          final titleRect = _paintedRect(tester, find.text(title));
          final valueRect = _paintedRect(tester, find.text(value));
          final bounds = tester.getRect(find.byType(SingleButton));
          final arrowRect = tester.getRect(find.byIcon(Icons.keyboard_arrow_right_rounded));
          final gap = valueRect.left - titleRect.right;
          final titleFont = tester.widget<Text>(find.text(title)).style!.fontSize!;
          final valueFont = tester.widget<Text>(find.text(value)).style!.fontSize!;
          final titlePaintedFont = titleFont * scale * titleRect.width / tester.getSize(find.text(title)).width;
          final valuePaintedFont = valueFont * scale * valueRect.width / tester.getSize(find.text(value)).width;
          await tester.tap(find.text(title));
          await tester.pumpAndSettle();
          await _record(tester, key, 'settings-$id', {
            'painted_gap': gap,
            'title_painted_font': titlePaintedFont,
            'value_painted_font': valuePaintedFont,
            'title_rect': titleRect.toString(),
            'value_rect': valueRect.toString(),
            'button_rect': bounds.toString(),
            'trailing_inset': bounds.right - arrowRect.right,
            'taps': taps,
          });
          expect(gap, greaterThanOrEqualTo(7.99));
          expect(
            bounds.right - arrowRect.right,
            closeTo(21, .01),
            reason: 'the arrow stays at the existing 20px padding plus 1px button border',
          );
          expect(
            titleRect.overlaps(Rect.fromLTRB(titleRect.left, valueRect.top, titleRect.right, valueRect.bottom)),
            isTrue,
          );
          expect(titlePaintedFont, greaterThanOrEqualTo(titleFont - .01));
          expect(valuePaintedFont, greaterThanOrEqualTo(valueFont - .01));
          expect(bounds.contains(titleRect.center), isTrue);
          expect(bounds.contains(valueRect.center), isTrue);
          expect(titleRect.width, greaterThan(0));
          expect(valueRect.right, lessThanOrEqualTo(bounds.right));
          expect(taps, 1);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  testWidgets('shared rows retain null, vertical and trailing variants', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var taps = 0;
    for (final vertical in [false, true]) {
      for (final subtitle in [null, 'Description']) {
        if (vertical && subtitle == null) continue;
        for (final trailing in [false, true]) {
          for (final arrow in [false, true]) {
            final key = GlobalKey();
            await tester.pumpWidget(
              _host(
                key,
                SingleButton(
                  title: 'Settings',
                  subtitle: subtitle,
                  isVerticalSubtitle: vertical,
                  rightElement: trailing ? const SizedBox(width: 40, height: 24, child: Icon(Icons.check)) : null,
                  showRightArrowWithRightElement: arrow,
                  onPressed: () => taps++,
                  enableShrinkAnim: true,
                ),
                CoconutThemeVariant.coconutTheme,
                2,
              ),
            );
            await tester.pumpAndSettle();
            final before = taps;
            await tester.tap(find.text('Settings'));
            await tester.pumpAndSettle();
            await _record(tester, key, 'variant-$vertical-$subtitle-$trailing-$arrow', {'taps': taps});
            expect(taps, before + 1);
            expect(find.byIcon(Icons.keyboard_arrow_right_rounded), trailing && !arrow ? findsNothing : findsOneWidget);
            expect(find.byType(ShrinkAnimationButton), findsOneWidget);
            expect(tester.takeException(), isNull);
          }
        }
      }
    }
  });
}
