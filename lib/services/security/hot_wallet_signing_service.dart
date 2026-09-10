import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:flutter/foundation.dart';

typedef HotWalletSigningRequest =
    ({
      String storageKey,
      Uint8List? passphrase,
      String addressTypeName,
      int accountIndex,
      String expectedExtendedPublicKey,
      String unsignedPsbt,
    });

typedef _HotWalletSigningArguments =
    ({
      Uint8List mnemonic,
      Uint8List passphrase,
      String addressTypeName,
      int accountIndex,
      String expectedExtendedPublicKey,
      String unsignedPsbt,
    });

typedef _HotWalletPassphraseValidationArguments =
    ({
      Uint8List mnemonic,
      Uint8List passphrase,
      String addressTypeName,
      int accountIndex,
      String expectedExtendedPublicKey,
    });

class HotWalletSigningService {
  HotWalletSigningService({HotWalletSecretRepository? secretRepository})
    : _secretRepository = secretRepository ?? HotWalletSecretRepository();

  final HotWalletSecretRepository _secretRepository;

  Future<String> sign(HotWalletSigningRequest request) async {
    final plaintext = await _secretRepository.unlockAfterAuthentication(request.storageKey);
    try {
      return await compute(_signHotWalletInBackground, (
        mnemonic: Uint8List.fromList(plaintext.mnemonic),
        passphrase: Uint8List.fromList(request.passphrase ?? plaintext.passphrase),
        addressTypeName: request.addressTypeName,
        accountIndex: request.accountIndex,
        expectedExtendedPublicKey: request.expectedExtendedPublicKey,
        unsignedPsbt: request.unsignedPsbt,
      ));
    } finally {
      plaintext.wipe();
    }
  }

  Future<bool> validatePassphrase({
    required String storageKey,
    required Uint8List passphrase,
    required String addressTypeName,
    required int accountIndex,
    required String expectedExtendedPublicKey,
  }) async {
    final plaintext = await _secretRepository.unlockAfterAuthentication(storageKey);
    try {
      return await compute(_validateHotWalletPassphraseInBackground, (
        mnemonic: Uint8List.fromList(plaintext.mnemonic),
        passphrase: Uint8List.fromList(passphrase),
        addressTypeName: addressTypeName,
        accountIndex: accountIndex,
        expectedExtendedPublicKey: expectedExtendedPublicKey,
      ));
    } finally {
      plaintext.wipe();
    }
  }
}

bool _validateHotWalletPassphraseInBackground(_HotWalletPassphraseValidationArguments arguments) {
  SingleSignatureVault? vault;
  try {
    vault = SingleSignatureVault.fromMnemonic(
      arguments.mnemonic,
      passphrase: arguments.passphrase,
      addressType: AddressType.getAddressTypeFromName(arguments.addressTypeName),
      accountIndex: arguments.accountIndex,
    );
    return vault.keyStore.extendedPublicKey.serialize() == arguments.expectedExtendedPublicKey;
  } finally {
    vault?.keyStore.wipeSeed();
    arguments.mnemonic.fillRange(0, arguments.mnemonic.length, 0);
    arguments.passphrase.fillRange(0, arguments.passphrase.length, 0);
  }
}

String _signHotWalletInBackground(_HotWalletSigningArguments arguments) {
  SingleSignatureVault? vault;
  try {
    final addressType = AddressType.getAddressTypeFromName(arguments.addressTypeName);
    vault = SingleSignatureVault.fromMnemonic(
      arguments.mnemonic,
      passphrase: arguments.passphrase,
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
    arguments.mnemonic.fillRange(0, arguments.mnemonic.length, 0);
    arguments.passphrase.fillRange(0, arguments.passphrase.length, 0);
  }
}
