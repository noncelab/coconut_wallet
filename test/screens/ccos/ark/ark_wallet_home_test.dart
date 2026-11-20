import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:coconut_design_system/coconut_design_system.dart' show CoconutButton, CoconutSwitch;
import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_exit.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_feature_copy.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_movement.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/constants/external_links.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_wallet_home_view_model.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_home_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_settings_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_vtxo_list_screen.dart';
import 'package:coconut_wallet/screens/ccos/store/widgets/ccos_store_creator_story.dart';
import 'package:coconut_wallet/services/security/hot_wallet_authenticator.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:coconut_wallet/widgets/common/buttons/button_group.dart';
import 'package:coconut_wallet/widgets/common/buttons/copy_text_container.dart';
import 'package:coconut_wallet/widgets/common/buttons/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/common/info/info_section.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
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

  /// 누를 수 있는 칸은 코코넛 홈처럼 누르는 동안 줄어들고 눌림 색이 깔림
  bool isActive(WidgetTester tester, String key) => tester.widget(find.byKey(Key(key))) is HomePressableRow;

  testWidgets('add funds, withdraw, receive and send sit in one row of home shortcut tiles', (tester) async {
    await pump(tester, await walletWith(restored: true));

    final tiles = ['ark-wallet-fill', 'ark-wallet-export', 'ark-wallet-receive', 'ark-wallet-send'];
    final positions = [for (final key in tiles) tester.getTopLeft(find.byKey(Key(key)))];
    expect(positions.map((position) => position.dy).toSet(), hasLength(1));
    expect(positions.map((position) => position.dx).toList(), orderedEquals([...positions.map((p) => p.dx)]..sort()));
    expect(tester.getSize(find.byKey(const Key('ark-wallet-send'))).aspectRatio, 1);
    final labels = [t.ark_wallet.fill, t.ark_wallet.export, t.receive, t.send];
    expect(labels.map((label) => tester.getTopLeft(find.text(label)).dy).toSet(), hasLength(1));
    expect(isActive(tester, 'ark-wallet-receive'), isTrue);
    expect(isActive(tester, 'ark-wallet-send'), isFalse);
    expect(isActive(tester, 'ark-wallet-fill'), isFalse, reason: 'no hot wallet to add from');
    expect(isActive(tester, 'ark-wallet-export'), isFalse, reason: 'no balance and no wallet to withdraw to');
  });

  testWidgets('with a balance send is active', (tester) async {
    await pump(tester, await walletWith(restored: true, sats: 1000));

    expect(isActive(tester, 'ark-wallet-send'), isTrue);
  });

  testWidgets('with VTXOs but notifications off, home says renew reminders are off and asks to turn them on', (
    tester,
  ) async {
    final reminder = FakeArkReminder()..allowed = false;
    final backend = FakeArkBackend()..vtxoList = [fakeVtxo('a', expiry: 5000)];
    final wallet = await fakeArkWalletProvider(backend: backend, reminder: reminder);
    await wallet.restore(Uint8List.fromList(utf8.encode('${'abandon ' * 11}about')));
    await wallet.syncNow();
    await pump(tester, wallet);

    expect(find.byKey(const Key('ark-reminder-nudge')), findsOneWidget);
    reminder.grantOnAsk = true;
    await tester.tap(
      find.descendant(of: find.byKey(const Key('ark-reminder-nudge')), matching: find.byType(CoconutButton)),
    );
    await tester.pumpAndSettle();

    expect(reminder.asked, 1);
    expect(find.byKey(const Key('ark-reminder-nudge')), findsNothing);
  });

  testWidgets('with a balance but no Coconut wallet, withdraw opens with an address to type in', (tester) async {
    await pump(tester, await walletWith(restored: true, sats: 20000));

    expect(isActive(tester, 'ark-wallet-export'), isTrue);
    await tester.tap(find.byKey(const Key('ark-wallet-export')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('ark-export-address')), findsOneWidget);
    expect(find.byKey(const Key('ark-export-switch')), findsNothing);
    await tester.enterText(find.byType(EditableText).last, 'not-an-address-at-all-xxxxxxx');
    await tester.pumpAndSettle();
    expect(find.text(t.errors.address_error.invalid), findsOneWidget);
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

  testWidgets('the balance is in sats whatever the app unit and a tap switches it to ₿', (tester) async {
    final wallet = await walletWith(restored: true, sats: 12345);
    await pump(tester, wallet);
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text(BitcoinUnit.sats.symbol), findsOneWidget);
    expect(find.textContaining(BitcoinUnit.sats.displayBitcoinAmount(12345)), findsOneWidget);

    await tester.tap(find.byKey(const Key('ark-wallet-balance')));
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(wallet.unit, BitcoinUnit.bip177);
    expect(find.text(BitcoinUnit.sats.symbol), findsNothing);
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

    expect(find.text(TextUtils.preventLineBreakInsideWords(t.ark_wallet.delete_description)), findsOneWidget);
    await tester.tap(find.text(t.delete));
    await tester.pumpAndSettle();

    expect(wallet.hasWallet, isFalse);
    expect(find.byType(ArkWalletSettingsScreen), findsNothing);
    expect(find.text(t.ark_wallet.create_new), findsOneWidget);
  });

  testWidgets('settings show notifications and the Ark server under the Ark wallet section, without the chain server', (
    tester,
  ) async {
    final wallet = await fakeArkWalletProvider(backend: FakeArkBackend(), reminder: FakeArkReminder());
    await wallet.restore(Uint8List.fromList(utf8.encode('${'abandon ' * 11}about')));
    await pump(tester, wallet);
    await tester.tap(find.byKey(const Key('ark-wallet-settings')));
    await tester.pumpAndSettle();

    final section = find.ancestor(of: find.byKey(const Key('ark-settings-server')), matching: find.byType(InfoSection));
    expect(find.descendant(of: section, matching: find.text(t.ark_wallet.wallet_name)), findsOneWidget);
    expect(find.descendant(of: section, matching: find.byKey(const Key('ark-settings-reminder'))), findsOneWidget);
    expect(find.byKey(const Key('ark-settings-chain')), findsNothing);
  });

  testWidgets(
    'settings credit the Bark team at Second.tech and show the bark version, and the credit introduces Second.tech',
    (tester) async {
      final wallet = await fakeArkWalletProvider(backend: FakeArkBackend(), reminder: FakeArkReminder());
      await wallet.restore(Uint8List.fromList(utf8.encode('${'abandon ' * 11}about')));
      await pump(tester, wallet);
      await tester.tap(find.byKey(const Key('ark-wallet-settings')));
      await tester.pumpAndSettle();

      final credit = find.byKey(const Key('ark-settings-creator'));
      await tester.scrollUntilVisible(credit, 200);
      final section = find.ancestor(of: credit, matching: find.byType(InfoSection));
      expect(find.descendant(of: section, matching: find.text(t.ark_wallet.section_about)), findsOneWidget);
      expect(find.descendant(of: section, matching: find.text(ArkFeature.listing.author)), findsOneWidget);
      expect(find.descendant(of: section, matching: find.text(arkBarkVersion)), findsOneWidget);

      await tester.tap(credit);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(ArkFeature.listing.author), findsOneWidget);
      expect(find.text(t.ark_wallet.creator_tagline), findsOneWidget);
      expect(t.ark_wallet.creator_tagline, contains('Second.tech'));
      expect(find.byKey(const Key('ark-creator-github')), findsOneWidget);
      expect(
        find.ancestor(of: find.byKey(const Key('ark-creator-github')), matching: find.byType(ButtonGroup)),
        findsNothing,
      );
      expect(find.text(t.ark_wallet.creator_github), findsOneWidget);
      expect(GITHUB_URL_BARK, 'https://github.com/ark-bitcoin/bark');
      for (final paragraph in ArkFeatureCopySource.current.companyParagraphs) {
        expect(find.text(paragraph), findsOneWidget);
      }
      expect(find.byType(CcosStoreCreatorStory), findsNothing);
    },
  );

  test('every language introduces Bark as Ark on Bitcoin first and the Second.tech community last', () {
    for (final locale in AppLocale.values) {
      LocaleSettings.setLocaleSync(locale);
      final paragraphs = ArkFeatureCopySource.current.companyParagraphs;
      expect(paragraphs, hasLength(3), reason: locale.languageCode);
      expect(paragraphs.first, contains('Ark on Bitcoin'), reason: locale.languageCode);
      final copy = ArkFeatureCopySource.current;
      expect([...copy.companyParagraphs, ...copy.creatorParagraphs].join(), isNot(contains('Bitcoin Ark')));
      expect(paragraphs.last, contains('Second.tech'), reason: locale.languageCode);
    }
    LocaleSettings.setLocaleSync(AppLocale.ko);
  });

  test('the bark version shown matches the bundled bark_bitcoin package', () {
    final pubspec = File('third_party/bark_bitcoin/pubspec.yaml').readAsStringSync();
    expect(RegExp(r'version: .*\+bark-(\S+)').firstMatch(pubspec)!.group(1), arkBarkVersion);
  });

  testWidgets('settings show whether renew reminders are on, and a tap turns them on when off', (tester) async {
    final reminder = FakeArkReminder()..allowed = false;
    final wallet = await fakeArkWalletProvider(backend: FakeArkBackend(), reminder: reminder);
    await wallet.restore(Uint8List.fromList(utf8.encode('${'abandon ' * 11}about')));
    await wallet.syncNow();
    await pump(tester, wallet);
    await tester.tap(find.byKey(const Key('ark-wallet-settings')));
    await tester.pumpAndSettle();

    final row = find.byKey(const Key('ark-settings-reminder'));
    expect(find.descendant(of: row, matching: find.text(t.ark_wallet.reminder_off)), findsOneWidget);
    reminder.grantOnAsk = true;
    await tester.tap(row);
    await tester.pumpAndSettle();

    expect(reminder.asked, 1);
    expect(find.descendant(of: row, matching: find.text(t.ark_wallet.reminder_on)), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(reminder.asked, 1);
  });

  testWidgets('a wallet with balance cannot be deleted', (tester) async {
    final wallet = await walletWith(restored: true, sats: 1000);
    await pump(tester, wallet);
    await openSettings(tester);

    expect(find.text(TextUtils.preventLineBreakInsideWords(t.ark_wallet.delete_blocked_title)), findsOneWidget);
    expect(find.text(TextUtils.preventLineBreakInsideWords(t.ark_wallet.delete_description)), findsNothing);
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

  testWidgets(
    'a wallet that failed to open says so with a warning above the middle and retries from the bottom button',
    (tester) async {
      final backend = FakeArkBackend();
      final secrets = FakeArkSecrets();
      await (await fakeArkWalletProvider(backend: backend, secrets: secrets)).createNew();
      backend.opened.clear();
      backend.failOpen = true;
      final wallet = await fakeArkWalletProvider(backend: backend, secrets: secrets, keepPrefs: true);
      await wallet.openAfterAppEntrance();
      await pump(tester, wallet);

      expect(find.text(t.ark_wallet.open_failed), findsOneWidget);
      expect(find.text(t.ark_wallet.open_failed_desc), findsOneWidget);
      expect(find.byKey(const Key('ark-open-failed-icon')), findsOneWidget);
      expect(find.descendant(of: find.byType(FixedBottomButton), matching: find.text(t.retry)), findsOneWidget);
      expect(
        tester.getCenter(find.text(t.ark_wallet.open_failed)).dy,
        lessThan(tester.getSize(find.byType(Scaffold).first).height / 2),
      );
      backend.failOpen = false;
      await tester.tap(find.text(t.retry));
      await tester.pumpAndSettle();
      expect(wallet.state, ArkWalletState.open);
      expect(find.text(t.ark_wallet.open_failed), findsNothing);
    },
  );

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

    testWidgets('settings show VTXOs needing renewal and no switch to turn auto renew off', (tester) async {
      await pump(tester, await walletWith(restored: true, setup: dueSoon));
      await tester.tap(find.byKey(const Key('ark-wallet-settings')));
      await tester.pumpAndSettle();

      expect(find.text(t.ark_wallet.renew_needed), findsOneWidget);
      expect(find.byType(CoconutSwitch), findsNothing);
    });

    testWidgets('the VTXO list groups VTXOs and renews the due ones', (tester) async {
      await pump(tester, await walletWith(restored: true, setup: dueSoon));
      await tester.tap(find.byKey(const Key('ark-wallet-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ark-settings-vtxos')));
      await tester.pumpAndSettle();

      expect(find.byType(ArkVtxoListScreen), findsOneWidget);
      expect(find.byKey(const Key('ark-vtxo-about')), findsOneWidget);
      expect(
        find.text(
          '${t.ark_wallet.vtxo_count(n: 2)} · ${t.ark_wallet.vtxo_next_expiry(time: t.ark_wallet.duration_hours(n: 10))}',
        ),
        findsOneWidget,
      );
      expect(find.text(t.ark_wallet.vtxo_row_detail(block: '5,000', id: 'fine…')), findsOneWidget);
      expect(find.text('${t.ark_wallet.group_expiring} · 1'), findsOneWidget);
      expect(find.text('${t.ark_wallet.group_spendable} · 1'), findsOneWidget);
      expect(find.textContaining(t.ark_wallet.renew_button), findsWidgets);

      await tester.tap(find.byKey(const ValueKey('ark-vtxo-fine')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('ark-vtxo-lifetime')), findsOneWidget);
      expect(
        find.text(
          t.ark_wallet.vtxo_lifetime_line(
            total: t.ark_wallet.duration_days(n: 30),
            left: t.ark_wallet.duration_days(n: 27),
          ),
        ),
        findsOneWidget,
      );
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
    group('a due VTXO under the round minimum', () {
      void dustDue(FakeArkBackend backend) {
        dueSoon(backend);
        backend.vtxoList = [fakeVtxo('due', sats: 310, expiry: 1060), fakeVtxo('fine', expiry: 5000)];
      }

      Future<void> openList(WidgetTester tester) async {
        await tester.tap(find.byKey(const Key('ark-wallet-settings')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ark-settings-vtxos')));
        await tester.pumpAndSettle();
      }

      testWidgets('gets no home nudge and the list asks to pick at least the minimum together', (tester) async {
        late FakeArkBackend fake;
        await pump(tester, await walletWith(restored: true, setup: (backend) => dustDue(fake = backend)));
        expect(find.byKey(const Key('ark-renew-nudge')), findsNothing);

        await openList(tester);
        expect(find.byKey(const ValueKey('ark-vtxo-renew-due')), findsNothing);

        await tester.tap(find.byKey(const Key('ark-vtxo-select')));
        await tester.pumpAndSettle();
        final minimum = TextUtils.preventLineBreakInsideWords(t.ark_wallet.renew_min_total(amount: '330 sats'));
        expect(find.text(minimum), findsOneWidget);
        await tester.tap(find.text(t.ark_wallet.renew_selected(n: 1)));
        await tester.pumpAndSettle();
        expect(find.text(t.ark_wallet.renew_sheet_title), findsNothing);

        await tester.tap(find.byKey(const ValueKey('ark-vtxo-fine')));
        await tester.pumpAndSettle();
        expect(find.text(minimum), findsNothing);
        await tester.tap(find.text(t.ark_wallet.renew_selected(n: 2)));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('ark-renew-confirm')));
        await tester.pumpAndSettle();
        expect(fake.renewed.single, ['due', 'fine']);
      });

      testWidgets('its detail says it cannot be renewed alone', (tester) async {
        await pump(tester, await walletWith(restored: true, setup: dustDue));
        await openList(tester);
        await tester.tap(find.byKey(const ValueKey('ark-vtxo-due')));
        await tester.pumpAndSettle();

        expect(
          find.text(TextUtils.preventLineBreakInsideWords(t.ark_wallet.renew_alone_too_small(amount: '330 sats'))),
          findsOneWidget,
        );
        await tester.tap(find.text(t.ark_wallet.renew_button));
        await tester.pumpAndSettle();
        expect(find.text(t.ark_wallet.renew_sheet_title), findsNothing);
      });
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

  group('exit without the server', () {
    Future<void> openExit(WidgetTester tester, ArkWalletProvider wallet) async {
      await pump(tester, wallet);
      await tester.tap(find.byKey(const Key('ark-wallet-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ark-settings-exit')));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'starts with what it is and the four facts, then reads from the Ark wallet down to the receiving one, asking for a hot wallet to pay fees',
      (tester) async {
        await openExit(tester, await walletWith(restored: true));

        expect(find.text(t.ark_wallet.exit_fact_time), findsOneWidget);
        expect(find.text(t.ark_wallet.exit_fact_ark), findsOneWidget);
        await tester.tap(find.byKey(const Key('ark-exit-next')));
        await tester.pumpAndSettle();

        final from = tester.getTopLeft(find.text(t.ark_wallet.wallet_name)).dy;
        final arrival = tester.getTopLeft(find.byKey(const Key('ark-move-arrival'))).dy;
        expect(find.byKey(const Key('ark-exit-route')), findsOneWidget);
        expect(from, lessThan(arrival));
        expect(find.byKey(const Key('ark-exit-fee-wallet')), findsOneWidget);
        await tester.tap(find.byKey(const Key('ark-exit-claim-tooltip')));
        await tester.pumpAndSettle();
        expect(
          find.text(TextUtils.preventLineBreakInsideWords(t.ark_wallet.exit_claim_fee_tooltip), findRichText: true),
          findsOneWidget,
        );
        await tester.tapAt(const Offset(20, 700));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('ark-move-to-change')), findsNothing);
        expect(find.byType(InfoRowArrow), findsNothing);
        expect(find.text(TextUtils.preventLineBreakInsideWords(t.ark_wallet.exit_no_fee_wallet)), findsOneWidget);
      },
    );

    testWidgets('says what was left out because it is too small to exit', (tester) async {
      await openExit(
        tester,
        await walletWith(
          restored: true,
          setup:
              (backend) =>
                  backend.quote = const ArkExitQuote(
                    vtxoIds: ['a'],
                    amountSats: 20000,
                    feeSats: 400,
                    txCount: 1,
                    feeRateSatPerVb: 1,
                    firstExpiryHeight: 5000,
                    leftOutSats: 310,
                  ),
        ),
      );
      await tester.tap(find.byKey(const Key('ark-exit-next')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('ark-exit-left-out')), findsOneWidget);
    });

    testWidgets('a running exit shows its stage in settings and on the exit screen, and blocks deleting', (
      tester,
    ) async {
      final wallet = await walletWith(restored: true);
      await wallet.beginExit(
        ArkExitSession(
          vtxoIds: const ['a'],
          amountSats: 30000,
          destination: 'bcrt1qmine',
          fundingSats: 3000,
          feeRateSatPerVb: 2,
          firstExpiryHeight: 5000,
          startedAt: DateTime(2026, 11, 18),
        ),
      );
      await pump(tester, wallet);
      await tester.tap(find.byKey(const Key('ark-wallet-settings')));
      await tester.pumpAndSettle();

      expect(find.text(t.ark_wallet.exit_running), findsOneWidget);
      await tester.tap(find.byKey(const Key('ark-settings-exit')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(t.ark_wallet.exit_step_fund), findsOneWidget);
      expect(find.byKey(const Key('ark-exit-dismiss')), findsNothing);
      expect(find.text(t.ark_wallet.from), findsNothing);
      expect(find.text('bcrt1qmine'), findsOneWidget);
      expect(find.byKey(const Key('ark-exit-progress-address')), findsOneWidget);
      expect(find.byType(CopyTextContainer), findsNothing);
      expect(find.text('3,000 sats'), findsOneWidget);
      expect(find.byKey(const Key('ark-exit-wait-tooltip')), findsOneWidget);
    });

    testWidgets('while sending, the send step shows one cell per transaction and explains why there are several', (
      tester,
    ) async {
      final wallet = await walletWith(
        restored: true,
        setup:
            (backend) =>
                backend.steps.progress = const ArkExitProgress(
                  spent: false,
                  onChain: false,
                  allClaimable: false,
                  claimableHeight: null,
                  txDone: 1,
                  txTotal: 4,
                ),
      );
      await wallet.beginExit(
        ArkExitSession(
          vtxoIds: const ['a'],
          amountSats: 30000,
          destination: 'bcrt1qmine',
          fundingSats: 3000,
          feeRateSatPerVb: 2,
          firstExpiryHeight: 5000,
          startedAt: DateTime(2026, 11, 18),
          phase: ArkExitPhase.exiting,
          txDone: 1,
          txTotal: 4,
        ),
      );
      await pump(tester, wallet);
      await tester.tap(find.byKey(const Key('ark-wallet-settings')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ark-settings-exit')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(tester.widget<Wrap>(find.byKey(const Key('ark-exit-tx-cells'))).children, hasLength(4));
      expect(find.text(t.ark_wallet.exit_step_send_detail(done: 1, total: 4)), findsOneWidget);
      await tester.tap(find.byKey(const Key('ark-exit-send-tooltip')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.text(TextUtils.preventLineBreakInsideWords(t.ark_wallet.exit_step_send_tooltip), findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('a finished exit shows what arrived like the on-chain send done screen, and OK clears it', (
      tester,
    ) async {
      final wallet = await walletWith(restored: true);
      await wallet.beginExit(
        ArkExitSession(
          vtxoIds: const ['a'],
          amountSats: 30000,
          destination: 'bcrt1qmine',
          fundingSats: 3000,
          feeRateSatPerVb: 2,
          firstExpiryHeight: 5000,
          startedAt: DateTime(2026, 11, 18, 10),
          phase: ArkExitPhase.done,
          receivedSats: 29700,
          feeReturned: true,
          finishedAt: DateTime(2026, 11, 18, 10, 30),
        ),
      );
      await openExit(tester, wallet);

      expect(find.text(t.ark_wallet.exit_phase_done), findsOneWidget);
      expect(find.text(t.ark_wallet.duration_minutes(n: 30)), findsOneWidget);
      expect(find.text(t.ark_wallet.from), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(const Key('ark-exit-done-address')), matching: find.text('bcrt1qmine')),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('ark-exit-dismiss')));
      await tester.pumpAndSettle();
      expect(wallet.exit, isNull);
    });
  });
}
