import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/tools/p2p_calculator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'p2p_calculator_test.dart'
    show FakePreferenceProvider, FakeConnectivityProvider, FakePriceProvider, FakeWalletProvider;

void main() {
  setUpAll(() async {
    final font = FontLoader('Pretendard')..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
    await font.load();
    final numberFont = FontLoader('SpaceGrotesk')..addFont(rootBundle.load('assets/fonts/SpaceGrotesk-Regular.ttf'));
    await numberFont.load();
  });
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
