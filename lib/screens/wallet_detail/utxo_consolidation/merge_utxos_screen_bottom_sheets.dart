part of 'merge_utxos_screen.dart';

extension _MergeUtxosScreenBottomSheetsExtension on _MergeUtxosScreenState {
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

  void _showMergeCriteriaBottomSheet() async {
    if (_isBottomSheetOpened) return;
    _isBottomSheetOpened = true;

    vibrateExtraLight();

    try {
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
            initiallySelectedId: _viewModel.currentCriteria,
            allowConfirmWhenSelectionUnchanged: true,
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
                  _getCurrentCriteriaText(item)!,
                  style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
                ),
              );
            },
          ),
        ),
      );

      if (selectedItem != null && context.mounted) {
        final nextStep = _nextStepForMergeCriteria(selectedItem);
        _setScreenState(() {
          _viewModel.confirmMergeCriteriaSelection(selectedItem);
        });

        if (nextStep != null) {
          _viewModel.setCurrentStep(nextStep);
          _refreshAnimationsForCurrentStep();
          if (nextStep == UtxoMergeStep.selectReceiveAddress) {
            unawaited(_viewModel.prepareMergeTransaction());
          }
        }
      }
    } finally {
      _isBottomSheetOpened = false;
    }
  }

  void _showAmountCriteriaBottomSheet() async {
    if (_isBottomSheetOpened) return;
    _isBottomSheetOpened = true;

    vibrateExtraLight();

    final screenHeight = MediaQuery.sizeOf(context).height;
    final bodyHeight = (screenHeight * 0.9).clamp(340.0, 580.0);
    final firstAvailableRecommendedCriteria = _firstAvailableRecommendedAmountCriteria;
    final hasRecommendedCandidates = firstAvailableRecommendedCriteria != null;
    var selectedTabIndex = !hasRecommendedCandidates || _currentAmountCriteria == UtxoAmountCriteria.custom ? 1 : 0;
    UtxoAmountCriteria? selectedRecommendedCriteria =
        _recommendedAmountCriteriaItems.contains(_currentAmountCriteria) &&
                _viewModel.hasCandidateUtxosForAmountCriteria(_currentAmountCriteria)
            ? _currentAmountCriteria
            : firstAvailableRecommendedCriteria;
    final customAmountController = TextEditingController(text: _viewModel.customAmountCriteriaText ?? '');
    final customAmountFocusNode = FocusNode();
    var isCustomAmountLessThan = _viewModel.isCustomAmountLessThan;

    if (selectedTabIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          customAmountFocusNode.requestFocus();
        }
      });
    }

    try {
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
              final customAmountText = customAmountController.text.trim();
              final customAmountValue = double.tryParse(customAmountText);
              final hasCustomAmountInput =
                  customAmountText.isNotEmpty && customAmountValue != null && customAmountValue != 0;
              final matchingCustomAmountUtxoCount =
                  hasCustomAmountInput
                      ? _viewModel.candidateUtxoCountForCustomAmountText(
                        customAmountText,
                        isLessThan: isCustomAmountLessThan,
                      )
                      : 0;
              final hasMatchingCustomAmountUtxos = matchingCustomAmountUtxoCount >= 2;
              final customAmountErrorText =
                  !hasCustomAmountInput
                      ? null
                      : matchingCustomAmountUtxoCount == 0
                      ? t.merge_utxos_screen.no_utxos_for_amount_criteria
                      : matchingCustomAmountUtxoCount == 1
                      ? t.merge_utxos_screen.single_utxo_for_amount_criteria
                      : null;

              return _SegmentedBottomSheetBody(
                bodyHeight: bodyHeight,
                selectedTabIndex: selectedTabIndex,
                confirmText: t.complete,
                isConfirmEnabled:
                    selectedTabIndex == 0 ? selectedRecommendedCriteria != null : hasMatchingCustomAmountUtxos,
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
                      errorText: customAmountErrorText,
                      onAmountChanged: () {
                        modalSetState(() {});
                      },
                      onLessThanToggle: () {
                        vibrateExtraLight();
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

      if (selectedItem != null && context.mounted) {
        const nextStep = UtxoMergeStep.selectReceiveAddress;

        _setScreenState(() {
          _viewModel.confirmAmountCriteriaSelection(
            criteria: selectedItem.criteria,
            customAmountText: selectedItem.customAmountText,
            isLessThan: selectedItem.isLessThan,
          );
        });

        _viewModel.setCurrentStep(nextStep);
        unawaited(_viewModel.prepareMergeTransaction());
      }
    } finally {
      customAmountController.dispose();
      customAmountFocusNode.dispose();
      _isBottomSheetOpened = false;
    }
  }

  void _showTagSelectBottomSheet() async {
    if (_isBottomSheetOpened) return;
    _isBottomSheetOpened = true;

    vibrateExtraLight();

    try {
      final selectedItem = await showModalBottomSheet<TagSelectResult>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder:
            (context) => TagSelectBottomSheet(walletId: widget.id, initialSelectedTagName: _effectiveSelectedTagName),
      );

      if (selectedItem != null && context.mounted) {
        _setScreenState(() {
          _viewModel.confirmTagCriteriaSelection(selectedItem.selectedTagName);
        });

        _viewModel.setCurrentStep(UtxoMergeStep.selectReceiveAddress);
        _refreshAnimationsForCurrentStep();
        unawaited(_viewModel.prepareMergeTransaction());
      }
    } finally {
      _isBottomSheetOpened = false;
    }
  }

  List<Widget> _buildSelectedTagInlineWidgets(BuildContext context) {
    final selectedTagName = _effectiveSelectedTagName;
    if (selectedTagName == null || selectedTagName.isEmpty) return const [];

    final utxoTagProvider = context.read<UtxoTagProvider>();
    final selectedTag = utxoTagProvider
        .getUtxoTagList(widget.id)
        .cast<UtxoTag?>()
        .firstWhere((tag) => tag?.name == selectedTagName, orElse: () => null);

    if (selectedTag == null) return const [];

    final colorIndex = selectedTag.colorIndex;
    final foregroundColor = tagColorPalette[colorIndex];

    return [
      IntrinsicWidth(
        child: CoconutChip(
          minWidth: 40,
          color: CoconutColors.backgroundColorPaletteDark[colorIndex],
          borderColor: foregroundColor,
          label: '#${selectedTag.name}',
          labelSize: 12,
          labelColor: foregroundColor,
        ),
      ),
    ];
  }

  void _showReceiveAddressBottomSheet() async {
    if (_isBottomSheetOpened) return;
    _isBottomSheetOpened = true;

    vibrateExtraLight();

    final screenHeight = MediaQuery.sizeOf(context).height;
    final bodyHeight = (screenHeight * 0.9).clamp(340.0, 580.0);
    final isUsingDirectInput =
        _viewModel.customReceiveAddressText != null &&
        _viewModel.selectedReceiveAddress == _viewModel.customReceiveAddressText;
    var selectedTabIndex = isUsingDirectInput ? 1 : 0;
    String? selectedOwnedAddress = isUsingDirectInput ? null : _viewModel.selectedReceiveAddress;
    final directInputController = TextEditingController(
      text: isUsingDirectInput ? (_viewModel.customReceiveAddressText ?? '') : '',
    );
    final directInputFocusNode = FocusNode();
    _viewModel.validateCustomReceiveAddress(directInputController.text);

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
        height: bodyHeight,
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
                      : directInputController.text.trim().isNotEmpty && _viewModel.isCustomReceiveAddressValidFormat,
              onConfirm: () {
                if (selectedTabIndex == 0) {
                  if (selectedOwnedAddress == null) return;
                  Navigator.pop(
                    context,
                    _ReceiveAddressSelectionResult(address: selectedOwnedAddress!, isDirectInput: false),
                  );
                  return;
                }

                if (directInputController.text.trim().isEmpty || !_viewModel.isCustomReceiveAddressValidFormat) return;
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
                  label: t.merge_utxos_screen.receive_address_bottomsheet.my_address,
                  child: _buildReceiveAddressOwnedTab(
                    addresses: _viewModel.nextReceiveAddressesOfAllWallets,
                    selectedAddress: selectedOwnedAddress,
                    onSelectionChanged: (address) {
                      modalSetState(() {
                        selectedOwnedAddress = address;
                      });
                    },
                  ),
                ),
                _BottomSheetTab(
                  label: t.merge_utxos_screen.receive_address_bottomsheet.custom,
                  child: _buildReceiveAddressDirectInputTab(
                    controller: directInputController,
                    focusNode: directInputFocusNode,
                    onChanged: (value) {
                      modalSetState(() {
                        _viewModel.validateCustomReceiveAddress(value);
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

    _isBottomSheetOpened = false;

    if (selectedItem != null && context.mounted) {
      _setScreenState(() {
        _viewModel.setSelectedReceiveAddress(selectedItem.address);
        _viewModel.setCustomReceiveAddressText(selectedItem.isDirectInput ? selectedItem.address : null);
      });
      unawaited(_viewModel.prepareMergeTransaction());
      return;
    }
  }

  Widget? _buildReceiveAddressValidationSubWidget(String input) {
    if (input.isEmpty) return null;

    if (!_viewModel.isCustomReceiveAddressValidFormat) {
      return Text(
        t.errors.address_error.invalid,
        style: CoconutTypography.body3_12.setColor(CoconutColors.hotPink),
        textAlign: TextAlign.center,
      );
    }

    if (!_viewModel.isCustomReceiveAddressOwnedByAnyWallet) {
      return Text(
        t.merge_utxos_screen.receive_address_bottomsheet.not_your_owned_wallet,
        style: CoconutTypography.body3_12.setColor(CoconutColors.white),
        textAlign: TextAlign.center,
      );
    }

    return null;
  }

  Widget _buildReceiveAddressOwnedTab({
    required List<ReceiveAddressOption> addresses,
    required String? selectedAddress,
    required ValueChanged<String?> onSelectionChanged,
  }) {
    return SelectableBottomSheetBody<ReceiveAddressOption>(
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
                              controller.text.isNotEmpty && !_viewModel.isCustomReceiveAddressValidFormat
                                  ? CoconutColors.hotPink
                                  : CoconutColors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                ),
                placeholderText: t.send_screen.address_placeholder,
                isError: controller.text.isNotEmpty && !_viewModel.isCustomReceiveAddressValidFormat,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAmountCriteriaRecommendationTab({
    required UtxoAmountCriteria? selectedRecommendedCriteria,
    required ValueChanged<UtxoAmountCriteria?> onSelectionChanged,
  }) {
    return SelectableBottomSheetBody<UtxoAmountCriteria>(
      key: const ValueKey('recommended-amount-criteria'),
      allowConfirmWhenSelectionUnchanged: true,
      items: _recommendedAmountCriteriaItems,
      showGradient: false,
      showConfirmButton: false,
      initiallySelectedId: selectedRecommendedCriteria,
      getItemId: (item) => item,
      confirmText: t.complete,
      backgroundColor: CoconutColors.gray900,
      onSelectionChanged: onSelectionChanged,
      itemBuilder: (context, item, isSelected, onTap) {
        final isDisabled = !_viewModel.hasCandidateUtxosForAmountCriteria(item);
        return SelectableBottomSheetTextItem(
          isSelected: isSelected,
          isDisabled: isDisabled,
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
    required String? errorText,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: CoconutTextField(
                      controller: controller,
                      focusNode: focusNode,
                      fontSize: 18,
                      style: CoconutTextFieldStyle.underline,
                      padding: const EdgeInsets.only(left: 5, right: 0, top: 16, bottom: 6),
                      onChanged: (_) => onAmountChanged(),
                      errorText: errorText ?? '',
                      isError: errorText != null,
                      errorColor: CoconutColors.hotPink,
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
                    padding: const EdgeInsets.only(top: 8),
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
