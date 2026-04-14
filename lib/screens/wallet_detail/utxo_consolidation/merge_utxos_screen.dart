import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/utxo_merge_enums.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/connectivity_provider.dart';
import 'package:coconut_wallet/providers/send_info_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/merge_utxos/merge_utxos_view_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/constants/dust_constants.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/services/fee_service.dart';
import 'package:coconut_wallet/screens/common/tag_select_bottom_sheet.dart';
import 'package:coconut_wallet/screens/send/refactor/send_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_bucket_card_row.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/address_scan_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/bitcoin/transaction_util.dart';
import 'package:coconut_wallet/utils/colors_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/text_field_filter_util.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/bottom_sheet/estimated_fee_bottom_sheet.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:shimmer/shimmer.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';

part 'merge_utxos_screen_components.dart';
part 'merge_utxos_screen_models.dart';
part 'merge_utxos_screen_cta.dart';
part 'merge_utxos_screen_animations.dart';
part 'merge_utxos_screen_bottom_sheets.dart';

class MergeUtxosScreen extends StatefulWidget {
  final int id;

  const MergeUtxosScreen({super.key, required this.id});

  @override
  State<MergeUtxosScreen> createState() => _MergeUtxosScreenState();
}

class _MergeUtxosScreenState extends State<MergeUtxosScreen> with SingleTickerProviderStateMixin {
  static const Duration _headerAnimationDuration = Duration(milliseconds: 400);
  static const Duration _optionPickerAnimationDuration = Duration(milliseconds: 300);

  late MergeUtxosViewModel _viewModel;
  late final AnimationController _receiveAddressSummaryLottieController;
  String? _preparedMergeTransactionKey;
  bool _isAmountTextHighlighted = false;

  @override
  void initState() {
    super.initState();
    _receiveAddressSummaryLottieController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _viewModel = MergeUtxosViewModel(widget.id, context.read<UtxoRepository>(), context.read<UtxoTagProvider>())
      ..initialize();
    final wallet = context.read<WalletProvider>().getWalletById(widget.id);
    _viewModel.setDustThreshold(
      wallet.walletType == WalletType.singleSignature ? DustThresholds.p2wpkh : DustThresholds.p2wsh,
    );
    _viewModel.setSelectedReceiveAddress(context.read<WalletProvider>().getReceiveAddress(widget.id).address);
  }

  @override
  void dispose() {
    _receiveAddressSummaryLottieController.dispose();
    _viewModel.dispose();
    super.dispose();
  }

