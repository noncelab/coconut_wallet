import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_wallet/ccos/features/ark/ark_exit.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_activity_groups.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_activity_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_movement_detail_screen.dart';
import 'package:coconut_wallet/widgets/common/buttons/copy_text_container.dart';
import 'package:coconut_wallet/widgets/features/ccos/ark/ark_info_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../ccos/ccos_store_test_fakes.dart';
import '../../../ccos/features/ark/ark_test_fakes.dart';

ArkMovement _movement(
  int id,
  DateTime at, {
  String status = 'successful',
  List<String> outputs = const [],
  String subsystem = 'bark.arkoor',
  int amount = 100,
  List<String> inputs = const [],
  List<String> sentTo = const [],
}) => ArkMovement.fromBark(
  bark.Movement(
    id: id,
    status: status,
    subsystemName: subsystem,
    subsystemKind: amount < 0 ? 'start' : 'receive',
    metadataJson: '{}',
    intendedBalanceSats: amount,
    effectiveBalanceSats: amount,
    offchainFeeSats: 0,
    sentToAddresses: sentTo,
    receivedOnAddresses: const [],
    inputVtxoIds: inputs,
    outputVtxoIds: outputs,
    exitedVtxoIds: const [],
    createdAt: at.toUtc().toIso8601String(),
    updatedAt: at.toUtc().toIso8601String(),
    completedAt: status == 'pending' ? null : at.toUtc().toIso8601String(),
  ),
);

