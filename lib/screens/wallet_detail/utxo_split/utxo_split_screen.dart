import 'dart:async';
import 'dart:ui';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/utxo_enums.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/core/transaction/utxo_split_transaction_builder.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/utxo_split/utxo_split_view_model.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/repository/realm/address_repository.dart';
import 'package:coconut_wallet/screens/send/refactor/utxo_selection_screen.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/bottom_sheet_auto_open_scheduler.dart';
import 'package:coconut_wallet/utils/bottom_sheet_open_guard.dart';
import 'package:coconut_wallet/utils/step_transition_controller.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/estimated_fee_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/loading_indicator/loading_indicator.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/foundation.dart';
import 'package:coconut_wallet/widgets/wallet_detail/utxo_management/utxo_estimated_fee_option_picker.dart';
import 'package:coconut_wallet/widgets/wallet_detail/utxo_management/utxo_unexpected_error_tooltip.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:coconut_wallet/widgets/card/animated_summary_card.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/widgets/ripple_effect.dart';
import 'package:shimmer/shimmer.dart';
import 'package:coconut_wallet/widgets/fixed_text_scale.dart';
import '../../../utils/logger.dart';

part 'utxo_split_screen_animations.dart';
part 'utxo_split_screen_bottom_sheets.dart';
part 'utxo_split_screen_components.dart';

class UtxoSplitScreen extends StatefulWidget {
  final int id;

  const UtxoSplitScreen({super.key, required this.id});

  @override
  State<UtxoSplitScreen> createState() => _UtxoSplitScreenState();
}

class _UtxoSplitScreenState extends State<UtxoSplitScreen> {
  static const Duration _headerAnimationDuration = Duration(milliseconds: 800);
  static const Duration _optionPickerAnimationDuration = Duration(milliseconds: 600);
  static const Duration _newestPickerRevealDelay = Duration(milliseconds: 1500);
  static const Duration _autoOpenUtxoBottomSheetDelay = Duration(milliseconds: 0);

  final StepTransitionController<({String title, UtxoSplitMethod? method})> _headerTransitionController =
      StepTransitionController<({String title, UtxoSplitMethod? method})>();
  final StepTransitionController<UtxoSplitStep> _optionPickerTransitionController =
      StepTransitionController<UtxoSplitStep>();

  bool _isMethodBodyVisible = false;
  bool _isHeaderFadingOut = false;

  final List<UtxoSplitStep> _visibleOptionPickerSteps = [];
  final BottomSheetAutoOpenScheduler _autoOpenUtxoPickerScheduler = BottomSheetAutoOpenScheduler();
  final BottomSheetAutoOpenScheduler _autoOpenMethodPickerScheduler = BottomSheetAutoOpenScheduler();
  bool _hasAutoOpenedUtxoPicker = false;
  bool _hasAutoOpenedMethodPicker = false;
  final BottomSheetOpenGuard _utxoSelectionBottomSheetGuard = BottomSheetOpenGuard();
  final BottomSheetOpenGuard _splitMethodSelectionBottomSheetGuard = BottomSheetOpenGuard();

  /// manual input 삭제 버튼은 딱 1개만 노출되어야 함
  ManualSplitItem? _visibleDeleteButtonItem;

  @override
  void dispose() {
    _autoOpenUtxoPickerScheduler.cancel();
    _autoOpenMethodPickerScheduler.cancel();
    super.dispose();
  }

  /// -------------------------------------------------
  /// manual input delete button 단일 노출 관리
  /// -------------------------------------------------
  void _syncManualSplitItemKeys(List<ManualSplitItem> manualSplitItems) {
    if (_visibleDeleteButtonItem != null && !manualSplitItems.contains(_visibleDeleteButtonItem)) {
      _visibleDeleteButtonItem = null;
    }
  }

