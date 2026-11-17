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

// 에픽3의 정수 입력·BTC 편집 검사와 develop의 통화·기호·커서 회귀 검사를 함께 유지한다.
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

  testWidgets('fiat sheet cancel and unchanged selection preserve input and premium; a change resets them', (
    tester,
  ) async {
    await _pumpCalculator(tester, fiat: FiatCode.KRW);
    final field = _amountField();
    final calculator = _viewModelOf(tester, field);
    await _replaceAmount(tester, field, '1000');
    calculator.setPremiumRate(3);
    _editable(tester, field).focusNode.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(find.text('KRW'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect((calculator.fiatCode, calculator.inputAmount, calculator.premiumRate), (FiatCode.KRW, 1000, 3.0));
    expect(_textOf(tester, field), '1,000');

    await tester.tap(find.text('KRW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('KRW').hitTestable().last);
    await tester.pumpAndSettle();
    expect((calculator.fiatCode, calculator.inputAmount, calculator.premiumRate), (FiatCode.KRW, 1000, 3.0));
    expect(_textOf(tester, field), '1,000');

    await tester.tap(find.text('KRW'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('USD').hitTestable());
    await tester.pumpAndSettle();
    expect((calculator.fiatCode, calculator.inputAmount, calculator.premiumRate), (FiatCode.USD, null, 1.0));
    await tester.pumpWidget(const SizedBox.shrink());
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

    // 소수 0자리 통화는 소수점·부호·지수가 섞인 붙여넣기를 금액으로 바꾸지 않고 거부한다(1234.5 → 12,345로 커지지 않게).
    for (final fiat in [FiatCode.KRW, FiatCode.JPY, FiatCode.CLP, FiatCode.VND]) {
      testWidgets('${fiat.code} ${preset.name} rejects decimal, signed, and exponent paste', (tester) async {
        await _pumpCalculator(tester, fiat: fiat);
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
    }

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

  // sats·BIP-177은 에픽3의 정수 형식기를 쓰며, develop의 빈 칸 기호·쉼표 입력 커서 회귀도 막아야 한다.
  // 숫자 표시 설정은 화면을 띄우기 전에 바꾼다(띄운 뒤 바꾸면 한 글자씩 치는 흐름이 실제와 달라진다).
  for (final unit in [BitcoinUnit.sats, BitcoinUnit.bip177]) {
    for (final preset in NumberFormatPreset.values) {
      testWidgets('${unit.name} ${preset.name} keeps an empty amount empty when a non-digit is typed', (tester) async {
        NumberFormatConfig.instance.applyPreset(preset);
        await _pumpCalculator(tester, fiat: FiatCode.KRW, unit: unit);
        await _switchToBtcInput(tester);
        final field = _amountField();
        final viewModel = _viewModelOf(tester, field);
        await tester.showKeyboard(field);
        final controller = _editable(tester, field).controller;

        for (final typed in [',', '.', '-', 'abc']) {
          await _typeAtCaret(tester, controller, typed);
          expect(controller.text, isEmpty, reason: typed);
          expect(viewModel.inputAmount, isNull, reason: typed);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('${unit.name} commaDecimal keeps the caret at the end after "," and appends the next digit', (
      tester,
    ) async {
      NumberFormatConfig.instance.applyPreset(NumberFormatPreset.commaDecimal);
      await _pumpCalculator(tester, fiat: FiatCode.KRW, unit: unit);
      await _switchToBtcInput(tester);
      final field = _amountField();
      final viewModel = _viewModelOf(tester, field);
      await tester.showKeyboard(field);
      final controller = _editable(tester, field).controller;

      for (final digit in '1293456'.split('')) {
        await _typeAtCaret(tester, controller, digit);
      }
      expect(controller.text, '1.293.456');
      expect(controller.selection, const TextSelection.collapsed(offset: 9));
      expect(viewModel.inputAmount, 1293456);

      await _typeAtCaret(tester, controller, ',');
      expect(controller.text, '1.293.456');
      expect(controller.selection, const TextSelection.collapsed(offset: 9));
      expect(viewModel.inputAmount, 1293456);

      await _typeAtCaret(tester, controller, '7');
      expect(controller.text, '12.934.567');
      expect(controller.selection, const TextSelection.collapsed(offset: 10));
      expect(viewModel.inputAmount, 12934567);
      expect(tester.takeException(), isNull);
    });
  }

  group('통화 소수 자리별 입력', () {
    testWidgets('소수 3자리 통화(KWD): 3자리까지 받고 넷째 자리는 받지 않는다', (tester) async {
      await _pumpCalculator(tester, fiat: FiatCode.KWD);
      final field = _amountField();
      final viewModel = _viewModelOf(tester, field);
      await tester.showKeyboard(field);
      final controller = _editable(tester, field).controller;

      for (final char in '12.345'.split('')) {
        await _typeAtCaret(tester, controller, char);
      }
      expect(controller.text, '12.345');
      expect(viewModel.inputAmount, 12345);

      await _typeAtCaret(tester, controller, '6');
      expect(controller.text, '12.345');
      expect(viewModel.inputAmount, 12345);
      expect(tester.takeException(), isNull);
    });

    testWidgets('소수 2자리 통화(THB): 2자리까지 받고 셋째 자리는 받지 않는다', (tester) async {
      await _pumpCalculator(tester, fiat: FiatCode.THB);
      final field = _amountField();
      final viewModel = _viewModelOf(tester, field);
      await tester.showKeyboard(field);
      final controller = _editable(tester, field).controller;

      for (final char in '1234.56'.split('')) {
        await _typeAtCaret(tester, controller, char);
      }
      expect(controller.text, '1,234.56');
      expect(viewModel.inputAmount, 123456);
      await _typeAtCaret(tester, controller, '7');
      expect(controller.text, '1,234.56');
      expect(viewModel.inputAmount, 123456);
      expect(tester.takeException(), isNull);
    });

    for (final fiat in [FiatCode.KRW, FiatCode.VND]) {
      testWidgets('소수 0자리 통화(${fiat.code})가 아래 결과 칸일 때도 소수점·부호·지수가 섞인 입력을 받지 않는다', (tester) async {
        await _pumpCalculator(tester, fiat: fiat);
        await _switchToBtcInput(tester);
        final result = find.descendant(
          of: find.byKey(const Key('p2p-result-amount')),
          matching: find.byType(EditableText),
        );
        expect(result, findsOneWidget);
        final viewModel = _viewModelOf(tester, result);

        for (final pasted in ['1234.5', '-1000', '1e3', '1000,0']) {
          await _replaceAmount(tester, result, pasted);
          expect(viewModel.isEditingResult, isFalse, reason: pasted);
          expect(_textOf(tester, result), isEmpty, reason: pasted);
        }

        await _replaceAmount(tester, result, '1000');
        expect(viewModel.resultAmount, 1000);
        await _replaceAmount(tester, result, '1234.5');
        expect(viewModel.resultAmount, 1000);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

/// 컨트롤러의 지금 커서 자리에 [typed]를 넣은 것처럼 입력기 값을 보낸다(한 글자씩 치기).
Future<void> _typeAtCaret(WidgetTester tester, TextEditingController controller, String typed) async {
  final selection = controller.selection;
  final start = selection.isValid ? selection.start : controller.text.length;
  final end = selection.isValid ? selection.end : controller.text.length;
  final text = controller.text.replaceRange(start, end, typed);
  tester.testTextInput.updateEditingValue(
    TextEditingValue(text: text, selection: TextSelection.collapsed(offset: start + typed.length)),
  );
  await tester.pump();
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
