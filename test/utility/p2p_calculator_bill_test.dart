import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/price_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/screens/settings/tools/p2p_calculator_screen.dart';
import 'package:coconut_wallet/widgets/common/buttons/coconut_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'p2p_calculator_test.dart'
    show FakePreferenceProvider, FakeConnectivityProvider, FakePriceProvider, FakeWalletProvider;

/// 계산기에 [input]을 넣고 거래 계산서를 연다(시세는 [price] 하나)
Future<void> _openBill(
  WidgetTester tester, {
  required FiatCode fiat,
  required int price,
  required String input,
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<PreferenceProvider>.value(value: FakePreferenceProvider(selectedFiat: fiat)),
        ChangeNotifierProvider<ConnectivityProvider>.value(value: FakeConnectivityProvider()),
        ChangeNotifierProvider<PriceProvider>.value(value: FakePriceProvider.withPrices({fiat: price})),
        ChangeNotifierProvider<WalletProvider>.value(value: FakeWalletProvider()),
      ],
      child: MaterialApp(
        theme: buildCoconutThemeData(),
        builder:
            (context, child) =>
                MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
        home: const P2PCalculatorScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final field = find.descendant(
    of: find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> && (w.key! as ValueKey<String>).value.startsWith('input_textfield_'),
    ),
    matching: find.byType(EditableText),
  );
  await tester.enterText(field, input);
  tester.widget<EditableText>(field).focusNode.unfocus();
  await tester.pumpAndSettle();
  await tester.tap(find.byWidgetPredicate((w) => w is CoconutAppBarActionButton && w.tooltip == null).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  // A-C1: 계산서의 프리미엄은 통화의 소수 자리를 따른다. 소수 3자리 통화(KWD·BHD)는 0.013까지 보이고, 괄호 안 sats와 같은
  // 금액을 가리킨다. 화면과 [모두 복사] 문구가 같다. 0·2자리 통화는 지금처럼 2자리까지(원화 "₩ 13", 엔화 10엔의 1%는
  // "¥ 0.10": 소수가 생기는 0자리 통화도 0으로 잘리지 않는다)
  for (final (fiat, price, input, premium) in [
    (FiatCode.KWD, 25000, '1.3', 'KD 0.013 (52 sats)'),
    (FiatCode.BHD, 25000, '1.3', 'BD 0.013 (52 sats)'),
    (FiatCode.KRW, 100000000, '1300', '₩ 13 (13 sats)'),
    (FiatCode.JPY, 100000, '10', '¥ 0.10 (100 sats)'),
  ]) {
    testWidgets('A-C1 ${fiat.code} bill premium reads "$premium" on screen and in the copied text', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      // 프리미엄 글만 보는 테스트라 글꼴과 상관없게 넓은 화면(430)에서 연다. 기본 테스트 글꼴은 글자마다 1em이라 엔화 출처
      // "비트플라이어 · 시각" 줄이 390에서는 한 줄을 넘는다
      await _openBill(tester, fiat: fiat, price: price, input: input, size: const Size(430, 932));
      expect(find.text(premium), findsOneWidget);
      await tester.tap(find.text(t.utility.p2p_calculator.copy_all));
      await tester.pump();
      expect(copied, contains('/ $premium'));
      // 복사 토스트가 사라질 때까지 흘려보낸다
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}
