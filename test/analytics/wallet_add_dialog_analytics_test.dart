import 'dart:io';

import 'package:coconut_wallet/app/router/app_route_names.dart';
import 'package:coconut_wallet/app/router/route_args.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_dialog.dart';
import 'package:coconut_wallet/services/analytics_service.dart';
import 'package:coconut_wallet/services/feature/feature_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class _Analytics extends AnalyticsService {
  _Analytics() : super(null, true);

  final events = <Map<String, Object>>[];

  @override
  Future<void> logEvent({
    required String eventName,
    Map<String, Object>? parameters,
  }) async {
    events.add({
      'name': eventName,
      'parameters': parameters ?? <String, Object>{},
    });
  }
}

enum _Entry { topType, topWatchOnly, bottom, bottomReplacing, feature }

const _home = '/analytics-test-home';
const _owner = '/analytics-test-owner';

Future<NavigatorState> _mount(WidgetTester tester, _Analytics analytics) async {
  await tester.binding.setSurfaceSize(const Size(390, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final navigatorKey = GlobalKey<NavigatorState>();
  await tester.pumpWidget(
    Provider<AnalyticsService>.value(
      value: analytics,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
        onGenerateRoute:
            (settings) => MaterialPageRoute<void>(
              settings:
                  settings.name == '/'
                      ? const RouteSettings(name: _home)
                      : settings,
              builder:
                  (_) => Scaffold(
                    body: Text(settings.name == '/' ? _home : settings.name!),
                  ),
            ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final navigator = navigatorKey.currentState!;
  navigator.pushNamed(_owner);
  await tester.pumpAndSettle();
  return navigator;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(WalletAddDialog),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _open(
  WidgetTester tester,
  NavigatorState navigator,
  _Entry entry,
) async {
  switch (entry) {
    case _Entry.topType:
      WalletAddDialog.showTopSheet(
        navigator.context,
        WalletAddDialogMode.walletType,
      );
      await tester.pumpAndSettle();
      await _tap(
        tester,
        t.wallet_home_screen.wallet_type_selection.watch_only.title,
      );
    case _Entry.topWatchOnly:
      WalletAddDialog.showTopSheet(
        navigator.context,
        WalletAddDialogMode.watchOnlySource,
      );
    case _Entry.bottom:
    case _Entry.bottomReplacing:
      WalletAddDialog.showBottomSheet(
        navigator.context,
        WalletAddDialogMode.watchOnlySource,
        replaceCurrentRouteOnWalletSelected: entry == _Entry.bottomReplacing,
      );
    case _Entry.feature:
      FeatureRegistry.builtin().byId(FeatureIds.walletAddWatchOnly)!.launch!(
        navigator.context,
        null,
      );
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  const sources = {
    WalletImportSource.coconutVault: 'coconutVault',
    WalletImportSource.keystone: 'keystone',
    WalletImportSource.seedSigner: 'seedSigner',
    WalletImportSource.jade: 'jade',
    WalletImportSource.coldCard: 'coldCard',
    WalletImportSource.krux: 'krux',
    WalletImportSource.passport: 'passport',
    WalletImportSource.trezor: 'trezor',
    WalletImportSource.bitbox02: 'bitbox02',
    WalletImportSource.extendedPublicKey: 'extendedPublicKey',
  };

  for (final entry in _Entry.values) {
    for (final source in sources.entries) {
      testWidgets(
        '${entry.name}/${source.value} logs one source entry and preserves navigation',
        (tester) async {
          final analytics = _Analytics();
          final navigator = await _mount(tester, analytics);
          await _open(tester, navigator, entry);
          await _tap(tester, source.key.displayName);

          final destination = switch (source.key) {
            WalletImportSource.trezor =>
              Platform.isAndroid
                  ? AppRouteNames.trezorTransportSelect
                  : AppRouteNames.trezorBleConnect,
            WalletImportSource.bitbox02 => AppRouteNames.bitbox02Connect,
            _ => AppRouteNames.walletAddScanner,
          };
          final screen = find.text(destination);
          expect(screen, findsOneWidget);
          final settings = ModalRoute.of(tester.element(screen))!.settings;
          switch (source.key) {
            case WalletImportSource.bitbox02:
              expect(settings.arguments, isA<BitBox02ConnectRouteArgs>());
              expect(
                (settings.arguments! as BitBox02ConnectRouteArgs).importSource,
                WalletImportSource.bitbox02,
              );
            case WalletImportSource.trezor:
              expect(
                settings.arguments,
                Platform.isAndroid
                    ? isA<TrezorTransportSelectRouteArgs>()
                    : isA<TrezorBleConnectRouteArgs>(),
              );
            default:
              expect(settings.arguments, isA<WalletAddScannerRouteArgs>());
              expect(
                (settings.arguments! as WalletAddScannerRouteArgs)
                    .walletImportSource,
                source.key,
              );
          }

          final entered =
              analytics.events
                  .where(
                    (event) => event['name'] == 'wallet_add_screen_entered',
                  )
                  .toList();
          expect(entered, [
            {
              'name': 'wallet_add_screen_entered',
              'parameters': {'wallet_add_import_source': source.value},
            },
          ]);

          navigator.pop();
          await tester.pumpAndSettle();
          expect(
            find.text(entry == _Entry.bottomReplacing ? _home : _owner),
            findsOneWidget,
          );
          expect(navigator.canPop(), entry != _Entry.bottomReplacing);
          expect(find.byType(WalletAddDialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  for (final entry in [_Entry.topWatchOnly, _Entry.bottom]) {
    testWidgets('${entry.name} cancellation does not log source entry', (
      tester,
    ) async {
      final analytics = _Analytics();
      final navigator = await _mount(tester, analytics);
      await _open(tester, navigator, entry);
      navigator.pop();
      await tester.pumpAndSettle();

      expect(
        analytics.events.where(
          (event) => event['name'] == 'wallet_add_screen_entered',
        ),
        isEmpty,
      );
      expect(find.text(_owner), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
