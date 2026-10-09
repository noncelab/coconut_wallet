import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/network_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/features/home/home_app_bar.dart';
import 'package:coconut_wallet/widgets/features/home/home_connection_status_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('all home app bar statuses keep three actions fixed across locales and widths', (tester) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      LocaleSettings.setLocaleSync(AppLocale.ko);
    });
    tester.view.devicePixelRatio = 1;

    for (final locale in AppLocale.values) {
      LocaleSettings.setLocaleSync(locale);
      final scenarios = <({NetworkStatus status, bool reconnected, bool syncing, String? message})>[
        (status: NetworkStatus.online, reconnected: false, syncing: false, message: null),
        (status: NetworkStatus.online, reconnected: false, syncing: true, message: t.status_updating),
        (status: NetworkStatus.offline, reconnected: false, syncing: false, message: t.errors.network_disconnected),
        (
          status: NetworkStatus.connectionFailed,
          reconnected: false,
          syncing: false,
          message: t.home_connection_status.electrum_connection_failed,
        ),
        (
          status: NetworkStatus.connectionFailed,
          reconnected: false,
          syncing: true,
          message: t.home_connection_status.electrum_connection_failed,
        ),
        (status: NetworkStatus.vpnBlocked, reconnected: false, syncing: false, message: t.errors.vpn_connected),
        (
          status: NetworkStatus.online,
          reconnected: true,
          syncing: false,
          message: t.home_connection_status.electrum_connection_restored,
        ),
        (
          status: NetworkStatus.online,
          reconnected: true,
          syncing: true,
          message: t.home_connection_status.electrum_connection_restored,
        ),
      ];

      for (final width in [320.0, 375.0, 430.0]) {
        tester.view.physicalSize = Size(width, 800);
        List<Rect>? baseline;

        for (final scenario in scenarios) {
          await tester.pumpWidget(
            MaterialApp(
              theme: buildCoconutThemeData(),
              home: Scaffold(
                body: CustomScrollView(
                  slivers: [
                    HomeAppBar(
                      networkStatus: scenario.status,
                      showReconnected: scenario.reconnected,
                      isSyncing: scenario.syncing,
                      isArranging: false,
                      addWalletButtonLink: LayerLink(),
                      onArrangeDone: () {},
                      onEdit: () {},
                      onAddWallet: () {},
                      onSettings: () {},
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 900)),
                  ],
                ),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 450));

          final label =
              '$locale, ${width.toInt()}px, ${scenario.status}, '
              'reconnected=${scenario.reconnected}, syncing=${scenario.syncing}';
          expect(tester.takeException(), isNull, reason: label);
          if (scenario.message == null) {
            expect(
              find.descendant(of: find.byType(HomeConnectionStatusIndicator), matching: find.byType(Text)),
              findsNothing,
              reason: label,
            );
          } else {
            expect(find.text(scenario.message!), findsOneWidget, reason: label);
          }

          final actions = [
            tester.getRect(find.byKey(const Key('home-edit-button'))),
            tester.getRect(find.byKey(const Key('home-add-wallet-button'))),
            tester.getRect(find.byKey(const Key('home-settings-button'))),
          ];
          baseline ??= actions;
          for (var i = 0; i < actions.length; i++) {
            expect(actions[i].left, closeTo(baseline[i].left, 0.01), reason: label);
            expect(actions[i].right, lessThanOrEqualTo(width), reason: label);
            expect(actions[i].width, 40, reason: label);
          }
          expect(
            tester.getRect(find.byType(HomeConnectionStatusIndicator)).right,
            lessThanOrEqualTo(actions.first.left),
            reason: label,
          );
        }
      }
    }
  });

  testWidgets('arranging mode shows Done instead of the three actions', (tester) async {
    for (final scenario in [
      (NetworkStatus.online, false, false),
      (NetworkStatus.online, false, true),
      (NetworkStatus.offline, false, false),
      (NetworkStatus.connectionFailed, false, false),
      (NetworkStatus.vpnBlocked, false, false),
      (NetworkStatus.online, true, false),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildCoconutThemeData(),
          home: Scaffold(
            body: CustomScrollView(
              slivers: [
                HomeAppBar(
                  networkStatus: scenario.$1,
                  showReconnected: scenario.$2,
                  isSyncing: scenario.$3,
                  isArranging: true,
                  addWalletButtonLink: LayerLink(),
                  onArrangeDone: () {},
                  onEdit: () {},
                  onAddWallet: () {},
                  onSettings: () {},
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('home-arrange-done')), findsOneWidget);
      expect(find.byType(HomeConnectionStatusIndicator), findsNothing);
      expect(find.byKey(const Key('home-edit-button')), findsNothing);
      expect(find.byKey(const Key('home-add-wallet-button')), findsNothing);
      expect(find.byKey(const Key('home-settings-button')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
