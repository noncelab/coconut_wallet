import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const regtestAddress = 'bcrt1qxa3vg4mdqmyc4gvvw7jtyqvt4e6mvc8v3w6ytr';
  const testnetAddress = 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx';

  test('testnet rejects regtest (bcrt1) addresses, which coconut_lib groups with testnet', () {
    expect(
      AddressValidator.validateAddress(regtestAddress, NetworkType.testnet),
      AddressValidationError.notTestnetAddress,
    );
  });

  test('mainnet and regtest keep rejecting testnet addresses', () {
    expect(
      AddressValidator.validateAddress(testnetAddress, NetworkType.mainnet),
      AddressValidationError.notMainnetAddress,
    );
    expect(
      AddressValidator.validateAddress(testnetAddress, NetworkType.regtest),
      AddressValidationError.notRegtestnetAddress,
    );
  });
}
