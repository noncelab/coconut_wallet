import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/model/feature/feature_item.dart';
import 'package:coconut_wallet/model/home/home_item.dart';
import 'package:coconut_wallet/services/home/home_item_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a wallet shortcut fades while there is no wallet and taps still reach the handler', (tester) async {
    final noWallets = ValueNotifier(true);
    final tapped = <String>[];
    final receive = ShortcutDefinition(
      FeatureItem(id: 'receive', label: () => 'Receive', context: FeatureContext.wallet),
      noWallets: noWallets,
      onTap: (_, feature) => tapped.add(feature.id),
    );
    final calculator = ShortcutDefinition(FeatureItem(id: 'calculator', label: () => 'Calc'), noWallets: noWallets);
    HomeItem item(String id) =>
        HomeItem(id: id, definitionId: 'shortcut:$id', kind: HomeItemKind.shortcut, order: 0, span: HomeSpan.shortcut);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Row(
          children: [
            SizedBox.square(
              dimension: 80,
              child: Builder(builder: (context) => receive.build(context, item('receive'))),
            ),
            SizedBox.square(
              dimension: 80,
              child: Builder(builder: (context) => calculator.build(context, item('calculator'))),
            ),
          ],
        ),
      ),
    );

    expect(find.byKey(const ValueKey('shortcut-receive-disabled')), findsOneWidget);
    expect(find.byKey(const ValueKey('shortcut-calculator-disabled')), findsNothing);
    await tester.tap(find.text('Receive'));
    expect(tapped, ['receive']);

    noWallets.value = false;
    await tester.pump();
    expect(find.byKey(const ValueKey('shortcut-receive-enabled')), findsOneWidget);
  });
}
