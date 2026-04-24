part of 'utxo_merge_screen.dart';

extension _UtxoMergeScreenBottomSheetsExtension on _UtxoMergeScreenState {
  UtxoMergeStep? _nextStepForMergeMethod(UtxoMergeMethod mergeMethod) {
    switch (mergeMethod) {
      case UtxoMergeMethod.smallAmounts:
        return UtxoMergeStep.selectAmountRange;
      case UtxoMergeMethod.sameTag:
        return UtxoMergeStep.selectTag;
      case UtxoMergeMethod.sameAddress:
        return UtxoMergeStep.selectReceivingAddress;
    }
  }

  void _showMergeOptionBottomSheet() async {
    if (!_bottomSheetOpenGuard.tryOpen()) return;

    vibrateExtraLight();

    try {
      final selectedItem = await CommonBottomSheets.showSelectableDraggableSheet<UtxoMergeMethod>(
        context: context,
        backgroundColor: CoconutColors.gray900,
        title: t.merge_utxos_screen.merge_method_bottomsheet.title,
        items: const [UtxoMergeMethod.smallAmounts, UtxoMergeMethod.sameTag, UtxoMergeMethod.sameAddress],
        showGradient: false,
        initiallySelectedId: _viewModel.currentMethod,
        allowConfirmWhenSelectionUnchanged: _viewModel.mergeState == MergeState.idle,
        getItemId: (item) => item,
        initialChildSize: 0.5,
        minChildSize: 0.499,
        maxChildSize: 0.9,
        confirmText: t.done,
        itemBuilder: (context, item, isSelected, onTap) {
          final isTagMergeItem = item == UtxoMergeMethod.sameTag;
          final isAddressMergeItem = item == UtxoMergeMethod.sameAddress;
          final isDisabled =
              (isTagMergeItem && !_viewModel.hasMergeableTaggedUtxos) ||
              (isAddressMergeItem && !_viewModel.hasSameAddressUtxos);

          return SelectableBottomSheetTextItem(
            isSelected: isSelected,
            onTap: onTap,
            isDisabled: isDisabled,
            child: Text(item.getLabel(t), style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)),
          );
        },
      );

      if (selectedItem != null && context.mounted) {
        final nextStep = _nextStepForMergeMethod(selectedItem);
        _setScreenState(() {
          _viewModel.confirmMergeMethodSelection(selectedItem);
        });

        if (nextStep != null) {
          _viewModel.setCurrentStep(nextStep);
          _refreshAnimationsForCurrentStep();
          if (nextStep == UtxoMergeStep.selectReceivingAddress) {
            unawaited(_viewModel.prepareMergeTransaction());
          }
        }
      }
    } finally {
      _bottomSheetOpenGuard.close();
    }
  }

  void _showAmountRangeBottomSheet() async {
    if (!_bottomSheetOpenGuard.tryOpen()) return;

    vibrateExtraLight();

    final firstAvailableRecommendedRange = _viewModel.firstAvailableRecommendedAmountRange;
    final hasRecommendedCandidates = firstAvailableRecommendedRange != null;
    final currentAmountRange = _viewModel.currentAmountRange;
    const amountRecommendedExtent = 0.75;
    const amountCustomExtent = 0.9;
    var selectedTabIndex = !hasRecommendedCandidates || currentAmountRange == UtxoAmountRange.custom ? 1 : 0;
    DraggableScrollableController? draggableController;
    UtxoAmountRange? selectedRecommendedRange =
        UtxoMergeViewModel.recommendedAmountRangeItems.contains(currentAmountRange) &&
                _viewModel.hasCandidateUtxosForAmountRange(currentAmountRange)
            ? currentAmountRange
            : firstAvailableRecommendedRange;
    final customAmountController = TextEditingController(text: _viewModel.customAmountRangeText ?? '');
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
      final selectedItem = await CommonBottomSheets.showSelectableDraggableSheet<_AmountRangeSelectionResult>(
        context: context,
        backgroundColor: CoconutColors.gray900,
        title: t.merge_utxos_screen.amount_range_bottomsheet.title,
        initialChildSize: 0.75,
        minChildSize: 0.749,
        maxChildSize: 0.9,
        adjustForKeyboardInset: false,
        onControllerReady: (controller) {
          draggableController = controller;
        },
        childBuilder:
            (scrollController) => StatefulBuilder(
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
                        ? t.merge_utxos_screen.no_utxos_for_amount_range
                        : matchingCustomAmountUtxoCount == 1
                        ? t.merge_utxos_screen.single_utxo_for_amount_range
                        : null;

                return _SegmentedBottomSheetBody(
                  scrollController: scrollController,
                  selectedTabIndex: selectedTabIndex,
                  confirmText: t.done,
                  isConfirmEnabled:
                      selectedTabIndex == 0 ? selectedRecommendedRange != null : hasMatchingCustomAmountUtxos,
                  onConfirm: () {
                    if (selectedTabIndex == 0) {
                      if (selectedRecommendedRange == null) return;
                      Navigator.pop(context, _AmountRangeSelectionResult(range: selectedRecommendedRange!));
                      return;
                    }

                    if (customAmountController.text.trim().isEmpty) return;
                    Navigator.pop(
                      context,
                      _AmountRangeSelectionResult(
                        range: UtxoAmountRange.custom,
                        customAmountText: customAmountController.text.trim(),
                        isLessThan: isCustomAmountLessThan,
                      ),
                    );
                  },
                  onTabSelected: (index) {
                    modalSetState(() {
                      selectedTabIndex = index;
                    });
                    final targetExtent = index == 1 ? amountCustomExtent : amountRecommendedExtent;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      final controller = draggableController;
                      if (controller != null && controller.isAttached) {
                        unawaited(
                          controller.animateTo(
                            targetExtent,
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                          ),
                        );
                      }
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
                      label: t.merge_utxos_screen.amount_range_bottomsheet.recommendation_range,
                      child: _buildAmountRangeRecommendationTab(
                        scrollController: scrollController,
                        selectedRecommendedRange: selectedRecommendedRange,
                        onSelectionChanged: (selected) {
                          modalSetState(() {
                            selectedRecommendedRange = selected;
                          });
                        },
                      ),
                    ),
                    _BottomSheetTab(
                      label: t.merge_utxos_screen.amount_range_bottomsheet.custom,
                      child: _buildCustomAmountTab(
                        scrollController: scrollController,
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
      );

      if (selectedItem != null && context.mounted) {
        const nextStep = UtxoMergeStep.selectReceivingAddress;

        _setScreenState(() {
          _viewModel.confirmAmountRangeSelection(
            range: selectedItem.range,
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
      _bottomSheetOpenGuard.close();
    }
  }

  void _showTagSelectBottomSheet() async {
    if (!_bottomSheetOpenGuard.tryOpen()) return;

    vibrateExtraLight();

    try {
      final selectedItem = await CommonBottomSheets.showDraggableBottomSheet<TagSelectResult>(
        context: context,
        title: t.merge_utxos_screen.select_tag_bottomsheet_title,
        minChildSize: 0.45,
        maxChildSize: 0.8,
        initialChildSize: 0.45,
        backgroundColor: CoconutColors.black,
        adjustForKeyboardInset: false,
        childBuilder:
            (scrollController) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
              child: TagSelectBottomSheet(
                walletId: widget.id,
                initialSelectedTagName: _viewModel.effectiveSelectedTagName,
                scrollController: scrollController,
                useSheetContainer: false,
              ),
            ),
      );

      if (selectedItem != null && context.mounted) {
        _setScreenState(() {
          _viewModel.confirmTagCriteriaSelection(selectedItem.selectedTagName);
        });

        _viewModel.setCurrentStep(UtxoMergeStep.selectReceivingAddress);
        _refreshAnimationsForCurrentStep();
        unawaited(_viewModel.prepareMergeTransaction());
      }
    } finally {
      _bottomSheetOpenGuard.close();
    }
  }

  List<Widget> _buildSelectedTagInlineWidgets(BuildContext context) {
    final selectedTagName = _viewModel.effectiveSelectedTagName;
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
    if (!_bottomSheetOpenGuard.tryOpen()) return;

    vibrateExtraLight();

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

    const receiveOwnedExtent = 0.6;
    const receiveDirectInputExtent = 0.9;
    final initialReceiveExtent = selectedTabIndex == 1 ? receiveDirectInputExtent : receiveOwnedExtent;
    DraggableScrollableController? draggableController;
    void animateReceiveSheetTo(double targetExtent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final controller = draggableController;
        if (controller != null && controller.isAttached) {
          unawaited(
            controller.animateTo(targetExtent, duration: const Duration(milliseconds: 220), curve: Curves.easeOutCubic),
          );
        }
      });
    }

    void handleDirectInputFocusChange() {
      if (!directInputFocusNode.hasFocus || selectedTabIndex != 1) return;
      animateReceiveSheetTo(receiveDirectInputExtent);
    }

    directInputFocusNode.addListener(handleDirectInputFocusChange);

    _ReceivingAddressSelectionResult? selectedItem;
    try {
      selectedItem = await CommonBottomSheets.showSelectableDraggableSheet<_ReceivingAddressSelectionResult>(
        context: context,
        backgroundColor: CoconutColors.gray900,
        title: t.merge_utxos_screen.receive_address,
        adjustForKeyboardInset: true,
        initialChildSize: initialReceiveExtent,
        minChildSize: 0.599,
        maxChildSize: 0.9,
        onControllerReady: (controller) {
          draggableController = controller;
          if (selectedTabIndex == 1) {
            animateReceiveSheetTo(receiveDirectInputExtent);
          }
        },
        childBuilder:
            (scrollController) => StatefulBuilder(
              builder: (context, modalSetState) {
                return _SegmentedBottomSheetBody(
                  scrollController: scrollController,
                  adjustForKeyboardInset: false,
                  selectedTabIndex: selectedTabIndex,
                  confirmText: t.done,
                  confirmSubWidget:
                      selectedTabIndex == 1
                          ? _buildReceiveAddressValidationSubWidget(directInputController.text.trim())
                          : null,
                  isConfirmEnabled:
                      selectedTabIndex == 0
                          ? selectedOwnedAddress != null
                          : directInputController.text.trim().isNotEmpty &&
                              _viewModel.isCustomReceiveAddressValidFormat,
                  onConfirm: () {
                    if (selectedTabIndex == 0) {
                      if (selectedOwnedAddress == null) return;
                      Navigator.pop(
                        context,
                        _ReceivingAddressSelectionResult(address: selectedOwnedAddress!, isDirectInput: false),
                      );
                      return;
                    }

                    if (directInputController.text.trim().isEmpty || !_viewModel.isCustomReceiveAddressValidFormat) {
                      return;
                    }
                    Navigator.pop(
                      context,
                      _ReceivingAddressSelectionResult(
                        address: normalizeAddress(directInputController.text.trim()),
                        isDirectInput: true,
                      ),
                    );
                  },
                  onTabSelected: (index) {
                    modalSetState(() {
                      selectedTabIndex = index;
                    });
                    final targetExtent = index == 1 ? receiveDirectInputExtent : receiveOwnedExtent;
                    animateReceiveSheetTo(targetExtent);
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
                        scrollController: scrollController,
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
                        scrollController: scrollController,
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
      );
    } finally {
      directInputFocusNode.removeListener(handleDirectInputFocusChange);
      directInputController.dispose();
      directInputFocusNode.dispose();
      _bottomSheetOpenGuard.close();
    }

    if (selectedItem != null && context.mounted) {
      final confirmedSelection = selectedItem;
      _setScreenState(() {
        _viewModel.setSelectedReceiveAddress(confirmedSelection.address);
        _viewModel.setCustomReceiveAddressText(confirmedSelection.isDirectInput ? confirmedSelection.address : null);
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
        style: CoconutTypography.body3_12.setColor(CoconutColors.hotPink),
        textAlign: TextAlign.center,
      );
    }

    return null;
  }

  Widget _buildReceiveAddressOwnedTab({
    required ScrollController scrollController,
    required List<ReceivingAddressOption> addresses,
    required String? selectedAddress,
    required ValueChanged<String?> onSelectionChanged,
  }) {
    return SelectableBottomSheetBody<ReceivingAddressOption>(
      key: const ValueKey('owned-receive-address-list'),
      scrollController: scrollController,
      items: addresses,
      showGradient: false,
      showConfirmButton: false,
      initiallySelectedId: selectedAddress,
      getItemId: (item) => item.address,
      confirmText: t.done,
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
    required ScrollController scrollController,
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
            controller: scrollController,
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

  Widget _buildAmountRangeRecommendationTab({
    required ScrollController scrollController,
    required UtxoAmountRange? selectedRecommendedRange,
    required ValueChanged<UtxoAmountRange?> onSelectionChanged,
  }) {
    return SelectableBottomSheetBody<UtxoAmountRange>(
      key: const ValueKey('recommended-amount-range'),
      scrollController: scrollController,
      allowConfirmWhenSelectionUnchanged: true,
      items: UtxoMergeViewModel.recommendedAmountRangeItems,
      showGradient: false,
      showConfirmButton: false,
      initiallySelectedId: selectedRecommendedRange,
      getItemId: (item) => item,
      confirmText: t.done,
      backgroundColor: CoconutColors.gray900,
      onSelectionChanged: onSelectionChanged,
      itemBuilder: (context, item, isSelected, onTap) {
        final isDisabled = !_viewModel.hasCandidateUtxosForAmountRange(item);
        return SelectableBottomSheetTextItem(
          isSelected: isSelected,
          isDisabled: isDisabled,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_amountRangeText(item), style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)),
              if (_amountRangeDescription(item) != null)
                Text(_amountRangeDescription(item)!, style: CoconutTypography.body3_12.setColor(CoconutColors.gray400)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomAmountTab({
    required ScrollController scrollController,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool isLessThan,
    required String? errorText,
    required VoidCallback onAmountChanged,
    required VoidCallback onLessThanToggle,
  }) {
    return SizedBox.expand(
      child: Container(
        key: const ValueKey('custom-amount-range'),
        color: CoconutColors.gray900,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            controller: scrollController,
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
                      isErrorTextMultiline: true,
                      textInputFormatter: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        SingleDotInputFormatter(),
                        const BtcAmountInputFormatter(),
                      ],
                      placeholderText: '',
                      suffix: Text(
                        t.btc,
                        style: CoconutTypography.heading4_18.copyWith(
                          color: CoconutColors.white,
                          height: 1.4,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
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
                              ? t.merge_utxos_screen.amount_range_bottomsheet.less_than
                              : t.merge_utxos_screen.amount_range_bottomsheet.or_less,
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
