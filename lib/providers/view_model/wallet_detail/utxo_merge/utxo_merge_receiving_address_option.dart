part of 'utxo_merge_view_model.dart';

class ReceivingAddressOption {
  final String address;
  final String walletName;
  final String derivationPath;

  const ReceivingAddressOption({required this.address, required this.walletName, required this.derivationPath});

  factory ReceivingAddressOption.fromWalletAddress(WalletAddress walletAddress, {required String walletName}) {
    return ReceivingAddressOption(
      address: walletAddress.address,
      walletName: walletName,
      derivationPath: walletAddress.derivationPath,
    );
  }
}
