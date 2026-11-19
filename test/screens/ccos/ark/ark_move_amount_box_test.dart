import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_move_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../ccos/features/ark/ark_test_fakes.dart';

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  Future<List<int?>> pump(WidgetTester tester, int? amount) async {
    final wallet = await fakeArkWalletProvider();
    await wallet.restore(Uint8List.fromList(utf8.encode('${'abandon ' * 11}about')));
    final entered = <int?>[];
    await tester.pumpWidget(
      ChangeNotifierProvider<ArkWalletProvider>.value(
        value: wallet,
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: Scaffold(
            body: ArkMoveAmountBox(
              label: 'amount',
              amountSats: amount,
              onAmount: entered.add,
              onMax: () => entered.add(-1),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return entered;
  }

  testWidgets('max sits inside the amount field', (tester) async {
    final entered = await pump(tester, null);
    final field = tester.getRect(find.byKey(const Key('ark-move-amount')));
    final max = tester.getRect(find.byKey(const Key('ark-move-max')));

    expect(field.contains(max.center), isTrue);
    await tester.tap(find.byKey(const Key('ark-move-max')));
    expect(entered, [-1]);
  });

  testWidgets('max keeps the dark button colour once an amount is in', (tester) async {
    await pump(tester, 5000);
    final context = tester.element(find.byKey(const Key('ark-move-max')));
    final button = tester.widget<CoconutButton>(find.byKey(const Key('ark-move-max')));

    expect(button.backgroundColor, context.coconutColors.surfaceButton);
  });

  testWidgets('an entered amount gets a clear button that empties it', (tester) async {
    final empty = await pump(tester, null);
    expect(find.bySemanticsLabel('Clear'), findsNothing);
    expect(empty, isEmpty);

    final entered = await pump(tester, 5000);
    await tester.tap(find.bySemanticsLabel('Clear'));
    expect(entered, [null]);
  });

  testWidgets('the field takes digits right away with grouping, no sheet', (tester) async {
    final entered = await pump(tester, null);

    await tester.enterText(find.byType(EditableText), '50000');
    await tester.pump();

    expect(find.text('50,000'), findsOneWidget);
    expect(entered.last, 50000);
    expect(find.byType(BottomSheet), findsNothing);
  });

  testWidgets('sats sits right after the number while only the number is edited', (tester) async {
    await pump(tester, 5000);

    final field = tester.state<EditableTextState>(find.byType(EditableText));
    expect(field.textEditingValue.text, '5,000');
    expect(field.buildTextSpan().toPlainText(), '5,000 sats');
  });
}
