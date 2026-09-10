import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/app_guard.dart';
import 'package:coconut_wallet/core/exceptions/wallet_name_conflict_exception.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/watch_only_wallet.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:flutter/foundation.dart';

typedef HotWalletMaterial = ({Uint8List mnemonic, String descriptor});
typedef HotWalletMaterialGenerator = Future<HotWalletMaterial> Function(int mnemonicWordCount, Uint8List passphrase);

HotWalletMaterial _generateHotWalletMaterial(({int mnemonicWordCount, Uint8List passphrase}) input) {
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

Future<HotWalletMaterial> _generateHotWalletMaterialInIsolate(int mnemonicWordCount, Uint8List passphrase) =>
    compute(_generateHotWalletMaterial, (mnemonicWordCount: mnemonicWordCount, passphrase: passphrase));

class HotWalletCreateResult {
  const HotWalletCreateResult({
    required this.walletId,
    required this.walletName,
    required this.descriptor,
    required this.mnemonic,
    required this.passphrase,
    required this.enterPassphraseWhenSigning,
  });

  final int walletId;
  final String walletName;
  final String descriptor;
  final Uint8List mnemonic;
  final Uint8List passphrase;
  final bool enterPassphraseWhenSigning;

  void clearSensitiveBytes() {
    mnemonic.fillRange(0, mnemonic.length, 0);
    passphrase.fillRange(0, passphrase.length, 0);
  }
}

class HotWalletCreateViewModel extends ChangeNotifier {
  HotWalletCreateViewModel(
    this._walletProvider, {
    HotWalletSecretRepository? secretRepository,
    HotWalletMaterialGenerator? materialGenerator,
    DateTime Function()? now,
  }) : _secretRepository = secretRepository ?? HotWalletSecretRepository(), // 테스트코드에서 사용하기 위해 저장소,생성기 주입
       _materialGenerator = materialGenerator ?? _generateHotWalletMaterialInIsolate,
       _now = now ?? DateTime.now;

  final WalletProvider _walletProvider;
  final HotWalletSecretRepository _secretRepository;
  final HotWalletMaterialGenerator _materialGenerator;
  final DateTime Function() _now;
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
    final storageKey = _secretRepository.newSecretStorageKey();

    try {
      final material = await _materialGenerator(mnemonicWordCount, Uint8List.fromList(passphraseBytes));
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
          () => _secretRepository.create(storageKey: storageKey, mnemonic: mnemonic!, passphrase: passphraseToStore),
        );
      } finally {
        passphraseToStore.fillRange(0, passphraseToStore.length, 0);
      }

      final addedWallet = await _walletProvider.addHotWallet(
        wallet,
        secureStorageKey: storageKey,
        backupVerified: false,
        enterPassphraseWhenSigning: enterPassphraseWhenSigning,
        createdAt: _now(),
      );

      return HotWalletCreateResult(
        walletId: addedWallet.id,
        walletName: walletName,
        descriptor: material.descriptor,
        mnemonic: Uint8List.fromList(mnemonic),
        passphrase: Uint8List.fromList(passphraseBytes),
        enterPassphraseWhenSigning: enterPassphraseWhenSigning,
      );
    } catch (_) {
      try {
        await _secretRepository.delete(storageKey);
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
