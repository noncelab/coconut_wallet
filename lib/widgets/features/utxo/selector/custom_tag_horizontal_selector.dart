import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_filter.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:flutter/material.dart';

/// [CustomTagHorizontalSelector] : 태그 목록을 보여주고 선택할 수 있는 위젯 (가로)
/// [tags] : 표시할 태그 목록
/// [onSelectedFilter]: 필터 선택시 호출되는 콜백
class CustomTagHorizontalSelector extends StatefulWidget {
  final List<UtxoTag> tags;
  final UtxoFilter selectedFilter;
  final bool showDefaultTags;
  final ValueChanged<UtxoFilter> onSelectedFilter;
  final ScrollPhysics? scrollPhysics;
  const CustomTagHorizontalSelector({
    super.key,
    required this.tags,
    required this.selectedFilter,
    required this.onSelectedFilter,
    this.showDefaultTags = true,
    this.scrollPhysics = const AlwaysScrollableScrollPhysics(),
  });

  @override
  State<CustomTagHorizontalSelector> createState() => _CustomTagHorizontalSelectorState();
}

class _CustomTagHorizontalSelectorState extends State<CustomTagHorizontalSelector> {
  @override
  Widget build(BuildContext context) {
    final items = <({UtxoFilter filter, String text, bool isFixedTag})>[
      (filter: UtxoFilter.all, text: t.all, isFixedTag: true),
      if (widget.showDefaultTags) ...[
        (filter: UtxoFilter.locked, text: t.utxo_detail_screen.utxo_locked, isFixedTag: true),
        (filter: UtxoFilter.change, text: t.change, isFixedTag: true),
      ],
      for (final tag in widget.tags) (filter: UtxoFilter.tag(tag.id), text: '#${tag.name}', isFixedTag: false),
    ];

    return SizedBox(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: widget.scrollPhysics,
        itemCount: items.length,
        itemBuilder: (BuildContext context, int index) {
          final item = items[index];

          return Row(
            children: [
              if (index == 0) CoconutLayout.spacing_400w,
              GestureDetector(
                onTap: () {
                  widget.onSelectedFilter.call(item.filter);
                },
                child: _tagSelectorChip(item.text, widget.selectedFilter == item.filter, item.isFixedTag),
              ),
              if (index == items.length) CoconutLayout.spacing_400w,
            ],
          );
        },
      ),
    );
  }

  Widget _tagSelectorChip(String name, bool isSelected, bool isFixedTag) {
    final colors = context.coconutColors;
    final bgColor = isSelected ? colors.chipSelectedBackground : colors.chipUnselectedBackground;
    final textColor = isSelected ? colors.chipSelectedText : colors.chipUnselectedText;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(right: 4),
      height: 32,
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: FittedBox(
        child: Text(
          name,
          style: CoconutTypography.body3_12_Number.copyWith(
            color: textColor,
            height: 1.3,
            fontWeight:
                isFixedTag
                    ? FontWeight.w400
                    : isSelected
                    ? FontWeight.w700
                    : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
