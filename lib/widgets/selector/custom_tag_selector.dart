import 'package:coconut_wallet/model/utxo_tag.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:flutter/material.dart';

class CustomTagSelector extends StatefulWidget {
  final List<UtxoTag> tags;
  final Function(UtxoTag) onSelectedTag;
  final String? changeSelectedTag;
  const CustomTagSelector({
    super.key,
    required this.tags,
    required this.onSelectedTag,
    this.changeSelectedTag,
  });

  @override
  State<CustomTagSelector> createState() => _CustomTagSelectorState();
}

class _CustomTagSelectorState extends State<CustomTagSelector> {
  String _selectedTag = '';

  @override
  Widget build(BuildContext context) {
    if (_selectedTag.isNotEmpty && _selectedTag != widget.changeSelectedTag) {
      _selectedTag = widget.changeSelectedTag ?? '';
      setState(() {});
    }

    return ListView.builder(
      itemCount: widget.tags.length,
      itemBuilder: (BuildContext context, int index) {
        final utxoTag = widget.tags[index];
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedTag = utxoTag.name;
            });
            widget.onSelectedTag.call(utxoTag);
          },
          child: CustomTagSelectorItem(
            tag: utxoTag.name,
            colorIndex: utxoTag.colorIndex,
            usedCount: utxoTag.utxoIdList?.length ?? 0,
            isSelected: _selectedTag == utxoTag.name,
          ),
        );
      },
    );
  }
}

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
                  fontSize: 12,
                  color: ColorPalette[colorIndex],
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#$tag',
                style: Styles.body1.copyWith(
                  fontSize: 12,
                  color: MyColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Visibility(
                visible: usedCount > 0,
                child: Text(
                  '$usedCount개에 적용',
                  style: Styles.body1
                      .copyWith(fontSize: 10, color: MyColors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
