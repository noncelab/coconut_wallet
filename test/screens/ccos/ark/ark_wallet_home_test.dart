import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_wallet/ccos/features/ark/ark_balance.dart';
import 'package:coconut_wallet/ccos/features/ark/ark_wallet_provider.dart';
import 'package:coconut_wallet/design_system/theme/coconut_theme_data.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/ccos/ark/ark_wallet_home_view_model.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_home_screen.dart';
import 'package:coconut_wallet/screens/ccos/ark/ark_wallet_settings_screen.dart';
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

class _Authenticator implements HotWalletAuthenticator {
  _Authenticator(this.result);

  final bool result;

  @override
  Future<bool> authenticate() async => result;
}

void main() {
  setUp(() => LocaleSettings.setLocaleSync(AppLocale.ko));

  Future<ArkWalletProvider> walletWith({required bool restored, int sats = 0}) async {
    final backend =
        FakeArkBackend()
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
    return wallet;
  }

  Future<void> pump(WidgetTester tester, ArkWalletProvider wallet) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<PreferenceProvider>.value(value: FakeStorePreferences()),
          ChangeNotifierProvider<ArkWalletProvider>.value(value: wallet),
          InheritedProvider<AuthProvider>.value(value: _Auth()),
        ],
        child: MaterialApp(
          theme: buildCoconutThemeData(variant: CoconutThemeVariant.dark),
          home: const ArkWalletHomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

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
}
