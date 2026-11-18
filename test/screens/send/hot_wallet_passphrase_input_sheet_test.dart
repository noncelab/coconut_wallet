import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/screens/send/hot_wallet_passphrase_input_sheet.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('visibility button sits at the field edge and toggles masking in place', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(),
        home: Scaffold(
          body: HotWalletPassphraseInputSheet(
            requiresAuthentication: false,
            showIncorrectError: true,
            onAuthenticationStarted: () async {},
            onPassphraseInputResumed: () {},
          ),
        ),
      ),
    );
    await tester.pump();
    final field = find.byType(CupertinoTextField);
    final toggle = find.byType(IconButton);
    final fieldRect = tester.getRect(field);
    expect(tester.getRect(toggle).right, fieldRect.right);
    expect(tester.getCenter(toggle).dy, fieldRect.center.dy);
    expect(tester.widget<CupertinoTextField>(field).obscureText, isTrue);

    await tester.enterText(field, 'test');
    for (final obscured in [false, true]) {
      await tester.tap(toggle);
      await tester.pump();
      final input = tester.widget<CupertinoTextField>(field);
      expect(input.obscureText, obscured);
      expect(input.controller!.text, 'test');
      expect(input.focusNode!.hasFocus, isTrue);
      expect(tester.getRect(toggle).right, fieldRect.right);
    }
  });
}
