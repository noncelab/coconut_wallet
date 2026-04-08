import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/split_utxo/split_utxo_view_model.dart';
import 'package:coconut_wallet/screens/send/refactor/utxo_selection_screen.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
// import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SplitUtxoScreen extends StatelessWidget {
  final int id;

  const SplitUtxoScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SplitUtxoViewModel>(
      create: (context) => SplitUtxoViewModel(id, context.read<PreferenceProvider>()),
      child: Scaffold(
        backgroundColor: CoconutColors.black,
        appBar: _buildAppBar(context),
        body: Consumer<SplitUtxoViewModel>(builder: (context, viewModel, _) => _buildBody(context, viewModel)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CoconutAppBar.build(
      context: context,
      backgroundColor: CoconutColors.black,
      title: t.split_utxo_screen.title,
      isBottom: true,
      isBackButton: true,
    );
  }

  Widget _buildBody(BuildContext context, SplitUtxoViewModel viewModel) {
    final hasSelectedCriteria = viewModel.selectedCriteria != null;

    return SafeArea(
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              CoconutLayout.spacing_800h,
              Text(
                viewModel.getHeaderTitle(t),
                style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white),
              ),
              CoconutLayout.spacing_500h,
              if (hasSelectedCriteria) _buildSplitContent(viewModel),

              _buildCriteriaPicker(context, viewModel),
              _buildUtxoPicker(context, viewModel),
              CoconutLayout.spacing_400h,
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCriteriaPicker(BuildContext context, SplitUtxoViewModel viewModel) {
    if (viewModel.selectedUtxoList.isEmpty) return const SizedBox.shrink();

    final criteria = viewModel.selectedCriteria;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoconutOptionPicker(
          label: criteria != null ? t.split_utxo_screen.label_split_criteria : null,
          text: criteria?.getLabel(t) ?? t.split_utxo_screen.placeholder_criteria,
          textColor: criteria != null ? CoconutColors.white : CoconutColors.gray500,
          onTap: () => _showSplitCriteriaBottomSheet(context, viewModel),
        ),
        CoconutLayout.spacing_1000h,
      ],
    );
  }

  Widget _buildUtxoPicker(BuildContext context, SplitUtxoViewModel viewModel) {
    final bool isSelected = viewModel.selectedUtxoList.isNotEmpty;
    final String amountText =
        isSelected
            ? viewModel.currentUnit.displayBitcoinAmount(viewModel.selectedUtxoList.first.amount, withUnit: true)
            : t.split_utxo_screen.placeholder_utxo;

    List<Widget> inlineWidgets = [];
    if (isSelected) {
      final utxoTagProvider = context.read<UtxoTagProvider>();
      final tags = utxoTagProvider.getUtxoTagsByUtxoId(id, viewModel.selectedUtxoList.first.utxoId);

      if (tags.isNotEmpty) {
        final firstTag = tags.first;
        final int colorIndex = firstTag.colorIndex;
        final Color foregroundColor = tagColorPalette[colorIndex];

        inlineWidgets.add(
          IntrinsicWidth(
            child: CoconutChip(
              minWidth: 40,
              color: CoconutColors.backgroundColorPaletteDark[colorIndex],
              borderColor: foregroundColor,
              label: '#${firstTag.name}',
              labelSize: 12,
              labelColor: foregroundColor,
            ),
          ),
        );

        if (tags.length > 1) {
          final int additionalTagCount = tags.length - 1;
          inlineWidgets.add(
            Text(
              t.split_utxo_screen.and_more_tags(count: additionalTagCount),
              style: CoconutTypography.caption_10.setColor(CoconutColors.gray500),
            ),
          );
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoconutOptionPicker(
          label: isSelected ? t.split_utxo_screen.label_selected_utxo : null,
          text: amountText,
          guideText:
              viewModel.hasAmountError
                  ? t.split_utxo_screen.utxo_error
                  : viewModel.hasAmountWarning
                  ? t.split_utxo_screen.utxo_warning
                  : null,
          textColor: isSelected ? CoconutColors.white : CoconutColors.gray500,
          inlineWidgets: inlineWidgets,
          coconutOptionStateEnum:
              viewModel.hasAmountError
                  ? CoconutOptionStateEnum.error
                  : viewModel.hasAmountWarning
                  ? CoconutOptionStateEnum.warning
                  : CoconutOptionStateEnum.normal,
          onTap: () => _showUtxoSelectionBottomSheet(context, viewModel),
        ),
      ],
    );
  }

  Widget _buildSplitContent(SplitUtxoViewModel viewModel) {
    switch (viewModel.selectedCriteria) {
      case SplitCriteria.byAmount:
        return _buildSplitByAmountBody(viewModel);
      case SplitCriteria.evenly:
        return _buildSplitEvenlyBody();
      case SplitCriteria.manually:
        return _buildSplitManuallyBody();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSplitByAmountBody(SplitUtxoViewModel viewModel) => Column(
  );
  Widget _buildSplitEvenlyBody() =>
      Center(child: Text('균등하게 나누기 화면', style: CoconutTypography.body1_16.setColor(CoconutColors.white)));
  Widget _buildSplitManuallyBody() =>
      Center(child: Text('수동으로 나누기 화면', style: CoconutTypography.body1_16.setColor(CoconutColors.white)));

  void _showUtxoSelectionBottomSheet(BuildContext context, SplitUtxoViewModel viewModel) async {
    final result = await CommonBottomSheets.showDraggableBottomSheet<List<UtxoState>>(
      context: context,
      minChildSize: 0.6,
      maxChildSize: 0.9,
      initialChildSize: 0.6,
      childBuilder:
          (scrollController) => UtxoSelectionScreen(
            selectedUtxoList: viewModel.selectedUtxoList,
            walletId: id,
            currentUnit: viewModel.currentUnit,
            scrollController: scrollController,
            isSplitMode: true,
          ),
    );

    if (result != null && context.mounted) {
      viewModel.setSelectedUtxoList(result);
    }
  }

  void _showSplitCriteriaBottomSheet(BuildContext context, SplitUtxoViewModel viewModel) async {
    final selectedItem = await CommonBottomSheets.showSelectableDraggableSheet<SplitCriteria>(
      context: context,
      title: t.split_utxo_screen.criteria_bottom_sheet.title,
      items: SplitCriteria.values,
      getItemId: (item) => item.name,
      initialChildSize: 0.5,
      confirmText: t.complete,
      minChildSize: 0.49,
      maxChildSize: 0.9,
      backgroundColor: CoconutColors.gray900,
      itemBuilder: (context, item, isSelected, onTap) {
        return SelectableBottomSheetTextItem(text: item.getLabel(t), isSelected: isSelected, onTap: onTap);
      },
    );

    if (selectedItem != null && context.mounted) {
      viewModel.setSelectedCriteria(selectedItem);
    }
  }
}
