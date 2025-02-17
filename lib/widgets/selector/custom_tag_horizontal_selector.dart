import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';

/// [CustomTagHorizontalSelector] : 태그 목록을 보여주고 선택할 수 있는 위젯 (가로)
/// [tags] : 표시할 태그 목록
/// [onSelectedTag]: 태그 선택시 호출되는 콜백
class CustomTagHorizontalSelector extends StatefulWidget {
  final List<String> tags;
  final Function(String) onSelectedTag;
  const CustomTagHorizontalSelector({
    super.key,
    required this.tags,
    required this.onSelectedTag,
  });

  @override
  State<CustomTagHorizontalSelector> createState() =>
      _CustomTagHorizontalSelectorState();
}

class _CustomTagHorizontalSelectorState
    extends State<CustomTagHorizontalSelector> {
  String _selectedTagName = '전체';

  final List<String> _tags = ['전체'];

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
        itemCount: _tags.length,
        itemBuilder: (BuildContext context, int index) {
          final name = _tags[index];
          final isSelected = _selectedTagName == name;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTagName = name;
              });
              widget.onSelectedTag.call(name);
            },
            child: Container(
              margin: const EdgeInsets.only(right: 4),
              child: CoconutChip(
                color: isSelected ? CoconutColors.white : CoconutColors.gray800,
                borderWidth: 0,
                padding: const EdgeInsets.only(left: 12, right: 12, top: 6),
                child: Text(
                  name,
                  style: CoconutTypography.body3_12.copyWith(
                    color: !isSelected
                        ? CoconutColors.white
                        : CoconutColors.gray800,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
