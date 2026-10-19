import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutButton;
import 'package:coconut_wallet/app.dart';
import 'package:coconut_wallet/app/theme/app_cupertino_theme.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/design_system/tokens/coconut_colors.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

typedef Settings = ({CoconutThemeVariant variant, bool disable, bool accessible});
const _paint = ValueKey('paint');
const _label = ValueKey('label');
const _button = ValueKey('button');
const _boundary = ValueKey('boundary');
const _sheet = ValueKey('sheet');
const _card = ValueKey('card');
const _icon = ValueKey('icon');

Widget harness(
  ValueNotifier<Settings> settings,
  TextEditingController input,
  FocusNode focus,
  GlobalKey<NavigatorState> navigator,
) => ValueListenableBuilder<Settings>(
  valueListenable: settings,
  builder:
      (context, value, _) => CupertinoApp(
        navigatorKey: navigator,
        theme: buildAppCupertinoTheme(variant: value.variant),
        builder:
            (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: value.disable, accessibleNavigation: value.accessible),
              child: CoconutAppTheme(
                variant: value.variant,
                materialTheme: buildCoconutThemeData(variant: value.variant),
                cupertinoTheme: buildAppCupertinoTheme(variant: value.variant),
                child: child!,
              ),
            ),
        home: Builder(
          builder:
              (context) => RepaintBoundary(
                key: _boundary,
                child: ColoredBox(
                  key: _paint,
                  color: context.coconutColors.background,
                  child: Column(
                    children: [
                      const Text('One label', key: _label),
                      Icon(CupertinoIcons.circle_fill, key: _icon, color: context.coconutColors.iconPrimary, size: 16),
                      CoconutButton(
                        key: _button,
                        text: 'Action',
                        width: 200,
                        height: 48,
                        onPressed: () {},
                        backgroundColor: context.coconutColors.primaryText,
                        foregroundColor: context.coconutColors.background,
                      ),
                      for (final surface in [
                        (_sheet, context.coconutColors.surfaceBottomSheet, 'Sheet title'),
                        (_card, context.coconutColors.homeSurface, 'Card title'),
                      ])
                        ColoredBox(
                          key: surface.$1,
                          color: surface.$2,
                          child: SizedBox(
                            width: 200,
                            height: 32,
                            child: Center(
                              child: Text(surface.$3, style: TextStyle(color: context.coconutColors.primaryText)),
                            ),
                          ),
                        ),
                      CupertinoTextField(controller: input, focusNode: focus),
                    ],
                  ),
                ),
              ),
        ),
      ),
);

AnimationController themeController(WidgetTester tester) =>
    tester
            .widget<AnimatedBuilder>(
              find.descendant(of: find.byType(CoconutAppTheme), matching: find.byType(AnimatedBuilder)).first,
            )
            .animation
        as AnimationController;

void expectPixel(int rgba, Color expected) {
  final argb = expected.toARGB32();
  // Rasterization rounds fractional interpolated channels to the nearest byte.
  for (final shifts in [(24, 16), (16, 8), (8, 0)]) {
    expect((rgba >> shifts.$1) & 255, closeTo((argb >> shifts.$2) & 255, 1));
  }
  expect(rgba & 255, 255);
}

double contrast(Color foreground, Color background) {
  final a = Color.alphaBlend(Color(foreground.toARGB32()), Color(background.toARGB32())).computeLuminance();
  final b = Color(background.toARGB32()).computeLuminance();
  return a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
}

