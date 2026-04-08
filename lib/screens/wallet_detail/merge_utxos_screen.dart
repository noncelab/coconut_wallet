import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/enums/utxo_merge_enums.dart';
import 'package:coconut_wallet/extensions/widget_animation_extensions.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/view_model/wallet_detail/merge_utxos/merge_utxos_view_model.dart';
import 'package:coconut_wallet/providers/utxo_tag_provider.dart';
import 'package:coconut_wallet/screens/send/refactor/send_screen.dart';
import 'package:coconut_wallet/utils/text_field_filter_util.dart';
import 'package:coconut_wallet/widgets/button/fixed_bottom_button.dart';
import 'package:coconut_wallet/widgets/button/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/overlays/common_bottom_sheets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:coconut_wallet/repository/realm/utxo_repository.dart';

class MergeUtxosScreen extends StatefulWidget {
  final int id;

  const MergeUtxosScreen({super.key, required this.id});

  @override
  State<MergeUtxosScreen> createState() => _MergeUtxosScreenState();
}

class _MergeUtxosScreenState extends State<MergeUtxosScreen> {
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

  @override
  void initState() {
    super.initState();
    _viewModel = MergeUtxosViewModel(widget.id, context.read<UtxoRepository>(), context.read<UtxoTagProvider>())
      ..initialize();
  }

  @override
  void dispose() {
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

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildAnimatedHeader(), CoconutLayout.spacing_400h, _buildVisibleOptionPickers(context)],
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

  void _syncHeaderAnimation(UtxoMergeStep step) {
    if (!_isAnimatedHeaderStep(step)) return;

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

  void _syncOptionPickerAnimation(UtxoMergeStep step) {
    if (!_isAnimatedHeaderStep(step)) return;

    _pendingOptionPickerStep = step;

    if (_displayedOptionPickerStep == null) {
      setState(() {
        _displayedOptionPickerStep = step;
        if (!_visibleOptionPickerSteps.contains(step)) {
          _visibleOptionPickerSteps.insert(0, step);
        }
      });
      return;
    }

    if (_displayedOptionPickerStep == step) {
      return;
    }

    ++_optionPickerAnimationNonce;
    setState(() {
      _displayedOptionPickerStep = _pendingOptionPickerStep;
      final pendingStep = _pendingOptionPickerStep;
      if (pendingStep != null && !_visibleOptionPickerSteps.contains(pendingStep)) {
        _visibleOptionPickerSteps.insert(0, pendingStep);
      }
    });
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
      default:
        break;
    }
  }

