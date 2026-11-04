part of 'utxo_merge_screen.dart';

class _BottomSheetTab {
  final String label;
  final Widget child;

  /// 세그먼트 아래 여백. 목록 항목은 자체 위 여백이 있어 0
  final double topSpacing;

  const _BottomSheetTab({required this.label, required this.child, this.topSpacing = 16});
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
