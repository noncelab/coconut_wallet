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