void main() {
  test('pending comes first, then today, yesterday and older days, newest first', () {
    final now = DateTime(2026, 11, 18, 15);
    final groups = groupArkMovements([
      _movement(1, DateTime(2026, 11, 16, 9)),
      _movement(2, DateTime(2026, 11, 18, 10)),
      _movement(3, DateTime(2026, 11, 17, 20)),
      _movement(4, DateTime(2026, 11, 18, 12), status: 'pending'),
      _movement(5, DateTime(2026, 11, 18, 14)),
    ], now);

    expect(groups.map((group) => group.kind), [
      ArkActivityGroupKind.pending,
      ArkActivityGroupKind.today,
      ArkActivityGroupKind.yesterday,
      ArkActivityGroupKind.day,
    ]);
    expect(groups[1].movements.map((m) => m.id), [5, 2]);
    expect(groups.last.day, DateTime(2026, 11, 16));
  });

  testWidgets('the activity list opens a movement with its details', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final backend =
        FakeArkBackend()
          ..movements = [
            _movement(8, now, outputs: ['vtxo-a:0', 'vtxo-b:1']),
            _movement(9, now, status: 'pending'),
          ];
    final wallet = await fakeArkWalletProvider(backend: backend);
    await wallet.createNew();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: FakeStorePreferences()),
          ChangeNotifierProvider<ArkWalletProvider>.value(value: wallet),
          ...fakeArkPriceProviders(),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: const ArkActivityScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(t.ark_wallet.group_pending), findsOneWidget);
    expect(find.text(t.home_widgets.today), findsOneWidget);
    expect(find.textContaining(' · ${t.ark_wallet.route_ark}'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('recent-transactions-row-0')).last);
    await tester.pumpAndSettle();
    expect(find.byType(ArkMovementDetailScreen), findsOneWidget);
    expect(find.text(t.ark_wallet.status_received), findsNothing);
    expect(find.text('+ ₩ 0'), findsOneWidget);

    expect(find.text(t.ark_wallet.route), findsOneWidget);
    expect(find.text(t.ark_wallet.date), findsOneWidget);
    expect(find.text(t.ark_wallet.movement_id), findsNothing);

    await tester.tap(find.byKey(const Key('ark-movement-details')));
    await tester.pumpAndSettle();
    expect(find.text(t.ark_wallet.movement_id), findsOneWidget);
    expect(find.text('VTXO'), findsOneWidget);
    expect(find.text('vtxo-a:0\nvtxo-b:1'), findsOneWidget);
    expect(find.byType(CopyTextContainer), findsNothing);

    expect(find.text(t.ark_wallet.memo_add), findsOneWidget);
    await tester.tap(find.byKey(const Key('ark-movement-memo')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).last, 'Rent');
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.done));
    await tester.pumpAndSettle();

    expect(wallet.memoOf(8), 'Rent');
    expect(find.text('Rent'), findsOneWidget);
  });

  Future<ArkWalletProvider> showExit(WidgetTester tester, ArkMovement movement, ArkExitSession? exit) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final wallet = await fakeArkWalletProvider(backend: FakeArkBackend());
    await wallet.createNew();
    if (exit != null) await wallet.beginExit(exit);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: FakeStorePreferences()),
          ChangeNotifierProvider<ArkWalletProvider>.value(value: wallet),
          ...fakeArkPriceProviders(),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: ArkMovementDetailScreen(movement: movement),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ark-movement-details')));
    await tester.pumpAndSettle();
    return wallet;
  }

  ArkExitSession exitSession() => ArkExitSession(
    vtxoIds: const ['vtxo-x:0'],
    amountSats: 20000,
    destination: 'bcrt1qmine',
    fundingSats: 700,
    feeRateSatPerVb: 1,
    firstExpiryHeight: null,
    startedAt: DateTime(2026, 11, 18),
    fundingFeeSats: 141,
  );

  testWidgets('a finished exit shows what left, what arrived, the fee paid and the claim transaction', (tester) async {
    final movement = _movement(
      15,
      DateTime.now(),
      subsystem: 'bark.exit',
      amount: -20000,
      inputs: const ['vtxo-x:0'],
      sentTo: const ['{"type":"bitcoin","value":"bcrt1pbarkinternal"}'],
    );
    await showExit(
      tester,
      movement,
      exitSession().copyWith(
        phase: ArkExitPhase.done,
        feeReturned: true,
        receivedSats: 19882,
        claimTxid: 'claimtxid',
        returnedSats: 400,
      ),
    );

    expect(find.text(t.ark_wallet.exit_amount_done), findsOneWidget);
    expect(find.text(t.ark_wallet.exit_received), findsOneWidget);
    expect(find.text('19,882 sats'), findsOneWidget);
    expect(find.text('${141 + 700 - 400 + 118} sats'), findsOneWidget);
    expect(find.text(t.tx_id), findsOneWidget);
    expect(find.text('claimtxid'), findsOneWidget);
    expect(find.byType(ArkCopyRow), findsNWidgets(2));
    expect(find.byType(CopyTextContainer), findsNothing);
    expect(find.text('bcrt1qmine'), findsOneWidget);
    expect(find.text(t.ark_wallet.from), findsOneWidget);
    expect(find.text(t.ark_wallet.recipient), findsNothing);
    expect(find.text('bcrt1pbarkinternal'), findsNothing);
    expect(find.text(t.ark_wallet.sent_amount), findsNothing);
    expect(find.text(t.ark_wallet.movement_id), findsNothing);
  });

  testWidgets('an exit still running or made before records has no fee or transaction yet', (tester) async {
    final movement = _movement(
      15,
      DateTime.now(),
      status: 'pending',
      subsystem: 'bark.exit',
      amount: -20000,
      inputs: const ['vtxo-x:0'],
    );
    await showExit(tester, movement, exitSession().copyWith(phase: ArkExitPhase.waiting));

    expect(find.text(t.ark_wallet.exit_amount_done), findsOneWidget);
    expect(find.text('bcrt1qmine'), findsOneWidget);
    expect(find.text(t.ark_wallet.recipient), findsOneWidget);
    expect(find.text(t.fee), findsNothing);
    expect(find.text(t.ark_wallet.exit_received), findsNothing);
    expect(find.text(t.tx_id), findsNothing);
    expect(find.text(t.ark_wallet.movement_id), findsNothing);
  });
}
