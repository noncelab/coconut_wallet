import 'package:coconut_design_system/coconut_design_system.dart' show CoconutPulldown;
import 'package:coconut_wallet/analytics/analytics_screen_observer.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/common/qr_with_copy_text_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Preferences extends Fake with ChangeNotifier implements PreferenceProvider {
  @override
  BitcoinUnit get currentUnit => BitcoinUnit.btc;
}

void main() {
  // The multisig backup data screen is the only QrWithCopyTextScreen with the format pulldown.
  Future<List<String>> pumpBackupScreen(WidgetTester tester) async {
    final logged = <String>[];
    final observer = AnalyticsScreenObserver(logScreenView: logged.add, nameExtractor: analyticsRouteScreenName);
    await tester.pumpWidget(
      ChangeNotifierProvider<PreferenceProvider>(
        create: (_) => _Preferences(),
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          navigatorObservers: [observer],
          onGenerateRoute:
              (_) => MaterialPageRoute<void>(
                settings: const RouteSettings(name: AppRouteNames.walletBackupData),
                builder:
                    (_) => const QrWithCopyTextScreen(
                      title: 'backup',
                      qrData: 'qa-a',
                      showPulldownMenu: true,
                      qrDataMap: {'BSMS': 'qa-a', 'Output Descriptor': 'qa-b'},
                    ),
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(logged, [AppRouteNames.walletBackupData]);
    return logged;
  }

  testWidgets('closing the format menu by tapping outside does not log the backup screen again', (tester) async {
    final logged = await pumpBackupScreen(tester);

    await tester.tap(find.byType(CoconutPulldown));
    await tester.pumpAndSettle();
    expect(find.text('Output Descriptor'), findsWidgets);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(find.text('Output Descriptor'), findsNothing);
    expect(logged, [AppRouteNames.walletBackupData]);
  });

  testWidgets('picking a format closes the menu without logging the backup screen again', (tester) async {
    final logged = await pumpBackupScreen(tester);

    await tester.tap(find.byType(CoconutPulldown));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Output Descriptor').last);
    await tester.pumpAndSettle();

    expect(find.byType(QrWithCopyTextScreen), findsOneWidget);
    expect(logged, [AppRouteNames.walletBackupData]);
  });
}
