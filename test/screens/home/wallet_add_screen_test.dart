import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_actions.dart';
import 'package:coconut_wallet/screens/home/wallet_add/wallet_add_screen.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildCoconutThemeData(), home: const WalletAddScreen()));
}

void main() {
  testWidgets('offers watch-only (air-gapped, connected) and hot wallet (create, import) choices', (tester) async {
    await _pump(tester);

    expect(find.text(TextUtils.preventLineBreakInsideWords(t.wallet_add_screen.title)), findsOneWidget);
    expect(find.text(TextUtils.preventLineBreakInsideWords(t.wallet_add_screen.subtitle)), findsOneWidget);
    for (final key in [
      'wallet-add-air-gapped',
      'wallet-add-connected',
      'wallet-add-hot-create',
      'wallet-add-hot-restore',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(
      tester.getTopLeft(find.byKey(const Key('wallet-add-air-gapped'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const Key('wallet-add-hot-create'))).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('air-gapped and connected open their own device lists', (tester) async {
    await _pump(tester);

    await tester.tap(find.byKey(const Key('wallet-add-connected')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wallet-add-source-trezor')), findsOneWidget);
    expect(find.byKey(const ValueKey('wallet-add-source-keystone')), findsNothing);

    Navigator.of(tester.element(find.byKey(const ValueKey('wallet-add-source-trezor')))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wallet-add-air-gapped')));
    await tester.pumpAndSettle();
    for (final source in WalletAddActions.airGappedSources) {
      expect(find.byKey(ValueKey('wallet-add-source-${source.name}')), findsOneWidget, reason: source.name);
    }
    expect(find.byKey(const ValueKey('wallet-add-source-${'bitbox02'}')), findsNothing);
    expect(WalletAddActions.connectedSources, contains(WalletImportSource.bitbox02));
  });

  testWidgets('the full watch-only list splits air-gapped and connected devices under their own titles', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(find.text(t.feature_registry.wallet_add_watch_only));
    await tester.pumpAndSettle();

    final airGapped = tester.getTopLeft(find.text(t.wallet_add_screen.air_gapped)).dy;
    final connected = tester.getTopLeft(find.text(t.wallet_add_screen.connected)).dy;
    final keystone = tester.getTopLeft(find.byKey(const ValueKey('wallet-add-source-keystone'))).dy;
    final trezor = tester.getTopLeft(find.byKey(const ValueKey('wallet-add-source-trezor'))).dy;
    expect(airGapped, lessThan(keystone));
    expect(keystone, lessThan(connected));
    expect(connected, lessThan(trezor));
  });
}
