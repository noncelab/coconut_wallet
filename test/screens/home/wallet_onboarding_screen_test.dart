import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/home/wallet_onboarding_screen.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('opening a wallet feature without wallets explains what a wallet unlocks and offers to add one', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final registry = FeatureRegistry.builtin();
    final send = registry.byId(FeatureIds.send)!;

    await tester.pumpWidget(
      MaterialApp(theme: buildCoconutThemeData(), home: WalletOnboardingScreen(feature: send, registry: registry)),
    );

    expect(find.text(t.wallet_onboarding.subtitle), findsOneWidget);
    expect(find.text(send.label()), findsOneWidget);
    for (final description in [
      t.wallet_onboarding.receive,
      t.wallet_onboarding.send,
      t.wallet_onboarding.organize,
      t.wallet_onboarding.insights,
    ]) {
      expect(find.text(description), findsOneWidget);
    }
    expect(find.text(t.wallet_onboarding.add_first_wallet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
