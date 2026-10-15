import 'package:coconut_wallet/app/theme/app_cupertino_theme.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/widgets/features/wallet/connect/wallet_connect_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final variant in CoconutThemeVariant.values) {
    for (final message in <String?>[null, '', 'Turn on Bluetooth.']) {
      testWidgets('error card preserves guidance on narrow large-text ${variant.name}, message=$message', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final colors = resolveCoconutThemeExtension(variant: variant).colors;
        await tester.pumpWidget(
          CupertinoApp(
            theme: buildAppCupertinoTheme(variant: variant),
            builder:
                (context, child) => Theme(
                  data: buildCoconutThemeData(variant: variant),
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!,
                  ),
                ),
            home: CupertinoPageScaffold(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: WalletConnectErrorCard(
                  title: 'Connection failed',
                  description: 'Check the cable and device, then try again.',
                  errorMessage: message,
                  steps: const ['Check the device connection.', 'Try connecting again.'],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Unknown error'), findsNothing);
        expect(find.text('Connection failed'), findsOneWidget);
        expect(find.text('Check the cable and device, then try again.'), findsOneWidget);
        expect(find.text('1. Check the device connection.', findRichText: true), findsOneWidget);
        expect(find.text('2. Try connecting again.', findRichText: true), findsOneWidget);
        expect(find.text('Turn on Bluetooth.'), message == null || message.isEmpty ? findsNothing : findsOneWidget);
        expect(tester.widget<Text>(find.text('Connection failed')).style?.color, colors.danger);
        expect(
          tester.widget<Text>(find.text('Check the cable and device, then try again.')).style?.color,
          colors.primaryText,
        );
        expect(tester.takeException(), isNull);
      });
    }
  }
}
