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
    // compute로 isolate에 복사 전달되는 인자와는 별개로, 메인 isolate에 남는
    // 전달용 사본도 사용 후 명시적으로 지운다.
    final mnemonicCopy = Uint8List.fromList(plaintext.mnemonic);
    final passphraseCopy = Uint8List.fromList(request.passphrase ?? plaintext.passphrase);
    try {
      return await compute(_signHotWalletInBackground, (
        mnemonic: mnemonicCopy,
        passphrase: passphraseCopy,
        addressTypeName: request.addressTypeName,
        accountIndex: request.accountIndex,
        expectedExtendedPublicKey: request.expectedExtendedPublicKey,
        unsignedPsbt: request.unsignedPsbt,
      ));
    } finally {
      mnemonicCopy.fillRange(0, mnemonicCopy.length, 0);
      passphraseCopy.fillRange(0, passphraseCopy.length, 0);
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
    final mnemonicCopy = Uint8List.fromList(plaintext.mnemonic);
    final passphraseCopy = Uint8List.fromList(passphrase);
    try {
      return await compute(_validateHotWalletPassphraseInBackground, (
        mnemonic: mnemonicCopy,
        passphrase: passphraseCopy,
        addressTypeName: addressTypeName,
        accountIndex: accountIndex,
        expectedExtendedPublicKey: expectedExtendedPublicKey,
      ));
    } finally {
      mnemonicCopy.fillRange(0, mnemonicCopy.length, 0);
      passphraseCopy.fillRange(0, passphraseCopy.length, 0);
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
