import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/services/security/hot_wallet_signing_service.dart';
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
}
