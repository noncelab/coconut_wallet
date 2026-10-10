import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/features/send/vault_receiving_address_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows edge fades only where more address text can be scrolled', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: VaultReceivingAddressField(
                address: 'bc1${'q' * 100}',
                placeholder: 'Select address',
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final left = find.byKey(const ValueKey('vault-address-left-fade'));
    final right = find.byKey(const ValueKey('vault-address-right-fade'));
    expect(left, findsNothing);
    expect(right, findsOneWidget);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(-80, 0));
    await tester.pumpAndSettle();
    expect(left, findsOneWidget);
    expect(right, findsOneWidget);
    expect(taps, 0);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(-2000, 0));
    await tester.pumpAndSettle();
    expect(left, findsOneWidget);
    expect(right, findsNothing);
    await tester.tap(find.byType(VaultReceivingAddressField));
    expect(taps, 1);
    expect(find.byType(EditableText), findsNothing);
  });
}
