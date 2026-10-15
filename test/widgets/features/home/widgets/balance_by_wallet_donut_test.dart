import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/model/home/home_widget_data.dart';
import 'package:coconut_wallet/services/home/home_widget_math.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/wallet_widget_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter_test/flutter_test.dart';

const _size = 400;

typedef _DonutScene = ({CustomPainter painter, List<Color> colors, Color emptyColor, List<int> values, Size paintSize});

List<HomeBalanceShare> _shares(List<int> values, {int colorOffset = 0}) => [
  for (var i = 0; i < values.length; i++)
    HomeBalanceShare(
      walletId: i + 1,
      name: 'Synthetic ${i + 1}',
      balance: values[i],
      colorIndex: (i + colorOffset) % 10,
    ),
];

Future<_DonutScene> _painter(
  WidgetTester tester,
  List<int> values, {
  double reveal = 1,
  int colorOffset = 0,
  CoconutThemeVariant theme = CoconutThemeVariant.dark,
  List<HomeBalanceShare>? sharesOverride,
  Size widgetSize = const Size(400, 200),
  bool reducedMotion = false,
}) async {
  final shares = sharesOverride ?? _shares(values, colorOffset: colorOffset);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(variant: theme),
      themeAnimationDuration: Duration.zero,
      builder:
          (context, child) =>
              MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: reducedMotion), child: child!),
      home: Center(
        child: SizedBox.fromSize(
          size: widgetSize,
          child: BalanceByWalletView(
            shares: shares,
            total: const HomeAmount('Synthetic', 'BTC'),
            amountText: (value) => '$value',
            reveal: reveal,
          ),
        ),
      ),
    ),
  );
  final view = find.byType(BalanceByWalletView);
  final context = tester.element(view);
  final paintFinder = find.descendant(of: view, matching: find.byType(CustomPaint));
  final paint = tester.widget<CustomPaint>(paintFinder);
  return (
    painter: paint.painter!,
    colors: [for (final share in shares) BalanceByWalletView.colorOf(context, share)],
    emptyColor: context.coconutColors.surfaceMuted,
    values: [for (final share in shares) share.balance],
    paintSize: tester.getSize(paintFinder),
  );
}

Future<ByteData> _raster(
  WidgetTester tester,
  CustomPainter painter,
  String name, {
  double logicalSide = 400,
  double pixelRatio = 1,
  String? goldenPath,
}) async {
  ui.Image? goldenImage;
  final result = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder)..scale(pixelRatio), Size.square(logicalSide));
    final picture = recorder.endRecording();
    final pixelSide = (logicalSide * pixelRatio).round();
    final image = await picture.toImage(pixelSide, pixelSide);
    try {
      if (goldenPath != null) {
        goldenImage = image.clone();
      }
      final directory = Platform.environment['HODL_PIXEL_ARTIFACTS'];
      if (directory != null) {
        await Directory(directory).create(recursive: true);
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$directory/$name.png').writeAsBytes(png!.buffer.asUint8List());
      }
      return image.toByteData(format: ui.ImageByteFormat.rawRgba);
    } finally {
      image.dispose();
      picture.dispose();
    }
  });
  if (goldenPath != null) {
    try {
      await expectLater(goldenImage!, matchesGoldenFile(goldenPath));
    } finally {
      goldenImage!.dispose();
    }
  }
  return result!;
}

bool _matchesPixel(ByteData pixels, int pixelSide, int x, int y, Color color) {
  final index = (y * pixelSide + x) * 4;
  final expected = [(color.r * 255).round(), (color.g * 255).round(), (color.b * 255).round(), (color.a * 255).round()];
  for (var channel = 0; channel < 4; channel++) {
    if ((pixels.getUint8(index + channel) - expected[channel]).abs() > 2) return false;
  }
  return true;
}

