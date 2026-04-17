part of 'merge_utxos_screen.dart';

class _BottomSheetTab {
  final String label;
  final Widget child;

  const _BottomSheetTab({required this.label, required this.child});
}

class _TagCombinationSection {
  final List<UtxoTag> tags;
  final List<UtxoState> utxos;

  _TagCombinationSection({required this.tags, required this.utxos});
}

class _ReusedAddressSection {
  final String address;
  final List<UtxoState> utxos;

  _ReusedAddressSection({required this.address, required this.utxos});
}

class _ReceiveAddressOption {
  final String address;
  final String walletName;
  final String derivationPath;

  const _ReceiveAddressOption({required this.address, required this.walletName, required this.derivationPath});

  factory _ReceiveAddressOption.fromWalletAddress(WalletAddress walletAddress, {required String walletName}) {
    return _ReceiveAddressOption(
      address: walletAddress.address,
      walletName: walletName,
      derivationPath: walletAddress.derivationPath,
    );
  }
}

class _AmountCriteriaSelectionResult {
  final UtxoAmountCriteria criteria;
  final String? customAmountText;
  final bool isLessThan;

  const _AmountCriteriaSelectionResult({required this.criteria, this.customAmountText, this.isLessThan = false});
}

class _ReceiveAddressSelectionResult {
  final String address;
  final bool isDirectInput;

  const _ReceiveAddressSelectionResult({required this.address, required this.isDirectInput});
}
