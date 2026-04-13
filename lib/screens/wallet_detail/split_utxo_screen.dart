import 'dart:ui';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/core/transaction/utxo_split_transaction_builder.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:tuple/tuple.dart';
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
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/widgets/ripple_effect.dart';

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
            (outputCount) => _showBigTxConfirmDialog(context, outputCount),
          ),
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: CoconutColors.black,
            appBar: _buildAppBar(context),
            body: _buildBody(context),
          );
        },
      ),
    );
  }

  Future<bool> _showBigTxConfirmDialog(BuildContext context, int outputCount) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.confirm,
          description: '나누는 개수가 많아 트랜잭션 생성 시 1분 이상 걸릴 수 있어요. 취소를 누르시면 예측값을 보여드려요. 트랜잭션을 생성하시겠어요?',
          onTapRight: () {
            Navigator.pop(dialogContext, true);
          },
          onTapLeft: () {
            Navigator.pop(dialogContext, false);
          },
        );
      },
    );

    return result ?? false;
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

  Widget _buildBody(BuildContext context) {
    return SafeArea(
      child: Selector<SplitUtxoViewModel, bool>(
        selector: (_, vm) => vm.isBuilding,
        builder: (context, isBuilding, child) {
          return LoadingOverlay(isLoading: isBuilding, child: child!);
        },
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              children: [
                _buildExpectedResult(),
                CoconutLayout.spacing_800h,
                _buildHeaderTitle(),
                _buildDustError(),
                _buildSplitContent(context),
                _buildCriteriaPicker(context),
                _buildUtxoPicker(context),
                _buildFeePicker(context),
              ],
            ),
            _buildOrganizeButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderTitle() {
    return Selector<SplitUtxoViewModel, Tuple2<List<UtxoState>, SplitCriteria?>>(
      selector: (_, vm) => Tuple2(vm.selectedUtxoList, vm.selectedCriteria),
      builder: (context, data, _) {
        return Text(
          _getHeaderTitle(t, data.item1, data.item2),
          style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white),
        );
      },
    );
  }

  Widget _buildDustError() {
    return Selector<SplitUtxoViewModel, bool>(
      selector: (_, vm) => vm.isDustError,
      builder: (_, isDustError, __) {
        if (isDustError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoconutLayout.spacing_50h,
              Text(t.split_utxo_screen.dust_error, style: CoconutTypography.caption_10.setColor(CoconutColors.hotPink)),
              CoconutLayout.spacing_200h,
            ],
          );
        }
        return CoconutLayout.spacing_600h;
      },
    );
  }

  Widget _buildExpectedResult() {
    return Selector<SplitUtxoViewModel, Tuple2<bool, UtxoSplitResult?>>(
      selector: (_, vm) => Tuple2(vm.showSplitResultBox, vm.splitResult),
      builder: (context, data, _) {
        final showSplitResultBox = data.item1;
        final splitResult = data.item2;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SizeTransition(sizeFactor: animation, axisAlignment: -1.0, child: child),
            );
          },
          child:
              showSplitResultBox
                  ? SplitResultBox(key: const ValueKey('split_result_box'), isPreviewResult: splitResult == null)
                  : const SizedBox.shrink(key: ValueKey('split_result_box_empty')),
        );
      },
    );
  }

  Widget _buildOrganizeButton(BuildContext context) {
    return Selector<SplitUtxoViewModel, Tuple4<bool, bool, bool, String>>(
      selector: (_, vm) => Tuple4(vm.showSplitResultBox, vm.isSplitValid, vm.isBuilding, vm.finalErrorMessage),
      builder: (context, data, _) {
        final showSplitResultBox = data.item1;
        final isSplitValid = data.item2;
        final isBuilding = data.item3;
        final finalErrorMessage = data.item4;
        final viewModel = context.read<SplitUtxoViewModel>();
        return AnimatedOpacity(
          opacity: showSplitResultBox ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !showSplitResultBox,
            child: FixedBottomButton(
              subWidget:
                  finalErrorMessage.isNotEmpty
                      ? Text(
                        finalErrorMessage,
                        style: CoconutTypography.caption_10.setColor(CoconutColors.hotPink),
                        textAlign: TextAlign.center,
                      )
                      : null,
              text: t.organize,
              onButtonClicked: () async {
                if (!isSplitValid) return;
                FocusScope.of(context).unfocus();

                final isSuccess = await viewModel.buildTxAndSaveForNext();
                if (isSuccess && context.mounted) {
                  Navigator.pushNamed(context, '/send-confirm', arguments: {"currentUnit": viewModel.currentUnit});
                }
              },
              isActive: isSplitValid && !isBuilding && finalErrorMessage.isEmpty,
              backgroundColor: CoconutColors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCriteriaPicker(BuildContext context) {
    return Selector<SplitUtxoViewModel, Tuple2<bool, SplitCriteria?>>(
      selector: (_, vm) => Tuple2(vm.selectedUtxoList.isNotEmpty, vm.selectedCriteria),
      builder: (context, data, _) {
        final isUtxoSelected = data.item1;
        final criteria = data.item2;
        if (!isUtxoSelected) return const SizedBox.shrink();

        final viewModel = context.read<SplitUtxoViewModel>();
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
      },
    );
  }

  Widget _buildUtxoPicker(BuildContext context) {
    return Selector<SplitUtxoViewModel, Tuple4<bool, String?, CoconutOptionStateEnum, List<UtxoState>>>(
      selector: (_, vm) => Tuple4(vm.isUtxoSelected, vm.getUtxoGuideText(t), vm.utxoOptionState, vm.selectedUtxoList),
      builder: (context, data, _) {
        List<Widget> inlineWidgets = [];
        final isSelected = data.item1;
        final guideText = data.item2;
        final optionState = data.item3;
        final selectedUtxoList = data.item4;

        if (isSelected) {
          final utxoTagProvider = context.read<UtxoTagProvider>();
          final tags = utxoTagProvider.getUtxoTagsByUtxoId(id, selectedUtxoList.first.utxoId);

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

        final viewModel = context.read<SplitUtxoViewModel>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoconutOptionPicker(
              label: isSelected ? t.split_utxo_screen.label_selected_utxo : null,
              text: viewModel.getSelectedUtxoAmountText(t),
              guideText: guideText,
              textColor: isSelected ? CoconutColors.white : CoconutColors.gray500,
              inlineWidgets: inlineWidgets,
              coconutOptionStateEnum: optionState,
              onTap: () => _showUtxoSelectionBottomSheet(context, viewModel),
            ),
            CoconutLayout.spacing_1000h,
          ],
        );
      },
    );
  }

  Widget _buildFeePicker(BuildContext context) {
    return Selector<SplitUtxoViewModel, Tuple3<bool, Tuple2<bool, String?>, String>>(
      selector:
          (_, vm) => Tuple3(vm.shouldShowFeePicker, Tuple2(vm.hasFeeRate, vm.errorTextAboutFee), vm.previewFeeText),
      builder: (context, data, _) {
        final shouldShow = data.item1;
        final hasFeeRate = data.item2.item1;
        final feeExceedsAmountErrorText = data.item2.item2;
        final previewFeeText = data.item3;

        if (!shouldShow) {
          return const SizedBox.shrink();
        }

        final viewModel = context.read<SplitUtxoViewModel>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoconutOptionPicker(
              label: t.split_utxo_screen.label_expected_fee,
              text: _getFeePickerText(t, hasFeeRate, previewFeeText),
              textColor: hasFeeRate ? CoconutColors.white : CoconutColors.gray500,
              coconutOptionStateEnum: viewModel.feeOptionState,
              guideText: feeExceedsAmountErrorText,
              onTap:
                  () => EstimatedFeeBottomSheet.show(
                    context: context,
                    listenable: viewModel,
                    estimatedFeeTextGetter: () => viewModel.previewFeeText,
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
      },
    );
  }

  Widget _buildSplitContent(BuildContext context) {
    return Selector<SplitUtxoViewModel, SplitCriteria?>(
      selector: (_, vm) => vm.selectedCriteria,
      builder: (context, criteria, _) {
        if (criteria == null) return const SizedBox.shrink();
        switch (criteria) {
          case SplitCriteria.byAmount:
            return _buildSplitByAmountBody(context);
          case SplitCriteria.evenly:
            return _buildSplitEvenlyBody(context);
          case SplitCriteria.manually:
            return _buildSplitManuallyBody(context);
        }
      },
    );
  }

  Widget _buildSplitByAmountBody(BuildContext context) {
    final viewModel = context.read<SplitUtxoViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Selector<SplitUtxoViewModel, Tuple2<String?, String>>(
          selector: (_, vm) => Tuple2(vm.amountErrorText, vm.currentUnit.symbol),
          builder: (context, data, _) {
            return TextField(
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
                errorText: data.item1,
                errorStyle: CoconutTypography.caption_10.setColor(CoconutColors.hotPink),
                errorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: CoconutColors.hotPink)),
                focusedErrorBorder: const UnderlineInputBorder(borderSide: BorderSide(color: CoconutColors.hotPink)),
                enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: CoconutColors.gray500)),
                focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: CoconutColors.white)),
                suffixIcon: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [Text(data.item2, style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white))],
                ),
              ),
            );
          },
        ),
        CoconutLayout.spacing_300h,
        _buildRecommendedAmounts(),
        CoconutLayout.spacing_1000h,
      ],
    );
  }

  Widget _buildRecommendedAmounts() {
    return Selector<SplitUtxoViewModel, Tuple2<List<double>, BitcoinUnit>>(
      selector: (_, vm) => Tuple2(vm.recommendedSplitAmounts, vm.currentUnit),
      builder: (context, data, _) {
        final recommendedSplitAmounts = data.item1;
        final currentUnit = data.item2;
        final viewModel = context.read<SplitUtxoViewModel>();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Wrap(
            spacing: 8,
            children:
                recommendedSplitAmounts.map((btc) {
                  final sats = (btc * 1e8).toInt();
                  return RippleEffect(
                    onTap: () => viewModel.onRecommendedAmountTapped(btc),
                    borderRadius: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        border: Border.all(color: CoconutColors.gray700),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        currentUnit.displayBitcoinAmount(sats, withUnit: true),
                        style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                      ),
                    ),
                  );
                }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildSplitEvenlyBody(BuildContext context) {
    final viewModel = context.read<SplitUtxoViewModel>();
    return Column(
      children: [
        Selector<SplitUtxoViewModel, Tuple2<int, bool>>(
          selector: (_, vm) => Tuple2(vm.splitCount, vm.isDustError),
          builder: (context, data, _) {
            final splitCount = data.item1;
            final isDustError = data.item2;
            final textColor = splitCount >= 2 && isDustError ? CoconutColors.hotPink : CoconutColors.white;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RippleEffect(
                  onTap: viewModel.decrementSplitCount,
                  borderRadius: 24,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: CoconutColors.gray800,
                      shape: BoxShape.circle,
                      border: Border.all(color: CoconutColors.gray300),
                    ),
                    child: const Icon(Icons.remove, color: CoconutColors.white),
                  ),
                ),
                CoconutLayout.spacing_300w,
                SizedBox(
                  width: 50,
                  child: TextField(
                    controller: viewModel.splitCountController,
                    focusNode: viewModel.splitCountFocusNode,
                    textAlign: TextAlign.center,
                    onTapOutside: (_) => viewModel.splitCountFocusNode.unfocus(),
                    onEditingComplete: () => viewModel.splitCountFocusNode.unfocus(),
                    onSubmitted: (_) => viewModel.splitCountFocusNode.unfocus(),
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.number,
                    style: CoconutTypography.heading2_28_Number.setColor(textColor),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: CoconutTypography.heading2_28_Number.setColor(CoconutColors.gray500),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                CoconutLayout.spacing_300w,
                RippleEffect(
                  onTap: viewModel.incrementSplitCount,
                  borderRadius: 24,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: CoconutColors.gray800,
                      shape: BoxShape.circle,
                      border: Border.all(color: CoconutColors.gray300),
                    ),
                    child: const Icon(Icons.add, color: CoconutColors.white),
                  ),
                ),
              ],
            );
          },
        ),
        CoconutLayout.spacing_300h,
        _buildRecommendedCounts(),
        CoconutLayout.spacing_1000h,
      ],
    );
  }

  Widget _buildSplitManuallyBody(BuildContext context) {
    final viewModel = context.read<SplitUtxoViewModel>();
    return Selector<SplitUtxoViewModel, List<ManualSplitItem>>(
      selector: (_, vm) => List<ManualSplitItem>.of(vm.manualSplitItems),
      builder: (context, manualSplitItems, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...manualSplitItems.asMap().entries.map((entry) {
              return _ManualSplitListItem(
                key: ObjectKey(entry.value),
                index: entry.key,
                item: entry.value,
                viewModel: viewModel,
              );
            }),
            CoconutLayout.spacing_300h,
            RippleEffect(
              onTap: viewModel.addManualSplitItem,
              borderRadius: 12,
              child: CustomPaint(
                foregroundPainter: DashedBorderPainter(
                  color: CoconutColors.gray400,
                  radius: 12,
                  dashWidth: 2,
                  dashSpace: 2,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: CoconutColors.gray900, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/svg/plus.svg',
                        width: 12,
                        height: 12,
                        colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                      ),
                      const SizedBox(width: 5),
                      Text('금액 추가하기', style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)),
                    ],
                  ),
                ),
              ),
            ),
            CoconutLayout.spacing_1000h,
          ],
        );
      },
    );
  }

  Widget _buildRecommendedCounts() {
    return Selector<SplitUtxoViewModel, List<int>>(
      selector: (_, vm) => vm.recommendedSplitCounts,
      builder: (context, recommendedSplitCounts, _) {
        final viewModel = context.read<SplitUtxoViewModel>();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Wrap(
            spacing: 8,
            children:
                recommendedSplitCounts.map((count) {
                  return RippleEffect(
                    onTap: () => viewModel.onRecommendedCountTapped(count),
                    borderRadius: 8,
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: CoconutColors.gray700),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      width: 50,
                      height: 25,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('$count', style: CoconutTypography.body3_12.setColor(CoconutColors.white)),
                      ),
                    ),
                  );
                }).toList(),
          ),
        );
      },
    );
  }

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
      initiallySelectedId: viewModel.selectedCriteria?.name,
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

  String _getHeaderTitle(Translations t, List<UtxoState> selectedUtxoList, SplitCriteria? selectedCriteria) {
    if (selectedUtxoList.isEmpty) {
      return t.split_utxo_screen.question_select_utxo;
    }
    if (selectedCriteria == null) {
      return t.split_utxo_screen.question_select_criteria;
    }

    switch (selectedCriteria) {
      case SplitCriteria.byAmount:
        return t.split_utxo_screen.question_split_by_amount;
      case SplitCriteria.evenly:
        return t.split_utxo_screen.question_split_evenly;
      case SplitCriteria.manually:
        return t.split_utxo_screen.question_select_criteria;
    }
  }

  String _getFeePickerText(Translations t, bool hasFeeRate, String previewFeeText) {
    return hasFeeRate ? previewFeeText : t.split_utxo_screen.placeholder_expected_fee;
  }
}

