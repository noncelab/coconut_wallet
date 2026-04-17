import 'dart:async';
import 'dart:ui';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/core/transaction/utxo_split_transaction_builder.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
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
import 'package:flutter/foundation.dart';
import 'package:coconut_wallet/widgets/overlays/error_tooltip.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/widgets/ripple_effect.dart';
import 'package:shimmer/shimmer.dart';

import '../../utils/logger.dart';

enum SplitStep { selectUtxo, selectCriteria, enterDetails }

class SplitUtxoScreen extends StatefulWidget {
  final int id;

  const SplitUtxoScreen({super.key, required this.id});

  @override
  State<SplitUtxoScreen> createState() => _SplitUtxoScreenState();
}

class _SplitUtxoScreenState extends State<SplitUtxoScreen> {
  static const Duration _headerAnimationDuration = Duration(milliseconds: 400);
  static const Duration _newestPickerRevealDelay = Duration(milliseconds: 1500);
  static const Duration _autoOpenUtxoBottomSheetDelay = Duration(milliseconds: 850);
  String? _displayedHeaderTitle;
  String? _pendingHeaderTitle;
  String? _lastObservedHeaderTitle;
  bool _isHeaderFadingOut = false;
  int _headerAnimationNonce = 0;

  static const Duration _pickerAnimationDuration = Duration(milliseconds: 300);
  SplitStep? _displayedPickerStep;
  SplitStep? _pendingPickerStep;
  SplitStep? _lastObservedPickerStep;
  int _pickerAnimationNonce = 0;
  final List<SplitStep> _visiblePickerSteps = [];
  Timer? _autoOpenUtxoPickerTimer;
  Timer? _autoOpenCriteriaPickerTimer;
  bool _hasAutoOpenedUtxoPicker = false;
  bool _hasAutoOpenedCriteriaPicker = false;
  bool _isUtxoSelectionBottomSheetOpen = false;
  bool _isCriteriaBottomSheetOpen = false;

  /// manual input 삭제 버튼은 딱 1개만 노출되어야 함
  final Map<ManualSplitItem, GlobalKey<_ManualSplitListItemState>> _manualSplitItemKeys = {};
  ManualSplitItem? _visibleDeleteButtonItem;

  @override
  void dispose() {
    _autoOpenUtxoPickerTimer?.cancel();
    _autoOpenCriteriaPickerTimer?.cancel();
    super.dispose();
  }

  /// -------------------------------------------------
  /// manual input delete button 단일 노출 관리
  /// -------------------------------------------------
  GlobalKey<_ManualSplitListItemState> _getManualSplitItemKey(ManualSplitItem item) {
    return _manualSplitItemKeys.putIfAbsent(item, () => GlobalKey<_ManualSplitListItemState>());
  }

  void _syncManualSplitItemKeys(List<ManualSplitItem> manualSplitItems) {
    _manualSplitItemKeys.removeWhere((item, _) => !manualSplitItems.contains(item));

    if (_visibleDeleteButtonItem != null && !manualSplitItems.contains(_visibleDeleteButtonItem)) {
      _visibleDeleteButtonItem = null;
    }
  }

