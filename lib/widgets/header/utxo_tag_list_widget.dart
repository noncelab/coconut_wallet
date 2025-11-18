import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_list_view_model.dart';
import 'package:coconut_wallet/widgets/selector/custom_tag_horizontal_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class UtxoTagListWidget extends StatelessWidget {
  final String selectedUtxoTagName;
  final Function(String) onTagSelected;

  const UtxoTagListWidget({super.key, required this.selectedUtxoTagName, required this.onTagSelected});

  @override
  Widget build(BuildContext context) {
    return Consumer<UtxoListViewModel>(
      builder: (context, viewModel, child) {
        final utxoTagList = viewModel.utxoTagList;
        final tagListKey = viewModel.utxoTagListKey;

        return CustomTagHorizontalSelector(
          key: ValueKey('tag_list_$tagListKey'),
          tags: utxoTagList.map((e) => e.name).toList(),
          selectedName: selectedUtxoTagName,
          onSelectedTag: onTagSelected,
        );
      },
    );
  }
}