/// Pixel-distance oracle for the rounded, separated style from e64dc8db^.
/// The normalized ring has radius .4 and half-width .1. Its rounded ends
/// consume .25 radians and the visible gap consumes .175 radians.
/// Classifying distances to arc interiors and endpoint circles also checks
/// tiny shares without treating them as proportional butt-ended sectors.
void _expectRoundedStyle(ByteData pixels, _DonutScene scene, double reveal, {int pixelSide = _size}) {
  final total = scene.values.fold<int>(0, (sum, value) => sum + value);
  final shown = reveal.clamp(0.0, 1.0);
  final visible = [
    for (var i = 0; i < scene.values.length; i++)
      if (scene.values[i] > 0) i,
  ];
  final arcs = <({double start, double end, Color color})>[];
  var cumulative = 0;
  for (final i in visible) {
    final from = cumulative / total * 2 * math.pi;
    cumulative += scene.values[i];
    final until = cumulative / total * 2 * math.pi;
    final start = visible.length == 1 ? 0.0 : from + .3375;
    final naturalEnd = visible.length == 1 ? until : math.max(start + .0001, until - .3375);
    final end = math.min(naturalEnd, shown * 2 * math.pi);
    // Flutter's host rasterizer drops the baseline's .0001-radian arc.
    // Archived baseline goldens below independently cover these tiny cases.
    if (visible.length > 1 && naturalEnd - start < .00011) continue;
    if (end > start) arcs.add((start: start, end: end, color: scene.colors[i]));
  }
  final failures = <String>[];
  var checked = 0;
  for (final radiusRatio in [.34, .40, .46]) {
    for (var sample = 0; sample < pixelSide * 6; sample++) {
      final angle = -math.pi / 2 + (sample + .37) / (pixelSide * 6) * 2 * math.pi;
      final x = (pixelSide / 2 + math.cos(angle) * pixelSide * radiusRatio).floor();
      final y = (pixelSide / 2 + math.sin(angle) * pixelSide * radiusRatio).floor();
      final point = Offset((x + .5) / pixelSide - .5, (y + .5) / pixelSide - .5);
      final theta = (math.atan2(point.dy, point.dx) + math.pi / 2) % (2 * math.pi);
      var expected = total <= 0 || shown < 1 ? scene.emptyColor : Colors.transparent;
      var ambiguous = false;
      for (final arc in arcs) {
        Offset endpoint(double a) => Offset(math.sin(a) * .4, -math.cos(a) * .4);
        final distance =
            theta >= arc.start && theta <= arc.end
                ? (point.distance - .4).abs()
                : math.min((point - endpoint(arc.start)).distance, (point - endpoint(arc.end)).distance);
        if ((distance - .1).abs() * pixelSide < 2) {
          ambiguous = true;
          break;
        }
        if (distance < .1) expected = Color.alphaBlend(arc.color, expected);
      }
      if (ambiguous) continue;
      checked++;
      if (!_matchesPixel(pixels, pixelSide, x, y, expected) && failures.length < 5) {
        failures.add('($x,$y), expected ${expected.toARGB32()}');
      }
    }
  }
  expect(checked, greaterThan(100));
  expect(failures, isEmpty, reason: 'rounded arcs, visible gaps and tiny-share behavior match e64dc8db^');
  expect(_matchesPixel(pixels, pixelSide, pixelSide ~/ 2, pixelSide ~/ 2, Colors.transparent), isTrue);
}

Color _atAngle(ByteData pixels, double fraction, {double radius = 160}) {
  final angle = -math.pi / 2 + fraction * 2 * math.pi;
  final x = (_size / 2 + math.cos(angle) * radius).floor();
  final y = (_size / 2 + math.sin(angle) * radius).floor();
  final index = (y * _size + x) * 4;
  return Color.fromARGB(
    pixels.getUint8(index + 3),
    pixels.getUint8(index),
    pixels.getUint8(index + 1),
    pixels.getUint8(index + 2),
  );
}