  void _onManualSplitDeleteButtonVisibilityChanged(ManualSplitItem item, bool isVisible) {
    if (isVisible) {
      if (_visibleDeleteButtonItem != null && _visibleDeleteButtonItem != item) {
        _manualSplitItemKeys[_visibleDeleteButtonItem]?.currentState?.setDeleteButtonVisible(false);
      }
      _visibleDeleteButtonItem = item;
      return;
    }

    if (_visibleDeleteButtonItem == item) {
      _visibleDeleteButtonItem = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SplitUtxoViewModel>(
      create:
          (context) => SplitUtxoViewModel(
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

  void _scheduleHeaderAnimation(String nextTitle) {
    if (_lastObservedHeaderTitle == nextTitle) return;
    _lastObservedHeaderTitle = nextTitle;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncHeaderAnimation(nextTitle);
    });
  }

  void _syncHeaderAnimation(String nextTitle) {
    _pendingHeaderTitle = nextTitle;

    if (_displayedHeaderTitle == null) {
      setState(() {
        _displayedHeaderTitle = nextTitle;
        _isHeaderFadingOut = false;
      });
      return;
    }

    if (_displayedHeaderTitle == nextTitle && !_isHeaderFadingOut) return;
    if (_isHeaderFadingOut) return;

    final token = _headerAnimationNonce + 1;
    _headerAnimationNonce = token;
    setState(() => _isHeaderFadingOut = true);

    Future.delayed(_headerAnimationDuration, () {
      if (!mounted || token != _headerAnimationNonce) return;

      setState(() {
        _displayedHeaderTitle = _pendingHeaderTitle;
        _isHeaderFadingOut = false;
      });
    });
  }

  void _scheduleOptionPickerAnimation(SplitStep step, SplitUtxoViewModel viewModel) {
    if (_lastObservedPickerStep == step) return;
    _lastObservedPickerStep = step;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncOptionPickerAnimation(step, viewModel);
    });
  }

  void _syncOptionPickerAnimation(SplitStep step, SplitUtxoViewModel viewModel) {
    _pendingPickerStep = step;
    final nextVisibleSteps = _visiblePickerStepsFor(step);

    _autoOpenUtxoPickerTimer?.cancel();
    _autoOpenCriteriaPickerTimer?.cancel();

    if (_displayedPickerStep == null) {
      setState(() {
        _displayedPickerStep = step;
        _visiblePickerSteps.clear();
        _visiblePickerSteps.addAll(nextVisibleSteps);
      });
      if (step == SplitStep.selectUtxo) {
        _scheduleAutoOpenUtxoSelectionBottomSheet(viewModel);
      }
      return;
    }

    if (_displayedPickerStep == step && listEquals(_visiblePickerSteps, nextVisibleSteps)) {
      return;
    }

    _pickerAnimationNonce++;
    setState(() {
      _displayedPickerStep = _pendingPickerStep;
      _visiblePickerSteps.clear();
      _visiblePickerSteps.addAll(nextVisibleSteps);
    });
    if (step == SplitStep.selectCriteria) {
      _scheduleAutoOpenCriteriaBottomSheet(viewModel);
    }
  }

  List<SplitStep> _visiblePickerStepsFor(SplitStep step) {
    switch (step) {
      case SplitStep.selectUtxo:
        return const [SplitStep.selectUtxo];
      case SplitStep.selectCriteria:
        return const [SplitStep.selectCriteria, SplitStep.selectUtxo];
      case SplitStep.enterDetails:
        return const [SplitStep.enterDetails, SplitStep.selectCriteria, SplitStep.selectUtxo];
    }
  }

