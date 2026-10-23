import 'dart:io';
import 'dart:ui' as ui;

import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/tools/p2p_calculator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'p2p_calculator_test.dart'
    show FakePreferenceProvider, FakeConnectivityProvider, FakePriceProvider, FakeWalletProvider;

void main() {
  setUpAll(() async {
    final font =
        FontLoader('Pretendard')
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'))
          ..addFont(rootBundle.load('assets/fonts/Pretendard-Bold.ttf'));
    await font.load();
    final numberFont = FontLoader('SpaceGrotesk')..addFont(rootBundle.load('assets/fonts/SpaceGrotesk-Regular.ttf'));
    await numberFont.load();
  });
  testWidgets('amount stays visible and tappable after keyboard dismissal; both amounts edit', (tester) async {
    tester.view.physicalSize = const Size(828, 1792);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: FakePreferenceProvider()),
          ChangeNotifierProvider<ConnectivityProvider>.value(value: FakeConnectivityProvider()),
          ChangeNotifierProvider<PriceProvider>.value(value: FakePriceProvider(defaultPrice: 100000000)),
          ChangeNotifierProvider<WalletProvider>.value(value: FakeWalletProvider()),
        ],
        child: MaterialApp(theme: buildCoconutThemeData(), home: const P2PCalculatorScreen()),
      ),
    );
    await tester.pumpAndSettle();
    final amounts = find.byWidgetPredicate((w) => w is EditableText && w.style.fontSize == 28);
    expect(amounts, findsNWidgets(2));
    final top = amounts.first;
    final bottom = amounts.last;
    await tester.tap(top);
    await tester.pumpAndSettle();
    expect(tester.getSize(top).width, greaterThanOrEqualTo(48));
    await tester.enterText(top, '100000');
    await tester.pumpAndSettle();
    expect(tester.state<EditableTextState>(top).renderEditable.maxScrollExtent, 0);
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(top);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(bottom, '0.00198');
    await tester.pumpAndSettle();
    expect(tester.widget<EditableText>(top).controller.text, '200,000');
    expect(tester.widget<EditableText>(bottom).controller.text, '0.00198');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  for (final width in [320.0, 414.0]) {
    for (final scale in [1.0, 3.0]) {
      for (final checkCaret in [true, false]) {
        testWidgets('amount geometry caret=$checkCaret width $width scale $scale', (tester) async {
          tester.view.physicalSize = Size(width * 2, 1792);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<PreferenceProvider>.value(value: FakePreferenceProvider()),
                ChangeNotifierProvider<ConnectivityProvider>.value(value: FakeConnectivityProvider()),
                ChangeNotifierProvider<PriceProvider>.value(value: FakePriceProvider(defaultPrice: 140000000)),
                ChangeNotifierProvider<WalletProvider>.value(value: FakeWalletProvider()),
              ],
              child: MaterialApp(
                theme: buildCoconutThemeData(),
                builder:
                    (context, child) => MediaQuery(
                      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                      child: child!,
                    ),
                home: const RepaintBoundary(key: Key('p2p-geometry-capture'), child: P2PCalculatorScreen()),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final amounts = find.byWidgetPredicate((w) => w is EditableText && w.style.fontSize == 28);
          final top = amounts.first;
          final bottom = amounts.last;
          await tester.tap(top);
          await tester.pumpAndSettle();
          final topRender = tester.state<EditableTextState>(top).renderEditable;
          final unitRight = tester.getBottomRight(find.text('₩ ')).dx;
          final caretLeft =
              topRender.localToGlobal(topRender.getLocalRectForCaret(const TextPosition(offset: 0)).topLeft).dx;
          if (checkCaret) {
            expect(
              caretLeft - unitRight,
              inInclusiveRange(-1, 6),
              reason: 'Empty caret must sit beside the currency unit',
            );
          }
          expect(tester.getSize(top).width, greaterThanOrEqualTo(48));
          for (final text in ['0', '', '50000']) {
            await tester.enterText(top, text);
            await tester.pumpAndSettle();
            expect(tester.state<EditableTextState>(top).renderEditable.maxScrollExtent, 0);
            if (checkCaret && text != '50000') {
              final render = tester.state<EditableTextState>(top).renderEditable;
              final leading =
                  render.localToGlobal(render.getLocalRectForCaret(const TextPosition(offset: 0)).topLeft).dx;
              expect(leading - tester.getBottomRight(find.text('₩ ')).dx, inInclusiveRange(-1, 6));
            }
          }
          expect(tester.widget<EditableText>(top).controller.text, '50,000');
          expect(tester.widget<EditableText>(bottom).controller.text.replaceAll(' ', ''), '0.00035357');
          final evidence = Platform.environment['P2P_GEOMETRY_EVIDENCE'];
          if (evidence != null) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('p2p-geometry-capture')));
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
              final file = File('$evidence/krw50000-$width-$scale-$checkCaret.png');
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          final bottomRender = tester.state<EditableTextState>(bottom).renderEditable;
          expect(bottomRender.maxScrollExtent, 0, reason: 'Entire grouped BTC amount must fit after KRW50000');
          final end = bottomRender.getLocalRectForCaret(
            TextPosition(offset: tester.widget<EditableText>(bottom).controller.text.length),
          );
          expect(end.right, lessThanOrEqualTo(bottomRender.size.width + 1));
          await tester.enterText(bottom, '0.00099');
          await tester.pumpAndSettle();
          expect(tester.widget<EditableText>(top).controller.text, '140,000');
          expect(tester.state<EditableTextState>(bottom).renderEditable.maxScrollExtent, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        });
      }
    }
  }
  for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
    for (final preset in [NumberFormatPreset.dotDecimal, NumberFormatPreset.commaDecimal]) {
      final separator = preset.decimalSeparator;
      testWidgets(
        'premium fits editing, blur and offline mirror with $separator on $platform',
        (tester) async {
          tester.view.physicalSize = const Size(828, 1792);
          tester.view.devicePixelRatio = 2;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final originalSeparator = NumberFormatConfig.instance.decimalSeparator;
          final originalGroupingSeparator = NumberFormatConfig.instance.groupingSeparator;
          addTearDown(() {
            NumberFormatConfig.instance.decimalSeparator = originalSeparator;
            NumberFormatConfig.instance.groupingSeparator = originalGroupingSeparator;
          });
          NumberFormatConfig.instance.applyPreset(preset);
          await tester.pumpWidget(
            MultiProvider(
              providers: [
                ChangeNotifierProvider<PreferenceProvider>.value(value: FakePreferenceProvider()),
                ChangeNotifierProvider<ConnectivityProvider>.value(value: FakeConnectivityProvider()),
                ChangeNotifierProvider<PriceProvider>.value(value: FakePriceProvider(defaultPrice: 140000000)),
                ChangeNotifierProvider<WalletProvider>.value(value: FakeWalletProvider()),
              ],
              child: MaterialApp(
                theme: buildCoconutThemeData().copyWith(platform: platform),
                home: const P2PCalculatorScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final premium = find.byWidgetPredicate((w) => w is EditableText && w.controller.text == '1${separator}0');
          expect(premium, findsOneWidget);
          tester.widget<EditableText>(premium).focusNode.requestFocus();
          await tester.pumpAndSettle();
          final controller = tester.widget<EditableText>(premium).controller;
          final initialWidth = tester.getSize(premium).width;
          for (final text in ['1${separator}0', '99${separator}9', '44${separator}4', '', '1', '1$separator']) {
            final field = find.byWidgetPredicate((w) => w is EditableText && w.controller == controller);
            await tester.enterText(field, text);
            await tester.pumpAndSettle();
            final render = tester.state<EditableTextState>(field).renderEditable;
            expect(render.maxScrollExtent, 0, reason: 'All premium glyphs must fit for $text');
            expect(controller.text, text);
            expect(tester.getSize(field).width, initialWidth);
            tester.widget<EditableText>(field).focusNode.unfocus();
            await tester.pumpAndSettle();
            expect(tester.state<EditableTextState>(field).renderEditable.maxScrollExtent, 0);
            final expected =
                text.isEmpty
                    ? '0'
                    : text.endsWith(separator)
                    ? '${text}0'
                    : text.contains(separator)
                    ? text
                    : '$text${separator}0';
            expect(controller.text, expected);
          }
          final field = find.byWidgetPredicate((w) => w is EditableText && w.controller == controller);
          await tester.enterText(field, '99${separator}9');
          tester.widget<EditableText>(field).focusNode.unfocus();
          await tester.pumpAndSettle();
          await tester.tap(find.byType(Lottie).first);
          await tester.pumpAndSettle();
          final mirrored = find.byWidgetPredicate((w) => w is EditableText && w.controller == controller);
          expect(mirrored, findsNWidgets(2));
          for (final element in mirrored.evaluate()) {
            final matching = find.byElementPredicate((candidate) => identical(candidate, element));
            expect(tester.state<EditableTextState>(matching).renderEditable.maxScrollExtent, 0);
            expect((element.widget as EditableText).controller.text, '99${separator}9');
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        },
        variant: TargetPlatformVariant({platform}),
      );
    }
  }
}
