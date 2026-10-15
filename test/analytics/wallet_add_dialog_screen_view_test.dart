import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/analytics/analytics_screen_observer.dart';
import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_dialog.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Analytics extends AnalyticsService {
  _Analytics() : super(null, true);
  final screens = <String>[];

  @override
  Future<void> logScreenView({required String screenName, Map<String, Object>? parameters}) async =>
      screens.add(screenName);
}

class _Auth extends Fake with ChangeNotifier implements AuthProvider {
  @override
  Future<bool> isDevicePasscodeSet() async => true;
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  testWidgets('wallet add top sheets log their names, with no wallet-home between two sheets', (tester) async {
    final analytics = _Analytics();
    late BuildContext home;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AnalyticsService>.value(value: analytics),
          ChangeNotifierProvider<AuthProvider>(create: (_) => _Auth()),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          // The app's observer (app.dart); named routes report their route name.
          navigatorObservers: [
            AnalyticsScreenObserver(logScreenView: (name) => analytics.logScreenView(screenName: name)),
          ],
          onGenerateRoute:
              (settings) => MaterialPageRoute<void>(
                // The app reports its root route as wallet-home (app.dart _extractAnalyticsScreenName).
                settings: settings.name == '/' ? const RouteSettings(name: AnalyticsScreenNames.walletHome) : settings,
                builder: (context) {
                  if (settings.name == '/') home = context;
                  return Scaffold(body: Text(settings.name ?? ''));
                },
              ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder inSheet(Finder finder) => find.descendant(of: find.byType(WalletAddDialog), matching: finder);
    Future<void> tap(Finder finder) async {
      await tester.tap(inSheet(finder));
      await tester.pumpAndSettle();
    }

    Future<void> openFromHome() async {
      WalletAddDialog.show(home, WalletAddDialogMode.walletType); // home + (HomeAddWalletOption.all)
      await tester.pumpAndSettle();
    }

    await openFromHome();
    await tap(find.text(t.wallet_home_screen.wallet_type_selection.watch_only.title));
    await tap(find.text(WalletImportSource.keystone.displayName));
    Navigator.of(home).pop();
    await tester.pumpAndSettle();

    await openFromHome();
    await tap(find.text(t.wallet_home_screen.wallet_type_selection.hot_wallet.title));
    await tap(find.text(t.wallet_home_screen.hot_wallet_add.create.title));
    Navigator.of(home).pop();
    await tester.pumpAndSettle();

    await openFromHome();
    await tap(find.byType(IconButton)); // close

    // ignore: avoid_print
    print({'screen_views': analytics.screens});
    expect(analytics.screens, [
      AnalyticsScreenNames.walletHome,
      AnalyticsScreenNames.walletHomeAddWalletTypeSheet,
      AnalyticsScreenNames.walletHomeAddWatchOnlySourceSheet, // straight from the type sheet
      AppRouteNames.walletAddScanner,
      AnalyticsScreenNames.walletHome,
      AnalyticsScreenNames.walletHomeAddWalletTypeSheet,
      AnalyticsScreenNames.walletHomeAddHotWalletActionSheet, // straight from the type sheet
      AppRouteNames.hotWalletCreate,
      AnalyticsScreenNames.walletHome,
      AnalyticsScreenNames.walletHomeAddWalletTypeSheet,
      AnalyticsScreenNames.walletHome, // closed
    ]);
  });
}
