import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/analytics/analytics_screen_names.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/ark_provider.dart';
import 'package:coconut_wallet/providers/auth_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/screens/common/flutter_hot_wallet_authenticator.dart';
import 'package:coconut_wallet/screens/send/hot_wallet_passphrase_input_sheet.dart';
import 'package:coconut_wallet/services/ark/ark_wallet_service.dart';
import 'package:coconut_wallet/services/security/hot_wallet_signing_service.dart';
import 'package:coconut_wallet/services/security/hot_wallet_unlock_service.dart';
import 'package:coconut_wallet/utils/nfkd_util.dart';
import 'package:coconut_wallet/widgets/common/overlays/common_bottom_sheets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/localization/strings.g.dart';

/// Opens the Ark wallet of hot wallet [walletId] for the rest of the session, prompting to
/// unlock it first. Returns whether it is open.
///
/// Without [userInitiated] (e.g. on entering the wallet) nothing is prompted when the user
/// already declined this session, so backing out of the prompt isn't repeated on every visit.
Future<bool> openArkWalletForSession(BuildContext context, int walletId, {bool userInitiated = false}) {
  final arkProvider = context.read<ArkProvider>();
  if (arkProvider.isOpen(walletId)) return Future.value(true);
  if (!userInitiated && !arkProvider.shouldAutoUnlock(walletId)) return Future.value(false);
  final wallet = context.read<WalletProvider>().getWalletById(walletId);
  return arkProvider.open(walletId, () => unlockArkSeed(context, wallet));
}

/// 앱 진입 인증을 통과한 뒤 패스프레이즈가 필요 없는 아크 지갑을 모두 엶
Future<void> openArkWalletsAfterAppEntrance(BuildContext context) async {
  final arkProvider = context.readArkProviderOrNull();
  if (arkProvider == null) return;
  final walletProvider = context.read<WalletProvider>();
  final loadState = walletProvider.walletLoadStateNotifier;
  if (loadState.value != WalletLoadState.loadCompleted) {
    final loaded = Completer<void>();
    void onChanged() {
      if (loadState.value == WalletLoadState.loadCompleted && !loaded.isCompleted) loaded.complete();
    }

    loadState.addListener(onChanged);
    await loaded.future;
    loadState.removeListener(onChanged);
  }
  await arkProvider.arkWalletsLoaded;
  for (final wallet in walletProvider.walletItemList) {
    final metadata = wallet.hotWalletMetadata;
    if (metadata == null || metadata.enterPassphraseWhenSigning || !arkProvider.shouldAutoUnlock(wallet.id)) continue;
    unawaited(arkProvider.open(wallet.id, () => _seedAfterAuthentication(metadata.secureStorageKey)));
  }
}

Future<String?> _seedAfterAuthentication(String secureStorageKey) async {
  final plaintext = await AppGuard.runWithoutPrivacyScreen(
    () => HotWalletSecretRepository().unlockAfterAuthentication(secureStorageKey),
  );
  final passphrase = Uint8List.fromList(plaintext.passphrase);
  try {
    return await ArkWalletService().seedForHotWallet(plaintext.mnemonic, passphrase);
  } finally {
    plaintext.wipe();
    passphrase.fillRange(0, passphrase.length, 0);
  }
}

/// Unlocks the hot wallet's seed (authentication, plus the passphrase for "enter passphrase
/// when signing" wallets) and derives its Ark seed. Returns null when the user cancels.
Future<String?> unlockArkSeed(BuildContext context, WalletItemBase wallet) async {
  final metadata = wallet.hotWalletMetadata!;
  HotWalletPlaintext? plaintext;
  Uint8List? passphrase;
  try {
    if (metadata.enterPassphraseWhenSigning) {
      final requiresAuthentication = context.read<AuthProvider>().isAuthEnabled;
      var showIncorrectError = false;
      while (true) {
        if (!context.mounted) return null;
        final entered = await CommonBottomSheets.showBottomSheet<Uint8List>(
          context: context,
          title: t.send_confirm_screen.passphrase_input_title,
          screenName: AnalyticsScreenNames.arkUnlockPassphraseSheet,
          showCloseButton: true,
          showDragHandle: true,
          backgroundColor: context.coconutColors.surfaceBottomSheet,
          child: HotWalletPassphraseInputSheet(
            requiresAuthentication: requiresAuthentication,
            showIncorrectError: showIncorrectError,
            onAuthenticationStarted: () async {},
            onPassphraseInputResumed: () {},
            description: t.ark.unlock.passphrase_description,
            buttonText: t.confirm,
          ),
        );
        if (entered == null) return null;
        final isCorrect = await AppGuard.runWithoutPrivacyScreen(() => _validatePassphrase(wallet, entered));
        if (isCorrect) {
          passphrase = NfkdUtil.normalizeNfkdUtf8(entered);
          entered.fillRange(0, entered.length, 0);
          break;
        }
        entered.fillRange(0, entered.length, 0);
        showIncorrectError = true;
      }
      // The passphrase sheet has already authenticated the user.
      final unlocked = await AppGuard.runWithoutPrivacyScreen(
        () => HotWalletSecretRepository().unlockAfterAuthentication(metadata.secureStorageKey),
      );
      plaintext = unlocked;
      return await ArkWalletService().seedForHotWallet(unlocked.mnemonic, passphrase);
    } else {
      final unlockService = HotWalletUnlockService(
        authenticator: FlutterHotWalletAuthenticator(
          context,
          pinTitle: t.ark.unlock.pin_title,
          biometricsReason: t.ark.unlock.biometrics_reason,
        ),
      );
      plaintext = await AppGuard.runWithoutPrivacyScreen(() => unlockService.unlock(metadata.secureStorageKey));
      if (plaintext == null) return null;
      final unlocked = plaintext;
      passphrase = Uint8List.fromList(unlocked.passphrase);
      return await ArkWalletService().seedForHotWallet(unlocked.mnemonic, passphrase);
    }
  } finally {
    plaintext?.wipe();
    passphrase?.fillRange(0, passphrase.length, 0);
  }
}

/// Checks a passphrase entered for an "enter passphrase when signing" wallet against the hot
/// wallet's xpub, so a typo can't open or create the wrong Ark wallet.
Future<bool> _validatePassphrase(WalletItemBase wallet, Uint8List passphrase) {
  final metadata = wallet.hotWalletMetadata!;
  final walletBase = wallet.walletBase as SingleSignatureWallet;
  return HotWalletSigningService().validatePassphrase(
    storageKey: metadata.secureStorageKey,
    passphrase: passphrase,
    addressTypeName: walletBase.addressType.name,
    accountIndex: metadata.accountIndex,
    expectedExtendedPublicKey: walletBase.keyStore.extendedPublicKey.serialize(),
  );
}
