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

// 정수 입력 테스트는 epic3 계산기 입력 수정과 함께 옮긴다. 여기에는 통화 선택 테스트만 둔다.
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