  void _setScreenState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MergeUtxosViewModel>.value(
      value: _viewModel,
      child: Consumer<MergeUtxosViewModel>(
        builder: (context, viewModel, child) {
          return Scaffold(
            backgroundColor: CoconutColors.black,
            appBar: _buildAppBar(context),
            body: SafeArea(child: _buildBody(context)),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return CoconutAppBar.build(
      context: context,
      backgroundColor: CoconutColors.black,
      title: t.merge_utxos_screen.title,
      isBottom: true,
      isBackButton: true,
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_viewModel.currentStep == UtxoMergeStep.entry) {
      // 2개 <= n(UTXO) < 11
      return _buildFewUtxosWarning(_viewModel);
    }

    return _buildMergeContent(context);
  }

  Widget _buildFewUtxosWarning(MergeUtxosViewModel viewModel) {
    int utxoCount = _viewModel.utxoCount;

    return Stack(
      children: [
        Container(
          width: MediaQuery.sizeOf(context).width,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CoconutSlideUpAnimation(
                delay: const Duration(milliseconds: 600),
                child: Text(t.merge_utxos_screen.not_enough_utxos, style: CoconutTypography.heading4_18_Bold),
              ),
              CoconutLayout.spacing_800h,
              CoconutSlideUpAnimation(
                delay: const Duration(milliseconds: 900),
                child: Text(
                  t.merge_utxos_screen.efficient_utxo_state(count: utxoCount),
                  textAlign: TextAlign.center,
                  style: CoconutTypography.body2_14,
                ),
              ),
            ],
          ),
        ),
        CoconutSlideUpAnimation(
          delay: const Duration(milliseconds: 1200),
          child: FixedBottomButton(
            onButtonClicked: () {
              _viewModel.setCurrentStep(UtxoMergeStep.selectMergeCriteria);
              debugPrint(_viewModel.currentStep.toString());
            },
            text: t.merge_utxos_screen.merge_anyway,
            backgroundColor: CoconutColors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildMergeContent(BuildContext context) {
    _scheduleHeaderAnimation(_viewModel.currentStep);
    _scheduleOptionPickerAnimation(_viewModel.currentStep);
    final isTransactionSummaryFailed = _viewModel.mergeTransactionSummaryState == MergeTransactionSummaryState.failed;
    final shouldBlockMergeActionForFeeRate =
        _viewModel.currentStep == UtxoMergeStep.selectReceiveAddress &&
        _viewModel.needsManualFeeRateInput &&
        _viewModel.feeRateController.text.trim().isEmpty;
    final showMergeBottomButton =
        _viewModel.currentStep == UtxoMergeStep.selectReceiveAddress &&
        !shouldBlockMergeActionForFeeRate &&
        !isTransactionSummaryFailed;
    final showMergeButtonSubText =
        _viewModel.mergeTransactionSummaryState == MergeTransactionSummaryState.invalidSelection ||
        _mergeCtaAssistData != null;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).top - kToolbarHeight,
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Container(
              padding: EdgeInsets.fromLTRB(
                16,
                isTransactionSummaryFailed ? 88 : 16,
                16,
                showMergeBottomButton ? (showMergeButtonSubText ? 160 : 132) : 16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_buildAnimatedHeader(), CoconutLayout.spacing_1000h, _buildVisibleOptionPickers(context)],
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
              child:
                  isTransactionSummaryFailed
                      ? _buildTransactionSummaryErrorTooltip()
                      : const SizedBox.shrink(key: ValueKey('merge-transaction-summary-error-empty')),
            ),
          ),
          if (showMergeBottomButton)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: showMergeButtonSubText ? 148 : 120,
                child: FixedBottomButton(
                  onButtonClicked: _onMergeButtonClicked,
                  isActive:
                      _viewModel.mergeTransactionSummaryState == MergeTransactionSummaryState.ready &&
                      _viewModel.selectedUtxoCount >= 2,
                  text: t.merge_utxos_screen.merge_action,
                  backgroundColor: CoconutColors.white,
                  subWidget: _getMergeButtonSubTextWidget(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _getMergeButtonSubTextWidget() {
    switch (_viewModel.mergeTransactionSummaryState) {
      case MergeTransactionSummaryState.invalidSelection:
        return Text(
          t.toast.merge_utxos_unavailable_description,
          style: CoconutTypography.body3_12.setColor(CoconutColors.warningText),
        );
      case MergeTransactionSummaryState.ready:
        final ctaAssistData = _mergeCtaAssistData;
        if (ctaAssistData == null) return const SizedBox.shrink();
        return Text(ctaAssistData.message, style: CoconutTypography.body3_12.setColor(ctaAssistData.color));
      case MergeTransactionSummaryState.idle:
      case MergeTransactionSummaryState.preparing:
      case MergeTransactionSummaryState.failed:
        return const SizedBox.shrink();
    }
  }

  Future<void> _onMergeButtonClicked() async {
    if (context.read<ConnectivityProvider>().isInternetOn != true) {
      CoconutToast.showToast(context: context, text: t.errors.network_error, isVisibleIcon: true);
      return;
    }
    if (_viewModel.mergeTransactionSummaryState != MergeTransactionSummaryState.ready) return;

    TransactionBuildResult? txBuildResult = _viewModel.preparedMergeTransactionBuildResult;
    if (!mounted || txBuildResult == null || !txBuildResult.isSuccess || txBuildResult.transaction == null) {
      return;
    }

    context.loaderOverlay.show();
    try {
      final wallet = context.read<WalletProvider>().getWalletById(widget.id);
      final sendInfoProvider = context.read<SendInfoProvider>();
      final feeRate =
          _viewModel.appliedMergeFeeRate ??
          double.tryParse(_viewModel.feeRateController.text.trim()) ??
          _viewModel.feeInfos[1].satsPerVb ??
          _viewModel.feeInfos[2].satsPerVb ??
          _viewModel.feeInfos[0].satsPerVb ??
          1.0;

      sendInfoProvider.clear();
      sendInfoProvider.setSendEntryPoint(SendEntryPoint.walletDetail);
      sendInfoProvider.setWalletId(wallet.id);
      sendInfoProvider.setTransaction(txBuildResult.transaction!);
      sendInfoProvider.setIsMultisig(wallet.walletType == WalletType.multiSignature);
      sendInfoProvider.setWalletImportSource(wallet.walletImportSource);
      sendInfoProvider.setFeeRate(feeRate);
      sendInfoProvider.setIsMaxMode(false);

      if (!mounted) return;
      context.loaderOverlay.hide();
      Navigator.pushNamed(
        context,
        '/send-confirm',
        arguments: {"currentUnit": context.read<PreferenceProvider>().currentUnit},
      );
    } finally {
      if (mounted && context.loaderOverlay.visible) {
        context.loaderOverlay.hide();
      }
    }
  }

  List<UtxoMergeStep> _visibleOptionPickerStepsFor(UtxoMergeStep step) {
    switch (step) {
      case UtxoMergeStep.selectMergeCriteria:
        return const [UtxoMergeStep.selectMergeCriteria];
      case UtxoMergeStep.selectAmountCriteria:
        return const [UtxoMergeStep.selectAmountCriteria, UtxoMergeStep.selectMergeCriteria];
      case UtxoMergeStep.selectTag:
        return const [UtxoMergeStep.selectTag, UtxoMergeStep.selectMergeCriteria];
      case UtxoMergeStep.selectReceiveAddress:
        switch (_currentMergeCriteria) {
          case UtxoMergeCriteria.sameAddress:
            return const [UtxoMergeStep.selectReceiveAddress, UtxoMergeStep.selectMergeCriteria];
          case UtxoMergeCriteria.sameTag:
            return const [
              UtxoMergeStep.selectReceiveAddress,
              UtxoMergeStep.selectTag,
              UtxoMergeStep.selectMergeCriteria,
            ];
          case UtxoMergeCriteria.smallAmounts:
            return const [
              UtxoMergeStep.selectReceiveAddress,
              UtxoMergeStep.selectAmountCriteria,
              UtxoMergeStep.selectMergeCriteria,
            ];
        }
      case UtxoMergeStep.entry:
        return const [];
    }
  }

  void _scheduleBottomSheetOpen(UtxoMergeStep step) async {
    await Future.delayed(const Duration(milliseconds: 50));
    // 옵션 피커가 생긴 뒤 BottomSheet 자동 노출 예약
    switch (step) {
      case UtxoMergeStep.selectMergeCriteria:
        if (!_viewModel.didConfirmMergeCriteria) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_viewModel.isBottomSheetOpen) {
              _showMergeCriteriaBottomSheet(context);
            }
          });
        }
        break;
      case UtxoMergeStep.selectAmountCriteria:
        if (!_viewModel.didConfirmAmountCriteria) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_viewModel.isBottomSheetOpen) {
              _showAmountCriteriaBottomSheet(context);
            }
          });
        }
        break;
      case UtxoMergeStep.selectReceiveAddress:
        if (!_viewModel.didConfirmAmountCriteria) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_viewModel.isBottomSheetOpen) {
              _showReceiveAddressBottomSheet(context);
            }
          });
        }
        break;
      case UtxoMergeStep.selectTag:
        if (!_viewModel.didConfirmTagCriteria) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_viewModel.isBottomSheetOpen) {
              _showTagSelectBottomSheet(context);
            }
          });
        }
        break;
      default:
        break;
    }
  }

  bool _isAnimatedHeaderStep(UtxoMergeStep step) {
    return step == UtxoMergeStep.selectMergeCriteria ||
        step == UtxoMergeStep.selectAmountCriteria ||
        step == UtxoMergeStep.selectTag ||
        step == UtxoMergeStep.selectReceiveAddress;
  }

  String? _headerTextForStep(UtxoMergeStep? step) {
    switch (step) {
      case UtxoMergeStep.selectMergeCriteria:
        return t.merge_utxos_screen.select_merge_criteria;
      case UtxoMergeStep.selectAmountCriteria:
        return t.merge_utxos_screen.select_amount_criteria;
      case UtxoMergeStep.selectTag:
        return t.merge_utxos_screen.select_tag;
      default:
        return null;
    }
  }

  Widget _buildAnimatedHeader() {
    final step = _viewModel.displayedHeaderStep;

    if (step == null) {
      return const SizedBox.shrink();
    }

    if (step == UtxoMergeStep.selectReceiveAddress) {
      if (_viewModel.mergeTransactionSummaryState == MergeTransactionSummaryState.invalidSelection ||
          _viewModel.mergeTransactionSummaryState == MergeTransactionSummaryState.idle) {
        return const SizedBox.shrink();
      }

      final summaryCard = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTransactionSummaryCard(),
          if (_viewModel.hasDustUtxosInCurrentCandidates &&
              _currentMergeCriteria != UtxoMergeCriteria.smallAmounts) ...[
            const SizedBox(height: 12),
            _buildDustWarningRow(),
          ],
        ],
      );

      if (_viewModel.isHeaderFadingOut) {
        return summaryCard.fadeOutAnimation(
          key: ValueKey('merge-header-out-${step.name}-${_viewModel.headerAnimationNonce}'),
          duration: const Duration(milliseconds: 100),
        );
      }

      return summaryCard.fadeInAnimation(
        key: ValueKey('merge-header-in-${step.name}-${_viewModel.headerAnimationNonce}'),
        duration: _headerAnimationDuration,
        delay: const Duration(milliseconds: 300),
      );
    }

    final text = _headerTextForStep(step);
    if (text == null) {
      return const SizedBox.shrink();
    }

    if (_viewModel.isHeaderFadingOut) {
      return text.characterFadeOutAnimation(
        key: ValueKey('merge-header-out-${step.name}-${_viewModel.headerAnimationNonce}'),
        textStyle: CoconutTypography.heading4_18_Bold,
        duration: const Duration(milliseconds: 100),
        slideDirection: CoconutCharacterFadeSlideDirection.slideUp,
      );
    }

    return text.characterFadeInAnimation(
      key: ValueKey('merge-header-in-${step.name}-${_viewModel.headerAnimationNonce}'),
      textStyle: CoconutTypography.heading4_18_Bold,
      duration: _headerAnimationDuration,
      delay: const Duration(milliseconds: 300),
      slideDirection: CoconutCharacterFadeSlideDirection.slideDown,
    );
  }

  Widget _buildTransactionSummaryCard() {
    return _buildTransactionSummaryCardBody();
  }

  Widget _buildTransactionSummaryCardBody() {
    final amountText = _summaryCardHeadlineText;
    final totalAmountText = _selectedUtxosTotalAmountText;
    final destinationText = _summaryCardDestinationText;
    final isPreparing = _viewModel.mergeTransactionSummaryState == MergeTransactionSummaryState.preparing;
    final isReady = _viewModel.mergeTransactionSummaryState == MergeTransactionSummaryState.ready;
    final isInvalidSelection = _viewModel.mergeTransactionSummaryState == MergeTransactionSummaryState.invalidSelection;

    return Container(
      key: const ValueKey('merge-transaction-summary-card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: CoconutColors.gray800,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CoconutColors.gray600, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Lottie.asset(
              'assets/lottie/three-stars-growing.json',
              controller: _receiveAddressSummaryLottieController,
              onLoaded: (composition) {
                _receiveAddressSummaryLottieController.duration = composition.duration;
                if (_viewModel.displayedHeaderStep == UtxoMergeStep.selectReceiveAddress) {
                  if (isReady) {
                    _receiveAddressSummaryLottieController.value = 1;
                  } else if (isPreparing && !_receiveAddressSummaryLottieController.isAnimating) {
                    _receiveAddressSummaryLottieController.repeat(
                      period: _receiveAddressSummaryLottieController.duration ?? composition.duration,
                    );
                  } else if (!isPreparing) {
                    _receiveAddressSummaryLottieController.reset();
                  }
                }
              },
              width: 24,
              height: 24,
              fit: BoxFit.contain,
              repeat: false,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [...previousChildren, if (currentChild != null) currentChild],
                  );
                },
                transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                child:
                    isReady
                        ? RichText(
                          key: const ValueKey('receive-address-summary-text'),
                          text: TextSpan(
                            style: CoconutTypography.body1_16_Bold.setColor(CoconutColors.white),
                            children: [
                              TextSpan(
                                text: amountText,
                                style: TextStyle(
                                  decoration: TextDecoration.underline,
                                  color: _isAmountTextHighlighted ? CoconutColors.gray350 : CoconutColors.white,
                                ),
                                recognizer:
                                    TapGestureRecognizer()
                                      ..onTapDown = (_) {
                                        setState(() {
                                          _isAmountTextHighlighted = true;
                                        });
                                      }
                                      ..onTapUp = (_) {
                                        setState(() {
                                          _isAmountTextHighlighted = false;
                                        });
                                        _showSelectedUtxosPreviewBottomSheet();
                                      }
                                      ..onTapCancel = () {
                                        setState(() {
                                          _isAmountTextHighlighted = false;
                                        });
                                      },
                              ),
                              TextSpan(
                                text: t.merge_utxos_screen.receive_address_summary_total(amount: totalAmountText),
                              ),
                              TextSpan(text: destinationText),
                            ],
                          ),
                        ).fadeInAnimation(
                          key: ValueKey(
                            'receive-address-summary-text-fade-${_viewModel.receiveAddressSummaryAnimationNonce}',
                          ),
                          duration: const Duration(milliseconds: 260),
                        )
                        : isPreparing
                        ? _buildReceiveAddressSummarySkeleton()
                        : _buildReceiveAddressSummaryFallback(
                          message: isInvalidSelection ? t.merge_utxos_screen.not_enough_utxos : '',
                        ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionSummaryErrorTooltip() {
    final rawErrorMessage = _viewModel.preparedMergeTransactionBuildResult?.exception?.toString();
    final errorMessage =
        rawErrorMessage == null || rawErrorMessage.isEmpty
            ? t.merge_utxos_screen.transaction_build_error
            : t.merge_utxos_screen.transaction_build_error_with_message(error_msg: rawErrorMessage);

    return SizedBox(
      key: const ValueKey('merge-transaction-summary-error-tooltip'),
      width: double.infinity,
      child: CoconutToolTip(
        tooltipType: CoconutTooltipType.fixed,
        tooltipState: CoconutTooltipState.error,
        showIcon: true,
        icon: SvgPicture.asset(
          'assets/svg/triangle-warning.svg',
          colorFilter: const ColorFilter.mode(CoconutColors.hotPink, BlendMode.srcIn),
        ),
        richText: RichText(
          text: TextSpan(text: errorMessage, style: CoconutTypography.body3_12.setColor(CoconutColors.white)),
        ),
      ),
    );
  }

  Widget _buildDustWarningRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            t.merge_utxos_screen.dust_warning,
            style: CoconutTypography.body3_12.setColor(CoconutColors.yellow),
          ),
        ),
        ShrinkAnimationButton(
          onPressed: _toggleDustExclusion,
          defaultColor: Colors.transparent,
          pressedColor: CoconutColors.gray800,
          borderRadius: 8,
          borderWidth: 0,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: CoconutColors.gray500, width: 1),
                  ),
                  child:
                      _viewModel.excludeDustUtxos
                          ? Center(
                            child: SvgPicture.asset(
                              'assets/svg/check.svg',
                              width: 12,
                              height: 12,
                              colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 8),
                Text(
                  t.merge_utxos_screen.exclude_dust,
                  style: CoconutTypography.body3_12.setColor(CoconutColors.white),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDustWarningToggleCompact() {
    return ShrinkAnimationButton(
      onPressed: _toggleDustExclusion,
      defaultColor: Colors.transparent,
      pressedColor: CoconutColors.gray800,
      borderRadius: 8,
      borderWidth: 0,
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: CoconutColors.gray500, width: 1),
              ),
              child:
                  _viewModel.excludeDustUtxos
                      ? Center(
                        child: SvgPicture.asset(
                          'assets/svg/check.svg',
                          width: 14,
                          height: 14,
                          colorFilter: const ColorFilter.mode(CoconutColors.white, BlendMode.srcIn),
                        ),
                      )
                      : null,
            ),
            const SizedBox(width: 8),
            Text(t.merge_utxos_screen.exclude_dust, style: CoconutTypography.body3_12.setColor(CoconutColors.white)),
          ],
        ),
      ),
    );
  }

  void _toggleDustExclusion() {
    final nextExcludeDustUtxos = !_viewModel.excludeDustUtxos;
    final selectedUtxoIdsBeforeToggle = _viewModel.selectedUtxosBeforeDustExclusion.map((utxo) => utxo.utxoId).toSet();

    setState(() {
      _viewModel.setExcludeDustUtxos(nextExcludeDustUtxos);
      if (nextExcludeDustUtxos) {
        _viewModel.setEditedSelectedUtxoIds(
          selectedUtxoIdsBeforeToggle.where((utxoId) {
            final utxo = _viewModel.candidateUtxosForCurrentCriteria.firstWhere((item) => item.utxoId == utxoId);
            return utxo.amount > _viewModel.dustThreshold;
          }).toSet(),
        );
      } else {
        _viewModel.setEditedSelectedUtxoIds(null);
      }
    });
    unawaited(_calculateEstimatedMergeFee());
  }

  String get _selectedUtxosTotalAmountText {
    final totalSats = _viewModel.selectedUtxosTotalAmountSats;
    return '${BalanceFormatUtil.formatSatoshiToReadableBitcoin(totalSats)} BTC';
  }

  String? get _selectedReceiveWalletName {
    final selectedReceiveAddress = _viewModel.selectedReceiveAddress;
    if (selectedReceiveAddress == null || selectedReceiveAddress.isEmpty) return null;

    final matchedOption = _receiveAddresses.cast<_ReceiveAddressOption?>().firstWhere(
      (item) => item?.address == selectedReceiveAddress,
      orElse: () => null,
    );

    return matchedOption?.walletName;
  }

  String get _summaryCardHeadlineText {
    final utxoCount = _viewModel.selectedUtxoCount;

    switch (_currentMergeCriteria) {
      case UtxoMergeCriteria.smallAmounts:
        return _viewModel.isCustomAmountLessThan
            ? t.merge_utxos_screen.receive_address_summary_headline_under(
              amount: _summaryAmountThresholdText,
              count: utxoCount,
            )
            : t.merge_utxos_screen.receive_address_summary_headline_or_less(
              amount: _summaryAmountThresholdText,
              count: utxoCount,
            );
      case UtxoMergeCriteria.sameTag:
        return t.merge_utxos_screen.receive_address_summary_count(count: utxoCount);
      case UtxoMergeCriteria.sameAddress:
        return t.merge_utxos_screen.receive_address_summary_count(count: utxoCount);
    }
  }

  String get _summaryCardDestinationText {
    final walletName = _selectedReceiveWalletName;
    if (walletName != null && walletName.isNotEmpty) {
      return t.merge_utxos_screen.receive_address_summary_to_wallet(wallet_name: walletName);
    }
    return t.merge_utxos_screen.receive_address_summary_to_selected_address;
  }

  String get _summaryAmountThresholdText {
    switch (_currentAmountCriteria) {
      case UtxoAmountCriteria.below001:
        return '0.01 BTC';
      case UtxoAmountCriteria.below0001:
        return '0.001 BTC';
      case UtxoAmountCriteria.below00001:
        return '0.0001 BTC';
      case UtxoAmountCriteria.custom:
        final customAmount = _viewModel.customAmountCriteriaText ?? '';
        final formattedAmount = customAmount.isEmpty ? customAmount : '${_formatCustomAmountText(customAmount)} BTC';
        return formattedAmount;
    }
  }

  Widget _buildReceiveAddressSummarySkeleton() {
    return Shimmer.fromColors(
      key: const ValueKey('receive-address-summary-skeleton'),
      baseColor: CoconutColors.gray700,
      highlightColor: CoconutColors.gray600,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Container(
            width: 132,
            height: 16,
            decoration: BoxDecoration(color: CoconutColors.white, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 6),
          Container(
            width: 120,
            height: 16,
            decoration: BoxDecoration(color: CoconutColors.white, borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(height: 6),
          Container(
            width: 168,
            height: 16,
            decoration: BoxDecoration(color: CoconutColors.white, borderRadius: BorderRadius.circular(4)),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiveAddressSummaryFallback({required String message}) {
    return Text(
      message,
      key: ValueKey('receive-address-summary-fallback-$message'),
      style: CoconutTypography.body2_14.setColor(CoconutColors.gray300),
    );
  }

  String? get _effectiveSelectedTagName => _viewModel.effectiveSelectedTagName;

  String get _estimatedMergeFeeText {
    if (_viewModel.isEstimatedMergeFeeLoading) return '...';
    if (_viewModel.estimatedMergeFeeSats == null) return '-';
    return '${BalanceFormatUtil.formatSatoshiToReadableBitcoin(_viewModel.estimatedMergeFeeSats!, forceEightDecimals: true)} BTC';
  }

  void _syncEstimatedFeeTextToViewModel() {
    _viewModel.setEstimatedFeeText(_estimatedMergeFeeText);
  }

  Future<void> _handleEnterSelectReceiveAddressStep() async {
    final currentFeeRateText = _viewModel.feeRateController.text.trim();
    if (currentFeeRateText.isNotEmpty) {
      if (mounted) {
        setState(() {
          _viewModel.setNeedsManualFeeRateInput(false);
        });
      }
      await _calculateEstimatedMergeFee(forceRebuild: true);
      return;
    }

    final didFetchRecommendedFees = await _viewModel.refreshRecommendedFees();
    if (!mounted) return;
    setState(() {
      _viewModel.setNeedsManualFeeRateInput(!didFetchRecommendedFees);
    });
    await _calculateEstimatedMergeFee(forceRebuild: true);
  }

  Future<void> _calculateEstimatedMergeFee({bool forceRebuild = false}) async {
    final preparationKey = _viewModel.mergeTransactionPreparationKey;
    if (preparationKey == null) {
      if (!mounted) return;
      setState(() {
        _viewModel.setPreparedMergeTransactionBuildResult(null);
        _preparedMergeTransactionKey = null;
        _viewModel.setEstimatedMergeFeeSats(null);
        _viewModel.setIsEstimatedMergeFeeLoading(false);
        _viewModel.setAppliedMergeFeeRate(null);
        _viewModel.setMergeTransactionSummaryState(
          _viewModel.selectedUtxoCount >= 2
              ? MergeTransactionSummaryState.idle
              : MergeTransactionSummaryState.invalidSelection,
        );
      });
      _receiveAddressSummaryLottieController
        ..stop()
        ..reset();
      _syncEstimatedFeeTextToViewModel();
      return;
    }

    if (!forceRebuild &&
        _viewModel.mergeTransactionSummaryState != MergeTransactionSummaryState.preparing &&
        _preparedMergeTransactionKey == preparationKey &&
        _viewModel.preparedMergeTransactionBuildResult != null) {
      return;
    }

    final selectedReceiveAddress = _viewModel.selectedReceiveAddress;
    final selectedUtxos = _viewModel.selectedUtxosForCurrentCriteria;

    if (_viewModel.currentStep != UtxoMergeStep.selectReceiveAddress ||
        selectedReceiveAddress == null ||
        selectedReceiveAddress.isEmpty ||
        selectedUtxos.length < 2) {
      if (!mounted) return;
      setState(() {
        _viewModel.setPreparedMergeTransactionBuildResult(null);
        _preparedMergeTransactionKey = null;
        _viewModel.setEstimatedMergeFeeSats(null);
        _viewModel.setIsEstimatedMergeFeeLoading(false);
        _viewModel.setAppliedMergeFeeRate(null);
        _viewModel.setMergeTransactionSummaryState(MergeTransactionSummaryState.invalidSelection);
      });
      _receiveAddressSummaryLottieController
        ..stop()
        ..reset();
      _syncEstimatedFeeTextToViewModel();
      return;
    }

    final nonce = _viewModel.mergeTransactionPreparationNonce + 1;
    _viewModel.setMergeTransactionPreparationNonce(nonce);
    setState(() {
      _preparedMergeTransactionKey = preparationKey;
      _viewModel.setIsEstimatedMergeFeeLoading(true);
      _viewModel.setMergeTransactionSummaryState(MergeTransactionSummaryState.preparing);
      _viewModel.setReceiveAddressSummaryAnimationNonce(_viewModel.receiveAddressSummaryAnimationNonce + 1);
    });
    _receiveAddressSummaryLottieController
      ..stop()
      ..reset()
      ..repeat(period: const Duration(seconds: 1));
    await Future<void>.delayed(Duration.zero);
    if (!mounted || nonce != _viewModel.mergeTransactionPreparationNonce) return;

    try {
      final walletProvider = context.read<WalletProvider>();
      final wallet = walletProvider.getWalletById(widget.id);
      final changeAddress = walletProvider.getChangeAddress(widget.id);
      final recommendedFees = await FeeService().getRecommendedFees();
      final inputFeeRate = double.tryParse(_viewModel.feeRateController.text.trim());
      final feeRate =
          inputFeeRate ??
          recommendedFees?.halfHourFee ??
          recommendedFees?.hourFee ??
          recommendedFees?.minimumFee ??
          1.0;
      final totalInputAmount = selectedUtxos.fold<int>(0, (sum, utxo) => sum + utxo.amount);

      final txBuildResult =
          TransactionBuilder(
            availableUtxos: selectedUtxos,
            recipients: {selectedReceiveAddress: totalInputAmount},
            feeRate: feeRate,
            changeDerivationPath: changeAddress.derivationPath,
            walletListItemBase: wallet,
            isFeeSubtractedFromAmount: true,
            isUtxoFixed: true,
          ).build();

      if (!mounted || nonce != _viewModel.mergeTransactionPreparationNonce) return;
      setState(() {
        _viewModel.setPreparedMergeTransactionBuildResult(txBuildResult);
        _viewModel.setAppliedMergeFeeRate(feeRate);
        _viewModel.setEstimatedMergeFeeSats(
          txBuildResult.isSuccess ? txBuildResult.estimatedFee - (txBuildResult.unintendedDustFee ?? 0) : null,
        );
        _viewModel.setIsEstimatedMergeFeeLoading(false);
        _viewModel.setMergeTransactionSummaryState(
          txBuildResult.isSuccess ? MergeTransactionSummaryState.ready : MergeTransactionSummaryState.failed,
        );
        _viewModel.setReceiveAddressSummaryAnimationNonce(_viewModel.receiveAddressSummaryAnimationNonce + 1);
      });
      _receiveAddressSummaryLottieController
        ..stop()
        ..value = txBuildResult.isSuccess ? 1 : 0;
      _syncEstimatedFeeTextToViewModel();
    } catch (_) {
      if (!mounted || nonce != _viewModel.mergeTransactionPreparationNonce) return;
      setState(() {
        _viewModel.setPreparedMergeTransactionBuildResult(null);
        _viewModel.setEstimatedMergeFeeSats(null);
        _viewModel.setIsEstimatedMergeFeeLoading(false);
        _viewModel.setAppliedMergeFeeRate(null);
        _viewModel.setMergeTransactionSummaryState(MergeTransactionSummaryState.failed);
        _viewModel.setReceiveAddressSummaryAnimationNonce(_viewModel.receiveAddressSummaryAnimationNonce + 1);
      });
      _receiveAddressSummaryLottieController
        ..stop()
        ..reset();
      _syncEstimatedFeeTextToViewModel();
    }
  }

  String _getUtxosPreviewBottomSheetTitle() {
    switch (_currentMergeCriteria) {
      case UtxoMergeCriteria.smallAmounts:
        return _currentAmountCriteriaText;
      case UtxoMergeCriteria.sameAddress:
        return t.merge_utxos_screen.reused_address;
      case UtxoMergeCriteria.sameTag:
        return t.merge_utxos_screen.selected_tag_title(name: _effectiveSelectedTagName ?? '');
    }
  }

  Future<void> _showSelectedUtxosPreviewBottomSheet() async {
    // 합치기 대상 후보 UTXO들
    final candidateUtxos = _viewModel.candidateUtxosForCurrentCriteria;

    // BTC 단위로 고정
    const currentUnit = BitcoinUnit.btc;

    final reusedAddresses = _viewModel.reusedAddressesInWallet;
    final isEditingNotifier = ValueNotifier(false);
    final initialSelectedUtxoIds = _viewModel.selectedUtxosForCurrentCriteria.map((utxo) => utxo.utxoId).toSet();
    final draftSelectedUtxoIdsNotifier = ValueNotifier<Set<String>>(initialSelectedUtxoIds);

    try {
      await CommonBottomSheets.showBottomSheet<void>(
        title: _getUtxosPreviewBottomSheetTitle(),
        showDragHandle: true,
        context: context,
        actionList: [
          ValueListenableBuilder<bool>(
            valueListenable: isEditingNotifier,
            builder:
                (context, isEditing, _) => CoconutUnderlinedButton(
                  text: isEditing ? t.complete : t.edit,
                  onTap: () {
                    if (isEditing) {
                      final committedSelectedUtxoIds = Set<String>.from(draftSelectedUtxoIdsNotifier.value);
                      setState(() {
                        _viewModel.setEditedSelectedUtxoIds(committedSelectedUtxoIds);
                        if (_viewModel.selectionContainsDust(committedSelectedUtxoIds)) {
                          _viewModel.setExcludeDustUtxos(false);
                        }
                      });
                      unawaited(_calculateEstimatedMergeFee());
                    }
                    isEditingNotifier.value = !isEditing;
                  },
                ),
          ),
        ],
        backgroundColor: CoconutColors.gray900,
        child: _SelectedUtxosPreviewBottomSheetBody(
          utxos: candidateUtxos,
          currentUnit: currentUnit,
          reusedAddresses: reusedAddresses,
          mergeCriteria: _currentMergeCriteria,
          amountCriteriaText: _currentAmountCriteriaText,
          selectedTagInlineWidgets:
              _currentMergeCriteria == UtxoMergeCriteria.sameTag ? _buildSelectedTagInlineWidgets(context) : const [],
          isEditingListenable: isEditingNotifier,
          initialSelectedUtxoIds: initialSelectedUtxoIds,
          onSelectionChanged: (selectedUtxoIds) {
            draftSelectedUtxoIdsNotifier.value = Set<String>.from(selectedUtxoIds);
          },
        ),
      );
    } finally {
      isEditingNotifier.dispose();
      draftSelectedUtxoIdsNotifier.dispose();
    }
  }

  UtxoMergeCriteria get _defaultMergeCriteria => _viewModel.defaultMergeCriteria;
  UtxoMergeCriteria get _currentMergeCriteria => _viewModel.currentMergeCriteria;
  String get _currentMergeCriteriaText => _mergeCriteriaText(_currentMergeCriteria);
  String _mergeCriteriaText(UtxoMergeCriteria criteria) {
    switch (criteria) {
      case UtxoMergeCriteria.smallAmounts:
        return t.merge_utxos_screen.merge_criteria_bottomsheet.merge_small_amounts;
      case UtxoMergeCriteria.sameTag:
        return t.merge_utxos_screen.merge_criteria_bottomsheet.merge_same_tag;
      case UtxoMergeCriteria.sameAddress:
        return t.merge_utxos_screen.merge_criteria_bottomsheet.merge_same_address;
    }
  }

  UtxoAmountCriteria get _defaultAmountCriteria => _viewModel.defaultAmountCriteria;
  UtxoAmountCriteria get _currentAmountCriteria => _viewModel.currentAmountCriteria;
  String get _currentAmountCriteriaText => _amountCriteriaText(_currentAmountCriteria);
  String _amountCriteriaText(UtxoAmountCriteria criteria) {
    switch (criteria) {
      case UtxoAmountCriteria.below001:
        return t.merge_utxos_screen.amount_criteria_bottomsheet.below_001;
      case UtxoAmountCriteria.below0001:
        return t.merge_utxos_screen.amount_criteria_bottomsheet.below_0001;
      case UtxoAmountCriteria.below00001:
        return t.merge_utxos_screen.amount_criteria_bottomsheet.below_00001;
      case UtxoAmountCriteria.custom:
        if (_viewModel.customAmountCriteriaText != null && _viewModel.customAmountCriteriaText!.isNotEmpty) {
          return '${_formatCustomAmountText(_viewModel.customAmountCriteriaText!)} ${t.btc} ${_viewModel.isCustomAmountLessThan ? t.merge_utxos_screen.amount_criteria_bottomsheet.less_than : t.merge_utxos_screen.amount_criteria_bottomsheet.or_less}';
        }
        return t.merge_utxos_screen.amount_criteria_bottomsheet.custom;
    }
  }

  String _formatCustomAmountText(String value) {
    final parts = value.split('.');
    if (parts.length != 2) return value;

    final integerPart = parts.first;
    final decimalPart = parts.last;
    if (decimalPart.isEmpty) return value;

    final chunks = <String>[];
    for (var i = 0; i < decimalPart.length; i += 4) {
      final end = (i + 4) > decimalPart.length ? decimalPart.length : i + 4;
      chunks.add(decimalPart.substring(i, end));
    }

    return '$integerPart.${chunks.join(' ')}';
  }

  String? _amountCriteriaDescription(UtxoAmountCriteria criteria) {
    switch (criteria) {
      case UtxoAmountCriteria.below001:
        return t.merge_utxos_screen.amount_criteria_bottomsheet.below_001_description;
      case UtxoAmountCriteria.below0001:
        return t.merge_utxos_screen.amount_criteria_bottomsheet.below_0001_description;
      case UtxoAmountCriteria.below00001:
        return t.merge_utxos_screen.amount_criteria_bottomsheet.below_00001_description;
      case UtxoAmountCriteria.custom:
        return null;
    }
  }

  List<UtxoAmountCriteria> get _recommendedAmountCriteriaItems => MergeUtxosViewModel.recommendedAmountCriteriaItems;
  UtxoAmountCriteria? get _firstAvailableRecommendedAmountCriteria =>
      _viewModel.firstAvailableRecommendedAmountCriteria;

  Widget _buildVisibleOptionPickers(BuildContext context) {
    final pickerWidgets =
        _viewModel.visibleOptionPickerSteps.indexed.map((entry) {
          final index = entry.$1;
          final step = entry.$2;
          final picker = _buildStepOptionPicker(context, step);
          final isNewest = step == _viewModel.displayedOptionPickerStep && index == 0;

          if (isNewest) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: picker.slideUpAnimation(
                key: ValueKey('merge-picker-in-${step.name}-${_viewModel.optionPickerAnimationNonce}'),
                duration: _optionPickerAnimationDuration,
                delay: const Duration(milliseconds: 1500),
                offset: const Offset(0, 24),
                onCompleted: () => _scheduleBottomSheetOpen(step),
              ),
            );
          }

          return Padding(padding: EdgeInsets.only(bottom: index == 0 ? 0 : 40), child: picker);
        }).toList();

    if (_viewModel.currentStep == UtxoMergeStep.selectReceiveAddress) {
      pickerWidgets.add(Padding(padding: const EdgeInsets.only(bottom: 40), child: _buildEstimatedFeeOptionPicker()));
    }

    return AnimatedSize(
      duration: _optionPickerAnimationDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(children: pickerWidgets),
    );
  }

  Widget _buildStepOptionPicker(BuildContext context, UtxoMergeStep step) {
    return switch (step) {
      UtxoMergeStep.selectMergeCriteria => CoconutOptionPicker(
        text: _currentMergeCriteriaText,
        label: _viewModel.currentStep == UtxoMergeStep.selectMergeCriteria ? null : t.merge_utxos_screen.merge_criteria,
        onTap: _viewModel.isBottomSheetOpen ? null : () => _showMergeCriteriaBottomSheet(context),
      ),
      UtxoMergeStep.selectAmountCriteria => CoconutOptionPicker(
        text: _currentAmountCriteriaText,
        label:
            _viewModel.currentStep == UtxoMergeStep.selectAmountCriteria ? null : t.merge_utxos_screen.amount_criteria,
        onTap: _viewModel.isBottomSheetOpen ? null : () => _showAmountCriteriaBottomSheet(context),
        coconutOptionStateEnum:
            _viewModel.hasDustUtxosInCurrentCandidates && !_viewModel.excludeDustUtxos
                ? CoconutOptionStateEnum.warning
                : CoconutOptionStateEnum.normal,
        guideText: _viewModel.hasDustUtxosInCurrentCandidates ? t.merge_utxos_screen.dust_warning : null,
        subWidget: _viewModel.hasDustUtxosInCurrentCandidates ? _buildDustWarningToggleCompact() : null,
      ),
      UtxoMergeStep.selectTag => CoconutOptionPicker(
        text: _effectiveSelectedTagName == null ? t.merge_utxos_screen.select_tag : '',
        label: _viewModel.currentStep == UtxoMergeStep.selectTag ? null : t.merge_utxos_screen.select_tag,
        onTap: _viewModel.isBottomSheetOpen ? null : () => _showTagSelectBottomSheet(context),
        inlineWidgets: _buildSelectedTagInlineWidgets(context),
        inlineSpacing: 0,
      ),
      UtxoMergeStep.selectReceiveAddress => CoconutOptionPicker(
        inlineWidgets: [_buildReceiveAddressOptionText()],
        label: t.merge_utxos_screen.receive_address,
        onTap: _viewModel.isBottomSheetOpen ? null : () => _showReceiveAddressBottomSheet(context),
        enableTextWrap: true,
        coconutOptionStateEnum:
            _isDirectInputReceiveAddressWarning ? CoconutOptionStateEnum.error : CoconutOptionStateEnum.normal,
        guideText:
            _isDirectInputReceiveAddressWarning
                ? t.merge_utxos_screen.receive_address_bottomsheet.not_your_owned_wallet
                : null,
      ),
      _ => const SizedBox.shrink(),
    };
  }

  bool get _isDirectInputReceiveAddressWarning {
    return _viewModel.customReceiveAddressText != null &&
        _viewModel.selectedReceiveAddress == _viewModel.customReceiveAddressText &&
        _viewModel.isCustomReceiveAddressValidFormat &&
        !_viewModel.isCustomReceiveAddressOwnedByAnyWallet;
  }

  Widget _buildReceiveAddressOptionText() {
    final address = _viewModel.selectedReceiveAddress ?? '';
    final baseStyle = CoconutTypography.body1_16_Number.setColor(CoconutColors.white);
    final boldStyle = CoconutTypography.body1_16_NumberBold.setColor(CoconutColors.white);

    return _buildHighlightedSegwitAddressText(address: address, baseStyle: baseStyle, highlightedStyle: boldStyle);
  }

  Widget _buildHighlightedSegwitAddressText({
    required String address,
    required TextStyle baseStyle,
    required TextStyle highlightedStyle,
  }) {
    if (address.isEmpty) {
      return Text('', style: baseStyle);
    }

    final bech32SeparatorIndex = address.indexOf('1');
    final highlightStart =
        bech32SeparatorIndex >= 0 && bech32SeparatorIndex + 2 < address.length ? bech32SeparatorIndex + 2 : 0;
    final firstBoldEnd = (highlightStart + 4).clamp(0, address.length);
    final lastBoldStart = address.length > 4 ? address.length - 4 : 0;

    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          if (highlightStart > 0) TextSpan(text: address.substring(0, highlightStart)),
          if (firstBoldEnd > highlightStart)
            TextSpan(text: address.substring(highlightStart, firstBoldEnd), style: highlightedStyle),
          if (lastBoldStart > firstBoldEnd) TextSpan(text: address.substring(firstBoldEnd, lastBoldStart)),
          if (lastBoldStart < address.length) TextSpan(text: address.substring(lastBoldStart), style: highlightedStyle),
        ],
      ),
      softWrap: true,
    );
  }

  Widget _buildEstimatedFeeOptionPicker() {
    final shouldShowFeeRatePlaceholder =
        _viewModel.needsManualFeeRateInput && _viewModel.feeRateController.text.trim().isEmpty;

    return CoconutOptionPicker(
      text: shouldShowFeeRatePlaceholder ? t.merge_utxos_screen.fee_rate_input_placeholder : _estimatedMergeFeeText,
      label: t.estimated_fee,
      textColor: shouldShowFeeRatePlaceholder ? CoconutColors.gray500 : CoconutColors.white,
      onTap: _showEstimatedFeeBottomSheet,
    );
  }

  void _showEstimatedFeeBottomSheet() {
    unawaited(_viewModel.refreshRecommendedFees());
    EstimatedFeeBottomSheet.show(
      context: context,
      listenable: _viewModel,
      estimatedFeeTextGetter: () => _viewModel.estimatedFeeText,
      feeRateController: _viewModel.feeRateController,
      feeRateFocusNode: _viewModel.feeRateFocusNode,
      onFeeRateChanged: (text) {
        final isTooLow = _viewModel.onFeeRateChanged(text);
        final currentText = _viewModel.feeRateController.text.trim();
        if (mounted) {
          setState(() {
            _viewModel.setNeedsManualFeeRateInput(currentText.isEmpty ? _viewModel.needsManualFeeRateInput : false);
          });
        }
        if (currentText.isNotEmpty && !currentText.endsWith('.')) {
          unawaited(_calculateEstimatedMergeFee());
        }
        return isTooLow;
      },
      onEditingComplete: () {
        _viewModel.removeTrailingDotInFeeRate();
        unawaited(_calculateEstimatedMergeFee());
        FocusScope.of(context).unfocus();
        Navigator.pop(context);
      },
      recommendedFeeFetchStatusGetter: () => _viewModel.recommendedFeeFetchStatus,
      feeInfosGetter: () => _viewModel.feeInfos,
      refreshRecommendedFees: _viewModel.refreshRecommendedFees,
      onFeeRateSelected: (sats) {
        _viewModel.setFeeRateFromRecommendation(sats);
        if (mounted) {
          setState(() {
            _viewModel.setNeedsManualFeeRateInput(false);
          });
        }
        unawaited(_calculateEstimatedMergeFee());
        FocusScope.of(context).unfocus();
        Navigator.pop(context);
      },
    );
  }
}
