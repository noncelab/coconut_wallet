import 'dart:async';

import 'package:coconut_lib/coconut_lib.dart';
import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/fiat_enums.dart';
import 'package:coconut_wallet/enums/utxo_merge_enums.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_state.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/merge_utxos/merge_utxos_view_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/providers/wallet_provider.dart';
import 'package:coconut_wallet/core/transaction/transaction_builder.dart';
import 'package:coconut_wallet/model/wallet/wallet_address.dart';
import 'package:coconut_wallet/services/fee_service.dart';
import 'package:coconut_wallet/screens/send/refactor/send_screen.dart';
import 'package:coconut_wallet/screens/wallet_detail/utxo_overview/utxo_bucket_card_row.dart';
import 'package:coconut_wallet/utils/address_util.dart';
import 'package:coconut_wallet/utils/address_scan_util.dart';
import 'package:coconut_wallet/utils/balance_format_util.dart';
import 'package:coconut_wallet/utils/datetime_util.dart';
import 'package:coconut_wallet/utils/text_field_filter_util.dart';
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
import 'package:shimmer/shimmer.dart';

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
  UtxoMergeCriteria? _selectedMergeCriteria;
  bool _didConfirmMergeCriteria = false;
  bool _isBottomSheetOpen = false;

  UtxoAmountCriteria? _selectedAmountCriteria;
  String? _customAmountCriteriaText;
  bool _isCustomAmountLessThan = false;
  bool _didConfirmAmountCriteria = false;
  String? _selectedReceiveAddress;
  String? _customReceiveAddressText;
  bool _isCustomReceiveAddressValidFormat = false;
  bool _isCustomReceiveAddressOwnedByAnyWallet = false;
  Set<String>? _editedSelectedUtxoIds;
  int? _estimatedMergeFeeSats;
  bool _isEstimatedMergeFeeLoading = false;
  UtxoMergeStep? _displayedHeaderStep;
  UtxoMergeStep? _pendingHeaderStep;
  UtxoMergeStep? _lastObservedHeaderStep;
  bool _isHeaderFadingOut = false;
  int _headerAnimationNonce = 0;
  UtxoMergeStep? _displayedOptionPickerStep;
  UtxoMergeStep? _pendingOptionPickerStep;
  UtxoMergeStep? _lastObservedOptionPickerStep;
  int _optionPickerAnimationNonce = 0;
  final List<UtxoMergeStep> _visibleOptionPickerSteps = [];
  late final AnimationController _receiveAddressSummaryLottieController;
  Timer? _receiveAddressSummaryTimer;
  bool _showReceiveAddressSummaryText = false;
  int _receiveAddressSummaryAnimationNonce = 0;
  bool _isAmountTextHighlighted = false;

  @override
  void initState() {
    super.initState();
    _receiveAddressSummaryLottieController = AnimationController(vsync: this, duration: const Duration(seconds: 1));
    _viewModel = MergeUtxosViewModel(widget.id, context.read<UtxoRepository>(), context.read<UtxoTagProvider>())
      ..initialize();
    _selectedReceiveAddress = context.read<WalletProvider>().getReceiveAddress(widget.id).address;
  }

  @override
  void dispose() {
    _receiveAddressSummaryTimer?.cancel();
    _receiveAddressSummaryLottieController.dispose();
    _viewModel.dispose();
    super.dispose();
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
    final showMergeBottomButton = _viewModel.currentStep == UtxoMergeStep.selectReceiveAddress;

    return Stack(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(16, 16, 16, showMergeBottomButton ? 132 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildAnimatedHeader(), CoconutLayout.spacing_1000h, _buildVisibleOptionPickers(context)],
          ),
        ),
        if (showMergeBottomButton)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 120,
              child: FixedBottomButton(
                onButtonClicked: () {},
                isActive: _showReceiveAddressSummaryText,
                text: '정리하기',
                backgroundColor: CoconutColors.white,
              ),
            ),
          ),
      ],
    );
  }

  void _scheduleHeaderAnimation(UtxoMergeStep step) {
    if (!_isAnimatedHeaderStep(step) || _lastObservedHeaderStep == step) return;
    _lastObservedHeaderStep = step;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncHeaderAnimation(step);
    });
  }

  void _scheduleOptionPickerAnimation(UtxoMergeStep step) {
    if (!_isAnimatedHeaderStep(step) || _lastObservedOptionPickerStep == step) return;
    _lastObservedOptionPickerStep = step;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncOptionPickerAnimation(step);
    });
  }

  void _refreshAnimationsForCurrentStep() {
    final step = _viewModel.currentStep;
    _lastObservedHeaderStep = null;
    _lastObservedOptionPickerStep = null;
    _scheduleHeaderAnimation(step);
    _scheduleOptionPickerAnimation(step);
  }

  void _syncHeaderAnimation(UtxoMergeStep step) {
    if (!_isAnimatedHeaderStep(step)) return;
    _handleReceiveAddressSummaryAnimation(step);

    _pendingHeaderStep = step;

    if (_displayedHeaderStep == null) {
      setState(() {
        _displayedHeaderStep = step;
        _isHeaderFadingOut = false;
      });
      return;
    }

    if (_displayedHeaderStep == step && !_isHeaderFadingOut) {
      return;
    }

    if (_isHeaderFadingOut) {
      return;
    }

    final token = ++_headerAnimationNonce;
    setState(() {
      _isHeaderFadingOut = true;
    });

    Future.delayed(_headerAnimationDuration, () {
      if (!mounted || token != _headerAnimationNonce) return;

      setState(() {
        _displayedHeaderStep = _pendingHeaderStep;
        _isHeaderFadingOut = false;
      });
    });
  }

  void _handleReceiveAddressSummaryAnimation(UtxoMergeStep step) {
    _receiveAddressSummaryTimer?.cancel();

    if (step != UtxoMergeStep.selectReceiveAddress) {
      _receiveAddressSummaryLottieController.stop();
      _receiveAddressSummaryLottieController.reset();
      _showReceiveAddressSummaryText = false;
      return;
    }

    final nonce = ++_receiveAddressSummaryAnimationNonce;
    _receiveAddressSummaryLottieController
      ..stop()
      ..reset()
      ..repeat(period: const Duration(seconds: 1));

    if (_showReceiveAddressSummaryText) {
      setState(() {
        _showReceiveAddressSummaryText = false;
      });
    }

    _receiveAddressSummaryTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted || nonce != _receiveAddressSummaryAnimationNonce) return;

      _receiveAddressSummaryLottieController
        ..stop()
        ..value = 1;

      setState(() {
        _showReceiveAddressSummaryText = true;
      });
    });
  }

  void _syncOptionPickerAnimation(UtxoMergeStep step) {
    if (!_isAnimatedHeaderStep(step)) return;

    _pendingOptionPickerStep = step;
    final nextVisibleSteps = _visibleOptionPickerStepsFor(step);

    if (_displayedOptionPickerStep == null) {
      setState(() {
        _displayedOptionPickerStep = step;
        _visibleOptionPickerSteps
          ..clear()
          ..addAll(nextVisibleSteps);
      });
      return;
    }

    if (_displayedOptionPickerStep == step && listEquals(_visibleOptionPickerSteps, nextVisibleSteps)) {
      return;
    }

    ++_optionPickerAnimationNonce;
    setState(() {
      _displayedOptionPickerStep = _pendingOptionPickerStep;
      _visibleOptionPickerSteps
        ..clear()
        ..addAll(nextVisibleSteps);
    });
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
        if (!_didConfirmMergeCriteria) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isBottomSheetOpen) {
              _showMergeCriteriaBottomSheet(context);
            }
          });
        }
        break;
      case UtxoMergeStep.selectAmountCriteria:
        if (!_didConfirmAmountCriteria) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isBottomSheetOpen) {
              _showAmountCriteriaBottomSheet(context);
            }
          });
        }
        break;
      case UtxoMergeStep.selectReceiveAddress:
        if (!_didConfirmAmountCriteria) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isBottomSheetOpen) {
              _showReceiveAddressBottomSheet(context);
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
    final step = _displayedHeaderStep;

    if (step == null) {
      return const SizedBox.shrink();
    }

    if (step == UtxoMergeStep.selectReceiveAddress) {
      final summaryCard = _buildReceiveAddressSummaryCard();

      if (_isHeaderFadingOut) {
        return summaryCard.fadeOutAnimation(
          key: ValueKey('merge-header-out-${step.name}-$_headerAnimationNonce'),
          duration: const Duration(milliseconds: 100),
        );
      }

      return summaryCard.fadeInAnimation(
        key: ValueKey('merge-header-in-${step.name}-$_headerAnimationNonce'),
        duration: _headerAnimationDuration,
        delay: const Duration(milliseconds: 300),
      );
    }

    final text = _headerTextForStep(step);
    if (text == null) {
      return const SizedBox.shrink();
    }

    if (_isHeaderFadingOut) {
      return text.characterFadeOutAnimation(
        key: ValueKey('merge-header-out-${step.name}-$_headerAnimationNonce'),
        textStyle: CoconutTypography.heading4_18_Bold,
        duration: const Duration(milliseconds: 100),
        slideDirection: CoconutCharacterFadeSlideDirection.slideUp,
      );
    }

    return text.characterFadeInAnimation(
      key: ValueKey('merge-header-in-${step.name}-$_headerAnimationNonce'),
      textStyle: CoconutTypography.heading4_18_Bold,
      duration: _headerAnimationDuration,
      delay: const Duration(milliseconds: 300),
      slideDirection: CoconutCharacterFadeSlideDirection.slideDown,
    );
  }

  Widget _buildReceiveAddressSummaryCard() {
    final amountText = _currentAmountCriteriaText;
    final utxoCount = _selectedUtxosForCurrentAmountCriteria.length;

    return Container(
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
                if (_displayedHeaderStep == UtxoMergeStep.selectReceiveAddress) {
                  if (_showReceiveAddressSummaryText) {
                    _receiveAddressSummaryLottieController.value = 1;
                  } else if (!_receiveAddressSummaryLottieController.isAnimating) {
                    _receiveAddressSummaryLottieController.repeat(
                      period: _receiveAddressSummaryLottieController.duration ?? composition.duration,
                    );
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
                    _showReceiveAddressSummaryText
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
                                text: '\n${t.merge_utxos_screen.receive_address_summary_count(count: utxoCount)}',
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
                              TextSpan(text: t.merge_utxos_screen.receive_address_summary),
                            ],
                          ),
                        ).fadeInAnimation(
                          key: ValueKey('receive-address-summary-text-fade-$_receiveAddressSummaryAnimationNonce'),
                          duration: const Duration(milliseconds: 260),
                        )
                        : _buildReceiveAddressSummarySkeleton(),
              ),
            ),
          ),
        ],
      ),
    );
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

  List<UtxoState> get _candidateUtxosForCurrentAmountCriteria {
    final utxos = _viewModel.utxoList.where((utxo) => !utxo.isLocked).toList();
    switch (_currentMergeCriteria) {
      case UtxoMergeCriteria.smallAmounts:
        final int? satsThreshold = switch (_currentAmountCriteria) {
          UtxoAmountCriteria.below001 => 1_000_000,
          UtxoAmountCriteria.below0001 => 100_000,
          UtxoAmountCriteria.below00001 => 10_000,
          UtxoAmountCriteria.custom => () {
            if (_customAmountCriteriaText == null || _customAmountCriteriaText!.trim().isEmpty) {
              return null;
            }
            try {
              return UnitUtil.convertBitcoinToSatoshi(double.parse(_customAmountCriteriaText!.trim()));
            } catch (_) {
              return null;
            }
          }(),
        };

        return utxos.where((utxo) {
          if (satsThreshold == null) return false;
          return _isCustomAmountLessThan ? utxo.amount < satsThreshold : utxo.amount <= satsThreshold;
        }).toList();
      case UtxoMergeCriteria.sameAddress:
        final addressCounts = <String, int>{};
        for (final utxo in utxos) {
          addressCounts[utxo.to] = (addressCounts[utxo.to] ?? 0) + 1;
        }
        return utxos.where((utxo) => (addressCounts[utxo.to] ?? 0) >= 2).toList();
      case UtxoMergeCriteria.sameTag:
        final duplicatedTagNames = <String>{};
        final tagCounts = <String, int>{};
        for (final utxo in utxos) {
          final uniqueTagNames = (utxo.tags ?? []).map((tag) => tag.name).toSet();
          for (final tagName in uniqueTagNames) {
            final nextCount = (tagCounts[tagName] ?? 0) + 1;
            tagCounts[tagName] = nextCount;
            if (nextCount >= 2) {
              duplicatedTagNames.add(tagName);
            }
          }
        }
        return utxos.where((utxo) {
          final tagNames = (utxo.tags ?? []).map((tag) => tag.name);
          return tagNames.any(duplicatedTagNames.contains);
        }).toList();
    }
  }

  List<UtxoState> get _selectedUtxosForCurrentAmountCriteria {
    final candidateUtxos = _candidateUtxosForCurrentAmountCriteria;
    final editedSelectedUtxoIds = _editedSelectedUtxoIds;
    if (editedSelectedUtxoIds == null) return candidateUtxos;
    return candidateUtxos.where((utxo) => editedSelectedUtxoIds.contains(utxo.utxoId)).toList();
  }

  String get _estimatedMergeFeeText {
    if (_isEstimatedMergeFeeLoading) return '...';
    if (_estimatedMergeFeeSats == null) return '-';
    return '${BalanceFormatUtil.formatSatoshiToReadableBitcoin(_estimatedMergeFeeSats!, forceEightDecimals: true)} BTC';
  }

  void _syncEstimatedFeeTextToViewModel() {
    _viewModel.setEstimatedFeeText(_estimatedMergeFeeText);
  }

  Future<void> _calculateEstimatedMergeFee() async {
    final selectedReceiveAddress = _selectedReceiveAddress;
    final selectedUtxos = _selectedUtxosForCurrentAmountCriteria;

    if (_viewModel.currentStep != UtxoMergeStep.selectReceiveAddress ||
        selectedReceiveAddress == null ||
        selectedReceiveAddress.isEmpty ||
        selectedUtxos.isEmpty) {
      if (!mounted) return;
      setState(() {
        _estimatedMergeFeeSats = null;
        _isEstimatedMergeFeeLoading = false;
      });
      _syncEstimatedFeeTextToViewModel();
      return;
    }

    setState(() {
      _isEstimatedMergeFeeLoading = true;
    });

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

      if (!mounted) return;
      setState(() {
        _estimatedMergeFeeSats =
            txBuildResult.isSuccess ? txBuildResult.estimatedFee - (txBuildResult.unintendedDustFee ?? 0) : null;
        _isEstimatedMergeFeeLoading = false;
      });
      _syncEstimatedFeeTextToViewModel();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _estimatedMergeFeeSats = null;
        _isEstimatedMergeFeeLoading = false;
      });
      _syncEstimatedFeeTextToViewModel();
    }
  }

  Set<String> get _reusedAddressesInWallet {
    final counts = <String, int>{};
    for (final utxo in _viewModel.utxoList) {
      counts[utxo.to] = (counts[utxo.to] ?? 0) + 1;
    }
    return counts.entries.where((entry) => entry.value >= 2).map((entry) => entry.key).toSet();
  }

  Future<void> _showSelectedUtxosPreviewBottomSheet() async {
    final candidateUtxos = _candidateUtxosForCurrentAmountCriteria;
    const currentUnit = BitcoinUnit.btc;
    final reusedAddresses = _reusedAddressesInWallet;
    final isEditingNotifier = ValueNotifier(false);
    final draftSelectedUtxoIdsNotifier = ValueNotifier<Set<String>>(
      _editedSelectedUtxoIds ?? candidateUtxos.map((utxo) => utxo.utxoId).toSet(),
    );

    try {
      await CommonBottomSheets.showBottomSheet<void>(
        title: _currentAmountCriteriaText,
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
                      setState(() {
                        _editedSelectedUtxoIds = Set<String>.from(draftSelectedUtxoIdsNotifier.value);
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
          isEditingListenable: isEditingNotifier,
          initialSelectedUtxoIds: _editedSelectedUtxoIds ?? candidateUtxos.map((utxo) => utxo.utxoId).toSet(),
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

  UtxoMergeCriteria get _defaultMergeCriteria => UtxoMergeCriteria.smallAmounts;
  UtxoMergeCriteria get _currentMergeCriteria => _selectedMergeCriteria ?? _defaultMergeCriteria;
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

  UtxoAmountCriteria get _defaultAmountCriteria => UtxoAmountCriteria.below0001; // TODO: default 기준 금액 선정 로직 추가
  UtxoAmountCriteria get _currentAmountCriteria => _selectedAmountCriteria ?? _defaultAmountCriteria;
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
        if (_customAmountCriteriaText != null && _customAmountCriteriaText!.isNotEmpty) {
          return '${_formatCustomAmountText(_customAmountCriteriaText!)} ${t.btc} ${_isCustomAmountLessThan ? t.merge_utxos_screen.amount_criteria_bottomsheet.less_than : t.merge_utxos_screen.amount_criteria_bottomsheet.or_less}';
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

  Widget _buildVisibleOptionPickers(BuildContext context) {
    final pickerWidgets =
        _visibleOptionPickerSteps.indexed.map((entry) {
          final index = entry.$1;
          final step = entry.$2;
          final picker = _buildStepOptionPicker(context, step);
          final isNewest = step == _displayedOptionPickerStep && index == 0;

          if (isNewest) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: picker.slideUpAnimation(
                key: ValueKey('merge-picker-in-${step.name}-$_optionPickerAnimationNonce'),
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
        onTap: _isBottomSheetOpen ? null : () => _showMergeCriteriaBottomSheet(context),
      ),
      UtxoMergeStep.selectAmountCriteria => CoconutOptionPicker(
        text: _currentAmountCriteriaText,
        label:
            _viewModel.currentStep == UtxoMergeStep.selectAmountCriteria ? null : t.merge_utxos_screen.amount_criteria,
        onTap: _isBottomSheetOpen ? null : () => _showAmountCriteriaBottomSheet(context),
      ),
      UtxoMergeStep.selectTag => CoconutOptionPicker(text: t.merge_utxos_screen.select_tag, onTap: () {}),
      UtxoMergeStep.selectReceiveAddress => CoconutOptionPicker(
        inlineWidgets: [_buildReceiveAddressOptionText()],
        label: t.merge_utxos_screen.receive_address,
        onTap: _isBottomSheetOpen ? null : () => _showReceiveAddressBottomSheet(context),
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
    return _customReceiveAddressText != null &&
        _selectedReceiveAddress == _customReceiveAddressText &&
        _isCustomReceiveAddressValidFormat &&
        !_isCustomReceiveAddressOwnedByAnyWallet;
  }

  Widget _buildReceiveAddressOptionText() {
    final address = _selectedReceiveAddress ?? '';
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
    return CoconutOptionPicker(
      text: _estimatedMergeFeeText,
      label: t.estimated_fee,
      onTap: () {
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
            unawaited(_calculateEstimatedMergeFee());
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
          },
        );
      },
    );
  }

  UtxoMergeStep? _nextStepForMergeCriteria(UtxoMergeCriteria mergeCriteria) {
    switch (mergeCriteria) {
      case UtxoMergeCriteria.smallAmounts:
        return UtxoMergeStep.selectAmountCriteria;
      case UtxoMergeCriteria.sameTag:
        return UtxoMergeStep.selectTag;
      case UtxoMergeCriteria.sameAddress:
        return UtxoMergeStep.selectReceiveAddress;
    }
  }

  void _showMergeCriteriaBottomSheet(BuildContext context) async {
    if (_isBottomSheetOpen) return;

    setState(() {
      _isBottomSheetOpen = true;
    });

    final selectedItem = await CommonBottomSheets.showBottomSheet<UtxoMergeCriteria>(
      showCloseButton: true,
      context: context,
      backgroundColor: CoconutColors.gray900,
      title: t.merge_utxos_screen.merge_criteria_bottomsheet.title,
      child: SizedBox(
        height: 320,
        child: SelectableBottomSheetBody<UtxoMergeCriteria>(
          items: const [UtxoMergeCriteria.smallAmounts, UtxoMergeCriteria.sameTag, UtxoMergeCriteria.sameAddress],
          showGradient: false,
          initiallySelectedId: _currentMergeCriteria,
          getItemId: (item) => item,
          confirmText: t.complete,
          backgroundColor: CoconutColors.gray900,
          itemBuilder: (context, item, isSelected, onTap) {
            final isTagMergeItem = item == UtxoMergeCriteria.sameTag;
            final isAddressMergeItem = item == UtxoMergeCriteria.sameAddress;
            final isDisabled =
                (isTagMergeItem && !_viewModel.hasMergeableTaggedUtxos) ||
                (isAddressMergeItem && !_viewModel.hasSameAddressUtxos);

            return SelectableBottomSheetTextItem(
              isSelected: isSelected,
              onTap: onTap,
              isDisabled: isDisabled,
              child: Text(
                _mergeCriteriaText(item),
                style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
              ),
            );
          },
        ),
      ),
    );

    if (selectedItem != null && context.mounted) {
      final nextStep = _nextStepForMergeCriteria(selectedItem);
      final previousMergeCriteria = _selectedMergeCriteria;
      final didMergeCriteriaChange = previousMergeCriteria != selectedItem;

      setState(() {
        _selectedMergeCriteria = selectedItem;
        _didConfirmMergeCriteria = true;
        if (didMergeCriteriaChange) {
          switch (selectedItem) {
            case UtxoMergeCriteria.smallAmounts:
              _didConfirmAmountCriteria = false;
              _editedSelectedUtxoIds = null;
              _estimatedMergeFeeSats = null;
              break;
            case UtxoMergeCriteria.sameTag:
              _editedSelectedUtxoIds = null;
              _estimatedMergeFeeSats = null;
              break;
            case UtxoMergeCriteria.sameAddress:
              _editedSelectedUtxoIds = null;
              _estimatedMergeFeeSats = null;
              break;
          }
        }
        _isBottomSheetOpen = false;
      });

      if (nextStep != null) {
        _viewModel.setCurrentStep(nextStep);
        _refreshAnimationsForCurrentStep();
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isBottomSheetOpen = false;
      });
    }
  }

  void _showAmountCriteriaBottomSheet(BuildContext context) async {
    if (_isBottomSheetOpen) return;

    setState(() {
      _isBottomSheetOpen = true;
    });

    final screenHeight = MediaQuery.sizeOf(context).height;
    final bodyHeight = (screenHeight * 0.9).clamp(340.0, 580.0);
    var selectedTabIndex = _currentAmountCriteria == UtxoAmountCriteria.custom ? 1 : 0;
    UtxoAmountCriteria? selectedRecommendedCriteria =
        [
              UtxoAmountCriteria.below001,
              UtxoAmountCriteria.below0001,
              UtxoAmountCriteria.below00001,
            ].contains(_currentAmountCriteria)
            ? _currentAmountCriteria
            : null;
    final customAmountController = TextEditingController(text: _customAmountCriteriaText ?? '');
    final customAmountFocusNode = FocusNode();
    var isCustomAmountLessThan = _isCustomAmountLessThan;

    if (selectedTabIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          customAmountFocusNode.requestFocus();
        }
      });
    }

    final selectedItem = await CommonBottomSheets.showBottomSheet<_AmountCriteriaSelectionResult>(
      showCloseButton: true,
      adjustForKeyboardInset: false,
      context: context,
      backgroundColor: CoconutColors.gray900,
      title: t.merge_utxos_screen.amount_criteria_bottomsheet.title,
      child: SizedBox(
        height: bodyHeight + 16,
        child: StatefulBuilder(
          builder: (context, modalSetState) {
            return _SegmentedBottomSheetBody(
              bodyHeight: bodyHeight,
              selectedTabIndex: selectedTabIndex,
              confirmText: t.complete,
              isConfirmEnabled:
                  selectedTabIndex == 0
                      ? selectedRecommendedCriteria != null
                      : customAmountController.text.trim().isNotEmpty &&
                          double.tryParse(customAmountController.text.trim()) != 0,
              onConfirm: () {
                if (selectedTabIndex == 0) {
                  if (selectedRecommendedCriteria == null) return;
                  Navigator.pop(context, _AmountCriteriaSelectionResult(criteria: selectedRecommendedCriteria!));
                  return;
                }

                if (customAmountController.text.trim().isEmpty) return;
                Navigator.pop(
                  context,
                  _AmountCriteriaSelectionResult(
                    criteria: UtxoAmountCriteria.custom,
                    customAmountText: customAmountController.text.trim(),
                    isLessThan: isCustomAmountLessThan,
                  ),
                );
              },
              onTabSelected: (index) {
                modalSetState(() {
                  selectedTabIndex = index;
                });
                if (index == 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      customAmountFocusNode.requestFocus();
                    }
                  });
                } else {
                  customAmountFocusNode.unfocus();
                }
              },
              tabs: [
                _BottomSheetTab(
                  label: t.merge_utxos_screen.amount_criteria_bottomsheet.recommendation_criteria,
                  child: _buildAmountCriteriaRecommendationTab(
                    selectedRecommendedCriteria: selectedRecommendedCriteria,
                    onSelectionChanged: (selected) {
                      modalSetState(() {
                        selectedRecommendedCriteria = selected;
                      });
                    },
                  ),
                ),
                _BottomSheetTab(
                  label: t.merge_utxos_screen.amount_criteria_bottomsheet.custom,
                  child: _buildCustomAmountTab(
                    controller: customAmountController,
                    focusNode: customAmountFocusNode,
                    isLessThan: isCustomAmountLessThan,
                    onAmountChanged: () {
                      modalSetState(() {});
                    },
                    onLessThanToggle: () {
                      modalSetState(() {
                        isCustomAmountLessThan = !isCustomAmountLessThan;
                      });
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    customAmountController.dispose();
    customAmountFocusNode.dispose();

    if (selectedItem != null && context.mounted) {
      const nextStep = UtxoMergeStep.selectReceiveAddress;

      setState(() {
        _selectedAmountCriteria = selectedItem.criteria;
        _customAmountCriteriaText = selectedItem.customAmountText;
        _isCustomAmountLessThan = selectedItem.isLessThan;
        _editedSelectedUtxoIds = null;
        _estimatedMergeFeeSats = null;
        _didConfirmAmountCriteria = true;
        _isBottomSheetOpen = false;
      });

      _viewModel.setCurrentStep(nextStep);
      unawaited(_calculateEstimatedMergeFee());
      return;
    }

    if (mounted) {
      setState(() {
        _isBottomSheetOpen = false;
      });
    }
  }

  void _showReceiveAddressBottomSheet(BuildContext context) async {
    if (_isBottomSheetOpen) return;

    setState(() {
      _isBottomSheetOpen = true;
    });

    final screenHeight = MediaQuery.sizeOf(context).height;
    final bodyHeight = (screenHeight * 0.9).clamp(340.0, 580.0);
    final isUsingDirectInput =
        _customReceiveAddressText != null && _selectedReceiveAddress == _customReceiveAddressText;
    var selectedTabIndex = isUsingDirectInput ? 1 : 0;
    String? selectedOwnedAddress = isUsingDirectInput ? null : _selectedReceiveAddress;
    final directInputController = TextEditingController(
      text: isUsingDirectInput ? (_customReceiveAddressText ?? '') : '',
    );
    final directInputFocusNode = FocusNode();
    _validateCustomReceiveAddress(directInputController.text);

    if (selectedTabIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          directInputFocusNode.requestFocus();
        }
      });
    }

    final selectedItem = await CommonBottomSheets.showBottomSheet<_ReceiveAddressSelectionResult>(
      showCloseButton: true,
      adjustForKeyboardInset: false,
      context: context,
      backgroundColor: CoconutColors.gray900,
      title: t.merge_utxos_screen.receive_address,
      child: SizedBox(
        height: bodyHeight + 16,
        child: StatefulBuilder(
          builder: (context, modalSetState) {
            return _SegmentedBottomSheetBody(
              bodyHeight: bodyHeight,
              selectedTabIndex: selectedTabIndex,
              confirmText: t.complete,
              confirmSubWidget:
                  selectedTabIndex == 1
                      ? _buildReceiveAddressValidationSubWidget(directInputController.text.trim())
                      : null,
              isConfirmEnabled:
                  selectedTabIndex == 0
                      ? selectedOwnedAddress != null
                      : directInputController.text.trim().isNotEmpty && _isCustomReceiveAddressValidFormat,
              onConfirm: () {
                if (selectedTabIndex == 0) {
                  if (selectedOwnedAddress == null) return;
                  Navigator.pop(
                    context,
                    _ReceiveAddressSelectionResult(address: selectedOwnedAddress!, isDirectInput: false),
                  );
                  return;
                }

                if (directInputController.text.trim().isEmpty || !_isCustomReceiveAddressValidFormat) return;
                Navigator.pop(
                  context,
                  _ReceiveAddressSelectionResult(
                    address: normalizeAddress(directInputController.text.trim()),
                    isDirectInput: true,
                  ),
                );
              },
              onTabSelected: (index) {
                modalSetState(() {
                  selectedTabIndex = index;
                });
                if (index == 1) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      directInputFocusNode.requestFocus();
                    }
                  });
                } else {
                  directInputFocusNode.unfocus();
                }
              },
              tabs: [
                _BottomSheetTab(
                  label: '내 주소',
                  child: _buildReceiveAddressOwnedTab(
                    addresses: _receiveAddresses,
                    selectedAddress: selectedOwnedAddress,
                    onSelectionChanged: (address) {
                      modalSetState(() {
                        selectedOwnedAddress = address;
                      });
                    },
                  ),
                ),
                _BottomSheetTab(
                  label: '직접 입력',
                  child: _buildReceiveAddressDirectInputTab(
                    controller: directInputController,
                    focusNode: directInputFocusNode,
                    onChanged: (value) {
                      modalSetState(() {
                        _validateCustomReceiveAddress(value);
                      });
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );

    directInputController.dispose();
    directInputFocusNode.dispose();

    if (selectedItem != null && context.mounted) {
      setState(() {
        _selectedReceiveAddress = selectedItem.address;
        _customReceiveAddressText = selectedItem.isDirectInput ? selectedItem.address : null;
        _isBottomSheetOpen = false;
      });
      unawaited(_calculateEstimatedMergeFee());
      return;
    }

    if (mounted) {
      setState(() {
        _isBottomSheetOpen = false;
      });
    }
  }

  void _validateCustomReceiveAddress(String rawAddress) {
    final trimmed = rawAddress.trim();
    _customReceiveAddressText = trimmed.isEmpty ? null : trimmed;

    if (trimmed.isEmpty) {
      _isCustomReceiveAddressValidFormat = false;
      _isCustomReceiveAddressOwnedByAnyWallet = false;
      return;
    }

    final normalized = normalizeAddress(trimmed);
    final walletProvider = context.read<WalletProvider>();

    try {
      _isCustomReceiveAddressValidFormat = WalletUtility.validateAddress(normalized);
      _isCustomReceiveAddressOwnedByAnyWallet =
          _isCustomReceiveAddressValidFormat && walletProvider.containsAddressInAnyWallet(normalized);
    } catch (_) {
      _isCustomReceiveAddressValidFormat = false;
      _isCustomReceiveAddressOwnedByAnyWallet = false;
    }
  }

  Widget? _buildReceiveAddressValidationSubWidget(String input) {
    if (input.isEmpty) return null;

    if (!_isCustomReceiveAddressValidFormat) {
      return Text(
        t.errors.address_error.invalid,
        style: CoconutTypography.body3_12.setColor(CoconutColors.hotPink),
        textAlign: TextAlign.center,
      );
    }

    if (!_isCustomReceiveAddressOwnedByAnyWallet) {
      return Text(
        t.merge_utxos_screen.receive_address_bottomsheet.not_your_owned_wallet,
        style: CoconutTypography.body3_12.setColor(CoconutColors.white),
        textAlign: TextAlign.center,
      );
    }

    return null;
  }

  Widget _buildReceiveAddressOwnedTab({
    required List<_ReceiveAddressOption> addresses,
    required String? selectedAddress,
    required ValueChanged<String?> onSelectionChanged,
  }) {
    return SelectableBottomSheetBody<_ReceiveAddressOption>(
      key: const ValueKey('owned-receive-address-list'),
      items: addresses,
      showGradient: false,
      showConfirmButton: false,
      initiallySelectedId: selectedAddress,
      getItemId: (item) => item.address,
      confirmText: t.complete,
      backgroundColor: CoconutColors.gray900,
      onSelectionChanged: (selected) {
        onSelectionChanged(selected?.address);
      },
      itemBuilder: (context, item, isSelected, onTap) {
        return SelectableBottomSheetTextItem(
          isSelected: isSelected,
          onTap: onTap,
          reserveCheckIconSpace: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.address, style: CoconutTypography.body2_14_NumberBold.setColor(CoconutColors.white)),
              Text(
                '${item.walletName} • ${item.derivationPath}',
                style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReceiveAddressDirectInputTab({
    required TextEditingController controller,
    required FocusNode focusNode,
    required ValueChanged<String> onChanged,
  }) {
    return SizedBox.expand(
      child: Container(
        key: const ValueKey('custom-receive-address'),
        color: CoconutColors.gray900,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CoconutTextField(
                controller: controller,
                focusNode: focusNode,
                backgroundColor: CoconutColors.black,
                height: 52,
                padding: const EdgeInsets.only(left: 16, right: 0),
                onChanged: onChanged,
                maxLines: 1,
                suffix: IconButton(
                  iconSize: 14,
                  padding: EdgeInsets.zero,
                  onPressed: () async {
                    if (controller.text.isEmpty) {
                      final scannedData = await showAddressScannerBottomSheet(context, title: t.send);
                      if (scannedData == null) return;
                      final normalized =
                          scannedData.startsWith('bitcoin:')
                              ? normalizeAddress(parseBip21Uri(scannedData).address)
                              : normalizeAddress(scannedData);
                      controller.text = normalized;
                      controller.selection = TextSelection.collapsed(offset: controller.text.length);
                      onChanged(normalized);
                      return;
                    }

                    controller.clear();
                    onChanged('');
                  },
                  icon:
                      controller.text.isEmpty
                          ? SvgPicture.asset('assets/svg/scan.svg')
                          : SvgPicture.asset(
                            'assets/svg/text-field-clear.svg',
                            colorFilter: ColorFilter.mode(
                              controller.text.isNotEmpty && !_isCustomReceiveAddressValidFormat
                                  ? CoconutColors.hotPink
                                  : CoconutColors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                ),
                placeholderText: t.send_screen.address_placeholder,
                isError: controller.text.isNotEmpty && !_isCustomReceiveAddressValidFormat,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_ReceiveAddressOption> get _receiveAddresses {
    final walletProvider = context.read<WalletProvider>();
    final seen = <String>{};

    return walletProvider.walletItemList
        .map((wallet) => (wallet: wallet, address: walletProvider.getReceiveAddress(wallet.id)))
        .where((entry) => seen.add(entry.address.address))
        .map((entry) => _ReceiveAddressOption.fromWalletAddress(entry.address, walletName: entry.wallet.name))
        .toList();
  }

  Widget _buildAmountCriteriaRecommendationTab({
    required UtxoAmountCriteria? selectedRecommendedCriteria,
    required ValueChanged<UtxoAmountCriteria?> onSelectionChanged,
  }) {
    return SelectableBottomSheetBody<UtxoAmountCriteria>(
      key: const ValueKey('recommended-amount-criteria'),
      items: const [UtxoAmountCriteria.below001, UtxoAmountCriteria.below0001, UtxoAmountCriteria.below00001],
      showGradient: false,
      showConfirmButton: false,
      initiallySelectedId: selectedRecommendedCriteria,
      getItemId: (item) => item,
      confirmText: t.complete,
      backgroundColor: CoconutColors.gray900,
      onSelectionChanged: onSelectionChanged,
      itemBuilder: (context, item, isSelected, onTap) {
        return SelectableBottomSheetTextItem(
          isSelected: isSelected,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_amountCriteriaText(item), style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)),
              if (_amountCriteriaDescription(item) != null)
                Text(
                  _amountCriteriaDescription(item)!,
                  style: CoconutTypography.body3_12.setColor(CoconutColors.gray400),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomAmountTab({
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isLessThan,
    required VoidCallback onAmountChanged,
    required VoidCallback onLessThanToggle,
  }) {
    return SizedBox.expand(
      child: Container(
        key: const ValueKey('custom-amount-criteria'),
        color: CoconutColors.gray900,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: CoconutTextField(
                      controller: controller,
                      focusNode: focusNode,
                      fontSize: 18,
                      style: CoconutTextFieldStyle.underline,
                      padding: const EdgeInsets.only(left: 5, right: 0, top: 16, bottom: 6),
                      onChanged: (_) => onAmountChanged(),
                      textInputType: const TextInputType.numberWithOptions(decimal: true),
                      textInputFormatter: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        SingleDotInputFormatter(),
                        const BtcAmountInputFormatter(),
                      ],
                      placeholderText: '',
                      suffix: Text(
                        t.btc,
                        style: CoconutTypography.heading4_18.copyWith(
                          color: CoconutColors.gray600,
                          height: 1.4,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: ShrinkAnimationButton(
                      onPressed: onLessThanToggle,
                      defaultColor: CoconutColors.gray800,
                      pressedColor: CoconutColors.gray700,
                      borderRadius: 8,
                      borderWidth: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Text(
                          isLessThan
                              ? t.merge_utxos_screen.amount_criteria_bottomsheet.less_than
                              : t.merge_utxos_screen.amount_criteria_bottomsheet.or_less,
                          style: CoconutTypography.body3_12_Bold.setColor(CoconutColors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentedBottomSheetBody extends StatelessWidget {
  final double bodyHeight;
  final int selectedTabIndex;
  final List<_BottomSheetTab> tabs;
  final String confirmText;
  final Widget? confirmSubWidget;
  final bool isConfirmEnabled;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onConfirm;

  const _SegmentedBottomSheetBody({
    required this.bodyHeight,
    required this.selectedTabIndex,
    required this.tabs,
    required this.confirmText,
    this.confirmSubWidget,
    required this.isConfirmEnabled,
    required this.onTabSelected,
    required this.onConfirm,
  });

  double _tabBodyHeight(BuildContext context) {
    return bodyHeight - 230;
  }

  @override
  Widget build(BuildContext context) {
    final tabBodyHeight = _tabBodyHeight(context);
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    const buttonBottomSpacing = 16.0;
    const confirmSubWidgetHeight = 32;
    final buttonAreaHeight =
        FixedBottomButton.fixedBottomButtonDefaultHeight +
        bottomSafeArea +
        buttonBottomSpacing +
        3 +
        (confirmSubWidget != null ? confirmSubWidgetHeight : 0);

    return SafeArea(
      top: false,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: buttonAreaHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: CoconutSegmentedControl(
                    labels: tabs.map((tab) => tab.label).toList(),
                    isSelected: List.generate(tabs.length, (index) => selectedTabIndex == index),
                    onPressed: onTabSelected,
                  ),
                ),
                CoconutLayout.spacing_400h,
                SizedBox(
                  height: tabBodyHeight - confirmSubWidgetHeight,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: [...previousChildren, if (currentChild != null) currentChild],
                      );
                    },
                    child: KeyedSubtree(key: ValueKey(selectedTabIndex), child: tabs[selectedTabIndex].child),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: keyboardInset + 2,
            child: SizedBox(
              height: buttonAreaHeight,
              child: FixedBottomButton(
                showGradient: false,
                isVisibleAboveKeyboard: false,
                bottomPadding: buttonBottomSpacing,
                subWidget: confirmSubWidget,
                onButtonClicked: onConfirm,
                isActive: isConfirmEnabled,
                text: confirmText,
                backgroundColor: CoconutColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedUtxosPreviewBottomSheetBody extends StatefulWidget {
  final List<UtxoState> utxos;
  final BitcoinUnit currentUnit;
  final Set<String> reusedAddresses;
  final ValueListenable<bool> isEditingListenable;
  final Set<String> initialSelectedUtxoIds;
  final ValueChanged<Set<String>> onSelectionChanged;

  const _SelectedUtxosPreviewBottomSheetBody({
    required this.utxos,
    required this.currentUnit,
    required this.reusedAddresses,
    required this.isEditingListenable,
    required this.initialSelectedUtxoIds,
    required this.onSelectionChanged,
  });

  @override
  State<_SelectedUtxosPreviewBottomSheetBody> createState() => _SelectedUtxosPreviewBottomSheetBodyState();
}

class _SelectedUtxosPreviewBottomSheetBodyState extends State<_SelectedUtxosPreviewBottomSheetBody> {
  static const int _columnCount = 4;
  static const double _coinSize = 72;

  late Set<String> _selectedUtxoIds;
  String? _expandedUtxoId;

  @override
  void initState() {
    super.initState();
    _selectedUtxoIds = Set<String>.from(widget.initialSelectedUtxoIds);
    widget.isEditingListenable.addListener(_handleEditingChanged);
  }

  @override
  void dispose() {
    widget.isEditingListenable.removeListener(_handleEditingChanged);
    super.dispose();
  }

  void _handleEditingChanged() {
    if (widget.isEditingListenable.value && _expandedUtxoId != null) {
      setState(() {
        _expandedUtxoId = null;
      });
      return;
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _handleUtxoTap(UtxoState utxo, bool isEditing) {
    setState(() {
      if (isEditing) {
        if (_selectedUtxoIds.contains(utxo.utxoId)) {
          _selectedUtxoIds.remove(utxo.utxoId);
        } else {
          _selectedUtxoIds.add(utxo.utxoId);
        }
        widget.onSelectionChanged(_selectedUtxoIds);
        return;
      }

      _expandedUtxoId = _expandedUtxoId == utxo.utxoId ? null : utxo.utxoId;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: SizedBox(
        height: (MediaQuery.sizeOf(context).height * 0.68).clamp(420.0, 720.0),
        child: ValueListenableBuilder<bool>(
          valueListenable: widget.isEditingListenable,
          builder: (context, isEditing, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: CoconutColors.gray800,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: CoconutColors.gray700, width: 1),
                    ),
                    child: Text(
                      t.merge_utxos_screen.used_utxos_count(total: widget.utxos.length, used: _selectedUtxoIds.length),
                      style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (int start = 0; start < widget.utxos.length; start += _columnCount) ...[
                          _buildUtxoRow(
                            widget.utxos.sublist(
                              start,
                              (start + _columnCount) > widget.utxos.length ? widget.utxos.length : start + _columnCount,
                            ),
                            isEditing,
                          ),
                          const SizedBox(height: 20),
                        ],
                        const SizedBox(height: 50),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildUtxoRow(List<UtxoState> rowUtxos, bool isEditing) {
    final expandedIndex = rowUtxos.indexWhere((utxo) => utxo.utxoId == _expandedUtxoId);
    final expandedUtxo = expandedIndex >= 0 ? rowUtxos[expandedIndex] : null;

    return Column(
      children: [
        Row(
          children: [
            for (int column = 0; column < _columnCount; column++)
              Expanded(
                child:
                    column < rowUtxos.length
                        ? Center(
                          child: AnimatedScale(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            scale: (!isEditing && expandedIndex == column) ? 1.08 : 1,
                            child: UtxoCoinCard(
                              utxo: rowUtxos[column],
                              size: _coinSize,
                              compact: true,
                              isFocused: isEditing || _selectedUtxoIds.contains(rowUtxos[column].utxoId),
                              isSelected: isEditing && _selectedUtxoIds.contains(rowUtxos[column].utxoId),
                              currentUnit: widget.currentUnit,
                              isAddressReused: false,
                              isSuspiciousDust: false,
                              showSelectedCheckIcon: false,
                              onTap: () => _handleUtxoTap(rowUtxos[column], isEditing),
                              dustThreshold: 294, // TODO: 임시 설정,
                            ),
                          ),
                        )
                        : const SizedBox.shrink(),
              ),
          ],
        ),
        if (!isEditing)
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child:
                expandedUtxo == null
                    ? const SizedBox.shrink()
                    : Padding(
                      padding: const EdgeInsets.only(top: 18),
                      child: _SelectedUtxoDetailCard(utxo: expandedUtxo, selectedColumnIndex: expandedIndex),
                    ),
          ),
      ],
    );
  }
}

class _SelectedUtxoDetailCard extends StatelessWidget {
  final UtxoState utxo;
  final int selectedColumnIndex;

  const _SelectedUtxoDetailCard({required this.utxo, required this.selectedColumnIndex});

  @override
  Widget build(BuildContext context) {
    final timestamp = DateTimeUtil.formatTimestamp(utxo.timestamp);

    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = constraints.maxWidth / _SelectedUtxosPreviewBottomSheetBodyState._columnCount;
        final arrowLeft = (slotWidth * selectedColumnIndex) + (slotWidth / 2) - 10;
        const arrowCutoutHalfWidth = 14.0;
        final arrowCenterX = arrowLeft + 10;
        final leftTopLineWidth = (arrowCenterX - arrowCutoutHalfWidth).clamp(0.0, constraints.maxWidth).toDouble();
        final rightTopLineLeft = (arrowCenterX + arrowCutoutHalfWidth).clamp(0.0, constraints.maxWidth).toDouble();
        final rightTopLineWidth = (constraints.maxWidth - rightTopLineLeft).clamp(0.0, constraints.maxWidth).toDouble();

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              decoration: BoxDecoration(
                color: CoconutColors.black,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: CoconutColors.gray800, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${timestamp[0]} | ${timestamp[1]}',
                    style: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray500),
                  ),
                  const SizedBox(height: 2),
                  _buildHighlightedSegwitAddressText(
                    address: utxo.to,
                    baseStyle: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray500),
                    highlightedStyle: CoconutTypography.body3_12_Number.setColor(CoconutColors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(utxo.derivationPath, style: CoconutTypography.body3_12.setColor(CoconutColors.gray500)),
                ],
              ),
            ),
            Positioned(
              top: -9.3,
              left: arrowLeft,
              child: Transform.rotate(
                angle: 0.78539816339,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: CoconutColors.black,
                    border: Border(
                      top: BorderSide(color: CoconutColors.gray800),
                      left: BorderSide(color: CoconutColors.gray800),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BottomSheetTab {
  final String label;
  final Widget child;

  const _BottomSheetTab({required this.label, required this.child});
}

class _ReceiveAddressOption {
  final String address;
  final String walletName;
  final String derivationPath;

  const _ReceiveAddressOption({required this.address, required this.walletName, required this.derivationPath});

  factory _ReceiveAddressOption.fromWalletAddress(WalletAddress walletAddress, {required String walletName}) {
    return _ReceiveAddressOption(
      address: walletAddress.address,
      walletName: walletName,
      derivationPath: walletAddress.derivationPath,
    );
  }
}

class _AmountCriteriaSelectionResult {
  final UtxoAmountCriteria criteria;
  final String? customAmountText;
  final bool isLessThan;

  const _AmountCriteriaSelectionResult({required this.criteria, this.customAmountText, this.isLessThan = false});
}

class _ReceiveAddressSelectionResult {
  final String address;
  final bool isDirectInput;

  const _ReceiveAddressSelectionResult({required this.address, required this.isDirectInput});
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