  Widget _buildVisibleOptionPickers(BuildContext context) {
    final pickerWidgets =
        _visiblePickerSteps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;

          Widget picker;
          switch (step) {
            case SplitStep.selectUtxo:
              picker = _buildUtxoPicker(context);
              break;
            case SplitStep.selectCriteria:
              picker = _buildCriteriaPicker(context);
              break;
            case SplitStep.enterDetails:
              picker = _buildSplitContent(context);
              break;
          }

          final isNewest = step == _displayedPickerStep && index == 0;

          if (isNewest) {
            return picker.slideUpAnimation(
              key: ValueKey('split-picker-in-${step.name}-$_pickerAnimationNonce'),
              duration: _pickerAnimationDuration,
              delay: _newestPickerRevealDelay,
              offset: const Offset(0, 24),
            );
          }

          return picker;
        }).toList();

    if (_displayedPickerStep == SplitStep.enterDetails) {
      pickerWidgets.add(_buildFeePicker(context));
    }

    return AnimatedSize(
      duration: _pickerAnimationDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: pickerWidgets),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SafeArea(
      child: Selector<SplitUtxoViewModel, bool>(
        selector: (_, vm) => vm.isPreparingNextStep,
        builder: (context, isPreparingNextStep, child) {
          return LoadingOverlay(isLoading: isPreparingNextStep, child: child!);
        },
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              children: [
                _buildUnexpectedErrorTooltip(),
                _buildExpectedResult(),
                CoconutLayout.spacing_1000h,
                _buildHeaderTitle(),
                _buildVisibleOptionPickers(context),
              ],
            ),
            _buildApplyButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUnexpectedErrorTooltip() {
    return Selector<SplitUtxoViewModel, String>(
      selector: (_, vm) => vm.unexpectedErrorMessage,
      builder: (context, finalErrorMessage, _) {
        if (finalErrorMessage.isEmpty) {
          return const SizedBox.shrink();
        }
        final message = "${t.errors.unexpected}\n$finalErrorMessage";
        return ErrorTooltip(isShown: true, errorMessage: message);
      },
    );
  }

  Widget _buildHeaderTitle() {
    return Selector<SplitUtxoViewModel, Tuple3<List<UtxoState>, SplitCriteria?, String?>>(
      selector: (_, vm) => Tuple3(vm.selectedUtxoList, vm.selectedCriteria, vm.headerTitleErrorMessage),
      builder: (context, data, _) {
        final viewModel = context.read<SplitUtxoViewModel>();
        final nextTitle = _getHeaderTitle(t, data.item1, data.item2);
        _scheduleHeaderAnimation(nextTitle);

        final currentStep =
            data.item1.isEmpty
                ? SplitStep.selectUtxo
                : (data.item2 == null ? SplitStep.selectCriteria : SplitStep.enterDetails);
        _scheduleOptionPickerAnimation(currentStep, viewModel);

        final titleToDisplay = _displayedHeaderTitle ?? nextTitle;

        Widget titleWidget;
        if (_isHeaderFadingOut) {
          titleWidget = titleToDisplay.characterFadeOutAnimation(
            key: ValueKey('split-header-out-$_headerAnimationNonce'),
            textStyle: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white),
            duration: const Duration(milliseconds: 100),
            slideDirection: CoconutCharacterFadeSlideDirection.slideUp,
          );
        } else {
          titleWidget = titleToDisplay.characterFadeInAnimation(
            key: ValueKey('split-header-in-$_headerAnimationNonce'),
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
    return Selector<SplitUtxoViewModel, Tuple4<bool, bool, bool, UtxoSplitResult?>>(
      selector: (_, vm) => Tuple4(vm.showSplitResultBox, vm.showSkeletonResultBox, vm.usePreview, vm.splitResult),
      builder: (context, data, _) {
        final showSplitResultBox = data.item1;
        return AnimatedSwitcher(
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
                    showSkeletonResultBox: data.item2,
                    usePreview: data.item3,
                    splitResult: data.item4,
                  )
                  : const SizedBox.shrink(key: ValueKey('split_result_box_empty')),
        );
      },
    );
  }

  Widget _buildApplyButton(BuildContext context) {
    return Selector<SplitUtxoViewModel, Tuple6<bool, bool, bool, String, double?, bool>>(
      selector:
          (_, vm) => Tuple6(
            vm.showSplitResultBox,
            vm.isSplitValid,
            vm.isPreparingNextStep,
            vm.unexpectedErrorMessage,
            vm.feeRatio,
            vm.showSkeletonResultBox,
          ),
      builder: (context, data, _) {
        final showSplitResultBox = data.item1;
        final isSplitValid = data.item2;
        final isPreparingNextStep = data.item3;
        final finalErrorMessage = data.item4;
        final feeRatio = data.item5;
        final showSkeletonResultBox = data.item6;
        final viewModel = context.read<SplitUtxoViewModel>();
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

  void _scheduleAutoOpenUtxoSelectionBottomSheet(SplitUtxoViewModel viewModel) {
    if (viewModel.isUtxoSelected ||
        _displayedPickerStep != SplitStep.selectUtxo ||
        _hasAutoOpenedUtxoPicker ||
        _isUtxoSelectionBottomSheetOpen) {
      _autoOpenUtxoPickerTimer?.cancel();
      return;
    }

    if (_autoOpenUtxoPickerTimer?.isActive ?? false) {
      return;
    }

    _autoOpenUtxoPickerTimer = Timer(_newestPickerRevealDelay + _autoOpenUtxoBottomSheetDelay, () {
      if (!mounted ||
          _displayedPickerStep != SplitStep.selectUtxo ||
          _hasAutoOpenedUtxoPicker ||
          _isUtxoSelectionBottomSheetOpen ||
          viewModel.isUtxoSelected) {
        return;
      }

      _hasAutoOpenedUtxoPicker = true;
      _showUtxoSelectionBottomSheet(context, viewModel);
    });
  }

  void _scheduleAutoOpenCriteriaBottomSheet(SplitUtxoViewModel viewModel) {
    if (!viewModel.isUtxoSelected ||
        viewModel.selectedCriteria != null ||
        _displayedPickerStep != SplitStep.selectCriteria ||
        _hasAutoOpenedCriteriaPicker ||
        _isCriteriaBottomSheetOpen) {
      _autoOpenCriteriaPickerTimer?.cancel();
      return;
    }

    if (_autoOpenCriteriaPickerTimer?.isActive ?? false) {
      return;
    }

    _autoOpenCriteriaPickerTimer = Timer(_newestPickerRevealDelay + _autoOpenUtxoBottomSheetDelay, () {
      if (!mounted ||
          !viewModel.isUtxoSelected ||
          viewModel.selectedCriteria != null ||
          _displayedPickerStep != SplitStep.selectCriteria ||
          _hasAutoOpenedCriteriaPicker ||
          _isCriteriaBottomSheetOpen) {
        return;
      }

      _hasAutoOpenedCriteriaPicker = true;
      _showSplitCriteriaBottomSheet(context, viewModel);
    });
  }

  Widget _buildFeePicker(BuildContext context) {
    return Selector<SplitUtxoViewModel, Tuple3<bool, Tuple2<bool, String?>, String>>(
      selector:
          (_, vm) =>
              Tuple3(vm.shouldShowFeePicker, Tuple2(vm.hasFeeRate, vm.errorTextAboutFee), vm.feePickerDisplayText),
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
              label: t.split_utxo_screen.label_estimated_fee,
              text: _getFeePickerText(t, hasFeeRate, previewFeeText),
              textColor: hasFeeRate ? CoconutColors.white : CoconutColors.gray500,
              coconutOptionStateEnum: viewModel.feeOptionState,
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
          selector: (_, vm) => Tuple2(vm.splitAmountErrorText, vm.currentUnit.symbol),
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
              isError: data.item1 != null,
              errorText: data.item1 ?? '',
              onChanged: (_) {},
              onEditingComplete: () => viewModel.amountFocusNode.unfocus(),
              textInputAction: TextInputAction.done,
              textInputType: const TextInputType.numberWithOptions(decimal: true),
              textInputFormatter: [_DecimalTextInputFormatter()],
              placeholderText: t.split_utxo_screen.placeholder_split_amount,
              maxLines: 1,
              unfocusOnTapOutside: true,
              padding: const EdgeInsets.only(left: 4, right: 4, top: 8, bottom: 4),
              suffix: Padding(
                padding: const EdgeInsets.only(top: 4, right: 4),
                child: Text(data.item2, style: CoconutTypography.heading4_18_Bold.setColor(CoconutColors.white)),
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
    return Selector<SplitUtxoViewModel, Tuple2<List<double>, BitcoinUnit>>(
      selector: (_, vm) => Tuple2(vm.recommendedSplitAmounts, vm.currentUnit),
      builder: (context, data, _) {
        final recommendedSplitAmounts = data.item1;
        final currentUnit = data.item2;
        final viewModel = context.read<SplitUtxoViewModel>();
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
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: CoconutColors.gray700),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            width: 47,
                            height: 24,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                currentUnit.displayBitcoinAmount(sats, withUnit: false),
                                style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                              ),
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
    final viewModel = context.read<SplitUtxoViewModel>();
    return Column(
      children: [
        Selector<SplitUtxoViewModel, Tuple3<int, bool, bool>>(
          selector: (_, vm) => Tuple3(vm.splitCount, vm.isDustError, vm.splitCountFocusNode.hasFocus),
          builder: (context, data, _) {
            final splitCount = data.item1;
            final isDustError = data.item2;
            final hasFocus = data.item3;
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
                            padding: const EdgeInsets.only(top: 8, bottom: 3),
                            placeholderText: '',
                          ),
                          if (inputText.isEmpty && !hasFocus)
                            IgnorePointer(
                              child: Text(
                                '0',
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
        _syncManualSplitItemKeys(manualSplitItems);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...manualSplitItems.asMap().entries.map((entry) {
              return _ManualSplitListItem(
                key: _getManualSplitItemKey(entry.value),
                index: entry.key,
                item: entry.value,
                viewModel: viewModel,
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
    return Selector<SplitUtxoViewModel, List<int>>(
      selector: (_, vm) => vm.recommendedSplitCounts,
      builder: (context, recommendedSplitCounts, _) {
        final viewModel = context.read<SplitUtxoViewModel>();
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
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: CoconutColors.gray700),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      width: 47,
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

  void _showUtxoSelectionBottomSheet(BuildContext context, SplitUtxoViewModel viewModel) async {
    if (_isUtxoSelectionBottomSheetOpen) return;

    _autoOpenUtxoPickerTimer?.cancel();
    _isUtxoSelectionBottomSheetOpen = true;

    try {
      final result = await CommonBottomSheets.showDraggableBottomSheet<List<UtxoState>>(
        context: context,
        minChildSize: 0.6,
        maxChildSize: 0.9,
        initialChildSize: 0.6,
        childBuilder:
            (scrollController) => UtxoSelectionScreen(
              selectedUtxoList: viewModel.selectedUtxoList,
              walletId: widget.id,
              currentUnit: viewModel.currentUnit,
              scrollController: scrollController,
              isSplitMode: true,
            ),
      );

      if (result != null && context.mounted) {
        viewModel.setSelectedUtxoList(result);
      }
    } finally {
      _isUtxoSelectionBottomSheetOpen = false;
    }
  }

  void _showSplitCriteriaBottomSheet(BuildContext context, SplitUtxoViewModel viewModel) async {
    if (_isCriteriaBottomSheetOpen) return;

    _autoOpenCriteriaPickerTimer?.cancel();
    _isCriteriaBottomSheetOpen = true;

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

    try {
      if (selectedItem != null && context.mounted) {
        viewModel.setSelectedCriteria(selectedItem);
      }
    } finally {
      _isCriteriaBottomSheetOpen = false;
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
    return hasFeeRate ? previewFeeText : t.split_utxo_screen.placeholder_estimated_fee;
  }
}

class _HeaderTitleErrorText extends StatelessWidget {
  const _HeaderTitleErrorText();

  @override
  Widget build(BuildContext context) {
    return Selector<SplitUtxoViewModel, Tuple3<String?, String, SplitCriteria?>>(
      selector: (_, vm) => Tuple3(vm.headerTitleErrorMessage, vm.feePickerDisplayText, vm.selectedCriteria),
      builder: (_, data, __) {
        final headerTitleErrorMessage = data.item1;
        final selectedCriteria = data.item3;
        if (headerTitleErrorMessage == null || headerTitleErrorMessage.isEmpty) {
          return SizedBox(height: selectedCriteria == SplitCriteria.manually ? 8 : 16);
        }

        return Padding(
          padding: const EdgeInsets.only(top: 2, bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              headerTitleErrorMessage,
              style: CoconutTypography.caption_10.setColor(CoconutColors.hotPink).copyWith(height: 1.0),
            ),
          ),
        );
      },
    );
  }
}

class _SplitResultContent extends StatefulWidget {
  final bool showSkeletonResultBox;
  final bool usePreview;
  final UtxoSplitResult? splitResult;

  const _SplitResultContent({
    super.key,
    required this.showSkeletonResultBox,
    required this.usePreview,
    required this.splitResult,
  });

  @override
  State<_SplitResultContent> createState() => _SplitResultContentState();
}

class _SplitResultContentState extends State<_SplitResultContent> with SingleTickerProviderStateMixin {
  late final AnimationController _lottieController;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
  }

  @override
  void didUpdateWidget(covariant _SplitResultContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    final isPreparing = widget.showSkeletonResultBox;
    final isReady = widget.splitResult != null || widget.usePreview;
    final isDone = isReady && !isPreparing;

    if (isDone) {
      _lottieController.stop();
      _lottieController.value = 1;
    } else if (isPreparing && !_lottieController.isAnimating) {
      _lottieController.repeat(period: _lottieController.duration ?? const Duration(seconds: 1));
    } else if (!isPreparing && !isReady) {
      _lottieController.stop();
      _lottieController.reset();
    }
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPreparing = widget.showSkeletonResultBox;
    final isReady = widget.splitResult != null || widget.usePreview;
    final isDone = isReady && !isPreparing;

    if (!isPreparing && !isReady) {
      return const SizedBox.shrink();
    }

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                Lottie.asset(
                  'assets/lottie/three-stars-growing.json',
                  controller: _lottieController,
                  onLoaded: (composition) {
                    _lottieController.duration = composition.duration;
                    if (isDone) {
                      _lottieController.value = 1;
                    } else if (isPreparing && !_lottieController.isAnimating) {
                      _lottieController.repeat(period: _lottieController.duration ?? composition.duration);
                    } else if (!isPreparing) {
                      _lottieController.reset();
                    }
                  },
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                  repeat: false,
                ),

                const SizedBox(width: 4),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.topLeft,
                        children: [...previousChildren, if (currentChild != null) currentChild],
                      );
                    },
                    transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                    child:
                        isDone
                            ? const _SplitResultReadyContent(key: ValueKey('split-ready'))
                            : const _SplitResultSkeletonContent(key: ValueKey('split-skeleton')),
                  ),
                ),
              ],
            ),
          ),
          Visibility(
            visible: widget.usePreview,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CoconutLayout.spacing_200h,
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    t.split_utxo_screen.expected_result.above_is_expected,
                    style: CoconutTypography.caption_10.setColor(CoconutColors.gray400),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SplitResultReadyContent extends StatelessWidget {
  const _SplitResultReadyContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<SplitUtxoViewModel, Tuple3<String, String?, String>>(
      selector: (_, vm) => Tuple3(vm.splitSummaryTitle, vm.splitOutputText, vm.feePickerDisplayText),
      builder: (context, data, _) {
        final splitSummaryTitle = data.item1;
        final splitOutputText = data.item2;
        final previewFeeText = data.item3;

        return Column(
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
                Expanded(
                  child: Text(
                    splitOutputText ?? '-',
                    style: CoconutTypography.body1_16.setColor(CoconutColors.white),
                    textAlign: TextAlign.right,
                  ),
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
                Text(previewFeeText, style: CoconutTypography.body1_16.setColor(CoconutColors.white)),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _SplitResultSkeletonContent extends StatelessWidget {
  const _SplitResultSkeletonContent({super.key});

  Widget _buildSkeletonBar({required double width, double height = 16}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: CoconutColors.white, borderRadius: BorderRadius.circular(999)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: CoconutColors.white.withValues(alpha: 0.12),
      highlightColor: CoconutColors.white.withValues(alpha: 0.24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSkeletonBar(width: double.infinity, height: 22),
          CoconutLayout.spacing_200h,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(padding: const EdgeInsets.only(top: 2), child: _buildSkeletonBar(width: 72, height: 16)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildSkeletonBar(width: MediaQuery.sizeOf(context).width / 2, height: 20),
                  CoconutLayout.spacing_100h,
                  _buildSkeletonBar(width: MediaQuery.sizeOf(context).width / 2, height: 20),
                ],
              ),
            ],
          ),
          CoconutLayout.spacing_100h,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(padding: const EdgeInsets.only(top: 2), child: _buildSkeletonBar(width: 64, height: 16)),
              _buildSkeletonBar(width: 92, height: 22),
            ],
          ),
        ],
      ),
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
  final ValueChanged<bool> onDeleteButtonVisibilityChanged;

  const _ManualSplitListItem({
    super.key,
    required this.index,
    required this.item,
    required this.viewModel,
    required this.onDeleteButtonVisibilityChanged,
  });

  @override
  State<_ManualSplitListItem> createState() => _ManualSplitListItemState();
}

class _ManualSplitListItemState extends State<_ManualSplitListItem> with TickerProviderStateMixin {
  late AnimationController _swipeController;
  late AnimationController _entranceController;
  late AnimationController _deleteController;
  final double _actionWidth = 60.0;
  bool _isDeleting = false;
  bool _isDeleteButtonVisible = false;

  void _handleFocusChanged() {
    Logger.log('-->handleFocusChanged');
    if (!mounted) return;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _swipeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _deleteController = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    widget.item.countFocusNode.addListener(_handleFocusChanged);
    _entranceController.forward();
  }

  void setDeleteButtonVisible(bool isVisible) {
    if (_isDeleteButtonVisible == isVisible) return;

    setState(() {
      _isDeleteButtonVisible = isVisible;
    });
    widget.onDeleteButtonVisibilityChanged(isVisible);

    if (!isVisible) {
      widget.item.amountFocusNode.unfocus();
      widget.item.countFocusNode.unfocus();
      _swipeController.reverse();
      return;
    }

    widget.item.amountFocusNode.unfocus();
    widget.item.countFocusNode.unfocus();
    _swipeController.forward();
  }

  @override
  void didUpdateWidget(covariant _ManualSplitListItem oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.viewModel.manualSplitItems.length <= 1 && _swipeController.value > 0) {
      if (_isDeleteButtonVisible) {
        widget.onDeleteButtonVisibilityChanged(false);
        _isDeleteButtonVisible = false;
      }
      _swipeController.reverse();
    }
  }

  @override
  void dispose() {
    widget.item.amountFocusNode.removeListener(_handleFocusChanged);
    widget.item.countFocusNode.removeListener(_handleFocusChanged);
    _swipeController.dispose();
    _entranceController.dispose();
    _deleteController.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.viewModel.manualSplitItems.length <= 1 || _isDeleting) return;

    if (!_isDeleteButtonVisible) {
      setDeleteButtonVisible(true);
    }

    _swipeController.value -= details.primaryDelta! / _actionWidth;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.viewModel.manualSplitItems.length <= 1 || _isDeleting) return;
    if (_swipeController.value > 0.5 || details.primaryVelocity! < -500) {
      _swipeController.forward();
    } else {
      _swipeController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: _entranceController, curve: Curves.easeOutCubic),
      axisAlignment: -1.0,
      child: FadeTransition(
        opacity: _entranceController,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 0),
          child: ClipRect(
            child: SlideTransition(
              position: Tween<Offset>(
                begin: Offset.zero,
                end: const Offset(-1.0, 0.0),
              ).animate(CurvedAnimation(parent: _deleteController, curve: Curves.easeIn)),
              child: GestureDetector(
                onHorizontalDragUpdate: _onHorizontalDragUpdate,
                onHorizontalDragEnd: _onHorizontalDragEnd,
                behavior: HitTestBehavior.opaque,
                child: Stack(
                  alignment: Alignment.centerRight,
                  children: [
                    AnimatedBuilder(
                      animation: _swipeController,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(-_swipeController.value * _actionWidth, 0),
                          child: child,
                        );
                      },
                      child: Container(
                        color: CoconutColors.black,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            /// 금액 입력란
                            Expanded(
                              child: CoconutTextField(
                                enabled: !_isDeleteButtonVisible,
                                controller: widget.item.amountController,
                                focusNode: widget.item.amountFocusNode,
                                style: CoconutTextFieldStyle.underline,
                                fontSize: 18,
                                activeColor: CoconutColors.white,
                                placeholderColor: CoconutColors.gray500,
                                errorColor: CoconutColors.hotPink,
                                onChanged: (_) {},
                                onEditingComplete: () => widget.item.amountFocusNode.unfocus(),
                                textInputAction: TextInputAction.done,
                                textInputType: const TextInputType.numberWithOptions(decimal: true),
                                textInputFormatter: [_DecimalTextInputFormatter()],
                                placeholderText: t.split_utxo_screen.placeholder_split_amount,
                                maxLines: 1,
                                padding: const EdgeInsets.only(left: 4, right: 4, top: 8, bottom: 4),
                                unfocusOnTapOutside: true,
                                suffix: Padding(
                                  padding: const EdgeInsets.only(top: 4, right: 4),
                                  child: Text(
                                    widget.viewModel.currentUnit.symbol,
                                    style: CoconutTypography.heading4_18.setColor(CoconutColors.white),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),

                            /// - 버튼
                            RippleEffect(
                              onTap: () {
                                if (_isDeleteButtonVisible) return;
                                widget.viewModel.decrementManualSplitCount(widget.index);
                              },
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
                            const SizedBox(width: 10),

                            /// 개수 입력란
                            SizedBox(
                              width: 60,
                              child: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: widget.item.countController,
                                builder: (context, value, _) {
                                  final inputText = value.text;
                                  final hasFocus = widget.item.countFocusNode.hasFocus;
                                  return Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      CoconutTextField(
                                        height: 40,
                                        fontHeight: 1,
                                        borderRadius: 8,
                                        enabled: !_isDeleteButtonVisible,
                                        controller: widget.item.countController,
                                        focusNode: widget.item.countFocusNode,
                                        textAlign: TextAlign.center,
                                        backgroundColor: hasFocus ? CoconutColors.gray800 : Colors.transparent,
                                        activeColor: CoconutColors.white,
                                        placeholderColor: CoconutColors.gray500,
                                        fontSize: 24,
                                        isVisibleBorder: false,
                                        onChanged: (_) {},
                                        onEditingComplete: () => widget.item.countFocusNode.unfocus(),
                                        textInputAction: TextInputAction.done,
                                        textInputType: TextInputType.number,
                                        textInputFormatter: [FilteringTextInputFormatter.digitsOnly],
                                        maxLines: 1,
                                        unfocusOnTapOutside: true,
                                        padding: const EdgeInsets.only(top: 8, bottom: 3),
                                        placeholderText: '',
                                      ),
                                      if (inputText.isEmpty && !hasFocus)
                                        IgnorePointer(
                                          child: Text(
                                            '0',
                                            style: CoconutTypography.heading3_21_NumberBold.copyWith(
                                              color: CoconutColors.gray500,
                                              fontSize: 24,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 10),

                            /// + 버튼
                            RippleEffect(
                              onTap: () {
                                if (_isDeleteButtonVisible) return;
                                widget.viewModel.incrementManualSplitCount(widget.index);
                              },
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
                          animation: _swipeController,
                          builder: (context, child) {
                            return Transform.translate(
                              offset: Offset(_actionWidth * (1 - _swipeController.value), 0),
                              child: child,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CoconutLayout.spacing_300w,
                              TapRegion(
                                onTapOutside: (_) {
                                  if (!_isDeleteButtonVisible || _isDeleting) return;
                                  setDeleteButtonVisible(false);
                                },
                                child: RippleEffect(
                                  onTap: () async {
                                    if (_isDeleting) return;
                                    setState(() => _isDeleting = true);

                                    await _deleteController.forward();
                                    if (!mounted) return;

                                    await _entranceController.reverse();
                                    if (!mounted) return;

                                    final currentIndex = widget.viewModel.manualSplitItems.indexOf(widget.item);
                                    if (currentIndex != -1) {
                                      widget.viewModel.removeManualSplitItem(currentIndex);
                                    }
                                  },
                                  borderRadius: 12,
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: CoconutColors.hotPink,
                                      borderRadius: BorderRadius.circular(12),
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
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DecimalTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String text = newValue.text;

    if (text.isEmpty) return newValue;

    if (text.startsWith('.')) {
      text = '0$text';
      return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: newValue.selection.end + 1));
    }

    if (text.length > 1 && text.startsWith('0') && !text.startsWith('0.')) {
      return oldValue;
    }

    if (!RegExp(r'^\d*\.?\d*$').hasMatch(text)) {
      return oldValue;
    }

    return newValue;
  }
}
