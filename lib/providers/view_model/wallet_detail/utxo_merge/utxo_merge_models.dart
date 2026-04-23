part of 'utxo_merge_view_model.dart';

class ReceiveAddressOption {
  final String address;
  final String walletName;
  final String derivationPath;

  const ReceiveAddressOption({required this.address, required this.walletName, required this.derivationPath});

  factory ReceiveAddressOption.fromWalletAddress(WalletAddress walletAddress, {required String walletName}) {
    return ReceiveAddressOption(
      address: walletAddress.address,
      walletName: walletName,
      derivationPath: walletAddress.derivationPath,
    );
  }
}
