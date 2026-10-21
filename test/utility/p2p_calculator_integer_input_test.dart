import 'package:coconut_wallet/config/number_format_config.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/number_format_preset.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/view_model/utility/p2p_calculator_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/tools/p2p_calculator_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import 'p2p_calculator_test.dart'
    show FakePreferenceProvider, FakeConnectivityProvider, FakePriceProvider, FakeWalletProvider;

void main() {
  setUpAll(() async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    final font = FontLoader('Pretendard')..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
    await font.load();
    final numberFont = FontLoader('SpaceGrotesk')..addFont(rootBundle.load('assets/fonts/SpaceGrotesk-Regular.ttf'));
    await numberFont.load();
  });

  setUp(() {
    NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
  });

  tearDown(() {
    NumberFormatConfig.instance.applyPreset(NumberFormatPreset.dotDecimal);
  });

  for (final preset in NumberFormatPreset.values) {
    for (final p2pMode in [false, true]) {
      testWidgets('BTC ${preset.name} preserves the caret when refocus keeps the text in P2P mode $p2pMode', (
        tester,
      ) async {
        await _pumpCalculator(tester, fiat: FiatCode.KRW);
        NumberFormatConfig.instance.applyPreset(preset);
        await _switchToBtcInput(tester);
        if (p2pMode) {
          await tester.tap(find.byType(Lottie).first);
          await tester.pumpAndSettle();
        }
        final field = _amountField();
        final viewModel = _viewModelOf(tester, field);
        for (final input in ['12', '1${preset.decimalSeparator}2345']) {
          await _replaceAmount(tester, field, input);
          final amount = viewModel.inputAmount;
          final editable = _editable(tester, field);
          editable.focusNode.unfocus();
          await tester.pumpAndSettle();
          editable.controller.selection = const TextSelection.collapsed(offset: 1);
          editable.focusNode.requestFocus();
          await tester.pumpAndSettle();
          expect(editable.controller.text, input);
          expect(editable.controller.selection, const TextSelection.collapsed(offset: 1));
          expect(viewModel.inputAmount, amount);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });

      testWidgets('BTC ${preset.name} can delete after blur and refocus in P2P mode $p2pMode', (tester) async {
        await _pumpCalculator(tester, fiat: FiatCode.KRW);
        NumberFormatConfig.instance.applyPreset(preset);
        await _switchToBtcInput(tester);
        if (p2pMode) {
          await tester.tap(find.byType(Lottie).first);
          await tester.pumpAndSettle();
        }
        final field = _amountField();
        final viewModel = _viewModelOf(tester, field);
        expect(viewModel.isOfflineMode, p2pMode);
        final decimal = preset.decimalSeparator;

        await _replaceAmount(tester, field, '0${decimal}12345678');
        expect(viewModel.inputAmount, 12345678);
        _editable(tester, field).focusNode.unfocus();
        await tester.pumpAndSettle();
        expect(_textOf(tester, field), '0${decimal}1234 5678');

        await tester.showKeyboard(field);
        await tester.pumpAndSettle();
        expect(viewModel.inputAmount, 12345678, reason: 'Refocusing must preserve the amount');
        final controller = _editable(tester, field).controller;
        final beforeDelete = controller.text;
        controller.selection = TextSelection.collapsed(offset: beforeDelete.length);
        tester.testTextInput.updateEditingValue(
          TextEditingValue(
            text: beforeDelete.substring(0, beforeDelete.length - 1),
            selection: TextSelection.collapsed(offset: beforeDelete.length - 1),
          ),
        );
        await tester.pump();
        expect(viewModel.inputAmount, 12345670, reason: 'Backspace must remove the final fractional digit');
        expect(controller.text, '0${decimal}1234567');
        expect(controller.selection.extentOffset, controller.text.length);

        for (var remaining = 20; controller.text.isNotEmpty && remaining > 0; remaining--) {
          final next = controller.text.substring(0, controller.text.length - 1);
          tester.testTextInput.updateEditingValue(
            TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length)),
          );
          await tester.pump();
        }
        expect(controller.text, isEmpty);
        expect(viewModel.inputAmount, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }

    testWidgets('BTC ${preset.name} remains editable after swapping the focused fiat input', (tester) async {
      await _pumpCalculator(tester, fiat: FiatCode.KRW);
      NumberFormatConfig.instance.applyPreset(preset);
      await _replaceAmount(tester, _amountField(), '173');
      await _switchToBtcInput(tester);
      final field = _amountField();
      final viewModel = _viewModelOf(tester, field);
      expect(viewModel.inputAmount, 122);
      await tester.showKeyboard(field);
      await tester.pumpAndSettle();
      final controller = _editable(tester, field).controller;
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: controller.text.substring(0, controller.text.length - 1),
          selection: TextSelection.collapsed(offset: controller.text.length - 1),
        ),
      );
      await tester.pump();
      expect(viewModel.inputAmount, 120);
      controller.selection = TextSelection(baseOffset: 2, extentOffset: controller.text.length);
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: '0${preset.decimalSeparator}00000001',
          selection: const TextSelection.collapsed(offset: 10),
          composing: const TextRange(start: 2, end: 10),
        ),
      );
      await tester.pump();
      expect(viewModel.inputAmount, 1);
      expect(controller.text, '0${preset.decimalSeparator}00000001');
      expect(controller.selection.extentOffset, 10);
      expect(controller.value.composing, const TextRange(start: 2, end: 10));
      expect(tester.takeException(), isNull);
    });

    testWidgets('KRW ${preset.name} rejects decimal, signed, and exponent paste', (tester) async {
      await _pumpCalculator(tester, fiat: FiatCode.KRW);
      NumberFormatConfig.instance.applyPreset(preset);
      await tester.pump();
      final field = _amountField();
      final viewModel = _viewModelOf(tester, field);

      await _replaceAmount(tester, field, '1000.0');
      expect(viewModel.inputAmount, isNull);
      expect(_textOf(tester, field), isEmpty);

      await _replaceAmount(tester, field, '-1000');
      expect(viewModel.inputAmount, isNull);
      await _replaceAmount(tester, field, '1e3');
      expect(viewModel.inputAmount, isNull);
      await _replaceAmount(tester, field, '1000,0');
      expect(viewModel.inputAmount, isNull);

      await _replaceAmount(tester, field, '1000');
      expect(viewModel.inputAmount, 1000);
      expect(_textOf(tester, field), _grouped(1000, preset));

      await _replaceAmount(tester, field, _grouped(1000, preset));
      expect(viewModel.inputAmount, 1000);
      expect(_textOf(tester, field), _grouped(1000, preset));

      await _replaceAmount(tester, field, '1000.0');
      expect(viewModel.inputAmount, 1000);
      expect(_textOf(tester, field), _grouped(1000, preset));
      expect(tester.takeException(), isNull);
    });

    testWidgets('sats ${preset.name} keeps grouped edits and rejects magnified paste', (tester) async {
      await _pumpCalculator(tester, fiat: FiatCode.KRW, unit: BitcoinUnit.sats);
      NumberFormatConfig.instance.applyPreset(preset);
      await tester.pump();
      await _switchToBtcInput(tester);
      final field = _amountField();
      final viewModel = _viewModelOf(tester, field);
      expect(viewModel.inputAssetType, InputAssetType.btc);
      expect(viewModel.currentUnit.isBasedOnSatoshi, isTrue);

      await _replaceAmount(tester, field, '1000.0');
      expect(viewModel.inputAmount, isNull, reason: '1000.0 must not become the sats value sent onward');
      expect(_textOf(tester, field), isEmpty);

      await _replaceAmount(tester, field, '-1000');
      expect(viewModel.inputAmount, isNull);
      await _replaceAmount(tester, field, '1e3');
      expect(viewModel.inputAmount, isNull);

      await _replaceAmount(
        tester,
        field,
        const TextEditingValue(
          text: '1000',
          selection: TextSelection.collapsed(offset: 4),
          composing: TextRange(start: 0, end: 4),
        ),
      );
      final composingText = _textOf(tester, field);
      final composing = _editable(tester, field).controller.value.composing;
      expect(viewModel.inputAmount, 1000);
      expect(composingText, _grouped(1000, preset));
      expect(composing.isValid && !composing.isCollapsed, isTrue);

      await _replaceAmount(tester, field, _grouped(1000, preset));
      expect(viewModel.inputAmount, 1000);
      expect(_textOf(tester, field), _grouped(1000, preset));

      await _replaceAmount(tester, field, '1000.0');
      expect(viewModel.inputAmount, 1000);
      expect(_textOf(tester, field), _grouped(1000, preset));

      if (preset == NumberFormatPreset.dotDecimal) {
        final controller = _editable(tester, field).controller;
        controller.selection = const TextSelection.collapsed(offset: 1);
        await _replaceAmount(
          tester,
          field,
          const TextEditingValue(text: '19,000', selection: TextSelection.collapsed(offset: 2)),
        );
        expect(viewModel.inputAmount, 19000);
        expect(controller.text, '19,000');
        expect(controller.selection.extentOffset, 2);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('bip177 uses the same strict integer field', (tester) async {
    await _pumpCalculator(tester, fiat: FiatCode.KRW, unit: BitcoinUnit.bip177);
    await _switchToBtcInput(tester);
    final field = _amountField();
    final viewModel = _viewModelOf(tester, field);

    await _replaceAmount(tester, field, '1000.0');
    expect(viewModel.inputAmount, isNull);
    await _replaceAmount(tester, field, '1000');
    expect(viewModel.inputAmount, 1000);
    expect(_textOf(tester, field), '1,000');
    expect(tester.takeException(), isNull);
  });

  for (final preset in [NumberFormatPreset.dotDecimal, NumberFormatPreset.commaDecimal]) {
    testWidgets('USD ${preset.name} decimal fiat still accepts a fractional amount', (tester) async {
      await _pumpCalculator(tester, fiat: FiatCode.USD);
      NumberFormatConfig.instance.applyPreset(preset);
      await tester.pump();
      final field = _amountField();
      final viewModel = _viewModelOf(tester, field);
      final text = preset == NumberFormatPreset.dotDecimal ? '10.50' : '10,50';

      await _replaceAmount(tester, field, text);
      expect(viewModel.inputAmount, 1050);
      expect(_textOf(tester, field), text);

      final grouped = preset == NumberFormatPreset.dotDecimal ? '1,234.50' : '1.234,50';
      await _replaceAmount(tester, field, grouped);
      expect(viewModel.inputAmount, 123450);
      expect(_textOf(tester, field), grouped);
      expect(tester.takeException(), isNull);
    });

    testWidgets('BTC ${preset.name} keeps alternate-decimal and exact grouping', (tester) async {
      await _pumpCalculator(tester, fiat: FiatCode.KRW, unit: BitcoinUnit.btc);
      NumberFormatConfig.instance.applyPreset(preset);
      await tester.pump();
      await _switchToBtcInput(tester);
      final field = _amountField();
      final viewModel = _viewModelOf(tester, field);
      final quarter = preset == NumberFormatPreset.dotDecimal ? '0.25' : '0,25';

      await _replaceAmount(tester, field, quarter);
      expect(viewModel.inputAmount, 25000000);
      expect(_textOf(tester, field), quarter);

      if (preset == NumberFormatPreset.commaDecimal) {
        await _replaceAmount(tester, field, '1.2345');
        expect(viewModel.inputAmount, 123450000);
        expect(_textOf(tester, field), '1,2345');
        await _replaceAmount(tester, field, '1.000');
        expect(viewModel.inputAmount, 100000000000);
        expect(_textOf(tester, field), '1.000');
      }
      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _pumpCalculator(WidgetTester tester, {required FiatCode fiat, BitcoinUnit unit = BitcoinUnit.btc}) async {
  tester.view.physicalSize = const Size(828, 1792);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferenceProvider>.value(
          value: FakePreferenceProvider(selectedFiat: fiat, currentUnit: unit),
        ),
        ChangeNotifierProvider<ConnectivityProvider>.value(value: FakeConnectivityProvider()),
        ChangeNotifierProvider<PriceProvider>.value(value: FakePriceProvider(defaultPrice: 140000000)),
        ChangeNotifierProvider<WalletProvider>.value(value: FakeWalletProvider()),
      ],
      child: MaterialApp(theme: buildCoconutThemeData(), home: const P2PCalculatorScreen()),
    ),
  );
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

Future<void> _switchToBtcInput(WidgetTester tester) async {
  final swap = find.byWidgetPredicate((widget) => widget is SizedBox && widget.width == 52 && widget.height == 52);
  expect(swap, findsOneWidget);
  await tester.tap(swap);
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 5),
  );
}

Finder _amountField() {
  return find.descendant(
    of: find.byWidgetPredicate(
      (widget) =>
          widget.key is ValueKey<String> && (widget.key! as ValueKey<String>).value.startsWith('input_textfield_'),
    ),
    matching: find.byWidgetPredicate(
      (widget) => widget is EditableText && widget.focusNode.debugLabel != 'offline_input_mirror',
    ),
  );
}

EditableText _editable(WidgetTester tester, Finder field) => tester.widget<EditableText>(field);

String _textOf(WidgetTester tester, Finder field) => _editable(tester, field).controller.text;

P2PCalculatorViewModel _viewModelOf(WidgetTester tester, Finder field) {
  return Provider.of<P2PCalculatorViewModel>(tester.element(field), listen: false);
}

String _grouped(int value, NumberFormatPreset preset) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(preset.groupingSeparator);
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

Future<void> _replaceAmount(WidgetTester tester, Finder field, Object value) async {
  await tester.showKeyboard(field);
  final controller = _editable(tester, field).controller;
  final next =
      value is TextEditingValue
          ? value
          : TextEditingValue(text: value as String, selection: TextSelection.collapsed(offset: (value).length));
  if (controller.text.isNotEmpty && value is String) {
    controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
  }
  tester.testTextInput.updateEditingValue(next);
  await tester.pump();
}
