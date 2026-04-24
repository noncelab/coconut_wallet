part of 'utxo_split_screen.dart';

extension _UtxoSplitScreenBottomSheets on _UtxoSplitScreenState {
  void _showUtxoSelectionBottomSheet(BuildContext context, UtxoSplitViewModel viewModel) async {
    _autoOpenUtxoPickerScheduler.cancel();
    final result = await _utxoSelectionBottomSheetGuard.run<List<UtxoState>>(() async {
      return CommonBottomSheets.showDraggableBottomSheet<List<UtxoState>>(
        context: context,
        minChildSize: 0.6,
        maxChildSize: 0.9,
        initialChildSize: 0.6,
        childBuilder:
            (scrollController) => FixedTextScale(
              child: UtxoSelectionScreen(
                selectedUtxoList: viewModel.selectedUtxoList,
                walletId: widget.id,
                currentUnit: viewModel.currentUnit,
                scrollController: scrollController,
                isSplitMode: true,
              ),
            ),
      );
    });
    if (result != null && context.mounted) {
      viewModel.setSelectedUtxoList(result);
    }
  }

  void _showSplitMethodBottomSheet(BuildContext context, UtxoSplitViewModel viewModel) async {
    _autoOpenMethodPickerScheduler.cancel();
    final selectedItem = await _splitMethodSelectionBottomSheetGuard.run<UtxoSplitMethod>(() async {
      return CommonBottomSheets.showSelectableDraggableSheet<UtxoSplitMethod>(
        context: context,
        title: t.split_utxo_screen.method_bottom_sheet.title,
        items: UtxoSplitMethod.values,
        getItemId: (item) => item.name,
        initiallySelectedId: viewModel.selectedMethod?.name ?? UtxoSplitMethod.byAmount.name,
        allowConfirmWhenSelectionUnchanged: viewModel.selectedMethod == null,
        initialChildSize: 0.5,
        confirmText: t.done,
        minChildSize: 0.49,
        maxChildSize: 0.9,
        backgroundColor: CoconutColors.gray900,
        showGradient: false,
        itemBuilder: (context, item, isSelected, onTap) {
          return SelectableBottomSheetTextItem(
            isSelected: isSelected,
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(item.getLabel(t), style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white))],
            ),
          );
        },
      );
    });
    if (selectedItem != null && context.mounted) {
      viewModel.setSplitMethod(selectedItem);
    }
  }
}