  void _onManualSplitDeleteButtonVisibilityChanged(ManualSplitItem item, bool isVisible) {
    if (isVisible) {
      _setScreenState(() {
        _visibleDeleteButtonItem = item;
      });
      return;
    }

    if (_visibleDeleteButtonItem == item) {
      _setScreenState(() {
        _visibleDeleteButtonItem = null;
      });
    }
  }

  void _setScreenState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UtxoSplitViewModel>(
      create:
          (context) => UtxoSplitViewModel(
            widget.id,
            context.read<PreferenceProvider>(),
            context.read<WalletProvider>(),
            context.read<AddressRepository>(),
            context.read<SendInfoProvider>(),
            (outputCount) => _showUsePreviewConfirmDialog(context, outputCount),
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

  Future<bool> _showUsePreviewConfirmDialog(BuildContext context, int outputCount) async {
    final result = await showDialog<bool>(
      barrierDismissible: false,
      context: context,
      builder: (dialogContext) {
        return CoconutPopup(
          languageCode: context.read<PreferenceProvider>().language,
          title: t.confirm,
          leftButtonText: t.split_utxo_screen.big_tx_confirm.create,
          rightButtonText: t.split_utxo_screen.big_tx_confirm.preview,
          description: t.split_utxo_screen.big_tx_confirm.description,
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

  List<UtxoSplitStep> _visiblePickerStepsFor(UtxoSplitStep step) {
    switch (step) {
      case UtxoSplitStep.selectUtxo:
        return const [UtxoSplitStep.selectUtxo];
      case UtxoSplitStep.selectSplitMethod:
        return const [UtxoSplitStep.selectSplitMethod, UtxoSplitStep.selectUtxo];
      case UtxoSplitStep.enterDetails:
        return const [UtxoSplitStep.enterDetails, UtxoSplitStep.selectSplitMethod, UtxoSplitStep.selectUtxo];
    }
  }

  Widget _buildVisibleOptionPickers(BuildContext context) {
    final pickerWidgets =
        _visibleOptionPickerSteps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;

          Widget picker;
          switch (step) {
            case UtxoSplitStep.selectUtxo:
              picker = _buildUtxoPicker(context);
              break;
            case UtxoSplitStep.selectSplitMethod:
              picker = _buildMethodPicker(context);
              break;
            case UtxoSplitStep.enterDetails:
              picker = _buildSplitContent(context);
              break;
          }

          final isNewest = step == _optionPickerTransitionController.displayedStep && index == 0;

          if (isNewest) {
            return picker.slideUpAnimation(
              key: ValueKey('split-picker-in-${step.name}-${_optionPickerTransitionController.nonce}'),
              duration: _optionPickerAnimationDuration,
              delay: _newestPickerRevealDelay,
              offset: const Offset(0, 24),
            );
          }

          return picker;
        }).toList();

    if (_optionPickerTransitionController.displayedStep == UtxoSplitStep.enterDetails) {
      pickerWidgets.add(_buildFeePicker(context));
    }

    return AnimatedSize(
      duration: _optionPickerAnimationDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: pickerWidgets),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SafeArea(
      child: Selector<UtxoSplitViewModel, bool>(
        selector: (_, vm) => vm.isPreparingNextStep,
        builder: (context, isPreparingNextStep, child) {
          return LoadingOverlay(isLoading: isPreparingNextStep, child: child!);
        },
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                _buildUnexpectedErrorTooltip(),
                _buildExpectedResult(),
                Selector<UtxoSplitViewModel, ({bool showSplitResultBox, int manualSplitItemsLength})>(
                  selector:
                      (_, vm) => (
                        showSplitResultBox: vm.showSplitResultBox,
                        manualSplitItemsLength: vm.manualSplitItems.length,
                      ),
                  builder: (context, data, _) {
                    final showSplitResultBox = data.showSplitResultBox;
                    final vm = context.read<UtxoSplitViewModel>();
                    final focusNodes = [
                      vm.amountFocusNode,
                      vm.splitCountFocusNode,
                      ...vm.manualSplitItems.expand((item) => [item.amountFocusNode, item.countFocusNode]),
                    ];

                    return AnimatedBuilder(
                      animation: Listenable.merge(focusNodes),
                      builder: (context, _) {
                        final isFocused = focusNodes.any((node) => node.hasFocus);
                        final actuallyShowResultBox = showSplitResultBox && !isFocused;
                        return SizedBox(height: actuallyShowResultBox ? 32 : 24);
                      },
                    );
                  },
                ),
                FixedTextScale(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_buildHeaderTitle(), _buildVisibleOptionPickers(context)],
                  ),
                ),
              ],
            ),
            _buildApplyButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUnexpectedErrorTooltip() {
    return Selector<UtxoSplitViewModel, String>(
      selector: (_, vm) => vm.unexpectedErrorMessage,
      builder: (context, finalErrorMessage, _) {
        return UtxoUnexpectedErrorTooltip(
          isShown: finalErrorMessage.isNotEmpty,
          errorMessage: "${t.errors.unexpected}\n$finalErrorMessage",
        );
      },
    );
  }

  Widget _buildHeaderTitle() {
    return Selector<
      UtxoSplitViewModel,
      ({List<UtxoState> selectedUtxoList, UtxoSplitMethod? selectedMethod, String? headerTitleErrorMessage})
    >(
      selector:
          (_, vm) => (
            selectedUtxoList: vm.selectedUtxoList,
            selectedMethod: vm.selectedMethod,
            headerTitleErrorMessage: vm.headerTitleErrorMessage,
          ),
      builder: (context, data, _) {
        final viewModel = context.read<UtxoSplitViewModel>();
        final nextTitle = _getHeaderTitle(
          t,
          data.selectedUtxoList,
          data.selectedMethod,
          viewModel.hasSelectedUtxoAmountError,
        );
        final nextMethod = data.selectedMethod;
        _scheduleHeaderAnimation(nextTitle, nextMethod);

        final currentStep =
            data.selectedUtxoList.isEmpty || viewModel.hasSelectedUtxoAmountError
                ? UtxoSplitStep.selectUtxo
                : (data.selectedMethod == null ? UtxoSplitStep.selectSplitMethod : UtxoSplitStep.enterDetails);
        _scheduleOptionPickerAnimation(currentStep, viewModel);

        final titleToDisplay = _headerTransitionController.displayedStep?.title ?? nextTitle;

        Widget titleWidget;
        if (_isHeaderFadingOut) {
          titleWidget = titleToDisplay.characterFadeOutAnimation(
            key: ValueKey('split-header-out-${_headerTransitionController.nonce}'),
            textStyle: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white),
            duration: const Duration(milliseconds: 100),
            slideDirection: CoconutCharacterFadeSlideDirection.slideUp,
          );
        } else {
          titleWidget = titleToDisplay.characterFadeInAnimation(
            key: ValueKey('split-header-in-${_headerTransitionController.nonce}'),
            textStyle: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white),
            duration: _headerAnimationDuration,
            delay: const Duration(milliseconds: 300),
            slideDirection: CoconutCharacterFadeSlideDirection.slideDown,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [titleWidget, const _HeaderTitleErrorText()],
        );
      },
    );
  }

  Widget _buildExpectedResult() {
    return Selector<
      UtxoSplitViewModel,
      ({
        bool showSplitResultBox,
        bool showSkeletonResultBox,
        bool usePreview,
        UtxoSplitResult? splitResult,
        String? splitOutputText,
        String splitSummaryTitle,
        int manualSplitItemsLength,
      })
    >(
      selector:
          (_, vm) => (
            showSplitResultBox: vm.showSplitResultBox,
            showSkeletonResultBox: vm.showSkeletonResultBox,
            usePreview: vm.usePreview,
            splitResult: vm.splitResult,
            splitOutputText: vm.splitOutputText,
            splitSummaryTitle: vm.splitSummaryTitle,
            manualSplitItemsLength: vm.manualSplitItems.length,
          ),
      builder: (context, data, _) {
        final vm = context.read<UtxoSplitViewModel>();
        final focusNodes = [
          vm.amountFocusNode,
          vm.splitCountFocusNode,
          ...vm.manualSplitItems.expand((item) => [item.amountFocusNode, item.countFocusNode]),
        ];

        return AnimatedBuilder(
          animation: Listenable.merge(focusNodes),
          builder: (context, _) {
            final isFocused = focusNodes.any((node) => node.hasFocus);
            final showSplitResultBox = data.showSplitResultBox && !isFocused;

            return AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child:
                    showSplitResultBox
                        ? _SplitResultContent(
                          key: const ValueKey('split_result_box_content'),
                          showSkeletonResultBox: data.showSkeletonResultBox,
                          usePreview: data.usePreview,
                          splitResult: data.splitResult,
                          splitOutputText: data.splitOutputText,
                          splitSummaryTitle: data.splitSummaryTitle.replaceAllMapped(
                            RegExp(r'(\S+)'),
                            (match) => match[0]!.split('').join('\u200D'),
                          ),
                        )
                        : const SizedBox.shrink(key: ValueKey('split_result_box_empty')),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildApplyButton(BuildContext context) {
    return Selector<
      UtxoSplitViewModel,
      ({
        bool showSplitResultBox,
        bool isSplitValid,
        bool isPreparingNextStep,
        String unexpectedErrorMessage,
        double? feeRatio,
        bool showSkeletonResultBox,
      })
    >(
      selector:
          (_, vm) => (
            showSplitResultBox: vm.showSplitResultBox,
            isSplitValid: vm.isSplitValid,
            isPreparingNextStep: vm.isPreparingNextStep,
            unexpectedErrorMessage: vm.unexpectedErrorMessage,
            feeRatio: vm.feeRatio,
            showSkeletonResultBox: vm.showSkeletonResultBox,
          ),
      builder: (context, data, _) {
        final showSplitResultBox = data.showSplitResultBox;
        final isSplitValid = data.isSplitValid;
        final isPreparingNextStep = data.isPreparingNextStep;
        final finalErrorMessage = data.unexpectedErrorMessage;
        final feeRatio = data.feeRatio;
        final showSkeletonResultBox = data.showSkeletonResultBox;
        final viewModel = context.read<UtxoSplitViewModel>();
        return AnimatedOpacity(
          opacity: showSplitResultBox ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: IgnorePointer(
            ignoring: !showSplitResultBox,
            child: FixedBottomButton(
              text: t.apply,
              subWidget:
                  feeRatio != null && feeRatio >= 10
                      ? Text(
                        t.merge_utxos_screen.merge_cta_high_fee_ratio(ratio: feeRatio),
                        style: CoconutTypography.caption_10.setColor(CoconutColors.yellow),
                      )
                      : null,
              onButtonClicked: () async {
                if (!isSplitValid) return;
                FocusScope.of(context).unfocus();

                final isSuccess = await viewModel.buildTxAndSaveForNext();
                if (isSuccess && context.mounted) {
                  Navigator.pushNamed(context, '/send-confirm', arguments: {"currentUnit": viewModel.currentUnit});
                }
                if (!isSuccess) {
                  vibrateLightDouble();
                }
              },
              isActive: isSplitValid && !isPreparingNextStep && finalErrorMessage.isEmpty && !showSkeletonResultBox,
              backgroundColor: CoconutColors.white,
            ),
          ),
        );
      },
    );
  }

  Widget _buildMethodPicker(BuildContext context) {
    return Selector<UtxoSplitViewModel, ({bool isUtxoSelected, UtxoSplitMethod? selectedMethod})>(
      selector: (_, vm) => (isUtxoSelected: vm.selectedUtxoList.isNotEmpty, selectedMethod: vm.selectedMethod),
      builder: (context, data, _) {
        final isUtxoSelected = data.isUtxoSelected;
        final method = data.selectedMethod;
        if (!isUtxoSelected) return const SizedBox.shrink();

        final viewModel = context.read<UtxoSplitViewModel>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoconutOptionPicker(
              label: method != null ? t.split_utxo_screen.label_split_method : null,
              text: method?.getLabel(t) ?? t.split_utxo_screen.method_bottom_sheet.split_by_amount,
              textColor: CoconutColors.white,
              onTap: () => _showSplitMethodBottomSheet(context, viewModel),
            ),
            CoconutLayout.spacing_1000h,
          ],
        );
      },
    );
  }

  Widget _buildUtxoPicker(BuildContext context) {
    return Selector<
      UtxoSplitViewModel,
      ({bool isSelected, String? guideText, CoconutOptionStateEnum optionState, List<UtxoState> selectedUtxoList})
    >(
      selector:
          (_, vm) => (
            isSelected: vm.isUtxoSelected,
            guideText: vm.getUtxoGuideText(t),
            optionState: vm.utxoOptionState,
            selectedUtxoList: vm.selectedUtxoList,
          ),
      builder: (context, data, _) {
        List<Widget> inlineWidgets = [];
        final isSelected = data.isSelected;
        final guideText = data.guideText;
        final optionState = data.optionState;
        final selectedUtxoList = data.selectedUtxoList;

        if (isSelected) {
          final utxoTagProvider = context.read<UtxoTagProvider>();
          final tags = utxoTagProvider.getUtxoTagsByUtxoId(widget.id, selectedUtxoList.first.utxoId);

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

        final viewModel = context.read<UtxoSplitViewModel>();
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

  void _scheduleAutoOpenUtxoSelectionBottomSheet(UtxoSplitViewModel viewModel) {
    if (viewModel.isUtxoSelected ||
        _optionPickerTransitionController.displayedStep != UtxoSplitStep.selectUtxo ||
        _hasAutoOpenedUtxoPicker ||
        _utxoSelectionBottomSheetGuard.isOpen) {
      _autoOpenUtxoPickerScheduler.cancel();
      return;
    }

    if (_autoOpenUtxoPickerScheduler.isScheduled) {
      return;
    }

    _autoOpenUtxoPickerScheduler.schedule(
      delay: _newestPickerRevealDelay + _optionPickerAnimationDuration + _autoOpenUtxoBottomSheetDelay,
      replaceIfScheduled: false,
      action: () {
        if (!mounted ||
            ModalRoute.of(context)?.isCurrent != true ||
            _optionPickerTransitionController.displayedStep != UtxoSplitStep.selectUtxo ||
            _hasAutoOpenedUtxoPicker ||
            _utxoSelectionBottomSheetGuard.isOpen ||
            viewModel.isUtxoSelected) {
          return;
        }

        _hasAutoOpenedUtxoPicker = true;
        _showUtxoSelectionBottomSheet(context, viewModel);
      },
    );
  }

  void _scheduleAutoOpenMethodBottomSheet(UtxoSplitViewModel viewModel) {
    if (!viewModel.isUtxoSelected ||
        viewModel.selectedMethod != null ||
        _optionPickerTransitionController.displayedStep != UtxoSplitStep.selectSplitMethod ||
        _hasAutoOpenedMethodPicker ||
        _splitMethodSelectionBottomSheetGuard.isOpen) {
      _autoOpenMethodPickerScheduler.cancel();
      return;
    }

    if (_autoOpenMethodPickerScheduler.isScheduled) {
      return;
    }

    _autoOpenMethodPickerScheduler.schedule(
      delay: _newestPickerRevealDelay + _optionPickerAnimationDuration + _autoOpenUtxoBottomSheetDelay,
      replaceIfScheduled: false,
      action: () {
        if (!mounted ||
            ModalRoute.of(context)?.isCurrent != true ||
            !viewModel.isUtxoSelected ||
            viewModel.selectedMethod != null ||
            _optionPickerTransitionController.displayedStep != UtxoSplitStep.selectSplitMethod ||
            _hasAutoOpenedMethodPicker ||
            _splitMethodSelectionBottomSheetGuard.isOpen) {
          return;
        }

        _hasAutoOpenedMethodPicker = true;
        _showSplitMethodBottomSheet(context, viewModel);
      },
    );
  }

  Widget _buildFeePicker(BuildContext context) {
    return Selector<
      UtxoSplitViewModel,
      ({bool shouldShow, bool hasFeeRate, String? feeExceedsAmountErrorText, String previewFeeText})
    >(
      selector:
          (_, vm) => (
            shouldShow: vm.shouldShowFeePicker,
            hasFeeRate: vm.hasFeeRate,
            feeExceedsAmountErrorText: vm.errorTextAboutFee,
            previewFeeText: vm.feePickerDisplayText,
          ),
      builder: (context, data, _) {
        final shouldShow = data.shouldShow;
        final hasFeeRate = data.hasFeeRate;
        final feeExceedsAmountErrorText = data.feeExceedsAmountErrorText;
        final previewFeeText = data.previewFeeText;

        if (!shouldShow) {
          return const SizedBox.shrink();
        }

        final viewModel = context.read<UtxoSplitViewModel>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UtxoEstimatedFeeOptionPicker(
              label: t.split_utxo_screen.label_estimated_fee,
              valueText: previewFeeText,
              placeholderText: t.split_utxo_screen.placeholder_estimated_fee,
              hasValue: hasFeeRate,
              optionState: viewModel.feeOptionState,
              guideText: feeExceedsAmountErrorText,
              onTap:
                  () => EstimatedFeeBottomSheet.show(
                    context: context,
                    listenable: viewModel,
                    estimatedFeeTextGetter: () => viewModel.feePickerDisplayText,
                    feeRateController: viewModel.feeRateController,
                    feeRateFocusNode: viewModel.feeRateFocusNode,
                    onFeeRateChanged: viewModel.onFeeRateChanged,
                    onEditingComplete: () {
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
                    onClosed: () {
                      viewModel.removeTrailingDotInFeeRate();
                      viewModel.restoreFeeRateIfZero();
                    },
                  ),
            ),
            CoconutLayout.spacing_1000h,
          ],
        );
      },
    );
  }

  Widget _buildSplitContent(BuildContext context) {
    final method = _headerTransitionController.displayedStep?.method;
    if (method == null) return const SizedBox.shrink();

    Widget content;
    switch (method) {
      case UtxoSplitMethod.byAmount:
        content = _buildSplitByAmountBody(context);
        break;
      case UtxoSplitMethod.evenly:
        content = _buildSplitEvenlyBody(context);
        break;
      case UtxoSplitMethod.manually:
        content = _buildSplitManuallyBody(context);
        break;
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 600),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [...previousChildren, if (currentChild != null) currentChild],
          );
        },
        transitionBuilder: (child, animation) {
          final offsetAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(animation);
          return FadeTransition(opacity: animation, child: SlideTransition(position: offsetAnimation, child: child));
        },
        child:
            _isMethodBodyVisible
                ? KeyedSubtree(key: ValueKey('split_method_${method.name}'), child: content)
                : Visibility(
                  key: ValueKey('empty_method_${method.name}'),
                  visible: false,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: content,
                ),
      ),
    );
  }

  Widget _buildSplitByAmountBody(BuildContext context) {
    final viewModel = context.read<UtxoSplitViewModel>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Selector<UtxoSplitViewModel, ({String? splitAmountErrorText, String unitSymbol})>(
          selector: (_, vm) => (splitAmountErrorText: vm.splitAmountErrorText, unitSymbol: vm.currentUnit.symbol),
          builder: (context, data, _) {
            return CoconutTextField(
              controller: viewModel.amountController,
              focusNode: viewModel.amountFocusNode,
              style: CoconutTextFieldStyle.underline,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              activeColor: CoconutColors.white,
              placeholderColor: CoconutColors.gray500,
              errorColor: CoconutColors.hotPink,
              isError: data.splitAmountErrorText != null,
              errorText: data.splitAmountErrorText ?? '',
              onChanged: (_) {},
              onEditingComplete: () => viewModel.amountFocusNode.unfocus(),
              textInputAction: TextInputAction.done,
              textInputType: const TextInputType.numberWithOptions(decimal: true),
              textInputFormatter: [_DecimalTextInputFormatter(decimalRange: viewModel.currentUnit.isBtcUnit ? 8 : 0)],
              placeholderText: t.split_utxo_screen.placeholder_split_amount,
              maxLines: 1,
              unfocusOnTapOutside: true,
              padding: const EdgeInsets.only(left: 4, right: 4, top: 6, bottom: 6),
              suffix: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(data.unitSymbol, style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white)),
              ),
            );
          },
        ),
        CoconutLayout.spacing_200h,
        _buildRecommendedAmounts(),
        CoconutLayout.spacing_1000h,
      ],
    );
  }

