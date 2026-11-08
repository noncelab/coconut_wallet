import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/utils/nfkd_util.dart';
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
      String networkType,
      String unsignedPsbt,
      _PsbtFinalization? finalization,
    });

/// How a payjoin PSBT is finalized after signing.
typedef _PsbtFinalization = ({bool allowFinalizedForeignInputs, bool keepDerivations, bool verifyForeignInputs});

typedef _HotWalletPassphraseValidationArguments =
    ({
      Uint8List mnemonic,
      Uint8List passphrase,
      String addressTypeName,
      int accountIndex,
      String expectedExtendedPublicKey,
      String networkType,
    });

class HotWalletSigningService {
  HotWalletSigningService({HotWalletSecretRepository? secretRepository})
    : _secretRepository = secretRepository ?? HotWalletSecretRepository();

  final HotWalletSecretRepository _secretRepository;

  Future<String> sign(HotWalletSigningRequest request) => _sign(request, null);

  /// Signs the PSBT and finalizes the inputs it signed, for a payjoin.
  ///
  /// With [allowFinalizedForeignInputs] the PSBT may carry inputs the other
  /// party already finalized; they are left as they are. A payjoin sender's
  /// Original keeps its derivations ([keepDerivations]) because payjoin
  /// copies them into the receiver's proposal, where the wallet needs them to
  /// recognise its inputs.
  ///
  /// The finalized PSBT is checked by extracting the transaction, which
  /// verifies every input's signature. A payjoin receiver passes false for
  /// [verifyForeignInputs]: the sender's inputs it is shown carry the
  /// Original's signatures, which do not cover the proposal. Our own
  /// signatures are verified when they are finalized either way.
  Future<String> signAndFinalize(
    HotWalletSigningRequest request, {
    required bool allowFinalizedForeignInputs,
    required bool keepDerivations,
    bool verifyForeignInputs = true,
  }) => _sign(request, (
    allowFinalizedForeignInputs: allowFinalizedForeignInputs,
    keepDerivations: keepDerivations,
    verifyForeignInputs: verifyForeignInputs,
  ));

  Future<String> _sign(HotWalletSigningRequest request, _PsbtFinalization? finalization) async {
    final plaintext = await _secretRepository.unlockAfterAuthentication(request.storageKey);
    Uint8List? mnemonicCopy;
    Uint8List? passphraseCopy;
    try {
      // compute로 isolate에 복사 전달되는 인자와는 별개로, 메인 isolate에 남는
      // 전달용 사본도 사용 후 명시적으로 지운다.
      mnemonicCopy = Uint8List.fromList(plaintext.mnemonic);
      // 저장된 패스프레이즈는 생성·복원 시 이미 NFKD로 정규화되어 있다.
      // 불필요하게 String으로 디코딩하지 않고 복사해, 지울 수 없는 평문 String 생성을 피한다.
      passphraseCopy =
          request.passphrase != null
              ? NfkdUtil.normalizeNfkdUtf8(request.passphrase!)
              : Uint8List.fromList(plaintext.passphrase);
      return await compute(_signHotWalletInBackground, (
        mnemonic: mnemonicCopy,
        passphrase: passphraseCopy,
        addressTypeName: request.addressTypeName,
        accountIndex: request.accountIndex,
        expectedExtendedPublicKey: request.expectedExtendedPublicKey,
        unsignedPsbt: request.unsignedPsbt,
        networkType: NetworkType.currentNetworkType.toString(),
        finalization: finalization,
      ));
    } finally {
      mnemonicCopy?.fillRange(0, mnemonicCopy.length, 0);
      passphraseCopy?.fillRange(0, passphraseCopy.length, 0);
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
    Uint8List? mnemonicCopy;
    Uint8List? passphraseCopy;
    try {
      mnemonicCopy = Uint8List.fromList(plaintext.mnemonic);
      passphraseCopy = NfkdUtil.normalizeNfkdUtf8(passphrase);
      return await compute(_validateHotWalletPassphraseInBackground, (
        mnemonic: mnemonicCopy,
        passphrase: passphraseCopy,
        addressTypeName: addressTypeName,
        accountIndex: accountIndex,
        expectedExtendedPublicKey: expectedExtendedPublicKey,
        networkType: NetworkType.currentNetworkType.toString(),
      ));
    } finally {
      mnemonicCopy?.fillRange(0, mnemonicCopy.length, 0);
      passphraseCopy?.fillRange(0, passphraseCopy.length, 0);
      plaintext.wipe();
    }
  }
}

bool _validateHotWalletPassphraseInBackground(_HotWalletPassphraseValidationArguments arguments) {
  SingleSignatureVault? vault;
  try {
    NetworkType.setNetworkType(NetworkType.getNetworkType(arguments.networkType));
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
    NetworkType.setNetworkType(NetworkType.getNetworkType(arguments.networkType));
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
    final finalization = arguments.finalization;
    if (finalization == null) {
      final signedPsbt = vault.addSignatureToPsbt(arguments.unsignedPsbt);
      Psbt.parse(signedPsbt).getSignedTransaction(addressType);
      return signedPsbt;
    }
    final signedPsbt = vault.addSignatureToPsbt(
      arguments.unsignedPsbt,
      allowFinalizedForeignInputs: finalization.allowFinalizedForeignInputs,
    );
    final finalized = Psbt.parse(signedPsbt).finalizeInputs(keepDerivations: finalization.keepDerivations);
    if (finalization.verifyForeignInputs) finalized.getSignedTransaction(addressType);
    return finalized.serialize();
  } finally {
    vault?.keyStore.wipeSeed();
    arguments.mnemonic.fillRange(0, arguments.mnemonic.length, 0);
    arguments.passphrase.fillRange(0, arguments.passphrase.length, 0);
  }
}
