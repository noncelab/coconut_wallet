part of 'merge_utxos_screen.dart';

class _SegmentedBottomSheetBody extends StatelessWidget {
  final ScrollController? scrollController;
  final int selectedTabIndex;
  final List<_BottomSheetTab> tabs;
  final String confirmText;
  final Widget? confirmSubWidget;
  final bool isConfirmEnabled;
  final bool adjustForKeyboardInset;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onConfirm;

  const _SegmentedBottomSheetBody({
    this.scrollController,
    required this.selectedTabIndex,
    required this.tabs,
    required this.confirmText,
    this.confirmSubWidget,
    required this.isConfirmEnabled,
    this.adjustForKeyboardInset = true,
    required this.onTabSelected,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final keyboardInset = adjustForKeyboardInset ? MediaQuery.of(context).viewInsets.bottom : 0.0;
    const buttonBottomSpacing = 16.0;
    const confirmSubWidgetHeight = 32;
    final buttonAreaHeight =
        FixedBottomButton.fixedBottomButtonDefaultHeight +
        bottomSafeArea +
        buttonBottomSpacing +
        3 +
        (confirmSubWidget != null ? confirmSubWidgetHeight : 0);
    final contentBottomInset = buttonAreaHeight + keyboardInset + 2;

    return SafeArea(
      top: false,
      child: Stack(
        children: [
          Positioned.fill(
            bottom: contentBottomInset,
            child: Column(
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
                Expanded(
                  child:
                      scrollController == null
                          ? AnimatedSwitcher(
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
                          )
                          : PrimaryScrollController(
                            controller: scrollController!,
                            child: KeyedSubtree(
                              key: ValueKey(selectedTabIndex),
                              child: tabs[selectedTabIndex].child,
                            ),
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
  final ScrollController scrollController;
  final List<UtxoState> utxos;
  final BitcoinUnit currentUnit;
  final Set<String> reusedAddresses;
  final UtxoMergeCriteria mergeCriteria;
  final String amountCriteriaText;
  final List<Widget> selectedTagInlineWidgets;
  final ValueListenable<bool> isEditingListenable;
  final Set<String> initialSelectedUtxoIds;
  final ValueChanged<Set<String>> onSelectionChanged;
  final AddressType addressType;

  const _SelectedUtxosPreviewBottomSheetBody({
    required this.scrollController,
    required this.utxos,
    required this.currentUnit,
    required this.reusedAddresses,
    required this.mergeCriteria,
    required this.amountCriteriaText,
    required this.selectedTagInlineWidgets,
    required this.isEditingListenable,
    required this.initialSelectedUtxoIds,
    required this.onSelectionChanged,
    required this.addressType,
  });

  @override
  State<_SelectedUtxosPreviewBottomSheetBody> createState() => _SelectedUtxosPreviewBottomSheetBodyState();
}

class _SelectedUtxosPreviewBottomSheetBodyState extends State<_SelectedUtxosPreviewBottomSheetBody> {
  static const int _columnCount = 4;
  static const double _columnSpacing = 14;

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

  Widget _buildCoinCardWithGlow({
    required UtxoState utxo,
    required double cardSize,
    required bool isExpanded,
    required Widget child,
  }) {
    final isBill = UtxoCoinCard.isBillShape(utxo.amount);
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        // 카드 모양/크기에 맞춘 shadow layer. Stack으로 카드 뒤에 배치해 테두리 전체를 감쌈.
        if (isExpanded)
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: isExpanded ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: Container(
                width: isBill ? cardSize * 1.35 : cardSize,
                height: isBill ? cardSize * 0.85 : cardSize,
                decoration: BoxDecoration(
                  shape: isBill ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isBill ? BorderRadius.circular(8) : null,
                  boxShadow: [BoxShadow(color: CoconutColors.white.withValues(alpha: 0.23), blurRadius: 12)],
                ),
              ),
            ),
          ),
        child,
      ],
    );
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: CoconutColors.gray800,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: CoconutColors.gray700, width: 1),
        ),
        child: Text(usedCountText, style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white)),
      ),
    );
  }

