import 'dart:convert';
import 'dart:typed_data';

import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_send_view_model.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_send_confirm_screen.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_info_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../ccos/ccos_store_test_fakes.dart';
import '../../../ccos/features/ark/ark_test_fakes.dart';

const _ark =
    'tark1pqma5v23zqqp5z47f6anpx0lp5vu757p3cnxzqx887t8zl3wacuvdgyeyee2puh3zqypf2680f7z8zau5ukptjaa7suxu0vadk0ncdyw4qdeazs9u29fddycffu4m9';
const _invoice =
    'lnbcrt300u1p4dtlwusp5nptqcasatxvy082yctgkamwtewxfdnuh3eemk48utk2cp6zz9umspp50rc6tq4889yrpqt5tlmssthes5qxrfzh3qh93fqm8h00j3sav27sdqqxqy9gcqcqzgq9qyysgqcjnlnm5mwfsf09uvnjraxzwj04c2l9gtduntevk95pec3vvkglv9wqu57rnw3mz8t37add2fsrs44llju7ncaty67ay3d2x9kayxxcsqertrwr';

class _Auth extends Fake implements AuthProvider {
  @override
  bool get isAuthEnabled => false;
}

ArkMovement _pending(int id, {String status = 'pending'}) => ArkMovement.fromBark(
  bark.Movement(
    id: id,
    status: status,
    subsystemName: 'bark.arkoor',
    subsystemKind: 'send',
    metadataJson: '{}',
    intendedBalanceSats: -1000,
    effectiveBalanceSats: -1000,
    offchainFeeSats: 0,
    sentToAddresses: const [],
    receivedOnAddresses: const [],
    inputVtxoIds: const [],
    outputVtxoIds: const [],
    exitedVtxoIds: const [],
    createdAt: DateTime(2026, 11, 19).toUtc().toIso8601String(),
    updatedAt: DateTime(2026, 11, 19).toUtc().toIso8601String(),
  ),
);

