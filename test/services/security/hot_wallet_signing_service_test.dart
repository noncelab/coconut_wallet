import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/services/security/hot_wallet_signing_service.dart';
import 'package:coconut_wallet/utils/nfkd_util.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecretRepository extends Fake implements HotWalletSecretRepository {
  _FakeSecretRepository(this.plaintext);

  final HotWalletPlaintext plaintext;
  String? requestedStorageKey;

  @override
  Future<HotWalletPlaintext> unlockAfterAuthentication(String storageKey) async {
    requestedStorageKey = storageKey;
    return plaintext;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const publicMnemonic =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  for (final network in [NetworkType.mainnet, NetworkType.regtest]) {
    for (final passphraseAtSigning in [false, true]) {
      test('signs and finalizes the original transaction ($network, input=$passphraseAtSigning)', () async {
        NetworkType.setNetworkType(network);
        final mnemonic = Uint8List.fromList(utf8.encode(publicMnemonic));
        final passphrase = NfkdUtil.encodeNfkd('Café');
        final vault = SingleSignatureVault.fromMnemonic(mnemonic, passphrase: passphrase);
        final plaintext = HotWalletPlaintext(
          mnemonic: Uint8List.fromList(mnemonic),
          passphrase: passphraseAtSigning ? Uint8List(0) : Uint8List.fromList(passphrase),
        );
        final runtimePassphrase = passphraseAtSigning ? Uint8List.fromList(utf8.encode('Café')) : null;
        final service = HotWalletSigningService(secretRepository: _FakeSecretRepository(plaintext));
        final transaction = Transaction.forSinglePayment(
          [Utxo(List.filled(32, '11').join(), 0, 100000, '${vault.derivationPath}/0/0')],
          vault.getAddress(2),
          '${vault.derivationPath}/1/0',
          10000,
          1,
          vault,
        );
        try {
          final signed = await service.sign((
            storageKey: 'hot_wallet_secret_sign_test',
            passphrase: runtimePassphrase,
            addressTypeName: vault.addressType.name,
            accountIndex: 0,
            expectedExtendedPublicKey: vault.keyStore.extendedPublicKey.serialize(),
            unsignedPsbt: Psbt.fromTransaction(transaction, vault).serialize(),
          ));
          // Finalization verifies the actual signatures, in addition to preserving transaction intent.
          final finalized = Psbt.parse(signed).getSignedTransaction(vault.addressType);
          expect(finalized.inputs.single.transactionHash, transaction.inputs.single.transactionHash);
          expect(finalized.inputs.single.index, transaction.inputs.single.index);
          expect(finalized.inputs.single.sequence, transaction.inputs.single.sequence);
          expect(finalized.inputs.single.witnessList, isNotEmpty);
          expect(
            finalized.outputs.map((output) => output.serialize()),
            transaction.outputs.map((output) => output.serialize()),
          );
          expect(finalized.version, transaction.version);
          expect(finalized.lockTime, transaction.lockTime);
          expect(plaintext.mnemonic, everyElement(0));
          expect(plaintext.passphrase, everyElement(0));
          if (runtimePassphrase != null) expect(runtimePassphrase, utf8.encode('Café'));
        } finally {
          vault.keyStore.wipeSeed();
          mnemonic.fillRange(0, mnemonic.length, 0);
          passphrase.fillRange(0, passphrase.length, 0);
          runtimePassphrase?.fillRange(0, runtimePassphrase.length, 0);
          NetworkType.setNetworkType(NetworkType.testnet);
        }
      });
    }
  }

  test('a different signer cannot sign and decrypted secrets are wiped on rejection', () async {
    final plaintext = HotWalletPlaintext(
      mnemonic: Uint8List.fromList(utf8.encode(publicMnemonic)),
      passphrase: Uint8List(0),
    );
    final vault = SingleSignatureVault.fromMnemonic(plaintext.mnemonic);
    final input = Uint8List.fromList(utf8.encode('wrong-passphrase'));
    final service = HotWalletSigningService(secretRepository: _FakeSecretRepository(plaintext));
    try {
      await expectLater(
        service.sign((
          storageKey: 'hot_wallet_secret_rejected_signer',
          passphrase: input,
          addressTypeName: vault.addressType.name,
          accountIndex: 0,
          expectedExtendedPublicKey: vault.keyStore.extendedPublicKey.serialize(),
          unsignedPsbt: '',
        )),
        throwsStateError,
      );
      expect(plaintext.mnemonic, everyElement(0));
      expect(plaintext.passphrase, everyElement(0));
      expect(input, utf8.encode('wrong-passphrase'));
    } finally {
      vault.keyStore.wipeSeed();
      input.fillRange(0, input.length, 0);
    }
  });

  test('a malformed PSBT is rejected and decrypted secrets are wiped', () async {
    final plaintext = HotWalletPlaintext(
      mnemonic: Uint8List.fromList(utf8.encode(publicMnemonic)),
      passphrase: Uint8List(0),
    );
    final vault = SingleSignatureVault.fromMnemonic(plaintext.mnemonic);
    final service = HotWalletSigningService(secretRepository: _FakeSecretRepository(plaintext));
    try {
      await expectLater(
        service.sign((
          storageKey: 'hot_wallet_secret_invalid_psbt',
          passphrase: null,
          addressTypeName: vault.addressType.name,
          accountIndex: 0,
          expectedExtendedPublicKey: vault.keyStore.extendedPublicKey.serialize(),
          unsignedPsbt: '%%%invalid-psbt%%%',
        )),
        throwsFormatException,
      );
      expect(plaintext.mnemonic, everyElement(0));
      expect(plaintext.passphrase, everyElement(0));
    } finally {
      vault.keyStore.wipeSeed();
    }
  });

  test('wrong passphrase validation returns false and wipes decrypted secrets', () async {
    final plaintext = HotWalletPlaintext(
      mnemonic: Uint8List.fromList(utf8.encode(publicMnemonic)),
      passphrase: Uint8List(0),
    );
    final vault = SingleSignatureVault.fromMnemonic(plaintext.mnemonic);
    final input = Uint8List.fromList(utf8.encode('wrong-passphrase'));
    final service = HotWalletSigningService(secretRepository: _FakeSecretRepository(plaintext));
    try {
      expect(
        await service.validatePassphrase(
          storageKey: 'hot_wallet_secret_invalid_passphrase',
          passphrase: input,
          addressTypeName: vault.addressType.name,
          accountIndex: 0,
          expectedExtendedPublicKey: vault.keyStore.extendedPublicKey.serialize(),
        ),
        isFalse,
      );
      expect(plaintext.mnemonic, everyElement(0));
      expect(plaintext.passphrase, everyElement(0));
    } finally {
      vault.keyStore.wipeSeed();
      input.fillRange(0, input.length, 0);
    }
  });

  for (final signing in [false, true]) {
    test('정규화 실패 시에도 복호화한 데이터를 지운다 (sign=$signing)', () async {
      final plaintext = HotWalletPlaintext(
        mnemonic: Uint8List.fromList([1, 2, 3]),
        passphrase: Uint8List.fromList([4, 5, 6]),
      );
      final input = Uint8List.fromList([0xFF]);
      final service = HotWalletSigningService(secretRepository: _FakeSecretRepository(plaintext));
      final Future<Object> result =
          signing
              ? service.sign((
                storageKey: 'test',
                passphrase: input,
                addressTypeName: 'p2wpkh',
                accountIndex: 0,
                expectedExtendedPublicKey: '',
                unsignedPsbt: '',
              ))
              : service.validatePassphrase(
                storageKey: 'test',
                passphrase: input,
                addressTypeName: 'p2wpkh',
                accountIndex: 0,
                expectedExtendedPublicKey: '',
              );
      await expectLater(result, throwsFormatException);
      expect(plaintext.mnemonic, everyElement(0));
      expect(plaintext.passphrase, everyElement(0));
      expect(input, [0xFF]);
    });
  }

  test('mainnet에서도 background isolate에서 패스프레이즈를 검증한다', () async {
    NetworkType.setNetworkType(NetworkType.mainnet);
    const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const passphrase = 'correct-passphrase';
    final mnemonicBytes = Uint8List.fromList(utf8.encode(mnemonic));
    final passphraseBytes = Uint8List.fromList(utf8.encode(passphrase));
    final vault = SingleSignatureVault.fromMnemonic(
      mnemonicBytes,
      passphrase: passphraseBytes,
      addressType: AddressType.p2wpkh,
      accountIndex: 0,
    );
    final repository = _FakeSecretRepository(
      HotWalletPlaintext(mnemonic: Uint8List.fromList(utf8.encode(mnemonic)), passphrase: Uint8List(0)),
    );
    final service = HotWalletSigningService(secretRepository: repository);

    try {
      expect(
        await service.validatePassphrase(
          storageKey: 'hot_wallet_secret_mainnet_test',
          passphrase: Uint8List.fromList(utf8.encode(passphrase)),
          addressTypeName: AddressType.p2wpkh.name,
          accountIndex: 0,
          expectedExtendedPublicKey: vault.keyStore.extendedPublicKey.serialize(),
        ),
        isTrue,
      );
    } finally {
      vault.keyStore.wipeSeed();
      mnemonicBytes.fillRange(0, mnemonicBytes.length, 0);
      passphraseBytes.fillRange(0, passphraseBytes.length, 0);
      NetworkType.setNetworkType(NetworkType.testnet);
    }
  });

  test('passphrase 검증 시 Screen에 mnemonic을 노출하지 않고 저장소에서 직접 복호화한다', () async {
    const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const passphrase = 'correct-passphrase';
    final mnemonicBytes = Uint8List.fromList(utf8.encode(mnemonic));
    final passphraseBytes = Uint8List.fromList(utf8.encode(passphrase));
    final vault = SingleSignatureVault.fromMnemonic(
      mnemonicBytes,
      passphrase: passphraseBytes,
      addressType: AddressType.p2wpkh,
      accountIndex: 0,
    );
    final repository = _FakeSecretRepository(
      HotWalletPlaintext(mnemonic: Uint8List.fromList(utf8.encode(mnemonic)), passphrase: Uint8List(0)),
    );
    final service = HotWalletSigningService(secretRepository: repository);

    final valid = await service.validatePassphrase(
      storageKey: 'hot_wallet_secret_test',
      passphrase: Uint8List.fromList(utf8.encode(passphrase)),
      addressTypeName: AddressType.p2wpkh.name,
      accountIndex: 0,
      expectedExtendedPublicKey: vault.keyStore.extendedPublicKey.serialize(),
    );

    expect(valid, isTrue);
    expect(repository.requestedStorageKey, 'hot_wallet_secret_test');
    expect(repository.plaintext.mnemonic.every((byte) => byte == 0), isTrue);
    expect(repository.plaintext.passphrase.every((byte) => byte == 0), isTrue);
    vault.keyStore.wipeSeed();
    mnemonicBytes.fillRange(0, mnemonicBytes.length, 0);
    passphraseBytes.fillRange(0, passphraseBytes.length, 0);
  });

  test('조합형 패스프레이즈 입력을 NFKD로 정규화해 동일한 signer로 검증한다', () async {
    const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
    const composedPassphrase = '코코넛-Café-がぎ';
    final mnemonicBytes = Uint8List.fromList(utf8.encode(mnemonic));
    final normalizedPassphrase = NfkdUtil.encodeNfkd(composedPassphrase);
    final vault = SingleSignatureVault.fromMnemonic(
      mnemonicBytes,
      passphrase: normalizedPassphrase,
      addressType: AddressType.p2wpkh,
      accountIndex: 0,
    );
    final repository = _FakeSecretRepository(
      HotWalletPlaintext(mnemonic: Uint8List.fromList(mnemonicBytes), passphrase: Uint8List(0)),
    );
    final service = HotWalletSigningService(secretRepository: repository);

    try {
      expect(
        await service.validatePassphrase(
          storageKey: 'hot_wallet_secret_nfkd_test',
          passphrase: Uint8List.fromList(utf8.encode(composedPassphrase)),
          addressTypeName: AddressType.p2wpkh.name,
          accountIndex: 0,
          expectedExtendedPublicKey: vault.keyStore.extendedPublicKey.serialize(),
        ),
        isTrue,
      );
    } finally {
      vault.keyStore.wipeSeed();
      mnemonicBytes.fillRange(0, mnemonicBytes.length, 0);
      normalizedPassphrase.fillRange(0, normalizedPassphrase.length, 0);
    }
  });
}