Map<String, (Color, Color, double)> foregroundPairs(CoconutColors c) => {
  'primaryText': (c.primaryText, c.background, 4.5),
  'secondaryTextStrong': (c.secondaryTextStrong, c.background, 4.5),
  'secondaryText': (c.secondaryText, c.background, 4.5),
  'tertiaryText': (c.tertiaryText, c.background, 4.5),
  'mutedText': (c.mutedText, c.background, 4.5),
  'iconPrimary': (c.iconPrimary, c.background, 3),
  'iconSecondary': (c.iconSecondary, c.background, 3),
  'surfaceButtonText': (c.surfaceButtonText, c.surfaceButton, 4.5),
  'buttonPrimaryForeground': (c.buttonPrimaryForeground, c.buttonPrimaryBackground, 4.5),
  'buttonSecondaryForeground': (c.buttonSecondaryForeground, c.buttonSecondaryBackground, 4.5),
  'chipUnselectedText': (c.chipUnselectedText, c.chipUnselectedBackground, 4.5),
  'chipSelectedText': (c.chipSelectedText, c.chipSelectedBackground, 4.5),
  'chipOutlinedUnselectedText': (c.chipOutlinedUnselectedText, c.chipOutlinedUnselectedBackground, 4.5),
  'chipMovingText': (c.chipMovingText, c.chipMovingBackground, 4.5),
  'chipEditModeText': (c.chipEditModeText, c.chipEditModeBackground, 4.5),
  'inputPlaceholder': (c.inputPlaceholder, c.inputSurface, 4.5),
  'segmentedControlSelectedText': (c.segmentedControlSelectedText, c.segmentedControlSelected, 4.5),
  'segmentedControlUnselectedText': (c.segmentedControlUnselectedText, c.segmentedControlBackground, 4.5),
  'pulldownMenuTextColor': (c.pulldownMenuTextColor, c.pulldownMenuBackground, 4.5),
  'popoverText': (c.popoverText, c.popoverBackground, 4.5),
  'checkIconForeground': (c.checkIconForeground, c.checkIconBackground, 3),
};

