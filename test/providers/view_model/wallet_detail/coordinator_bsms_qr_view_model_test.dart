import 'dart:convert';

import 'package:cbor/cbor.dart';
import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/coordinator_bsms_qr_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ur/ur_decoder.dart';

import '../../../mock/wallet_mock.dart';

class _WalletProvider extends Fake implements WalletProvider {
  _WalletProvider(this.wallet);

  final MultisigWalletItem wallet;

  @override
  WalletItemBase getWalletById(int id) {
    expect(id, wallet.id);
    return wallet;
  }
}

void main() {
  late MultisigWalletItem wallet;
  late CoordinatorBsmsQrViewModel viewModel;

  setUp(() {
    NetworkType.setNetworkType(NetworkType.regtest);
    wallet = WalletMock.createMultiSigWalletItem();
    viewModel = CoordinatorBsmsQrViewModel(_WalletProvider(wallet), wallet.id);
  });

  tearDown(() => viewModel.dispose());

  test('BSMS and Keystone UR QR bytes roundtrip to the complete export text', () {
    for (final format in ['BSMS', 'Keystone Multisig']) {
      final qr = viewModel.walletQrDataMap[format]!;
      expect(qr, startsWith('ur:bytes/'));

      final ur = URDecoder.decode(qr);
      expect(ur.type, 'bytes');
      final decoded = cbor.decode(ur.cbor);
      expect(decoded, isA<CborBytes>());
      expect(utf8.decode((decoded as CborBytes).bytes), viewModel.walletTextDataMap[format]);
    }

    expect(viewModel.walletTextDataMap['BSMS'], 'BSMS 1.0\n${wallet.descriptor}\n');
    expect(viewModel.walletTextDataMap['Keystone Multisig'], contains('Policy: 2 of 3'));
    expect(viewModel.walletTextDataMap['Keystone Multisig'], contains("Derivation: m/48'/1'/0'/2'"));
  });

  test('coordinator JSON and all export formats preserve wallet metadata and descriptor', () {
    final metadata = jsonDecode(viewModel.qrData) as Map<String, dynamic>;
    expect(metadata['name'], wallet.name);
    expect(metadata['colorIndex'], wallet.colorIndex);
    expect(metadata['iconIndex'], wallet.iconIndex);
    expect(metadata['coordinatorBsms'], viewModel.walletTextDataMap['BSMS']);
    expect((metadata['namesMap'] as Map).values.toSet(), wallet.signers.map((signer) => signer.name).toSet());

    expect(viewModel.walletQrDataMap.keys, unorderedEquals(viewModel.walletTextDataMap.keys));
    expect(viewModel.walletQrDataMap, hasLength(6));
    expect(viewModel.walletQrDataMap['Output Descriptor'], wallet.descriptor);
    expect(viewModel.walletTextDataMap['Output Descriptor'], wallet.descriptor);
    expect(viewModel.walletQrDataMap['Coldcard Multisig'], startsWith(r'B$ZU'));
    expect(
      viewModel.walletQrDataMap['BlueWallet Vault Multisig'],
      viewModel.walletTextDataMap['BlueWallet Vault Multisig'],
    );
    expect(viewModel.walletQrDataMap['Specter Desktop'], viewModel.walletTextDataMap['Specter Desktop']);
    expect((jsonDecode(viewModel.walletTextDataMap['Specter Desktop']!) as Map)['descriptor'], wallet.descriptor);
  });
}
