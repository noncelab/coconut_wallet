import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/features/home/home_connection_status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  NetworkStatus status = NetworkStatus.online,
  bool reconnected = false,
  bool syncing = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: buildCoconutThemeData(),
      home: Scaffold(
        body: HomeConnectionStatusIndicator(networkStatus: status, showReconnected: reconnected, isSyncing: syncing),
      ),
    ),
  );
}

void main() {
  testWidgets('online and not syncing shows nothing', (tester) async {
    await _pump(tester);

    expect(find.byType(Text), findsNothing);
  });

  testWidgets('first sync in progress shows the updating label', (tester) async {
    await _pump(tester, syncing: true);

    expect(find.text(t.status_updating), findsOneWidget);
  });

  testWidgets('a connection error shows its message and wins over syncing', (tester) async {
    await _pump(tester, status: NetworkStatus.connectionFailed, syncing: true);

    expect(find.text(t.home_connection_status.electrum_connection_failed), findsOneWidget);
    expect(find.text(t.status_updating), findsNothing);
  });

  testWidgets('offline and VPN-blocked show their own messages', (tester) async {
    await _pump(tester, status: NetworkStatus.offline);
    expect(find.text(t.errors.network_disconnected), findsOneWidget);

    await _pump(tester, status: NetworkStatus.vpnBlocked);
    expect(find.text(t.errors.vpn_connected), findsOneWidget);
  });

  testWidgets('after recovery the restored message is shown', (tester) async {
    await _pump(tester, reconnected: true);

    expect(find.text(t.home_connection_status.electrum_connection_restored), findsOneWidget);
  });

  testWidgets('connection messages fit a narrow leading area in every locale', (tester) async {
    addTearDown(() => LocaleSettings.setLocaleSync(AppLocale.ko));

    for (final locale in AppLocale.values) {
      LocaleSettings.setLocaleSync(locale);
      for (final status in [
        NetworkStatus.connectionFailed,
        NetworkStatus.offline,
        NetworkStatus.vpnBlocked,
        NetworkStatus.online,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: buildCoconutThemeData(),
            home: Scaffold(
              body: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 120,
                  child: HomeConnectionStatusIndicator(
                    networkStatus: status,
                    showReconnected: status == NetworkStatus.online,
                    isSyncing: false,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));

        expect(tester.takeException(), isNull, reason: '$locale, $status');
        expect(tester.getSize(find.byType(HomeConnectionStatusIndicator)).width, lessThanOrEqualTo(120));
      }
    }
  });
}
