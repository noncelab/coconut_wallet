part of 'merge_utxos_screen.dart';

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
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
  final UtxoMergeCriteria mergeCriteria;
  final String amountCriteriaText;
  final List<Widget> selectedTagInlineWidgets;
  final ValueListenable<bool> isEditingListenable;
  final Set<String> initialSelectedUtxoIds;
  final ValueChanged<Set<String>> onSelectionChanged;

  const _SelectedUtxosPreviewBottomSheetBody({
    required this.utxos,
    required this.currentUnit,
    required this.reusedAddresses,
    required this.mergeCriteria,
    required this.amountCriteriaText,
    required this.selectedTagInlineWidgets,
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

  Widget _buildSummaryCard() {
    final usedCountText = t.merge_utxos_screen.used_utxos_count(
      total: widget.utxos.length,
      used: _selectedUtxoIds.length,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: CoconutColors.gray800,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CoconutColors.gray700, width: 1),
        ),
        child: Text(usedCountText, style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)),
      ),
    );
  }

  Widget _buildSummaryBody(bool isEditing) {
    switch (widget.mergeCriteria) {
      case UtxoMergeCriteria.sameTag:
        return _buildSameTagSummaryBody(isEditing);
      case UtxoMergeCriteria.smallAmounts:
        return _buildSmallAmountsSummaryBody(isEditing);
      case UtxoMergeCriteria.sameAddress:
        return _buildSameAddressSummaryBody(isEditing);
    }
  }

  Widget _buildSmallAmountsSummaryBody(bool isEditing) {
    return Column(
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
      ],
    );
  }

  Widget _buildSameTagSummaryBody(bool isEditing) {
    final sections = _buildTagCombinationSections();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [CoconutColors.gray900, CoconutColors.gray800],
                      ),
                    ),
                    child: Text(
                      t.merge_utxos_screen.count(n: section.utxos.length, count: section.utxos.length),
                      textAlign: TextAlign.end,
                      style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16),
                      child: Wrap(spacing: 4, runSpacing: 8, children: section.tags.map(_buildTagChip).toList()),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                for (int start = 0; start < section.utxos.length; start += _columnCount) ...[
                  _buildUtxoRow(
                    section.utxos.sublist(
                      start,
                      (start + _columnCount) > section.utxos.length ? section.utxos.length : start + _columnCount,
                    ),
                    isEditing,
                  ),
                  const SizedBox(height: 36),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSameAddressSummaryBody(bool isEditing) {
    final sections = _buildReusedAddressSections();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in sections) ...[
          Stack(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [CoconutColors.gray900, CoconutColors.gray800],
                    ),
                  ),
                  child: Text(
                    t.merge_utxos_screen.count(n: section.utxos.length, count: section.utxos.length),
                    textAlign: TextAlign.end,
                    style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
                  ),
                ),
              ),
              Positioned.fill(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _buildHighlightedSegwitAddressText(
                      address: section.address,
                      baseStyle: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray500),
                      highlightedStyle: CoconutTypography.body3_12_Number.setColor(CoconutColors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              children: [
                for (int start = 0; start < section.utxos.length; start += _columnCount) ...[
                  _buildUtxoRow(
                    section.utxos.sublist(
                      start,
                      (start + _columnCount) > section.utxos.length ? section.utxos.length : start + _columnCount,
                    ),
                    isEditing,
                  ),
                  const SizedBox(height: 20),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  List<_TagCombinationSection> _buildTagCombinationSections() {
    final sectionMap = <String, _TagCombinationSection>{};

    for (final utxo in widget.utxos) {
      final tags = [...?utxo.tags]..sort((a, b) => a.name.compareTo(b.name));
      if (tags.isEmpty) continue;

      final key = tags.map((tag) => tag.name).join('|');
      final existing = sectionMap[key];
      if (existing == null) {
        sectionMap[key] = _TagCombinationSection(tags: tags, utxos: [utxo]);
      } else {
        existing.utxos.add(utxo);
      }
    }

    final sections = sectionMap.values.toList();
    sections.sort((a, b) {
      final countCompare = b.utxos.length.compareTo(a.utxos.length);
      if (countCompare != 0) return countCompare;
      final tagLengthCompare = a.tags.length.compareTo(b.tags.length);
      if (tagLengthCompare != 0) return tagLengthCompare;
      return a.tags.map((tag) => tag.name).join('|').compareTo(b.tags.map((tag) => tag.name).join('|'));
    });
    return sections;
  }

  List<_ReusedAddressSection> _buildReusedAddressSections() {
    final sectionMap = <String, List<UtxoState>>{};

    for (final utxo in widget.utxos) {
      sectionMap.putIfAbsent(utxo.to, () => <UtxoState>[]).add(utxo);
    }

    final sections =
        sectionMap.entries
            .where((entry) => entry.value.length >= 2)
            .map((entry) => _ReusedAddressSection(address: entry.key, utxos: entry.value))
            .toList();

    sections.sort((a, b) {
      final countCompare = b.utxos.length.compareTo(a.utxos.length);
      if (countCompare != 0) return countCompare;
      return a.address.compareTo(b.address);
    });

    return sections;
  }

  Widget _buildTagChip(UtxoTag tag) {
    final foregroundColor = tagColorPalette[tag.colorIndex];

    return IntrinsicWidth(
      child: CoconutChip(
        minWidth: 40,
        color: CoconutColors.backgroundColorPaletteDark[tag.colorIndex],
        borderColor: foregroundColor,
        label: '#${tag.name}',
        labelSize: 12,
        labelColor: foregroundColor,
      ),
    );
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
                _buildSummaryCard(),
                const SizedBox(height: 24),
                Expanded(
                  child: Stack(
                    children: [
                      SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 24),
                            _buildSummaryBody(isEditing),
                            const SizedBox(height: 50),
                          ],
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: IgnorePointer(
                          child: Container(
                            height: 32,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [CoconutColors.gray900, Color(0x001F1F1F)],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: IgnorePointer(
                          child: Container(
                            height: 32,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [CoconutColors.gray900, Color(0x001F1F1F)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                              dustThreshold:
                                  DustThresholds
                                      .p2wpkh, // TODO: selectedUtxoPreviewBottomSheetBody에 AddressType을 생성자 매개변수로 받아서 사용해야함
                            ),
                          ),
                        )
                        : const SizedBox.shrink(),
              ),
          ],
        ),
        if (!isEditing)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return SizeTransition(
                sizeFactor: animation,
                axisAlignment: -1,
                fixedCrossAxisSizeFactor: 1,
                child: child,
              );
            },
            layoutBuilder: (currentChild, previousChildren) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [...previousChildren, if (currentChild != null) currentChild],
              );
            },
            child:
                expandedUtxo == null
                    ? const SizedBox.shrink(key: ValueKey('selected-utxo-detail-empty'))
                    : Padding(
                      key: ValueKey(expandedUtxo.utxoId),
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
    const horizontalOverflow = 16.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final baseWidth =
            constraints.hasBoundedWidth
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width - (horizontalOverflow * 2);
        final slotWidth = baseWidth / _SelectedUtxosPreviewBottomSheetBodyState._columnCount;
        final arrowLeft = (slotWidth * selectedColumnIndex) + (slotWidth / 2) - 10 + horizontalOverflow;
        final cardWidth = baseWidth + (horizontalOverflow * 2);

        return SizedBox(
          width: baseWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: cardWidth,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  decoration: const BoxDecoration(
                    color: CoconutColors.black,
                    border: Border.symmetric(horizontal: BorderSide(color: CoconutColors.gray800, width: 1)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
              ),
              Positioned(
                top: -9.3,
                left: arrowLeft - 16,
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
          ),
        );
      },
    );
  }
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
