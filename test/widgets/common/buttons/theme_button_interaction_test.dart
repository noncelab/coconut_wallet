import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_wallet/design_system/theme/coconut_theme_extension.dart';
import 'package:coconut_wallet/screens/home/wallet_add/hot_wallet/widgets/wallet_appearance_sheet.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selectable_settings_row.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/effects/ripple_effect.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final themes = {
    'dark': CoconutThemeExtension.dark(),
    'light': CoconutThemeExtension.light(),
    'coconut': CoconutThemeExtension.coconutTheme(),
  };
  for (final theme in themes.entries) {
    Widget host(Widget child, {double scale = 1}) => MaterialApp(
      theme: ThemeData(extensions: [theme.value]),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Scaffold(body: Center(child: SizedBox(width: 240, child: child))),
      ),
    );

    for (final fill
        in {
          'primary': theme.value.colors.buttonPrimaryBackground,
          'neutral': theme.value.colors.surface,
          'transparent': Colors.transparent,
        }.entries) {
      testWidgets('${theme.key}: ${fill.key} keyboard focus has visible 3:1 ring without layout change', (
        tester,
      ) async {
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          host(
            RepaintBoundary(
              key: boundaryKey,
              child: ColoredBox(
                color: theme.value.colors.surface,
                child: ShrinkAnimationButton(
                  defaultColor: fill.value,
                  onPressed: () {},
                  child: const SizedBox(height: 50, child: Center(child: Text('Focus'))),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<Uint8List> capture(String state) async =>
            (await tester.runAsync(() async {
              final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
              final image = await boundary.toImage(pixelRatio: 1);
              try {
                final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
                final png = await image.toByteData(format: ui.ImageByteFormat.png);
                final file = File('.omo/evidence/theme-buttons-focus/${theme.key}-${fill.key}-$state.png');
                await file.parent.create(recursive: true);
                await file.writeAsBytes(png!.buffer.asUint8List());
                return data!.buffer.asUint8List();
              } finally {
                image.dispose();
              }
            }))!;
        final before = await capture('normal');
        final bounds = tester.getRect(find.byType(ShrinkAnimationButton));
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        final focused = await capture('focused');
        expect(tester.getRect(find.byType(ShrinkAnimationButton)), bounds);
        Color pixel(Uint8List bytes, int y) {
          final offset = (y * 240 + 120) * 4;
          return Color.fromARGB(bytes[offset + 3], bytes[offset], bytes[offset + 1], bytes[offset + 2]);
        }

        final ring = pixel(focused, 1);
        expect(pixel(focused, 2), ring, reason: 'ring must extend two pixels inside the existing border');
        final surface = pixel(focused, 6);
        final a = ring.computeLuminance() + .05;
        final b = surface.computeLuminance() + .05;
        final ratio = a > b ? a / b : b / a;
        await tester.runAsync(
          () => File('.omo/evidence/theme-buttons-focus/${theme.key}-${fill.key}-contrast.txt').writeAsString(
            'ring=${ring.toARGB32().toRadixString(16)} surface=${surface.toARGB32().toRadixString(16)} contrast=$ratio\n',
          ),
        );
        expect(focused, isNot(orderedEquals(before)), reason: 'Tab must produce visible focus');
        expect(ratio, greaterThanOrEqualTo(3), reason: 'actual ring pixel must contrast with actual fill');
      });
    }

    testWidgets('${theme.key}: actual appearance primary CTA uses primary pressed overlay and restores', (
      tester,
    ) async {
      final key = GlobalKey();
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [theme.value]),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: RepaintBoundary(
                key: key,
                child: SizedBox(
                  width: 360,
                  child: WalletAppearanceSheet(
                    walletName: 'QA',
                    initialColorIndex: 0,
                    initialIconIndex: 0,
                    onDone: (_) => taps++,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<Uint8List> capture(String state) async =>
          (await tester.runAsync(() async {
            final image = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(
              pixelRatio: 1,
            );
            try {
              final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
              final png = await image.toByteData(format: ui.ImageByteFormat.png);
              final file = File('.omo/evidence/theme-buttons-appearance/${theme.key}-$state.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(png!.buffer.asUint8List());
              return data!.buffer.asUint8List();
            } finally {
              image.dispose();
            }
          }))!;
      final button = find.byType(ShrinkAnimationButton);
      final bounds = tester.getRect(button);
      final boundaryOrigin = tester.getTopLeft(find.byKey(key));
      final sample = Offset(bounds.center.dx, bounds.top + 10) - boundaryOrigin;
      final offset = (sample.dy.floor() * 360 + sample.dx.floor()) * 4;
      Color background(Uint8List pixels) =>
          Color.fromARGB(pixels[offset + 3], pixels[offset], pixels[offset + 1], pixels[offset + 2]);
      final normal = await capture('normal');
      expect(background(normal), theme.value.colors.buttonPrimaryBackground);
      final gesture = await tester.startGesture(bounds.center);
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 150));
      final held = await capture('held');
      final expected = Color.alphaBlend(
        theme.value.colors.buttonPrimaryPressOverlay.withValues(
          alpha: theme.value.colors.buttonPrimaryPressOverlayOpacity,
        ),
        theme.value.colors.buttonPrimaryBackground,
      );
      for (final shift in [0, 8, 16]) {
        expect(
          background(held).toARGB32() >> shift & 255,
          closeTo(expected.toARGB32() >> shift & 255, 1),
          reason: 'rendered primary fill must match the primary overlay within 8-bit raster rounding',
        );
      }
      expect(
        tester.widget<ScaleTransition>(find.descendant(of: button, matching: find.byType(ScaleTransition))).scale.value,
        closeTo(.97, .001),
      );
      expect(taps, 0);
      await gesture.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(await capture('restored'), orderedEquals(normal));
    });

    testWidgets('${theme.key}: disabled CTA has no tap action and cannot activate', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(host(InlineActionButton(text: 'Continue', isActive: false, onPressed: () => taps++)));
      final node = tester.getSemantics(find.byType(ShrinkAnimationButton)).getSemanticsData();
      expect(node.flagsCollection.isButton, isTrue);
      expect(node.flagsCollection.hasEnabledState, isTrue);
      expect(node.flagsCollection.isEnabled, isFalse);
      expect(node.hasAction(SemanticsAction.tap), isFalse);
      await tester.tap(find.text('Continue'));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(taps, 0);
      semantics.dispose();
    });

    testWidgets('${theme.key}: tap, hold, cancel and keyboard dispatch once', (tester) async {
      var taps = 0;
      var holds = 0;
      await tester.pumpWidget(
        host(
          ShrinkAnimationButton(
            onPressed: () => taps++,
            onLongPress: () => holds++,
            child: const SizedBox(height: 50, child: Text('Action')),
          ),
        ),
      );
      final button = find.byType(ShrinkAnimationButton);
      final held = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        tester.widget<ScaleTransition>(find.descendant(of: button, matching: find.byType(ScaleTransition))).scale.value,
        closeTo(.97, .001),
      );
      await held.up();
      await tester.pumpAndSettle();
      expect(taps, 1);
      final cancelled = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pump(const Duration(milliseconds: 100));
      await cancelled.cancel();
      await tester.pumpAndSettle();
      expect(taps, 1);
      final long = await tester.startGesture(tester.getCenter(button));
      await tester.pump(const Duration(milliseconds: 800));
      await long.up();
      await tester.pumpAndSettle();
      expect(holds, 1);
      expect(taps, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();
      expect(taps, 3);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${theme.key}: disabling a held button cancels and callback may unmount', (tester) async {
      var enabled = true;
      var visible = true;
      var taps = 0;
      late StateSetter update;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return visible
                  ? ShrinkAnimationButton(
                    isActive: enabled,
                    onPressed: () {
                      taps++;
                      update(() => visible = false);
                    },
                    child: const SizedBox(height: 50, child: Text('Action')),
                  )
                  : const SizedBox();
            },
          ),
        ),
      );
      final held = await tester.startGesture(tester.getCenter(find.text('Action')));
      await tester.pump(const Duration(milliseconds: 150));
      update(() => enabled = false);
      await tester.pump();
      await held.up();
      await tester.pumpAndSettle();
      expect(taps, 0);
      update(() => enabled = true);
      await tester.pump();
      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(find.text('Action'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${theme.key}: fixed CTA scales above its stable bottom anchor', (tester) async {
      Widget fixed(double scale) => host(
        SizedBox(
          height: 400,
          child: FixedBottomButton(
            text: 'Continue with this selected wallet',
            horizontalPadding: 0,
            onButtonClicked: () {},
          ),
        ),
        scale: scale,
      );
      await tester.pumpWidget(fixed(1));
      final normal = tester.getRect(find.byType(ShrinkAnimationButton));
      await tester.pumpWidget(fixed(2));
      final scaled = tester.getRect(find.byType(ShrinkAnimationButton));
      expect(scaled.bottom, normal.bottom);
      expect(scaled.height, greaterThan(normal.height));
      expect(tester.takeException(), isNull);
    });

    testWidgets('${theme.key}: selected row exposes state', (tester) async {
      final semantics = tester.ensureSemantics();
      for (final selected in [true, false]) {
        await tester.pumpWidget(host(SelectableSettingsRow(title: 'Theme', isSelected: selected, onTap: () {})));
        final node = tester.getSemantics(find.byType(ShrinkAnimationButton)).getSemanticsData();
        expect(node.flagsCollection.isSelected, selected);
        expect(node.flagsCollection.isButton, isTrue);
      }
      semantics.dispose();
    });

    testWidgets('${theme.key}: CTA retains base height and grows for large text', (tester) async {
      await tester.pumpWidget(host(InlineActionButton(text: 'Continue', onPressed: () {})));
      final normal = tester.getSize(find.byType(ShrinkAnimationButton)).height;
      // Host runs on macOS: 53 logical pixels plus the existing 1-pixel border on each edge.
      expect(normal, 55);
      await tester.pumpWidget(
        host(InlineActionButton(text: 'Continue with this selected wallet', onPressed: () {}), scale: 2),
      );
      expect(tester.getSize(find.byType(ShrinkAnimationButton)).height, greaterThan(normal));
      final context = tester.element(find.text('Continue with this selected wallet'));
      expect(MediaQuery.textScalerOf(context).scale(14), 28);
      expect(tester.takeException(), isNull);
    });

    testWidgets('${theme.key}: ripple preserves foreground pixels and restores after release and cancel', (
      tester,
    ) async {
      final boundaryKey = GlobalKey();
      var taps = 0;
      await tester.pumpWidget(
        host(
          RepaintBoundary(
            key: boundaryKey,
            child: Material(
              color: theme.value.colors.surface,
              child: RippleEffect(
                onTap: () => taps++,
                child: SizedBox(
                  height: 80,
                  child: Center(child: Text('Readable', style: TextStyle(color: theme.value.colors.primaryText))),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Future<Uint8List> pixels(String state) async =>
          (await tester.runAsync(() async {
            final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
            final image = await boundary.toImage(pixelRatio: 1);
            try {
              final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
              final png = await image.toByteData(format: ui.ImageByteFormat.png);
              final file = File('.omo/evidence/theme-buttons-ripple/${theme.key}-$state.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(png!.buffer.asUint8List());
              return rgba!.buffer.asUint8List();
            } finally {
              image.dispose();
            }
          }))!;

      final normal = await pixels('normal');
      final foreground = theme.value.colors.primaryText.toARGB32();
      final foregroundOffsets = <int>[];
      for (var offset = 0; offset < normal.length; offset += 4) {
        if (normal[offset] == (foreground >> 16 & 255) &&
            normal[offset + 1] == (foreground >> 8 & 255) &&
            normal[offset + 2] == (foreground & 255) &&
            normal[offset + 3] == 255) {
          foregroundOffsets.add(offset);
        }
      }
      expect(foregroundOffsets.length, greaterThan(100), reason: 'fixture must render actual opaque label pixels');

      for (final cancel in [false, true]) {
        final gesture = await tester.startGesture(tester.getCenter(find.byType(RippleEffect)));
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pump(const Duration(milliseconds: 300));
        final held = await pixels(cancel ? 'cancel-held' : 'tap-held');
        for (final offset in foregroundOffsets) {
          expect(
            held.sublist(offset, offset + 4),
            normal.sublist(offset, offset + 4),
            reason: 'pressed feedback must not dim foreground at pixel ${offset ~/ 4}',
          );
        }
        const backgroundOffset = (10 * 240 + 10) * 4;
        expect(
          held.sublist(backgroundOffset, backgroundOffset + 4),
          isNot(normal.sublist(backgroundOffset, backgroundOffset + 4)),
          reason: 'held background must visibly respond',
        );
        expect(taps, cancel ? 1 : 0);
        if (cancel) {
          await gesture.cancel();
        } else {
          await gesture.up();
        }
        await tester.pumpAndSettle();
        expect(await pixels(cancel ? 'cancel-restored' : 'tap-restored'), orderedEquals(normal));
        expect(taps, 1, reason: 'release activates once, cancellation never activates');
      }
    });
  }
}