class SplitResultBox extends StatelessWidget {
  final bool isPreviewResult;

  const SplitResultBox({super.key, required this.isPreviewResult});

  @override
  Widget build(BuildContext context) {
    return Selector<SplitUtxoViewModel, Tuple3<String, String?, String>>(
      selector: (_, vm) => Tuple3(vm.splitSummaryTitle, vm.splitOutputText, vm.previewFeeText),
      builder: (context, data, _) {
        final splitSummaryTitle = data.item1;
        final splitOutputText = data.item2;
        final previewFeeText = data.item3;
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                  const SizedBox(width: 6),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(splitSummaryTitle, style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white)),
                        CoconutLayout.spacing_200h,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.split_utxo_screen.expected_result.new_utxos,
                              style: CoconutTypography.body2_14.setColor(CoconutColors.gray400),
                            ),
                            Text(
                              splitOutputText ?? '-',
                              style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white),
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                        CoconutLayout.spacing_100h,
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              t.split_utxo_screen.expected_result.fee,
                              style: CoconutTypography.body2_14.setColor(CoconutColors.gray400),
                            ),
                            Text(previewFeeText, style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            CoconutLayout.spacing_200h,
            Visibility(
              visible: isPreviewResult,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('위 결과는 예측값입니다.', style: CoconutTypography.caption_10.setColor(CoconutColors.gray400)),
              ),
            ),
          ],
        );
      },
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;
  final double dashWidth;
  final double dashSpace;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.radius = 8.0,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke;

    final path =
        Path()
          ..addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius)));
    final dashedPath = Path();

    for (PathMetric measurePath in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < measurePath.length) {
        dashedPath.addPath(measurePath.extractPath(distance, distance + dashWidth), Offset.zero);
        distance += dashWidth + dashSpace;
      }
    }
    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ManualSplitListItem extends StatefulWidget {
  final int index;
  final ManualSplitItem item;
  final SplitUtxoViewModel viewModel;

  const _ManualSplitListItem({super.key, required this.index, required this.item, required this.viewModel});

  @override
  State<_ManualSplitListItem> createState() => _ManualSplitListItemState();
}

