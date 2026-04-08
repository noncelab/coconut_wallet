import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/split_utxo/split_utxo_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/screens/send/refactor/utxo_selection_screen.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/estimated_fee_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';

class SplitUtxoScreen extends StatelessWidget {
  final int id;

  const SplitUtxoScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SplitUtxoViewModel>(
      create:
          (context) => SplitUtxoViewModel(
            id,
            context.read<PreferenceProvider>(),
            context.read<WalletProvider>(),
            context.read<AddressRepository>(),
            context.read<SendInfoProvider>(),
          ),
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
              _buildExpectedResult(viewModel),
              CoconutLayout.spacing_800h,
              Text(
                viewModel.getHeaderTitle(t),
                style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white),
              ),
              CoconutLayout.spacing_500h,
              if (hasSelectedCriteria) _buildSplitContent(viewModel),
              _buildCriteriaPicker(context, viewModel),
              _buildUtxoPicker(context, viewModel),
              _buildFeePicker(context, viewModel),
            ],
          ),
          _buildOrganizeButton(context, viewModel),
        ],
      ),
    );
  }

  Widget _buildExpectedResult(SplitUtxoViewModel viewModel) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SizeTransition(sizeFactor: animation, axisAlignment: -1.0, child: child),
        );
      },
      child:
          viewModel.showSplitResultBox
              ? SplitResultBox(key: const ValueKey('split_result_box'), viewModel: viewModel)
              : const SizedBox.shrink(key: ValueKey('split_result_box_empty')),
    );
  }

  Widget _buildOrganizeButton(BuildContext context, SplitUtxoViewModel viewModel) {
    return AnimatedOpacity(
      opacity: viewModel.showSplitResultBox ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: IgnorePointer(
        ignoring: !(viewModel.showSplitResultBox),
        child: FixedBottomButton(
          text: t.organize,
          onButtonClicked: () async {
            if (!viewModel.isSplitValid) return;
            FocusScope.of(context).unfocus();

            final isSuccess = await viewModel.buildSplitTransaction();
            if (isSuccess && context.mounted) {
              Navigator.pushNamed(context, '/send-confirm', arguments: {"currentUnit": viewModel.currentUnit});
            } else if (viewModel.finalErrorMessage.isNotEmpty && context.mounted) {
              Fluttertoast.showToast(
                msg: viewModel.finalErrorMessage,
                backgroundColor: CoconutColors.gray700,
                toastLength: Toast.LENGTH_SHORT,
              );
            }
          },
          isActive: viewModel.isSplitValid && !viewModel.isBuilding,
          backgroundColor: CoconutColors.white,
        ),
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
    final bool isSelected = viewModel.isUtxoSelected;

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
          text: viewModel.getSelectedUtxoAmountText(t),
          guideText: viewModel.getUtxoGuideText(t),
          textColor: isSelected ? CoconutColors.white : CoconutColors.gray500,
          inlineWidgets: inlineWidgets,
          coconutOptionStateEnum: viewModel.utxoOptionState,
          onTap: () => _showUtxoSelectionBottomSheet(context, viewModel),
        ),
        CoconutLayout.spacing_1000h,
      ],
    );
  }

  Widget _buildFeePicker(BuildContext context, SplitUtxoViewModel viewModel) {
    if (viewModel.splitAmountSats <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CoconutOptionPicker(
          label: t.split_utxo_screen.label_expected_fee,
          text: viewModel.getFeePickerText(t),
          textColor: viewModel.hasFeeRate ? CoconutColors.white : CoconutColors.gray500,
          onTap:
              () => EstimatedFeeBottomSheet.show(
                context: context,
                listenable: viewModel,
                estimatedFeeTextGetter: () => viewModel.estimatedFeeText,
                feeRateController: viewModel.feeRateController,
                feeRateFocusNode: viewModel.feeRateFocusNode,
                onFeeRateChanged: viewModel.onFeeRateChanged,
                onEditingComplete: () {
                  viewModel.removeTrailingDotInFeeRate();
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context);
                },
                recommendedFeeFetchStatusGetter: () => viewModel.recommendedFeeFetchStatus,
                feeInfosGetter: () => viewModel.feeInfos,
                refreshRecommendedFees: viewModel.refreshRecommendedFees,
                onFeeRateSelected: (sats) {
                  viewModel.setFeeRateFromRecommendation(sats);
                  FocusScope.of(context).unfocus();
                  Navigator.pop(context);
                },
              ),
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

  Widget _buildSplitByAmountBody(SplitUtxoViewModel viewModel) {
    return Column(
      children: [
        TextField(
          controller: viewModel.amountController,
          focusNode: viewModel.amountFocusNode,
          onTapOutside: (_) => viewModel.amountFocusNode.unfocus(),
          onEditingComplete: () => viewModel.amountFocusNode.unfocus(),
          onSubmitted: (_) => viewModel.amountFocusNode.unfocus(),
          textInputAction: TextInputAction.done,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white),
          decoration: InputDecoration(
            hintText: t.split_utxo_screen.placeholder_split_amount,
            hintStyle: CoconutTypography.body1_16.setColor(CoconutColors.gray500),
            errorText: viewModel.amountErrorText,
            errorStyle: CoconutTypography.caption_10.setColor(CoconutColors.hotPink),
            errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: CoconutColors.hotPink)),
            focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: CoconutColors.hotPink)),
            enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: CoconutColors.gray500)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: CoconutColors.white)),
            suffixIcon: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  viewModel.currentUnit.symbol,
                  style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white),
                ),
              ],
            ),
          ),
        ),
        CoconutLayout.spacing_1000h,
      ],
    );
  }

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

class SplitResultBox extends StatelessWidget {
  final SplitUtxoViewModel viewModel;

  const SplitResultBox({super.key, required this.viewModel});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: CoconutColors.gray800,
        border: Border.all(color: CoconutColors.gray600),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: SvgPicture.asset(
              'assets/svg/split-utxo.svg',
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(viewModel.splitText, style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white)),
                CoconutLayout.spacing_200h,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t.split_utxo_screen.expected_result.new_utxos,
                      style: CoconutTypography.body2_14.setColor(CoconutColors.gray400),
                    ),
                    Text(
                      viewModel.newUtxoResultText,
                      style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white),
                    ),
                  ],
                ),
                if (viewModel.remainderText.isNotEmpty) ...[
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      viewModel.remainderText,
                      style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.gray400),
                    ),
                  ),
                ],
                CoconutLayout.spacing_100h,
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      t.split_utxo_screen.expected_result.fee,
                      style: CoconutTypography.body2_14.setColor(CoconutColors.gray400),
                    ),
                    Text(
                      viewModel.estimatedFeeText,
                      style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
