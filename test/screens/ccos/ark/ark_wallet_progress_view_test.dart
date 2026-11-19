import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_progress_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the spinner and its step sit above the middle of the screen', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
        home: const Scaffold(body: ArkWalletProgressView(step: ArkCreateStep.restoring)),
      ),
    );
    await tester.pump();

    expect(tester.getCenter(find.byType(CircularProgressIndicator)).dy, lessThan(874 * 0.4));
  });
}
