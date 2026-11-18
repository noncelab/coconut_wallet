import 'dart:convert';
import 'dart:typed_data';

import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_design_system/coconut_design_system.dart' show CoconutButton, CoconutSwitch;
import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_wallet_home_view_model.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_home_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_settings_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_vtxo_list_screen.dart';
import 'package:coconut_wallet/services/security/hot_wallet_authenticator.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../../ccos/ccos_store_test_fakes.dart';
import '../../../ccos/features/ark/ark_test_fakes.dart';

class _Auth extends Fake implements AuthProvider {
  @override
  bool get isAuthEnabled => false;
}

ArkMovement _movement(int id, {int sats = 1000}) => ArkMovement.fromBark(
  bark.Movement(
    id: id,
    status: 'successful',
    subsystemName: 'bark.arkoor',
    subsystemKind: sats < 0 ? 'send' : 'receive',
    metadataJson: '{}',
    intendedBalanceSats: sats,
    effectiveBalanceSats: sats,
    offchainFeeSats: 0,
    sentToAddresses: const [],
    receivedOnAddresses: const [],
    inputVtxoIds: const [],
    outputVtxoIds: const [],
    exitedVtxoIds: const [],
    createdAt: '2026-11-1${id % 9}T10:00:00Z',
    updatedAt: '2026-11-18T10:00:00Z',
  ),
);

class _Authenticator implements HotWalletAuthenticator {
  _Authenticator(this.result);

  final bool result;

  @override
  Future<bool> authenticate() async => result;
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  Future<ArkWalletProvider> walletWith({
    required bool restored,
    int sats = 0,
    int movements = 0,
    void Function(FakeArkBackend backend)? setup,
  }) async {
    final backend =
        FakeArkBackend()
          ..movements = [for (var i = 1; i <= movements; i++) _movement(i)]
          ..currentBalance = ArkBalance(
            spendable: sats,
            pendingInRound: 0,
            pendingBoard: 0,
            pendingExit: 0,
            pendingLightningSend: 0,
            claimableLightningReceive: 0,
          );
    final wallet = await fakeArkWalletProvider(backend: backend);
    restored
        ? await wallet.restore(Uint8List.fromList(utf8.encode('${'abandon ' * 11}about')))
        : await wallet.createNew();
    if (setup != null) {
      setup(backend);
      await wallet.syncNow();
    }
    return wallet;
  }

  Future<void> pump(WidgetTester tester, ArkWalletProvider wallet, {Size size = const Size(430, 932)}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: FakeStorePreferences()),
          ChangeNotifierProvider<ArkWalletProvider>.value(value: wallet),
          InheritedProvider<AuthProvider>.value(value: _Auth()),
          ...fakeArkPriceProviders(),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: const ArkWalletHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('receive and send sit side by side and send needs a balance', (tester) async {
    await pump(tester, await walletWith(restored: true));

    expect(find.byKey(const Key('ark-wallet-receive')), findsOneWidget);
    expect(tester.widget<CoconutButton>(find.byKey(const Key('ark-wallet-send'))).isActive, isFalse);
  });

  testWidgets('with a balance send is active', (tester) async {
    await pump(tester, await walletWith(restored: true, sats: 1000));

    expect(tester.widget<CoconutButton>(find.byKey(const Key('ark-wallet-send'))).isActive, isTrue);
  });

