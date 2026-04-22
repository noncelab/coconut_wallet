part of 'utxo_merge_screen.dart';

class _BottomSheetTab {
  final String label;
  final Widget child;

  const _BottomSheetTab({required this.label, required this.child});
}

class _TaggedUtxoGroup {
  final List<UtxoTag> tags;
  final List<UtxoState> utxos;

  _TaggedUtxoGroup({required this.tags, required this.utxos});
}

class _ReusedAddressSection {
  final String address;
  final List<UtxoState> utxos;

  _ReusedAddressSection({required this.address, required this.utxos});
}

class _AmountRangeSelectionResult {
  final UtxoAmountRange range;
  final String? customAmountText;
  final bool isLessThan;

  const _AmountRangeSelectionResult({required this.range, this.customAmountText, this.isLessThan = false});
}

class _ReceivingAddressSelectionResult {
  final String address;
  final bool isDirectInput;

  const _ReceivingAddressSelectionResult({required this.address, required this.isDirectInput});
}
