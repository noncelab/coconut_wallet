import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

/// [CustomTagHorizontalSelector] : 태그 목록을 보여주고 선택할 수 있는 위젯 (가로)
/// [tags] : 표시할 태그 목록
/// [onSelectedTag]: 태그 선택시 호출되는 콜백
class CustomTagHorizontalSelector extends StatefulWidget {
  final List<String> tags;
  final String selectedName;
  final bool showDefaultTags;
  final Function(String) onSelectedTag;
  final ScrollPhysics? scrollPhysics;
  const CustomTagHorizontalSelector({
    super.key,
    required this.tags,
    required this.selectedName,
    required this.onSelectedTag,
    this.showDefaultTags = true,
    this.scrollPhysics = const AlwaysScrollableScrollPhysics(),
  });

  @override
  State<CustomTagHorizontalSelector> createState() => _CustomTagHorizontalSelectorState();
}

class _CustomTagHorizontalSelectorState extends State<CustomTagHorizontalSelector> {
  late final List<String> _tags;

  @override
  void initState() {
    super.initState();
    if (widget.showDefaultTags) {
      _tags = [t.all, t.utxo_detail_screen.utxo_locked, t.change];
    } else {
      _tags = [t.all];
    }
    _tags.addAll(widget.tags);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: widget.scrollPhysics,
        itemCount: _tags.length,
        itemBuilder: (BuildContext context, int index) {
          final name = _tags[index];
          return Row(
            children: [
              if (index == 0) CoconutLayout.spacing_400w,
              GestureDetector(
                onTap: () {
                  widget.onSelectedTag.call(name);
                },
                child: _tagSelectorChip(
                  index <= 2 ? _tags[index] : '#$name',
                  widget.selectedName == name,
                  index <= 2,
                ),
              ),
              if (index == _tags.length) CoconutLayout.spacing_400w,
            ],
          );
        },
      ),
    );
  }

  Widget _tagSelectorChip(String name, bool isSelected, bool isFixedTag) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(right: 4),
      height: 32,
      decoration: BoxDecoration(
        color: isSelected ? CoconutColors.white : CoconutColors.gray800,
        borderRadius: BorderRadius.circular(16),
      ),
      child: FittedBox(
        child: Text(
          name,
          style: CoconutTypography.body3_12_Number.copyWith(
            color: isSelected ? CoconutColors.gray800 : CoconutColors.white,
            height: 1.3,
            fontWeight: isFixedTag
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