class _ManualSplitListItemState extends State<_ManualSplitListItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final double _actionWidth = 60.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void didUpdateWidget(covariant _ManualSplitListItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.viewModel.manualSplitItems.length <= 1 && _controller.value > 0) {
      _controller.reverse();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.viewModel.manualSplitItems.length <= 1) return;
    _controller.value -= details.primaryDelta! / _actionWidth;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.viewModel.manualSplitItems.length <= 1) return;
    if (_controller.value > 0.5 || details.primaryVelocity! < -500) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: ClipRect(
        child: GestureDetector(
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            alignment: Alignment.centerRight,
            children: [
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Transform.translate(offset: Offset(-_controller.value * _actionWidth, 0), child: child);
                },
                child: Container(
                  color: CoconutColors.black,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.item.amountController,
                          focusNode: widget.item.amountFocusNode,
                          onTapOutside: (_) => widget.item.amountFocusNode.unfocus(),
                          onEditingComplete: () => widget.item.amountFocusNode.unfocus(),
                          onSubmitted: (_) => widget.item.amountFocusNode.unfocus(),
                          textInputAction: TextInputAction.done,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white),
                          decoration: InputDecoration(
                            hintText: t.split_utxo_screen.placeholder_split_amount,
                            hintStyle: CoconutTypography.body1_16.setColor(CoconutColors.gray500),
                            errorBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: CoconutColors.hotPink),
                            ),
                            focusedErrorBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: CoconutColors.hotPink),
                            ),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: CoconutColors.gray500),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(color: CoconutColors.white),
                            ),
                            suffixIcon: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.viewModel.currentUnit.symbol,
                                  style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      CoconutLayout.spacing_300w,
                      RippleEffect(
                        onTap: () => widget.viewModel.decrementManualSplitCount(widget.index),
                        borderRadius: 24,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: CoconutColors.gray800,
                            shape: BoxShape.circle,
                            border: Border.all(color: CoconutColors.gray300),
                          ),
                          child: const Icon(Icons.remove, color: CoconutColors.white),
                        ),
                      ),
                      CoconutLayout.spacing_300w,
                      SizedBox(
                        width: 50,
                        child: TextField(
                          controller: widget.item.countController,
                          focusNode: widget.item.countFocusNode,
                          textAlign: TextAlign.center,
                          onTapOutside: (_) => widget.item.countFocusNode.unfocus(),
                          onEditingComplete: () => widget.item.countFocusNode.unfocus(),
                          onSubmitted: (_) => widget.item.countFocusNode.unfocus(),
                          textInputAction: TextInputAction.done,
                          keyboardType: TextInputType.number,
                          style: CoconutTypography.heading2_28_Number.setColor(CoconutColors.white),
                          decoration: InputDecoration(
                            hintText: '0',
                            hintStyle: CoconutTypography.heading2_28_Number.setColor(CoconutColors.gray500),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      CoconutLayout.spacing_300w,
                      RippleEffect(
                        onTap: () => widget.viewModel.incrementManualSplitCount(widget.index),
                        borderRadius: 24,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: CoconutColors.gray800,
                            shape: BoxShape.circle,
                            border: Border.all(color: CoconutColors.gray300),
                          ),
                          child: const Icon(Icons.add, color: CoconutColors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (widget.viewModel.manualSplitItems.length > 1)
                Positioned(
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(_actionWidth * (1 - _controller.value), 0),
                        child: child,
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CoconutLayout.spacing_300w,
                        RippleEffect(
                          onTap: () {
                            _controller.reverse();
                            widget.viewModel.removeManualSplitItem(widget.index);
                          },
                          borderRadius: 12,
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: CoconutColors.hotPink,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: SvgPicture.asset(
                              'assets/svg/trash.svg',
                              width: 20,
                              height: 20,
                              colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
