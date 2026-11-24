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
  List<String> receivedOn = const [],
  String? invoice,
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
    receivedOnAddresses: receivedOn,
    inputVtxoIds: inputs,
    outputVtxoIds: outputs,
    exitedVtxoIds: const [],
    createdAt: at.toUtc().toIso8601String(),
    updatedAt: at.toUtc().toIso8601String(),
    completedAt: status == 'pending' ? null : at.toUtc().toIso8601String(),
    lightningInvoice: invoice,
  ),
);

const _describedInvoice =
    'lnbc1pvjluezsp5zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zyg3zygspp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqypqdpl2pkx2ctnv5sxxmmwwd5kgetjypeh2ursdae8g6twvus8g6rfwvs8qun0dfjkxaq9qrsgq357wnc5r2ueh7ck6q93dj32dlqnls087fxdwk8qakdyafkq3yap9us6v52vjjsrvywa6rt52cm9r9zqt8r2t7mlcwspyetp5h2tztugp9lfyql';

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

  testWidgets('chips filter the list to on-chain, Ark or Lightning rows, with each count', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final backend =
        FakeArkBackend()
          ..movements = [
            _movement(1, now),
            _movement(2, now, subsystem: 'bark.lightning_receive', invoice: _describedInvoice),
            _movement(3, now, subsystem: 'bark.board', amount: 1000),
            _movement(4, now, subsystem: 'bark.round', amount: -2),
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
    int rows() =>
        find
            .byWidgetPredicate(
              (w) => w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('recent-transactions-row-'),
            )
            .evaluate()
            .length;

    expect(rows(), 4);
    await tester.tap(find.byKey(const Key('ark-activity-filter-lightning')));
    await tester.pumpAndSettle();
    expect(rows(), 1);
    await tester.tap(find.byKey(const Key('ark-activity-filter-onchain')));
    await tester.pumpAndSettle();
    expect(rows(), 1);
    await tester.tap(find.byKey(const Key('ark-activity-filter-ark')));
    await tester.pumpAndSettle();
    expect(rows(), 2);
    await tester.tap(find.byKey(const Key('ark-activity-filter-all')));
    await tester.pumpAndSettle();
    expect(rows(), 4);
  });

  testWidgets('the filter chips stick under the app bar while the list scrolls', (tester) async {
    LocaleSettings.setLocaleSync(AppLocale.ko);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    final backend = FakeArkBackend()..movements = [for (var i = 1; i <= 30; i++) _movement(i, now)];
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
    final chip = find.byKey(const Key('ark-activity-filter-all'));
    final top = tester.getTopLeft(chip).dy;

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(chip).dy, top);
    expect(find.byKey(const Key('ark-activity-filter-fade')), findsNothing);
    expect(tester.getSize(find.byKey(const Key('ark-activity-filter-bar'))).width, 430);
    final bar = tester.widget<DecoratedBox>(find.byKey(const Key('ark-activity-filter-bar')));
    expect((bar.decoration as BoxDecoration).gradient, isA<LinearGradient>());
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
    expect(find.text('VTXO'), findsNothing);

    final box = find.byType(ArkInfoBox);
    final collapsed = tester.getSize(box).height;
    await tester.tap(find.byKey(const Key('ark-movement-details')));
    await tester.pumpAndSettle();
    final expanded = tester.getSize(box).height;

    await tester.tap(find.byKey(const Key('ark-movement-details')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(box).height, inExclusiveRange(collapsed, expanded));
    expect(find.text('VTXO'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.getSize(box).height, collapsed);
    expect(find.text('VTXO'), findsNothing);

    await tester.tap(find.byKey(const Key('ark-movement-details')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getSize(box).height, inExclusiveRange(collapsed, expanded));
    await tester.pumpAndSettle();
    expect(find.text('VTXO'), findsOneWidget);
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

  testWidgets('a Lightning receive shows the invoice memo apart from my own memo, and names the invoice', (
    tester,
  ) async {
    final movement = _movement(
      7,
      DateTime(2026, 11, 18, 10),
      subsystem: 'bark.lightning_receive',
      receivedOn: const [_describedInvoice],
      invoice: _describedInvoice,
    );
    await showExit(tester, movement, null);

    final box = find.byType(ArkInfoBox);
    expect(find.descendant(of: box, matching: find.text(t.ark_wallet.lightning_memo)), findsOneWidget);
    expect(find.descendant(of: box, matching: find.text('Please consider supporting this project')), findsOneWidget);
    expect(find.text(t.ark_wallet.memo), findsOneWidget);
    expect(find.text(t.ark_wallet.invoice), findsOneWidget);
    expect(find.text(t.ark_wallet.from), findsNothing);
    expect(find.text(t.ark_wallet.recipient), findsNothing);
  });

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
    expect(find.text('VTXO'), findsNothing);
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
    expect(find.text('VTXO'), findsNothing);
  });
}