void main() {
  final records = <Map<String, Object?>>[];
  final artifact = Directory(
    Platform.environment['THEME_FRAME_ARTIFACTS'] ?? '.qa/uiux/theme-completion-20261017/readability/frames',
  );
  setUpAll(() => artifact.createSync(recursive: true));
  tearDownAll(
    () => File(
      '${artifact.path}/paint-records.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(records)),
  );

  Future<double> capture(WidgetTester tester, String name) async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(_boundary));
    final image = await tester.runAsync(() => boundary.toImage());
    final rendered = image!;
    final raw = (await tester.runAsync(() => rendered.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    final png = (await tester.runAsync(() => rendered.toByteData(format: ui.ImageByteFormat.png)))!;
    File('${artifact.path}/$name.png').writeAsBytesSync(png.buffer.asUint8List());
    final color = tester.widget<ColoredBox>(find.byKey(_paint)).color;
    final pixel = raw.getUint32((rendered.width * (rendered.height - 5) + 5) * 4);
    expectPixel(pixel, color);
    final button = tester.getRect(find.byKey(_button));
    final buttonColor = tester.widget<CoconutButton>(find.byKey(_button)).backgroundColor!;
    final index = (rendered.width * (button.top.toInt() + 5) + button.center.dx.toInt()) * 4;
    expectPixel(raw.getUint32(index), buttonColor);
    int pixelAt(Offset point) => raw.getUint32((rendered.width * point.dy.toInt() + point.dx.toInt()) * 4);
    double glyphContrast(Finder label, int background) {
      final rect = tester.getRect(label);
      final backgroundLuminance = Color(0xff000000 | (background >> 8)).computeLuminance();
      var result = 1.0;
      for (var y = rect.top.ceil(); y < rect.bottom.floor(); y++) {
        for (var x = rect.left.ceil(); x < rect.right.floor(); x++) {
          final rgba = raw.getUint32((rendered.width * y + x) * 4);
          final luminance = Color(0xff000000 | (rgba >> 8)).computeLuminance();
          final contrast =
              (luminance > backgroundLuminance)
                  ? (luminance + .05) / (backgroundLuminance + .05)
                  : (backgroundLuminance + .05) / (luminance + .05);
          if (contrast > result) result = contrast;
        }
      }
      return result;
    }

    final textContrast = glyphContrast(find.byKey(_label), pixel);
    final buttonContrast = glyphContrast(find.text('Action'), raw.getUint32(index));
    final iconContrast = glyphContrast(find.byKey(_icon), pixel);
    final material = Theme.of(tester.element(find.byKey(_paint)));
    records.add({
      'frame': name,
      'backgroundRGBA': pixel,
      'buttonRGBA': raw.getUint32(index),
      'labelRect': tester.getRect(find.byKey(_label)).toString(),
      'labelCount': find.text('One label').evaluate().length,
      'textContrast': textContrast,
      'inverseButtonContrast': buttonContrast,
      'iconContrast': iconContrast,
      'unguardedMaterialBodyContrast': contrast(material.textTheme.bodyMedium!.color!, color),
      'unguardedMaterialSchemeContrast': contrast(material.colorScheme.onSurface, material.colorScheme.surface),
      'sheetTitleContrast': glyphContrast(
        find.text('Sheet title'),
        pixelAt(tester.getTopLeft(find.byKey(_sheet)) + const Offset(2, 2)),
      ),
      'cardTitleContrast': glyphContrast(
        find.text('Card title'),
        pixelAt(tester.getTopLeft(find.byKey(_card)) + const Offset(2, 2)),
      ),
    });
    rendered.dispose();
    expect(buttonContrast, greaterThanOrEqualTo(4.5), reason: '$name inverse button');
    expect(iconContrast, greaterThanOrEqualTo(3), reason: '$name icon');
    return textContrast;
  }

  testWidgets('primary text remains readable at 120ms of dark to light', (tester) async {
    final settings = ValueNotifier<Settings>((variant: CoconutThemeVariant.dark, disable: false, accessible: false));
    final input = TextEditingController();
    final focus = FocusNode();
    addTearDown(() {
      settings.dispose();
      input.dispose();
      focus.dispose();
    });
    await tester.pumpWidget(harness(settings, input, focus, GlobalKey<NavigatorState>()));
    settings.value = (variant: CoconutThemeVariant.light, disable: false, accessible: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final contrast = await capture(tester, 'dark-light-120ms');
    expect(contrast, greaterThanOrEqualTo(4.5), reason: 'Rendered primary glyphs must remain visible on their surface');
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final from in CoconutThemeVariant.values) {
    for (final to in CoconutThemeVariant.values.where((v) => v != from)) {
      test('foreground roles preserve contrast, surfaces and endpoints ${from.name} to ${to.name}', () {
        final a = resolveCoconutThemeExtension(variant: from).colors;
        final b = resolveCoconutThemeExtension(variant: to).colors;
        expect(CoconutColors.lerp(a, b, 0), same(a));
        expect(CoconutColors.lerp(a, b, 1), same(b));
        final source = foregroundPairs(a);
        final destination = foregroundPairs(b);
        final minima = <String, double>{};
        for (var frame = 0; frame <= 220; frame++) {
          final t = Curves.easeInOut.transform(frame / 220);
          final current = CoconutColors.lerp(a, b, t);
          for (final entry in foregroundPairs(current).entries) {
            final (foreground, surface, requirement) = entry.value;
            final (startForeground, startSurface, _) = source[entry.key]!;
            final (endForeground, endSurface, _) = destination[entry.key]!;
            final floor = [
              requirement,
              contrast(startForeground, startSurface),
              contrast(endForeground, endSurface),
            ].reduce((a, b) => a < b ? a : b);
            final measured = contrast(foreground, surface);
            expect(measured, greaterThanOrEqualTo(floor), reason: '${entry.key} at ${frame}ms');
            expect(surface, Color.lerp(startSurface, endSurface, t), reason: '${entry.key} surface at ${frame}ms');
            final unguarded = Color.lerp(startForeground, endForeground, t)!;
            if (contrast(unguarded, surface) >= floor) {
              expect(foreground, unguarded);
            }
            minima.update(entry.key, (old) => old < measured ? old : measured, ifAbsent: () => measured);
          }
        }
        records.add({'direction': '${from.name}-${to.name}', 'roleMinima': minima, 'samples': 221});
      });

      testWidgets('single subtree paint ${from.name} to ${to.name}', (tester) async {
        final settings = ValueNotifier<Settings>((variant: from, disable: false, accessible: false));
        final input = TextEditingController(text: 'keep selection');
        final focus = FocusNode();
        final navigator = GlobalKey<NavigatorState>();
        addTearDown(() {
          settings.dispose();
          input.dispose();
          focus.dispose();
        });
        await tester.pumpWidget(harness(settings, input, focus, navigator));
        input.selection = const TextSelection(baseOffset: 2, extentOffset: 5);
        focus.requestFocus();
        await tester.pump();
        final route = ModalRoute.of(tester.element(find.byKey(_paint)));
        final rect = tester.getRect(find.byKey(_label));
        final source = tester.widget<ColoredBox>(find.byKey(_paint)).color;
        await capture(tester, '${from.name}-${to.name}-start');
        settings.value = (variant: to, disable: false, accessible: false);
        await tester.pump();
        expect(tester.widget<ColoredBox>(find.byKey(_paint)).color, source);
        for (var elapsed = 10; elapsed < 110; elapsed += 10) {
          await tester.pump(const Duration(milliseconds: 10));
          expect(await capture(tester, '${from.name}-${to.name}-${elapsed}ms'), greaterThanOrEqualTo(4.5));
        }
        await tester.pump(const Duration(milliseconds: 10));
        final end = resolveCoconutThemeExtension(variant: to).colors.background;
        expect(tester.widget<ColoredBox>(find.byKey(_paint)).color, Color.lerp(source, end, .5));
        expect(await capture(tester, '${from.name}-${to.name}-mid'), greaterThanOrEqualTo(4.5));
        expect(tester.getRect(find.byKey(_label)), rect);
        expect(find.text('One label'), findsOneWidget);
        for (var elapsed = 120; elapsed < 220; elapsed += 10) {
          await tester.pump(const Duration(milliseconds: 10));
          expect(await capture(tester, '${from.name}-${to.name}-${elapsed}ms'), greaterThanOrEqualTo(4.5));
        }
        await tester.pump(const Duration(milliseconds: 10));
        expect(tester.widget<ColoredBox>(find.byKey(_paint)).color, end);
        await capture(tester, '${from.name}-${to.name}-end');
        expect(find.text('One label'), findsOneWidget);
        expect(tester.getRect(find.byKey(_label)), rect);
        expect(ModalRoute.of(tester.element(find.byKey(_paint))), same(route));
        expect(input.selection, const TextSelection(baseOffset: 2, extentOffset: 5));
        expect(focus.hasFocus, isTrue);
        await tester.pump(const Duration(milliseconds: 1));
        expect(themeController(tester).isAnimating, isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  for (final accessible in [false, true]) {
    testWidgets('${accessible ? 'accessibleNavigation' : 'disableAnimations'} snaps live and resumes', (tester) async {
      final settings = ValueNotifier<Settings>((variant: CoconutThemeVariant.dark, disable: false, accessible: false));
      final input = TextEditingController();
      final focus = FocusNode();
      addTearDown(() {
        settings.dispose();
        input.dispose();
        focus.dispose();
      });
      await tester.pumpWidget(harness(settings, input, focus, GlobalKey<NavigatorState>()));
      Color paint() => tester.widget<ColoredBox>(find.byKey(_paint)).color;
      settings.value = (variant: CoconutThemeVariant.light, disable: false, accessible: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 64));
      settings.value = (variant: CoconutThemeVariant.light, disable: !accessible, accessible: accessible);
      await tester.pump();
      expect(paint(), resolveCoconutThemeExtension(variant: CoconutThemeVariant.light).colors.background);
      await tester.pump(const Duration(milliseconds: 1));
      expect(themeController(tester).isAnimating, isFalse);
      settings.value = (variant: CoconutThemeVariant.coconutTheme, disable: !accessible, accessible: accessible);
      await tester.pump();
      expect(paint(), resolveCoconutThemeExtension(variant: CoconutThemeVariant.coconutTheme).colors.background);
      settings.value = (variant: CoconutThemeVariant.coconutTheme, disable: false, accessible: false);
      await tester.pump();
      final before = paint();
      settings.value = (variant: CoconutThemeVariant.dark, disable: false, accessible: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      expect(paint(), isNot(before));
      expect(paint(), isNot(resolveCoconutThemeExtension(variant: CoconutThemeVariant.dark).colors.background));
      await tester.pump(const Duration(milliseconds: 110));
      await tester.pump(const Duration(milliseconds: 1));
      expect(themeController(tester).isAnimating, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final accessible in [false, true]) {
    testWidgets('initial reduced theme and simultaneous re-enable $accessible', (tester) async {
      final settings = ValueNotifier<Settings>((
        variant: CoconutThemeVariant.dark,
        disable: !accessible,
        accessible: accessible,
      ));
      final input = TextEditingController();
      final focus = FocusNode();
      addTearDown(() {
        settings.dispose();
        input.dispose();
        focus.dispose();
      });
      await tester.pumpWidget(harness(settings, input, focus, GlobalKey<NavigatorState>()));
      settings.value = (variant: CoconutThemeVariant.light, disable: !accessible, accessible: accessible);
      await tester.pump();
      final light = resolveCoconutThemeExtension(variant: CoconutThemeVariant.light).colors.background;
      expect(tester.widget<ColoredBox>(find.byKey(_paint)).color, light);
      expect(themeController(tester).isAnimating, isFalse);
      settings.value = (variant: CoconutThemeVariant.dark, disable: false, accessible: false);
      await tester.pump();
      expect(tester.widget<ColoredBox>(find.byKey(_paint)).color, light);
      expect(themeController(tester).isAnimating, isTrue);
      await tester.pump(const Duration(milliseconds: 221));
      expect(
        tester.widget<ColoredBox>(find.byKey(_paint)).color,
        resolveCoconutThemeExtension(variant: CoconutThemeVariant.dark).colors.background,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('retarget while foreground guard is active preserves current paint', (tester) async {
    final settings = ValueNotifier<Settings>((variant: CoconutThemeVariant.dark, disable: false, accessible: false));
    final input = TextEditingController();
    final focus = FocusNode();
    addTearDown(() {
      settings.dispose();
      input.dispose();
      focus.dispose();
    });
    await tester.pumpWidget(harness(settings, input, focus, GlobalKey<NavigatorState>()));
    settings.value = (variant: CoconutThemeVariant.light, disable: false, accessible: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final before = foregroundPairs(tester.element(find.byKey(_paint)).coconutColors);
    expect(await capture(tester, 'active-guard-before-retarget'), greaterThanOrEqualTo(4.5));
    settings.value = (variant: CoconutThemeVariant.coconutTheme, disable: false, accessible: false);
    await tester.pump();
    expect(foregroundPairs(tester.element(find.byKey(_paint)).coconutColors), before);
    for (var elapsed = 0; elapsed <= 220; elapsed += 10) {
      if (elapsed != 0) await tester.pump(const Duration(milliseconds: 10));
      expect(await capture(tester, 'active-guard-retarget-${elapsed}ms'), greaterThanOrEqualTo(4.5));
    }
    expect(
      tester.element(find.byKey(_paint)).coconutColors.primaryText,
      resolveCoconutThemeExtension(variant: CoconutThemeVariant.coconutTheme).colors.primaryText,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('rapid retarget starts at current paint and settles latest selection', (tester) async {
    final settings = ValueNotifier<Settings>((variant: CoconutThemeVariant.dark, disable: false, accessible: false));
    final input = TextEditingController();
    final focus = FocusNode();
    addTearDown(() {
      settings.dispose();
      input.dispose();
      focus.dispose();
    });
    await tester.pumpWidget(harness(settings, input, focus, GlobalKey<NavigatorState>()));
    Color paint() => tester.widget<ColoredBox>(find.byKey(_paint)).color;
    for (final (index, target)
        in [
          CoconutThemeVariant.light,
          CoconutThemeVariant.coconutTheme,
          CoconutThemeVariant.dark,
          CoconutThemeVariant.light,
        ].indexed) {
      final before = paint();
      final beforeForeground = tester.element(find.byKey(_paint)).coconutColors.primaryText;
      settings.value = (variant: target, disable: false, accessible: false);
      await tester.pump();
      expect(paint(), before);
      expect(tester.element(find.byKey(_paint)).coconutColors.primaryText, beforeForeground);
      expect(await capture(tester, 'retarget-$index-${target.name}-start'), greaterThanOrEqualTo(4.5));
      await tester.pump(const Duration(milliseconds: 48));
      expect(await capture(tester, 'retarget-$index-${target.name}-48ms'), greaterThanOrEqualTo(4.5));
      expect(find.text('One label'), findsOneWidget);
    }
    await tester.pump(const Duration(milliseconds: 220));
    expect(paint(), resolveCoconutThemeExtension(variant: CoconutThemeVariant.light).colors.background);
    await tester.pump(const Duration(milliseconds: 1));
    expect(themeController(tester).isAnimating, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