  bool _isAnimatedHeaderStep(UtxoMergeStep step) {
    return step == UtxoMergeStep.selectMergeCriteria ||
        step == UtxoMergeStep.selectAmountCriteria ||
        step == UtxoMergeStep.selectTag;
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
    final text = _headerTextForStep(step);

    if (step == null || text == null) {
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
    return AnimatedSize(
      duration: _optionPickerAnimationDuration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Column(
        children:
            _visibleOptionPickerSteps.indexed.map((entry) {
              final index = entry.$1;
              final step = entry.$2;
              final picker = _buildStepOptionPicker(context, step);
              final isNewest = step == _displayedOptionPickerStep && index == 0;

              if (isNewest) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: picker.slideUpAnimation(
                    key: ValueKey('merge-picker-in-${step.name}-$_optionPickerAnimationNonce'),
                    duration: _optionPickerAnimationDuration,
                    delay: const Duration(milliseconds: 1500),
                    offset: const Offset(0, 24),
                    onCompleted: () => _scheduleBottomSheetOpen(step),
                  ),
                );
              }

              return Padding(padding: EdgeInsets.only(top: index == 0 ? 0 : 12), child: picker);
            }).toList(),
      ),
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
      _ => const SizedBox.shrink(),
    };
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
              text: _mergeCriteriaText(item),
              isSelected: isSelected,
              onTap: onTap,
              isDisabled: isDisabled,
            );
          },
        ),
      ),
    );

    if (selectedItem != null && context.mounted) {
      final nextStep = _nextStepForMergeCriteria(selectedItem);

      setState(() {
        _selectedMergeCriteria = selectedItem;
        _didConfirmMergeCriteria = true;
        _isBottomSheetOpen = false;
      });

      if (nextStep != null) {
        _viewModel.setCurrentStep(nextStep);
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

    final selectedItem = await CommonBottomSheets.showBottomSheet<_AmountCriteriaSelectionResult>(
      showCloseButton: true,
      adjustForKeyboardInset: false,
      context: context,
      backgroundColor: CoconutColors.gray900,
      title: t.merge_utxos_screen.amount_criteria_bottomsheet.title,
      child: SizedBox(
        height: bodyHeight + 16,
        child: _AmountCriteriaBottomSheetBody(
          bodyHeight: bodyHeight,
          initialSelectedCriteria: _currentAmountCriteria,
          recommendationTabLabel: t.merge_utxos_screen.amount_criteria_bottomsheet.recommendation_criteria,
          customTabLabel: t.merge_utxos_screen.amount_criteria_bottomsheet.custom,
          confirmText: t.complete,
          titleBuilder: _amountCriteriaText,
          descriptionBuilder: _amountCriteriaDescription,
        ),
      ),
    );

    if (selectedItem != null && context.mounted) {
      const nextStep = UtxoMergeStep.selectReceiveAddress;

      setState(() {
        _selectedAmountCriteria = selectedItem.criteria;
        _customAmountCriteriaText = selectedItem.customAmountText;
        _isCustomAmountLessThan = selectedItem.isLessThan;
        _didConfirmAmountCriteria = true;
        _isBottomSheetOpen = false;
      });

      _viewModel.setCurrentStep(nextStep);
      return;
    }

    if (mounted) {
      setState(() {
        _isBottomSheetOpen = false;
      });
    }
  }
}

class _AmountCriteriaBottomSheetBody extends StatefulWidget {
  final double bodyHeight;
  final UtxoAmountCriteria initialSelectedCriteria;
  final String recommendationTabLabel;
  final String customTabLabel;
  final String confirmText;
  final String Function(UtxoAmountCriteria criteria) titleBuilder;
  final String? Function(UtxoAmountCriteria criteria) descriptionBuilder;

  const _AmountCriteriaBottomSheetBody({
    required this.bodyHeight,
    required this.initialSelectedCriteria,
    required this.recommendationTabLabel,
    required this.customTabLabel,
    required this.confirmText,
    required this.titleBuilder,
    required this.descriptionBuilder,
  });

  @override
  State<_AmountCriteriaBottomSheetBody> createState() => _AmountCriteriaBottomSheetBodyState();
}