void main() {
  setUp(() {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    NetworkType.setNetworkType(NetworkType.regtest);
  });

  Future<FakeArkBackend> pump(WidgetTester tester, {String input = _ark}) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final backend =
        FakeArkBackend()
          ..currentBalance = const ArkBalance(
            spendable: 100000,
            pendingInRound: 0,
            pendingBoard: 0,
            pendingExit: 0,
            pendingLightningSend: 0,
            claimableLightningReceive: 0,
          );
    final wallet = await fakeArkWalletProvider(backend: backend);
    await wallet.restore(Uint8List.fromList(utf8.encode('${'abandon ' * 11}about')));
    final viewModel = ArkSendViewModel(wallet, network: NetworkType.regtest, feeDelay: Duration.zero)..setInput(input);
    viewModel.setAmount(1000);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: FakeStorePreferences()),
          ChangeNotifierProvider<ArkWalletProvider>.value(value: wallet),
          InheritedProvider<AuthProvider>.value(value: _Auth()),
          ...fakeArkPriceProviders(),
          ChangeNotifierProvider<ArkSendViewModel>.value(value: viewModel),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: const ArkSendConfirmScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    return backend;
  }

  Future<void> send(WidgetTester tester) async {
    await tester.tap(find.text(t.send).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('confirm opens with a moving arrow, then the title and amount in the middle', (tester) async {
    await pump(tester);

    expect(find.byKey(const Key('ark-send-icon-arrow')), findsOneWidget);
    final title = tester.widget<Text>(find.text(t.ark_wallet.confirm_ark));
    expect(title.textAlign, TextAlign.center);
    expect(tester.getCenter(find.text(t.ark_wallet.confirm_ark)).dx, 215);
    final firstRow = tester.widgetList<ArkInfoRow>(find.byType(ArkInfoRow)).first;
    expect(firstRow.label, t.ark_wallet.route);
    final feeRow = tester.widgetList<ArkInfoRow>(find.byType(ArkInfoRow)).firstWhere((row) => row.label == t.fee);
    final unit = Provider.of<ArkWalletProvider>(tester.element(find.byType(ArkSendConfirmScreen)), listen: false).unit;
    expect(feeRow.value, unit.displayBitcoinAmount(0, withUnit: true));
  });

  testWidgets('the box starts at the same height for Ark and Lightning', (tester) async {
    await pump(tester);
    final arkTop = tester.getTopLeft(find.byType(ArkInfoBox)).dy;
    await pump(tester, input: _invoice);

    expect(tester.getTopLeft(find.byType(ArkInfoBox)).dy, arkTop);
  });

  testWidgets('sending stays on the same screen: the top keeps its place and only the state changes', (tester) async {
    final backend = await pump(tester);
    backend.movements = [_pending(99)];
    final iconTop = tester.getTopLeft(find.byKey(const Key('ark-send-icon-arrow')));
    final titleTop = tester.getTopLeft(find.text(t.ark_wallet.confirm_ark));

    await send(tester);

    expect(find.byType(ArkSendConfirmScreen), findsOneWidget);
    expect(find.text(t.ark_wallet.result_pending), findsOneWidget);
    expect(tester.getTopLeft(find.byKey(const Key('ark-send-icon-arrow'))), iconTop);
    expect(tester.getTopLeft(find.text(t.ark_wallet.result_pending)), titleTop);
    expect(find.byKey(ValueKey(t.ark_wallet.result_pending_desc)), findsNothing);
    expect(find.text(t.done), findsOneWidget);
  });

  testWidgets('while sending over Lightning, a ring turns slowly around the bolt and the box stays put', (
    tester,
  ) async {
    final backend = await pump(tester, input: _invoice);
    backend.movements = [_pending(99)];
    final boxTop = tester.getTopLeft(find.byType(ArkInfoBox));
    await send(tester);

    expect(tester.getTopLeft(find.byType(ArkInfoBox)), boxTop);

    expect(find.byKey(const Key('ark-send-icon-progress')), findsOneWidget);
    expect(find.byKey(ValueKey(t.ark_wallet.result_pending_desc)), findsOneWidget);
    final ring = tester.widget<RotationTransition>(
      find.descendant(of: find.byKey(const Key('ark-send-icon-progress')), matching: find.byType(RotationTransition)),
    );
    final start = ring.turns.value;
    await tester.pump(const Duration(milliseconds: 500));
    expect(ring.turns.value - start, closeTo(0.25, 0.01));
  });

  testWidgets('a Lightning payment that settles later turns into sent on the same screen', (tester) async {
    final backend = await pump(tester, input: _invoice);
    backend.movements = [_pending(99)];
    await send(tester);
    expect(find.text(t.ark_wallet.result_pending), findsOneWidget);

    backend.movements = [_pending(99, status: 'successful')];
    await Provider.of<ArkWalletProvider>(tester.element(find.byType(ArkSendConfirmScreen)), listen: false).syncNow();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text(t.ark_wallet.result_sent), findsOneWidget);
    expect(find.byKey(ValueKey(t.ark_wallet.result_pending_desc)), findsNothing);
  });

  testWidgets('a sent payment shows the sent icon', (tester) async {
    await pump(tester);
    await send(tester);

    expect(find.text(t.ark_wallet.result_sent), findsOneWidget);
    expect(find.byKey(const Key('ark-send-icon-${FeatureArkIconPath.txSent}')), findsOneWidget);
  });

  testWidgets('a failed payment shows a warning without moving the box', (tester) async {
    final backend = await pump(tester);
    backend.sendError = 'boom';
    final boxTop = tester.getTopLeft(find.byType(ArkInfoBox));
    await send(tester);

    expect(tester.getTopLeft(find.byType(ArkInfoBox)), boxTop);

    expect(find.text(t.ark_wallet.result_failed), findsOneWidget);
    expect(find.byKey(const Key('ark-send-result-failed')), findsOneWidget);
  });
}
