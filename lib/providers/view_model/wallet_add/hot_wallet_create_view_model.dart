import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/core/exceptions/wallet_name_conflict_exception.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:flutter/foundation.dart';

({Uint8List mnemonic, String descriptor}) _generateHotWalletMaterial(
  ({int mnemonicWordCount, Uint8List passphrase}) input,
) {
  final passphrase = input.passphrase;
  final seed = Seed.random(mnemonicLength: input.mnemonicWordCount, passphrase: passphrase);
  try {
    final vault = SingleSignatureVault.fromSeed(seed);
    return (mnemonic: Uint8List.fromList(seed.mnemonic), descriptor: vault.descriptor);
  } finally {
    seed.wipe();
    passphrase.fillRange(0, passphrase.length, 0);
  }
}

class HotWalletCreateResult {
  const HotWalletCreateResult({
    required this.walletId,
    required this.walletName,
    required this.mnemonic,
    required this.passphrase,
    required this.enterPassphraseWhenSigning,
  });

  final int walletId;
  final String walletName;
  final Uint8List mnemonic;
  final Uint8List passphrase;
  final bool enterPassphraseWhenSigning;

  void clearSensitiveBytes() {
    mnemonic.fillRange(0, mnemonic.length, 0);
    passphrase.fillRange(0, passphrase.length, 0);
  }
}

class HotWalletCreateViewModel extends ChangeNotifier {
  HotWalletCreateViewModel(this._walletProvider);

  final WalletProvider _walletProvider;
  bool _isCreating = false;

  bool get isCreating => _isCreating;

  Future<HotWalletCreateResult> createWallet({
    required String walletName,
    required int colorIndex,
    required int iconIndex,
    required int mnemonicWordCount,
    required String passphrase,
    required bool enterPassphraseWhenSigning,
  }) async {
    if (_isCreating) {
      throw StateError('Hot wallet creation is already in progress');
    }
    if (_walletProvider.walletItemList.any((wallet) => wallet.name == walletName)) {
      throw const WalletNameConflictException();
    }

    _isCreating = true;
    notifyListeners();

    final passphraseBytes = Uint8List.fromList(utf8.encode(passphrase));
    Uint8List? mnemonic;
    final secretRepository = HotWalletSecretRepository();
    final storageKey = secretRepository.newSecretStorageKey();

    try {
      final material = await compute(_generateHotWalletMaterial, (
        mnemonicWordCount: mnemonicWordCount,
        passphrase: Uint8List.fromList(passphraseBytes),
      ));
      mnemonic = material.mnemonic;

      final wallet = WatchOnlyWallet(
        walletName,
        colorIndex,
        iconIndex,
        material.descriptor,
        null,
        null,
        WalletImportSource.coconutVault.name,
      );
      final passphraseToStore = enterPassphraseWhenSigning ? Uint8List(0) : Uint8List.fromList(passphraseBytes);
      try {
        await AppGuard.runWithoutPrivacyScreen(
          () => secretRepository.create(storageKey: storageKey, mnemonic: mnemonic!, passphrase: passphraseToStore),
        );
      } finally {
        passphraseToStore.fillRange(0, passphraseToStore.length, 0);
      }

      final addedWallet = await _walletProvider.addHotWallet(
        wallet,
        secureStorageKey: storageKey,
        backupVerified: false,
        enterPassphraseWhenSigning: enterPassphraseWhenSigning,
        createdAt: DateTime.now(),
      );

      return HotWalletCreateResult(
        walletId: addedWallet.id,
        walletName: walletName,
        mnemonic: Uint8List.fromList(mnemonic),
        passphrase: Uint8List.fromList(passphraseBytes),
        enterPassphraseWhenSigning: enterPassphraseWhenSigning,
      );
    } catch (_) {
      try {
        await secretRepository.delete(storageKey);
      } catch (_) {
        // 저장이 시작되기 전 실패했거나 이미 정리된 경우
      }
      rethrow;
    } finally {
      mnemonic?.fillRange(0, mnemonic.length, 0);
      passphraseBytes.fillRange(0, passphraseBytes.length, 0);
      _isCreating = false;
      notifyListeners();
    }
  }
}