class _AmountCriteriaBottomSheetBodyState extends State<_AmountCriteriaBottomSheetBody> {
  static const List<UtxoAmountCriteria> _recommendedCriteria = [
    UtxoAmountCriteria.below001,
    UtxoAmountCriteria.below0001,
    UtxoAmountCriteria.below00001,
  ];
  late int _selectedTabIndex;
  UtxoAmountCriteria? _selectedRecommendedCriteria;
  final TextEditingController _customAmountController = TextEditingController();
  final FocusNode _customAmountFocusNode = FocusNode();
  bool _isCustomAmountLessThan = false;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialSelectedCriteria == UtxoAmountCriteria.custom ? 1 : 0;
    _selectedRecommendedCriteria =
        _recommendedCriteria.contains(widget.initialSelectedCriteria) ? widget.initialSelectedCriteria : null;
    if (_selectedTabIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _customAmountFocusNode.requestFocus();
        }
      });
    }
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    _customAmountFocusNode.dispose();
    super.dispose();
  }

  double _tabBodyHeight(BuildContext context) {
    return widget.bodyHeight - 230;
  }

  Widget _amountCriteriaBottomSheetBody() {
    return SelectableBottomSheetBody<UtxoAmountCriteria>(
      key: const ValueKey('recommended-amount-criteria'),
      items: _recommendedCriteria,
      showGradient: false,
      showConfirmButton: false,
      initiallySelectedId: _selectedRecommendedCriteria,
      getItemId: (item) => item,

      confirmText: widget.confirmText,
      backgroundColor: CoconutColors.gray900,
      onSelectionChanged: (selected) {
        setState(() {
          _selectedRecommendedCriteria = selected;
        });
      },
      itemBuilder: (context, item, isSelected, onTap) {
        return SelectableBottomSheetTextItem(
          text: widget.titleBuilder(item),
          description: widget.descriptionBuilder(item),
          isSelected: isSelected,
          onTap: onTap,
        );
      },
    );
  }

  Widget _customAmountBottomSheetBody() {
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
                      controller: _customAmountController,
                      focusNode: _customAmountFocusNode,
                      fontSize: 18,
                      style: CoconutTextFieldStyle.underline,
                      padding: const EdgeInsets.only(left: 5, right: 0, top: 16, bottom: 6),
                      onChanged: (_) {
                        setState(() {});
                      },
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
                      onPressed: () {
                        setState(() {
                          _isCustomAmountLessThan = !_isCustomAmountLessThan;
                        });
                      },
                      defaultColor: CoconutColors.gray800,
                      pressedColor: CoconutColors.gray700,
                      borderRadius: 8,
                      borderWidth: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Text(
                          _isCustomAmountLessThan
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

  bool get _isConfirmEnabled {
    if (_selectedTabIndex == 0) {
      return _selectedRecommendedCriteria != null;
    }
    return _customAmountController.text.trim().isNotEmpty && double.tryParse(_customAmountController.text.trim()) != 0;
  }

  void _handleConfirm() {
    if (_selectedTabIndex == 0) {
      if (_selectedRecommendedCriteria == null) return;
      Navigator.pop(context, _AmountCriteriaSelectionResult(criteria: _selectedRecommendedCriteria!));
      return;
    }

    if (_customAmountController.text.trim().isEmpty) return;
    Navigator.pop(
      context,
      _AmountCriteriaSelectionResult(
        criteria: UtxoAmountCriteria.custom,
        customAmountText: _customAmountController.text.trim(),
        isLessThan: _isCustomAmountLessThan,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabBodyHeight = _tabBodyHeight(context);
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    const buttonBottomSpacing = 16.0;
    final buttonAreaHeight =
        FixedBottomButton.fixedBottomButtonDefaultHeight + bottomSafeArea + buttonBottomSpacing + 3;

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
                    labels: [widget.recommendationTabLabel, widget.customTabLabel],
                    isSelected: [_selectedTabIndex == 0, _selectedTabIndex == 1],
                    onPressed: (index) {
                      setState(() {
                        _selectedTabIndex = index;
                      });
                      if (index == 1) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) {
                            _customAmountFocusNode.requestFocus();
                          }
                        });
                      } else {
                        _customAmountFocusNode.unfocus();
                      }
                    },
                  ),
                ),
                CoconutLayout.spacing_400h,
                SizedBox(
                  height: tabBodyHeight,
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
                    child: _selectedTabIndex == 0 ? _amountCriteriaBottomSheetBody() : _customAmountBottomSheetBody(),
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
                onButtonClicked: _handleConfirm,
                isActive: _isConfirmEnabled,
                text: widget.confirmText,
                backgroundColor: CoconutColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountCriteriaSelectionResult {
  final UtxoAmountCriteria criteria;
  final String? customAmountText;
  final bool isLessThan;

  const _AmountCriteriaSelectionResult({required this.criteria, this.customAmountText, this.isLessThan = false});
}
