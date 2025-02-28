import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/model/utxo/utxo_tag.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:flutter/material.dart';

/// [CustomTagVerticalSelector] : 태그 목록을 보여주고 선택할 수 있는 위젯 (세로)
/// [tags] : 표시할 태그 목록
/// [onSelectedTag] : 태그 선택시 호출되는 콜백
/// [externalUpdatedTagName] : 선택된 태그명이 외부에서 변경되었을 때 선택 상태를 업데이트 ????
class CustomTagVerticalSelector extends StatefulWidget {
  final List<UtxoTag> tags;
  final Function(UtxoTag?) onSelectedTag;
  final String? externalUpdatedTagName;
  const CustomTagVerticalSelector({
    super.key,
    required this.tags,
    required this.onSelectedTag,
    this.externalUpdatedTagName,
  });

  @override
  State<CustomTagVerticalSelector> createState() =>
      _CustomTagVerticalSelectorState();
}

class _CustomTagVerticalSelectorState extends State<CustomTagVerticalSelector> {
  String _selectedTagName = '';
  int _selectedTagIndex = -1;

  @override
  void initState() {
    super.initState();
    // 초기 상태 설정: 외부에서 전달된 태그명을 반영
    _selectedTagName = widget.externalUpdatedTagName ?? '';
  }

  @override
  void didUpdateWidget(covariant CustomTagVerticalSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 외부 태그명이 변경되었을 경우 상태 업데이트
    if (widget.externalUpdatedTagName != oldWidget.externalUpdatedTagName &&
        widget.externalUpdatedTagName != _selectedTagName) {
      setState(() {
        _selectedTagName = widget.externalUpdatedTagName ?? '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.tags.length,
      itemBuilder: (BuildContext context, int index) {
        final utxoTag = widget.tags[index];
        return GestureDetector(
          onTap: () {
            if (_selectedTagName != utxoTag.name) {
              _selectedTagName = utxoTag.name;
              _selectedTagIndex = utxoTag.colorIndex;
              widget.onSelectedTag.call(utxoTag);
            } else {
              _selectedTagName = '';
              _selectedTagIndex = -1;
              widget.onSelectedTag.call(null);
            }
            setState(() {});
          },
          child: CustomTagSelectorItem(
            key: ValueKey(utxoTag.id),
            tag: utxoTag.name,
            colorIndex: utxoTag.colorIndex,
            usedCount: utxoTag.utxoIdList?.length ?? 0,
            isSelected: _selectedTagName == utxoTag.name &&
                _selectedTagIndex == utxoTag.colorIndex,
          ),
        );
      },
    );
  }
}

/// [CustomTagSelectorItem] : 개별 태그 아이템을 표시하는 위젯
/// [tag] : 태그명
/// [colorIndex] : 색상 인덱스
/// [usedCount] : 태그가 사용된 항목 수
/// [isSelected] : 선택 여부
class CustomTagSelectorItem extends StatelessWidget {
  final String tag;
  final int colorIndex;
  final int usedCount;
  final bool isSelected;

  const CustomTagSelectorItem({
    super.key,
    required this.tag,
    required this.colorIndex,
    required this.usedCount,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          EdgeInsets.symmetric(vertical: 11, horizontal: isSelected ? 10 : 0),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: isSelected ? MyColors.selectBackground : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: BackgroundColorPalette[colorIndex],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: ColorPalette[colorIndex],
                width: 1,
              ),
            ),
            child: Center(
              child: Text(
                '#',
                style: Styles.body1.copyWith(
                  fontSize: 14,
                  color: ColorPalette[colorIndex],
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '#$tag',
                  style: Styles.body1.copyWith(
                    fontSize: 14,
                    color: MyColors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Visibility(
                  visible: usedCount > 0,
                  child: Text(
                    t.apply_item(count: usedCount),
                    style: Styles.body1
                        .copyWith(fontSize: 11, color: MyColors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
