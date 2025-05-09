import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';

/// [CustomTagHorizontalSelector] : 태그 목록을 보여주고 선택할 수 있는 위젯 (가로)
/// [tags] : 표시할 태그 목록
/// [onSelectedTag]: 태그 선택시 호출되는 콜백
class CustomTagHorizontalSelector extends StatefulWidget {
  final List<String> tags;
  final String selectedName;
  final Function(String) onSelectedTag;
  final ScrollPhysics? scrollPhysics;
  const CustomTagHorizontalSelector({
    super.key,
    required this.tags,
    required this.selectedName,
    required this.onSelectedTag,
    this.scrollPhysics = const AlwaysScrollableScrollPhysics(),
  });

  @override
  State<CustomTagHorizontalSelector> createState() => _CustomTagHorizontalSelectorState();
}

class _CustomTagHorizontalSelectorState extends State<CustomTagHorizontalSelector> {
  final List<String> _tags = [t.all];

  @override
  void initState() {
    super.initState();
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
                child: _tagSelectorChip(index == 0 ? t.all : '#$name', widget.selectedName == name),
              ),
              if (index == _tags.length) CoconutLayout.spacing_400w,
            ],
          );
        },
      ),
    );
  }

  Widget _tagSelectorChip(String name, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.only(right: 4),
      height: 32,
      decoration: BoxDecoration(
        color: isSelected ? CoconutColors.white : CoconutColors.gray800,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        name,
        style: CoconutTypography.body3_12_Number.copyWith(
          color: isSelected ? CoconutColors.gray800 : CoconutColors.white,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    );
  }
}