  Widget _buildRecommendedAmounts() {
    return Selector<UtxoSplitViewModel, ({List<double> recommendedSplitAmounts, BitcoinUnit currentUnit})>(
      selector: (_, vm) => (recommendedSplitAmounts: vm.recommendedSplitAmounts, currentUnit: vm.currentUnit),
      builder: (context, data, _) {
        final recommendedSplitAmounts = data.recommendedSplitAmounts;
        final currentUnit = data.currentUnit;
        final viewModel = context.read<UtxoSplitViewModel>();
        final screenWidth = MediaQuery.sizeOf(context).width;
        return LayoutBuilder(
          builder: (context, constraints) {
            final widthFactor = screenWidth / constraints.maxWidth;
            return FractionallySizedBox(
              widthFactor: widthFactor,
              alignment: Alignment.center,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 4,
                  children:
                      recommendedSplitAmounts.map((btc) {
                        final sats = (btc * 1e8).toInt();
                        return RippleEffect(
                          onTap: () => viewModel.onRecommendedAmountTapped(btc),
                          borderRadius: 8,
                          child: Container(
                            alignment: Alignment.center,
                            constraints: const BoxConstraints(minWidth: 47),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: CoconutColors.gray700),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            height: 24,
                            child: Text(
                              currentUnit.displayBitcoinAmount(sats, withUnit: false),
                              style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSplitEvenlyBody(BuildContext context) {
    final viewModel = context.read<UtxoSplitViewModel>();
    return Column(
      children: [
        Selector<UtxoSplitViewModel, ({int splitCount, bool isDustError, bool hasFocus})>(
          selector:
              (_, vm) => (
                splitCount: vm.splitCount,
                isDustError: vm.isDustError,
                hasFocus: vm.splitCountFocusNode.hasFocus,
              ),
          builder: (context, data, _) {
            final splitCount = data.splitCount;
            final isDustError = data.isDustError;
            final hasFocus = data.hasFocus;
            final textColor = splitCount >= 2 && isDustError ? CoconutColors.hotPink : CoconutColors.white;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SplitCountStepButton(
                  icon: Icons.remove,
                  isActive: splitCount > 1,
                  onTap: viewModel.decrementSplitCount,
                ),
                const SizedBox(width: 10),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: viewModel.splitCountController,
                  builder: (context, value, _) {
                    final inputText = value.text;
                    final visibleCharCount = inputText.isEmpty ? 3 : inputText.length.clamp(3, 6);
                    final fieldWidth = (visibleCharCount * 16.0) + 12.0;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutCubic,
                      width: fieldWidth,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CoconutTextField(
                            height: 40,
                            fontHeight: 1,
                            borderRadius: 8,
                            backgroundColor: hasFocus ? CoconutColors.gray800 : Colors.transparent,
                            controller: viewModel.splitCountController,
                            focusNode: viewModel.splitCountFocusNode,
                            textAlign: TextAlign.center,
                            activeColor: textColor,
                            placeholderColor: CoconutColors.gray500,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            isVisibleBorder: false,
                            onChanged: (_) {},
                            onEditingComplete: () => viewModel.splitCountFocusNode.unfocus(),
                            textInputAction: TextInputAction.done,
                            textInputType: TextInputType.number,
                            textInputFormatter: [FilteringTextInputFormatter.digitsOnly],
                            maxLines: 1,
                            unfocusOnTapOutside: true,
                            padding: EdgeInsets.zero,
                            placeholderText: '',
                          ),
                          if (inputText.isEmpty && !hasFocus)
                            IgnorePointer(
                              child: Text(
                                '1',
                                style: CoconutTypography.heading3_21_NumberBold.copyWith(
                                  color: CoconutColors.gray500,
                                  fontSize: 24,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                _SplitCountStepButton(icon: Icons.add, onTap: viewModel.incrementSplitCount),
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
    final viewModel = context.read<UtxoSplitViewModel>();
    return Selector<UtxoSplitViewModel, List<ManualSplitItem>>(
      selector: (_, vm) => List<ManualSplitItem>.of(vm.manualSplitItems),
      builder: (context, manualSplitItems, _) {
        _syncManualSplitItemKeys(manualSplitItems);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...manualSplitItems.asMap().entries.map((entry) {
              return _ManualSplitListItem(
                key: ObjectKey(entry.value),
                index: entry.key,
                item: entry.value,
                viewModel: viewModel,
                isDeleteButtonVisible: identical(_visibleDeleteButtonItem, entry.value),
                onDeleteButtonVisibilityChanged: (isVisible) {
                  _onManualSplitDeleteButtonVisibilityChanged(entry.value, isVisible);
                },
              );
            }),
            const SizedBox(height: 14),
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
                      Text(
                        t.split_utxo_screen.add_new_amount,
                        style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
                      ),
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
    return Selector<UtxoSplitViewModel, List<int>>(
      selector: (_, vm) => vm.recommendedSplitCounts,
      builder: (context, recommendedSplitCounts, _) {
        final viewModel = context.read<UtxoSplitViewModel>();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Wrap(
            spacing: 4,
            children:
                recommendedSplitCounts.map((count) {
                  return RippleEffect(
                    onTap: () => viewModel.onRecommendedCountTapped(count),
                    borderRadius: 8,
                    child: Container(
                      alignment: Alignment.center,
                      constraints: const BoxConstraints(minWidth: 47),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: CoconutColors.gray700),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      height: 24,
                      child: Text('$count', style: CoconutTypography.body3_12_Number.setColor(CoconutColors.white)),
                    ),
                  );
                }).toList(),
          ),
        );
      },
    );
  }

  String _getHeaderTitle(
    Translations t,
    List<UtxoState> selectedUtxoList,
    UtxoSplitMethod? selectedMethod,
    bool hasError,
  ) {
    if (selectedUtxoList.isEmpty || hasError) {
      return t.split_utxo_screen.question_select_utxo;
    }
    if (selectedMethod == null) {
      return t.split_utxo_screen.question_select_method;
    }

    switch (selectedMethod) {
      case UtxoSplitMethod.byAmount:
        return t.split_utxo_screen.question_split_by_amount;
      case UtxoSplitMethod.evenly:
        return t.split_utxo_screen.question_split_evenly;
      case UtxoSplitMethod.manually:
        return t.split_utxo_screen.question_select_method;
    }
  }
}
