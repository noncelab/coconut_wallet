import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_activity_groups.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_activity_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_movement_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../ccos/ccos_store_test_fakes.dart';
import '../../../ccos/features/ark/ark_test_fakes.dart';

ArkMovement _movement(int id, DateTime at, {String status = 'successful'}) => ArkMovement.fromBark(
  bark.Movement(
    id: id,
    status: status,
    subsystemName: 'bark.arkoor',
    subsystemKind: 'receive',
    metadataJson: '{}',
    intendedBalanceSats: 100,
    effectiveBalanceSats: 100,
    offchainFeeSats: 0,
    sentToAddresses: const [],
    receivedOnAddresses: const [],
    inputVtxoIds: const [],
    outputVtxoIds: const [],
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
    final backend = FakeArkBackend()..movements = [_movement(8, now), _movement(9, now, status: 'pending')];
    final wallet = await fakeArkWalletProvider(backend: backend);
    await wallet.createNew();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: FakeStorePreferences()),
          ChangeNotifierProvider<ArkWalletProvider>.value(value: wallet),
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

    await tester.tap(find.byKey(const ValueKey('recent-transactions-row-0')).last);
    await tester.pumpAndSettle();
    expect(find.byType(ArkMovementDetailScreen), findsOneWidget);
    expect(find.text(t.ark_wallet.status_received), findsOneWidget);

    await tester.tap(find.byKey(const Key('ark-movement-details')));
    await tester.pumpAndSettle();
    expect(find.text(t.ark_wallet.movement_id), findsOneWidget);

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
}