void _expectColor(Color actual, Color expected, String reason) {
  // Theme surfaces can be translucent. Compare straight-alpha raster channels
  // with a small rounding tolerance rather than assuming an opaque background.
  for (final pair in [(actual.a, expected.a), (actual.r, expected.r), (actual.g, expected.g), (actual.b, expected.b)]) {
    expect(pair.$1, closeTo(pair.$2, 2 / 255), reason: reason);
  }
}

bool _hasOpaqueColor(ByteData pixels, Color color) {
  final red = (color.r * 255).round();
  final green = (color.g * 255).round();
  final blue = (color.b * 255).round();
  for (var index = 0; index < pixels.lengthInBytes; index += 4) {
    if ((pixels.getUint8(index) - red).abs() <= 2 &&
        (pixels.getUint8(index + 1) - green).abs() <= 2 &&
        (pixels.getUint8(index + 2) - blue).abs() <= 2 &&
        pixels.getUint8(index + 3) >= 253) {
      return true;
    }
  }
  return false;
}

void main() {
  for (final values in [
    [90, 10],
    [80, 10, 10],
    [99, 1],
    [1, 99],
    [50, 0, 50],
    [100],
    [0, 100, 0],
  ]) {
    for (final reveal in [0.0, 0.5, 1.0]) {
      testWidgets('donut restores rounded separated shares $values at reveal $reveal', (tester) async {
        final scene = await _painter(tester, values, reveal: reveal);
        final pixels = await _raster(tester, scene.painter, '${values.join('-')}-reveal-$reveal');
        _expectRoundedStyle(pixels, scene, reveal);
        _expectColor(_atAngle(pixels, 0.25, radius: 80), Colors.transparent, 'the donut hole stays empty');
      });
    }
  }

  testWidgets('rounded style matches archived baseline images including tiny-share limitations', (tester) async {
    for (final values in [
      [90, 10],
      [1, 99],
      [99, 1],
    ]) {
      final scene = await _painter(tester, values);
      await _raster(
        tester,
        scene.painter,
        'baseline-golden-${values.join("-")}',
        goldenPath: 'goldens/donut-rounded-${values.join("-")}.png',
      );
    }
  });

  testWidgets('zero shares draw only the empty ring', (tester) async {
    for (final values in [
      <int>[],
      [0],
      [0, 0],
    ]) {
      final scene = await _painter(tester, values);
      final pixels = await _raster(tester, scene.painter, 'empty-${values.length}');
      for (final fraction in [0.1, 0.3, 0.6, 0.9]) {
        _expectColor(_atAngle(pixels, fraction), scene.emptyColor, 'zero total');
      }
    }
  });

  testWidgets('unchanged donut inputs skip repaint but values, colors, reveal and theme invalidate it', (tester) async {
    final original = (await _painter(tester, [90, 10])).painter;
    final same = (await _painter(tester, [90, 10])).painter;
    expect(same.shouldRepaint(original), isFalse);
    final changedValues = (await _painter(tester, [80, 20])).painter;
    expect(changedValues.shouldRepaint(same), isTrue);
    final changedColors = (await _painter(tester, [90, 10], colorOffset: 1)).painter;
    expect(changedColors.shouldRepaint(same), isTrue);
    final changedReveal = (await _painter(tester, [90, 10], reveal: 0.5)).painter;
    expect(changedReveal.shouldRepaint(same), isTrue);
    final changedTheme = (await _painter(tester, [90, 10], theme: CoconutThemeVariant.light)).painter;
    expect(changedTheme.shouldRepaint(same), isTrue);
  });

  for (final fixture in [
    ('equal-four', [1, 1, 1, 1]),
    ('large-finite', [2100000000000000, 1050000000000000, 350000000000000]),
    ('one-sat-first', [1, 2100000000000000]),
    ('one-sat-last', [2100000000000000, 1]),
    ('one-sat-middle', [1050000000000000, 1, 1050000000000000]),
  ]) {
    testWidgets('rounded baseline handles ${fixture.$1} including its original minimum arc', (tester) async {
      for (final reveal in [0.0, 0.07, 0.31, 0.5, 0.73, 0.999, 1.0]) {
        final scene = await _painter(tester, fixture.$2, reveal: reveal);
        final pixels = await _raster(tester, scene.painter, '${fixture.$1}-reveal-$reveal');
        _expectRoundedStyle(pixels, scene, reveal);
      }
    });
  }

  for (final values in [
    [999, 1],
    [1, 999],
  ]) {
    testWidgets('rounded baseline retains original 0.1 percent visibility for $values', (tester) async {
      final scene = await _painter(tester, values);
      final pixels = await _raster(tester, scene.painter, '${values.join('-')}-high-resolution', pixelRatio: 4);
      _expectRoundedStyle(pixels, scene, 1, pixelSide: 1600);
      final smallIndex = values.indexOf(1);
      // Style restoration keeps the baseline's tiny-share limitation. A later
      // design change must address visibility without removing rounded ends.
      expect(_hasOpaqueColor(pixels, scene.colors[smallIndex]), isFalse);
    });
  }

  testWidgets('zero-share donut stays an empty ring throughout reveal and clamped endpoints', (tester) async {
    for (final reveal in [-0.5, 0.0, 0.001, 0.37, 0.999, 1.0, 1.5]) {
      final scene = await _painter(tester, [0, 0], reveal: reveal);
      final pixels = await _raster(tester, scene.painter, 'zero-reveal-$reveal');
      _expectRoundedStyle(pixels, scene, reveal);
    }
  });

  testWidgets('the provider share contract excludes non-positive balances before painting', (tester) async {
    for (final values in [
      [7, 0, -3, 5],
      [-7, 0, -3],
    ]) {
      final shares = HomeWidgetMath.balanceShares(_shares(values), othersName: 'Synthetic others');
      expect(shares.every((share) => share.balance > 0), isTrue);
      expect(
        shares.fold<int>(0, (sum, share) => sum + share.balance),
        values.where((v) => v > 0).fold(0, (a, b) => a + b),
      );
      final scene = await _painter(tester, const [], sharesOverride: shares);
      final pixels = await _raster(tester, scene.painter, 'filtered-${values.first}');
      _expectRoundedStyle(pixels, scene, 1);
    }
  });

  testWidgets('twenty wallets become the leading three plus others without losing total or color identity', (
    tester,
  ) async {
    final shares = HomeWidgetMath.balanceShares(
      _shares([for (var i = 1; i <= 20; i++) i]),
      othersName: 'Synthetic others',
    );
    expect(shares.map((share) => share.balance), [20, 19, 18, 153]);
    expect(shares.last.walletId, isNull);
    expect(shares.last.colorIndex, isNull);
    final scene = await _painter(tester, const [], sharesOverride: shares);
    expect(scene.colors.last, scene.emptyColor);
    final pixels = await _raster(tester, scene.painter, 'twenty-wallets-grouped');
    _expectRoundedStyle(pixels, scene, 1);
    expect(find.byKey(const ValueKey('balance-by-wallet-entry-others')), findsOneWidget);
    expect(find.text('72.9%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final variant in [(64.0, 1.0), (96.0, 1.0), (148.0, 1.0), (148.0, 3.0), (200.0, 2.0), (328.0, 2.0)]) {
    testWidgets('rounded donut matches baseline at ${variant.$1} logical pixels and DPR ${variant.$2}', (tester) async {
      final scene = await _painter(tester, [97, 2, 1], reveal: 0.986);
      final pixels = await _raster(
        tester,
        scene.painter,
        'size-${variant.$1}-dpr-${variant.$2}',
        logicalSide: variant.$1,
        pixelRatio: variant.$2,
      );
      _expectRoundedStyle(pixels, scene, 0.986, pixelSide: (variant.$1 * variant.$2).round());
    });
  }

  for (final theme in CoconutThemeVariant.values) {
    testWidgets('donut uses actual share and empty-track colors in ${theme.name}', (tester) async {
      final scene = await _painter(tester, [80, 10, 10], reveal: 0.94, theme: theme);
      final pixels = await _raster(tester, scene.painter, 'theme-${theme.name}');
      _expectRoundedStyle(pixels, scene, 0.94);
    });
  }

  for (final widgetSize in [const Size(328, 172), const Size(400, 200)]) {
    testWidgets('the real donut layout stays square with four shares in $widgetSize', (tester) async {
      final scene = await _painter(tester, [80, 10, 9, 1], widgetSize: widgetSize);
      expect(scene.paintSize.width, scene.paintSize.height);
      expect(scene.paintSize.width, greaterThan(0));
      expect(scene.paintSize.height, lessThan(widgetSize.height));
      final side = scene.paintSize.width.roundToDouble();
      final pixels = await _raster(
        tester,
        scene.painter,
        'actual-${widgetSize.width}-${widgetSize.height}',
        logicalSide: side,
      );
      _expectRoundedStyle(pixels, scene, 1, pixelSide: side.toInt());
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('rapid donut data, reveal and theme updates show the latest frame without stale sectors', (tester) async {
    CustomPainter? previous;
    for (var frame = 0; frame < 18; frame++) {
      final values =
          [
            <int>[],
            [0, 0],
            [100],
            [80, 10, 10],
            [999, 1],
            [1, 1, 1, 1],
          ][frame % 6];
      final reveal = [0.0, 0.07, 0.33, 0.66, 0.94, 1.0][frame % 6];
      final scene = await _painter(
        tester,
        values,
        reveal: reveal,
        colorOffset: frame % 3,
        theme: frame.isEven ? CoconutThemeVariant.dark : CoconutThemeVariant.light,
      );
      if (previous != null) expect(scene.painter.shouldRepaint(previous), isTrue);
      final pixels = await _raster(tester, scene.painter, 'rapid-frame-$frame');
      _expectRoundedStyle(pixels, scene, reveal);
      for (var absent = values.length + 1; absent <= 4; absent++) {
        expect(find.byKey(ValueKey('balance-by-wallet-entry-$absent')), findsNothing);
      }
      expect(tester.takeException(), isNull);
      previous = scene.painter;
    }
  });

  testWidgets('reduced motion does not change a supplied donut proportion or reveal frame', (tester) async {
    final normal = await _painter(tester, [99, 1], reveal: 0.994);
    final normalPixels = await _raster(tester, normal.painter, 'motion-normal');
    final reduced = await _painter(tester, [99, 1], reveal: 0.994, reducedMotion: true);
    final reducedPixels = await _raster(tester, reduced.painter, 'motion-reduced');
    expect(listEquals(normalPixels.buffer.asUint8List(), reducedPixels.buffer.asUint8List()), isTrue);
    _expectRoundedStyle(reducedPixels, reduced, 0.994);
  });

  testWidgets('seeded donut updates preserve rounded baseline across 32 real provider distributions', (tester) async {
    final random = math.Random(3292026);
    for (var frame = 0; frame < 32; frame++) {
      final values = [for (var i = 0, count = 1 + random.nextInt(24); i < count; i++) random.nextInt(100000)];
      final shares = HomeWidgetMath.balanceShares(_shares(values), othersName: 'Synthetic others');
      expect(shares.length, lessThanOrEqualTo(4));
      expect(shares.fold<int>(0, (sum, share) => sum + share.balance), values.fold(0, (a, b) => a + b));
      final reveal = random.nextDouble();
      final scene = await _painter(
        tester,
        const [],
        sharesOverride: shares,
        reveal: reveal,
        theme: CoconutThemeVariant.values[frame % 3],
      );
      final side = [96.0, 148.0, 200.0][frame % 3];
      final pixels = await _raster(tester, scene.painter, 'seeded-frame-$frame', logicalSide: side, pixelRatio: 2);
      _expectRoundedStyle(pixels, scene, reveal, pixelSide: (side * 2).round());
      expect(tester.takeException(), isNull);
    }
  });
}