  Widget _buildSummaryBody(bool isEditing) {
    final items = _buildSummaryListItems();

    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(top: 12, bottom: 50),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        if (item is _SummarySpacingItem) {
          return SizedBox(height: item.height);
        }

        if (item is _SummaryRowItem) {
          return _buildUtxoRow(item.rowUtxos, isEditing, horizontalPadding: item.horizontalPadding);
        }

        if (item is _SummaryTagHeaderItem) {
          return _SectionSummaryHeader(
            utxoCount: item.section.utxos.length,
            leading: Wrap(spacing: 4, runSpacing: 8, children: item.section.tags.map(_buildTagChip).toList()),
          );
        }

        final addressItem = item as _SummaryAddressHeaderItem;
        return Stack(
          children: [
            Container(
              width: double.infinity,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [CoconutColors.gray900, CoconutColors.gray800],
                ),
              ),
            ),
            Positioned.fill(
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildHighlightedSegwitAddressText(
                          address: addressItem.section.address,
                          baseStyle: CoconutTypography.body3_12_Number.setColor(CoconutColors.gray500),
                          highlightedStyle: CoconutTypography.body3_12_Number.setColor(CoconutColors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        t.merge_utxos_screen.count(
                          n: addressItem.section.utxos.length,
                          count: addressItem.section.utxos.length,
                        ),
                        textAlign: TextAlign.end,
                        style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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

  List<_SummaryListItem> _buildSummaryListItems() {
    switch (widget.mergeCriteria) {
      case UtxoMergeCriteria.smallAmounts:
        return _buildSmallAmountsSummaryItems();
      case UtxoMergeCriteria.sameTag:
        return _buildSameTagSummaryItems();
      case UtxoMergeCriteria.sameAddress:
        return _buildSameAddressSummaryItems();
    }
  }

  List<_SummaryListItem> _buildSmallAmountsSummaryItems() {
    final items = <_SummaryListItem>[];

    for (int start = 0; start < widget.utxos.length; start += _columnCount) {
      items.add(
        _SummaryRowItem(
          widget.utxos.sublist(
            start,
            (start + _columnCount) > widget.utxos.length ? widget.utxos.length : start + _columnCount,
          ),
          horizontalPadding: 18,
        ),
      );
      items.add(const _SummarySpacingItem(20));
    }

    return items;
  }

  List<_SummaryListItem> _buildSameTagSummaryItems() {
    final items = <_SummaryListItem>[];

    for (final section in _buildTagCombinationSections()) {
      items.add(_SummaryTagHeaderItem(section));
      items.add(const _SummarySpacingItem(16));

      for (int start = 0; start < section.utxos.length; start += _columnCount) {
        items.add(
          _SummaryRowItem(
            section.utxos.sublist(
              start,
              (start + _columnCount) > section.utxos.length ? section.utxos.length : start + _columnCount,
            ),
            horizontalPadding: 18,
          ),
        );
        items.add(const _SummarySpacingItem(20));
      }
    }

    return items;
  }

  List<_SummaryListItem> _buildSameAddressSummaryItems() {
    final items = <_SummaryListItem>[];

    for (final section in _buildReusedAddressSections()) {
      items.add(_SummaryAddressHeaderItem(section));
      items.add(const _SummarySpacingItem(20));

      for (int start = 0; start < section.utxos.length; start += _columnCount) {
        items.add(
          _SummaryRowItem(
            section.utxos.sublist(
              start,
              (start + _columnCount) > section.utxos.length ? section.utxos.length : start + _columnCount,
            ),
            horizontalPadding: 18,
          ),
        );
        items.add(const _SummarySpacingItem(20));
      }

      items.add(const _SummarySpacingItem(16));

      for (int start = 0; start < section.utxos.length; start += _columnCount) {
        items.add(
          _SummaryRowItem(
            section.utxos.sublist(
              start,
              (start + _columnCount) > section.utxos.length ? section.utxos.length : start + _columnCount,
            ),
            horizontalPadding: 18,
          ),
        );
        items.add(const _SummarySpacingItem(20));
      }
    }

    return items;
  }

  Widget _buildTagChip(UtxoTag tag) {
    final foregroundColor = tagColorPalette[tag.colorIndex];

    return IntrinsicWidth(
      child: CoconutChip(
        minWidth: 40,
        color: CoconutColors.backgroundColorPaletteDark[tag.colorIndex],
        borderColor: foregroundColor,
        label: '#${tag.name}',
        labelSize: 14,
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
        height: (MediaQuery.sizeOf(context).height * 0.78).clamp(420.0, 720.0),
        child: ValueListenableBuilder<bool>(
          valueListenable: widget.isEditingListenable,
          builder: (context, isEditing, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCard(),
                Expanded(
                  child: Stack(
                    children: [
                      _buildSummaryBody(isEditing),
                      // 상단 그림자
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

  Widget _buildUtxoRow(List<UtxoState> rowUtxos, bool isEditing, {double horizontalPadding = 0}) {
    final expandedIndex = rowUtxos.indexWhere((utxo) => utxo.utxoId == _expandedUtxoId);
    final expandedUtxo = expandedIndex >= 0 ? rowUtxos[expandedIndex] : null;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: LayoutBuilder(
            builder: (context, constraints) {
              const totalSpacing = _columnSpacing * (_columnCount - 1);
              final cardSize = (constraints.maxWidth - totalSpacing) / _columnCount;
              return Row(
                children: [
                  for (int column = 0; column < _columnCount; column++) ...[
                    if (column > 0) const SizedBox(width: _columnSpacing),
                    SizedBox(
                      width: cardSize,
                      child:
                          column < rowUtxos.length
                              ? Center(
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  scale: (!isEditing && expandedIndex == column) ? 1.2 : 1,
                                  child: _buildCoinCardWithGlow(
                                    utxo: rowUtxos[column],
                                    cardSize: cardSize,
                                    isExpanded: !isEditing && expandedIndex == column,
                                    child: UtxoCoinCard(
                                      utxo: rowUtxos[column],
                                      size: cardSize,
                                      compact: true,
                                      isFocused: isEditing || _selectedUtxoIds.contains(rowUtxos[column].utxoId),
                                      isSelected: isEditing && _selectedUtxoIds.contains(rowUtxos[column].utxoId),
                                      currentUnit: widget.currentUnit,
                                      isAddressReused: false,
                                      isSuspiciousDust: false,
                                      showSelectedCheckIcon: false,
                                      onTap: () => _handleUtxoTap(rowUtxos[column], isEditing),
                                      dustThreshold: widget.addressType.dustThreshold,
                                    ),
                                  ),
                                ),
                              )
                              : const SizedBox.shrink(),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
        if (!isEditing && expandedUtxo != null)
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: _SelectedUtxoDetailCard(
              utxo: expandedUtxo,
              selectedColumnIndex: expandedIndex,
              rowHorizontalPadding: horizontalPadding,
              columnSpacing: _columnSpacing,
            ),
          ),
      ],
    );
  }
}

class _SelectedUtxoDetailCard extends StatelessWidget {
  final UtxoState utxo;
  final int selectedColumnIndex;
  final double rowHorizontalPadding;
  final double columnSpacing;

  const _SelectedUtxoDetailCard({
    required this.utxo,
    required this.selectedColumnIndex,
    this.rowHorizontalPadding = 0,
    this.columnSpacing = 0,
  });

  @override
  Widget build(BuildContext context) {
    final timestamp = DateTimeUtil.formatTimestamp(utxo.timestamp);
    const horizontalOverflow = 16.0;
    const columnCount = _SelectedUtxosPreviewBottomSheetBodyState._columnCount;

    return LayoutBuilder(
      builder: (context, constraints) {
        final baseWidth =
            constraints.hasBoundedWidth
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width - (horizontalOverflow * 2);
        // 코인 행 레이아웃과 동일한 계산: 좌우 padding과 컬럼 간 간격을 반영한 실제 카드 중앙 좌표.
        final totalSpacing = columnSpacing * (columnCount - 1);
        final cardSize = (baseWidth - (rowHorizontalPadding * 2) - totalSpacing) / columnCount;
        final cardCenter = rowHorizontalPadding + selectedColumnIndex * (cardSize + columnSpacing) + cardSize / 2;
        final arrowLeft = cardCenter - 10;
        final cardWidth = baseWidth + (horizontalOverflow * 2);

        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: SizedBox(
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
            ),
          ),
        );
      },
    );
  }
}

class _SectionSummaryHeader extends StatelessWidget {
  final Widget leading;
  final int utxoCount;

  const _SectionSummaryHeader({required this.leading, required this.utxoCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(0, 4, 12, 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.transparent, CoconutColors.gray800],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: leading),
            const SizedBox(width: 8),
            Text(
              t.merge_utxos_screen.count(n: utxoCount, count: utxoCount),
              style: CoconutTypography.body3_12.setColor(CoconutColors.white),
            ),
          ],
        ),
      ),
    );
  }
}

abstract class _SummaryListItem {
  const _SummaryListItem();
}

class _SummarySpacingItem extends _SummaryListItem {
  final double height;

  const _SummarySpacingItem(this.height);
}

class _SummaryRowItem extends _SummaryListItem {
  final List<UtxoState> rowUtxos;
  final double horizontalPadding;

  const _SummaryRowItem(this.rowUtxos, {this.horizontalPadding = 0});
}

class _SummaryTagHeaderItem extends _SummaryListItem {
  final _TagCombinationSection section;

  const _SummaryTagHeaderItem(this.section);
}

class _SummaryAddressHeaderItem extends _SummaryListItem {
  final _ReusedAddressSection section;

  const _SummaryAddressHeaderItem(this.section);
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
