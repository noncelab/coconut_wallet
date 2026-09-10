import 'dart:convert';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:flutter/foundation.dart';

typedef HotWalletSigningRequest =
    ({
      String storageKey,
      String? passphrase,
      String addressTypeName,
      int accountIndex,
      String expectedExtendedPublicKey,
      String unsignedPsbt,
    });

typedef _HotWalletSigningArguments =
    ({
      String mnemonic,
      String passphrase,
      String addressTypeName,
      int accountIndex,
      String expectedExtendedPublicKey,
      String unsignedPsbt,
    });

typedef _HotWalletPassphraseValidationArguments =
    ({String mnemonic, String passphrase, String addressTypeName, int accountIndex, String expectedExtendedPublicKey});

class HotWalletSigningService {
  HotWalletSigningService({HotWalletSecretRepository? secretRepository})
    : _secretRepository = secretRepository ?? HotWalletSecretRepository();

  final HotWalletSecretRepository _secretRepository;

  Future<String> sign(HotWalletSigningRequest request) async {
    final plaintext = await _secretRepository.unlockAfterAuthentication(request.storageKey);
    return compute(_signHotWalletInBackground, (
      mnemonic: plaintext.mnemonic,
      passphrase: request.passphrase ?? plaintext.passphrase,
      addressTypeName: request.addressTypeName,
      accountIndex: request.accountIndex,
      expectedExtendedPublicKey: request.expectedExtendedPublicKey,
      unsignedPsbt: request.unsignedPsbt,
    ));
  }

  Future<bool> validatePassphrase({
    required String storageKey,
    required String passphrase,
    required String addressTypeName,
    required int accountIndex,
    required String expectedExtendedPublicKey,
  }) async {
    final plaintext = await _secretRepository.unlockAfterAuthentication(storageKey);
    return compute(_validateHotWalletPassphraseInBackground, (
      mnemonic: plaintext.mnemonic,
      passphrase: passphrase,
      addressTypeName: addressTypeName,
      accountIndex: accountIndex,
      expectedExtendedPublicKey: expectedExtendedPublicKey,
    ));
  }
}

bool _validateHotWalletPassphraseInBackground(_HotWalletPassphraseValidationArguments arguments) {
  final mnemonicBytes = Uint8List.fromList(utf8.encode(arguments.mnemonic));
  final passphraseBytes = Uint8List.fromList(utf8.encode(arguments.passphrase));
  SingleSignatureVault? vault;
  try {
    vault = SingleSignatureVault.fromMnemonic(
      mnemonicBytes,
      passphrase: passphraseBytes,
      addressType: AddressType.getAddressTypeFromName(arguments.addressTypeName),
      accountIndex: arguments.accountIndex,
    );
    return vault.keyStore.extendedPublicKey.serialize() == arguments.expectedExtendedPublicKey;
  } finally {
    vault?.keyStore.wipeSeed();
    mnemonicBytes.fillRange(0, mnemonicBytes.length, 0);
    passphraseBytes.fillRange(0, passphraseBytes.length, 0);
  }
}

String _signHotWalletInBackground(_HotWalletSigningArguments arguments) {
  final mnemonicBytes = Uint8List.fromList(utf8.encode(arguments.mnemonic));
  final passphraseBytes = Uint8List.fromList(utf8.encode(arguments.passphrase));
  SingleSignatureVault? vault;
  try {
    final addressType = AddressType.getAddressTypeFromName(arguments.addressTypeName);
    vault = SingleSignatureVault.fromMnemonic(
      mnemonicBytes,
      passphrase: passphraseBytes,
      addressType: addressType,
      accountIndex: arguments.accountIndex,
    );
    if (vault.keyStore.extendedPublicKey.serialize() != arguments.expectedExtendedPublicKey) {
      throw StateError('The signer does not match this wallet');
    }
    final signedPsbt = vault.addSignatureToPsbt(arguments.unsignedPsbt);
    Psbt.parse(signedPsbt).getSignedTransaction(addressType);
    return signedPsbt;
  } finally {
    vault?.keyStore.wipeSeed();
    mnemonicBytes.fillRange(0, mnemonicBytes.length, 0);
    passphraseBytes.fillRange(0, passphraseBytes.length, 0);
  }
}