  testWidgets('recent activity fills a tall screen with five rows', (tester) async {
    await pump(tester, await walletWith(restored: true, movements: 6), size: const Size(402, 874));

    expect(find.byKey(const ValueKey('recent-transactions-row-4')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-transactions-row-5')), findsNothing);
    expect(find.text(t.view_more), findsOneWidget);
  });

  testWidgets('recent activity shows only the transactions there are, without placeholders', (tester) async {
    await pump(tester, await walletWith(restored: true, movements: 2), size: const Size(402, 874));

    expect(find.byKey(const ValueKey('recent-transactions-row-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-transactions-row-2')), findsNothing);
    expect(find.byKey(const Key('recent-transactions-waiting')), findsNothing);
  });

  testWidgets('without transactions it says there are none yet', (tester) async {
    await pump(tester, await walletWith(restored: true));

    expect(find.text(t.ark_wallet.no_activity), findsOneWidget);
  });

  testWidgets('recent activity keeps three rows on a short screen', (tester) async {
    await pump(tester, await walletWith(restored: true, movements: 6), size: const Size(375, 560));

    expect(find.byKey(const ValueKey('recent-transactions-row-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('recent-transactions-row-3')), findsNothing);
  });

  testWidgets('a new wallet shows the backup prompt', (tester) async {
    await pump(tester, await walletWith(restored: false));

    expect(find.text(t.ark_wallet.backup_title), findsOneWidget);
  });

  testWidgets('a restored wallet shows no backup prompt', (tester) async {
    await pump(tester, await walletWith(restored: true));

    expect(find.text(t.ark_wallet.backup_title), findsNothing);
  });

  testWidgets('the balance follows the unit setting', (tester) async {
    await pump(tester, await walletWith(restored: true, sats: 12345));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text(t.ark_wallet.balance_label), findsOneWidget);
    expect(find.textContaining(BitcoinUnit.sats.displayBitcoinAmount(12345)), findsOneWidget);
    expect(find.text(BitcoinUnit.sats.symbol), findsOneWidget);
  });

  testWidgets('the gear opens settings with the mnemonic backup row', (tester) async {
    await pump(tester, await walletWith(restored: false));

    await tester.tap(find.byKey(const Key('ark-wallet-settings')));
    await tester.pumpAndSettle();

    expect(find.byType(ArkWalletSettingsScreen), findsOneWidget);
    expect(find.text(t.wallet_info_screen.mnemonic_backup), findsOneWidget);
    expect(find.text(t.wallet_info_screen.backup_required), findsOneWidget);
  });

  Future<void> openSettings(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('ark-wallet-settings')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(t.wallet_info_screen.delete_wallet));
    await tester.pumpAndSettle();
  }

  testWidgets('deleting an empty wallet asks first, then returns to the start view', (tester) async {
    final wallet = await walletWith(restored: true);
    await pump(tester, wallet);
    await openSettings(tester);

    expect(
      find.text(TextUtils.preventLineBreakInsideWords(t.alert.wallet_delete.confirm_delete_description)),
      findsOneWidget,
    );
    await tester.tap(find.text(t.delete));
    await tester.pumpAndSettle();

    expect(wallet.hasWallet, isFalse);
    expect(find.byType(ArkWalletSettingsScreen), findsNothing);
    expect(find.text(t.ark_wallet.create_new), findsOneWidget);
  });

  testWidgets('a wallet with balance cannot be deleted', (tester) async {
    final wallet = await walletWith(restored: true, sats: 1000);
    await pump(tester, wallet);
    await openSettings(tester);

    expect(find.text(TextUtils.preventLineBreakInsideWords(t.ark_wallet.delete_blocked_title)), findsOneWidget);
    expect(
      find.text(TextUtils.preventLineBreakInsideWords(t.alert.wallet_delete.confirm_delete_description)),
      findsNothing,
    );
    expect(wallet.hasWallet, isTrue);
  });

  testWidgets('a wallet that is not open cannot be deleted', (tester) async {
    final backend = FakeArkBackend();
    final secrets = FakeArkSecrets();
    await (await fakeArkWalletProvider(backend: backend, secrets: secrets)).createNew();
    backend.opened.clear();
    backend.failOpen = true;
    final wallet = await fakeArkWalletProvider(backend: backend, secrets: secrets, keepPrefs: true);
    await wallet.openAfterAppEntrance();
    await pump(tester, wallet);
    await openSettings(tester);

    expect(find.text(TextUtils.preventLineBreakInsideWords(t.ark_wallet.delete_not_ready)), findsOneWidget);
    expect(wallet.hasWallet, isTrue);
  });

  testWidgets('a wallet that failed to open says so and can retry', (tester) async {
    final backend = FakeArkBackend();
    final secrets = FakeArkSecrets();
    await (await fakeArkWalletProvider(backend: backend, secrets: secrets)).createNew();
    backend.opened.clear();
    backend.failOpen = true;
    final wallet = await fakeArkWalletProvider(backend: backend, secrets: secrets, keepPrefs: true);
    await wallet.openAfterAppEntrance();
    await pump(tester, wallet);

    expect(find.text(t.ark_wallet.open_failed), findsOneWidget);
    backend.failOpen = false;
    await tester.tap(find.text(t.retry));
    await tester.pumpAndSettle();
    expect(wallet.state, ArkWalletState.open);
    expect(find.text(t.ark_wallet.open_failed), findsNothing);
  });

  testWidgets('without a wallet there is no gear', (tester) async {
    await pump(tester, await fakeArkWalletProvider());

    expect(find.byKey(const Key('ark-wallet-settings')), findsNothing);
  });

  test('backup reads the words only after authentication and records a finished backup', () async {
    final wallet = await walletWith(restored: false);

    expect(await ArkWalletHomeViewModel(wallet, _Authenticator(false)).unlockForBackup(), isNull);
    final words = await ArkWalletHomeViewModel(wallet, _Authenticator(true)).unlockForBackup();
    expect(utf8.decode(words!), '${'zoo ' * 11}wrong');

    final viewModel = ArkWalletHomeViewModel(wallet, _Authenticator(true));
    await viewModel.finishBackup(confirmed: false);
    expect(wallet.needsBackup, isTrue);
    await viewModel.finishBackup(confirmed: true);
    expect(wallet.needsBackup, isFalse);
  });

  group('renew', () {
    void dueSoon(FakeArkBackend backend) {
      backend
        ..vtxoList = [fakeVtxo('due', sats: 2000, expiry: 1060), fakeVtxo('fine', expiry: 5000)]
        ..expiring = ['due']
        ..tip = 1000
        ..lifetime = 4320
        ..renewFee = 30;
    }

    testWidgets('VTXOs due within a day take the nudge before the backup prompt', (tester) async {
      await pump(tester, await walletWith(restored: false, setup: dueSoon));

      expect(find.byKey(const Key('ark-renew-nudge')), findsOneWidget);
      expect(find.text(t.ark_wallet.backup_title), findsNothing);
      expect(find.text(t.ark_wallet.renew_line(time: t.ark_wallet.expiry_hours(n: 10))), findsOneWidget);
    });

    testWidgets('renewing shows the fee and only renews after confirming', (tester) async {
      late FakeArkBackend fake;
      await pump(tester, await walletWith(restored: true, setup: (backend) => dueSoon(fake = backend)));

      await tester.tap(
        find.descendant(of: find.byKey(const Key('ark-renew-nudge')), matching: find.byType(CoconutButton)),
      );
      await tester.pumpAndSettle();
      expect(fake.renewed, isEmpty);
      expect(find.text(t.ark_wallet.renew_sheet_title), findsOneWidget);

      await tester.tap(find.byKey(const Key('ark-renew-confirm')));
      await tester.pumpAndSettle();

      expect(fake.renewed.single, ['due']);
      expect(find.byKey(const Key('ark-renew-nudge')), findsNothing);
    });

    testWidgets('settings show VTXOs needing renewal and auto renew on by default', (tester) async {
      final wallet = await walletWith(restored: true, setup: dueSoon);
      await pump(tester, wallet);
      await tester.tap(find.byKey(const Key('ark-wallet-settings')));
      await tester.pumpAndSettle();

      expect(find.text(t.ark_wallet.renew_needed), findsOneWidget);
      await tester.tap(find.byType(CoconutSwitch));
      await tester.pumpAndSettle();
      expect(wallet.autoRenew, isFalse);
    });

    testWidgets('the VTXO list groups VTXOs and renews the due ones', (tester) async {
      await pump(tester, await walletWith(restored: true, setup: dueSoon));
      await tester.tap(find.byKey(const Key('ark-wallet-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ark-settings-vtxos')));
      await tester.pumpAndSettle();

      expect(find.byType(ArkVtxoListScreen), findsOneWidget);
      expect(find.text(t.ark_wallet.group_expiring), findsOneWidget);
      expect(find.text(t.ark_wallet.group_spendable), findsOneWidget);
      expect(find.textContaining(t.ark_wallet.renew_button), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('ark-vtxo-fine')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ark-vtxo-lifetime')), findsOneWidget);
    });

    testWidgets('an expired VTXO still gets the renew nudge, saying it already expired', (tester) async {
      await pump(
        tester,
        await walletWith(
          restored: true,
          setup: (backend) {
            dueSoon(backend);
            backend.vtxoList = [fakeVtxo('due', expiry: 990)];
          },
        ),
      );

      expect(find.text(t.ark_wallet.renew_line_expired), findsOneWidget);
    });

    testWidgets('picking VTXOs starts with the due ones and renews what is picked', (tester) async {
      late FakeArkBackend fake;
      await pump(tester, await walletWith(restored: true, setup: (backend) => dueSoon(fake = backend)));
      await tester.tap(find.byKey(const Key('ark-wallet-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ark-settings-vtxos')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('ark-vtxo-select')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('ark-vtxo-fine')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(t.ark_wallet.renew_selected(n: 2)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ark-renew-confirm')));
      await tester.pumpAndSettle();

      expect(fake.renewed.single, ['due', 'fine']);
    });
  });

  testWidgets('a payment that arrives while the wallet is open shows a toast', (tester) async {
    late FakeArkBackend fake;
    final wallet = await walletWith(restored: true, setup: (backend) => fake = backend);
    await pump(tester, wallet);

    fake.movements = [_movement(1, sats: 3000)];
    await wallet.syncNow();
    await tester.pump();

    expect(find.text(t.ark_wallet.received(amount: '3,000 sats')), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });
}
