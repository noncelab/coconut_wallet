import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_signed_amount.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  Future<void> pump(WidgetTester tester, BitcoinUnit unit) => tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
      home: Scaffold(body: Center(child: ArkSignedAmount(unit: unit, sats: -5010))),
    ),
  );

  testWidgets('the sign comes before ₿, as in the recent transaction rows', (tester) async {
    await pump(tester, BitcoinUnit.bip177);

    expect(tester.getTopLeft(find.text('-')).dx, lessThan(tester.getTopLeft(find.text('₿')).dx));
    expect(find.text('5,010'), findsOneWidget);
  });

  testWidgets('with sats the sign stays on the number and the unit follows', (tester) async {
    await pump(tester, BitcoinUnit.sats);

    expect(find.text('-5,010'), findsOneWidget);
    expect(find.text(BitcoinUnit.sats.symbol), findsOneWidget);
  });
}
