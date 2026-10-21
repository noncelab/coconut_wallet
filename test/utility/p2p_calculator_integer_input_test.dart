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
    matching: find.byType(EditableText),
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
