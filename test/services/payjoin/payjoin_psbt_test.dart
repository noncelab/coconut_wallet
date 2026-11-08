import 'dart:convert';
import 'dart:typed_data';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/hot_wallet_secret.dart';
import 'package:coconut_wallet/repository/secure_storage/hot_wallet_secret_repository.dart';
import 'package:coconut_wallet/services/payjoin/payjoin_psbt.dart';
import 'package:coconut_wallet/services/security/hot_wallet_signing_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSecretRepository extends Fake implements HotWalletSecretRepository {
  _FakeSecretRepository(this.mnemonic);

  final String mnemonic;

  @override
  Future<HotWalletPlaintext> unlockAfterAuthentication(String storageKey) async =>
      HotWalletPlaintext(mnemonic: Uint8List.fromList(utf8.encode(mnemonic)), passphrase: Uint8List(0));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mnemonic = 'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';
  late SingleSignatureVault vault;
  late SingleSignatureWallet wallet;

  setUp(() {
    NetworkType.setNetworkType(NetworkType.regtest);
    vault = SingleSignatureVault.fromMnemonic(Uint8List.fromList(utf8.encode(mnemonic)));
    wallet = SingleSignatureWallet.fromDescriptor(vault.descriptor);
  });

  tearDown(() {
    vault.keyStore.wipeSeed();
    NetworkType.setNetworkType(NetworkType.testnet);
  });

  Transaction twoInputSpend() => Transaction.forSinglePayment(
    [
      Utxo(List.filled(32, '11').join(), 0, 60000, '${vault.derivationPath}/0/3'),
      Utxo(List.filled(32, '22').join(), 1, 50000, '${vault.derivationPath}/1/7'),
    ],
    vault.getAddress(9),
    '${vault.derivationPath}/1/0',
    80000,
    1,
    vault,
  );

  String stripDerivations(String psbtBase64) {
    final psbt = Psbt.parse(psbtBase64);
    for (final input in psbt.toKeyMap()['inputs'] as List<dynamic>) {
      (input as Map<String, dynamic>).removeWhere((key, _) => key.startsWith('06'));
    }
    return Psbt.parse(psbt.serialize()).serialize();
  }

  String? pathOf(String address) {
    for (final isChange in [false, true]) {
      for (var i = 0; i < 20; i++) {
        if (wallet.getAddress(i, isChange: isChange) == address) {
          return '${vault.derivationPath}/${isChange ? 1 : 0}/$i';
        }
      }
    }
    return null;
  }

  group('addOwnDerivations', () {
    test('restores the derivations a signer needs', () {
      final unsigned = Psbt.fromTransaction(twoInputSpend(), wallet).serialize();
      final stripped = stripDerivations(unsigned);
      expect(Psbt.parse(stripped).inputs.every((i) => i.bip32Derivation?.isEmpty ?? true), isTrue);

      final restored = addOwnDerivations(stripped, wallet: wallet, derivationPathOf: pathOf);

      final want = Psbt.parse(unsigned).inputs;
      final got = Psbt.parse(restored).inputs;
      for (var i = 0; i < want.length; i++) {
        expect(got[i].bip32Derivation!.single.publicKey, want[i].bip32Derivation!.single.publicKey);
        expect(got[i].bip32Derivation!.single.path, want[i].bip32Derivation!.single.path);
        expect(got[i].bip32Derivation!.single.masterFingerprint, want[i].bip32Derivation!.single.masterFingerprint);
      }
      // The signer accepts the restored PSBT and signs every input.
      final signed = vault.addSignatureToPsbt(restored);
      expect(Psbt.parse(signed).getSignedTransaction(AddressType.p2wpkh).inputs, hasLength(2));
    });

    test('leaves inputs alone when the address is not ours or the path does not derive it', () {
      final stripped = stripDerivations(Psbt.fromTransaction(twoInputSpend(), wallet).serialize());
      expect(addOwnDerivations(stripped, wallet: wallet, derivationPathOf: (_) => null), stripped);
      expect(
        addOwnDerivations(stripped, wallet: wallet, derivationPathOf: (_) => '${vault.derivationPath}/0/15'),
        stripped,
        reason: 'a path that derives a different address is ignored',
      );
    });

    test('is a no-op when the derivations are present', () {
      final unsigned = Psbt.fromTransaction(twoInputSpend(), wallet).serialize();
      expect(addOwnDerivations(unsigned, wallet: wallet, derivationPathOf: pathOf), unsigned);
    });
  });

  group('HotWalletSigningService.signAndFinalize', () {
    test('finalizes an Original and keeps derivations when asked', () async {
      final service = HotWalletSigningService(secretRepository: _FakeSecretRepository(mnemonic));
      final transaction = twoInputSpend();
      final finalized = await service.signAndFinalize(
        (
          storageKey: 'k',
          passphrase: null,
          addressTypeName: vault.addressType.name,
          accountIndex: 0,
          expectedExtendedPublicKey: vault.keyStore.extendedPublicKey.serialize(),
          unsignedPsbt: Psbt.fromTransaction(transaction, wallet).serialize(),
        ),
        allowFinalizedForeignInputs: false,
        keepDerivations: true,
      );
      final psbt = Psbt.parse(finalized);
      expect(psbt.inputs.every((input) => input.isFinalized), isTrue);
      expect(psbt.inputs.every((input) => input.bip32Derivation?.length == 1), isTrue);
      expect(psbt.getSignedTransaction(AddressType.p2wpkh).transactionHash, transaction.transactionHash);
    });
  });
}
