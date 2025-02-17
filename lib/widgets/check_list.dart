import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';

class ChecklistItem {
  String title;
  bool isChecked;

  ChecklistItem({required this.title, this.isChecked = false});
}

class ChecklistTile extends StatefulWidget {
  final ChecklistItem item;
  final ValueChanged<bool?> onChanged;

  const ChecklistTile({super.key, required this.item, required this.onChanged});

  @override
  State<ChecklistTile> createState() => _ChecklistTileState();
}

class _ChecklistTileState extends State<ChecklistTile> {
  late bool isChecked;

  @override
  void initState() {
    super.initState();
    isChecked = widget.item.isChecked;
  }

  void _checked(bool checked) {
    setState(() {
      isChecked = checked;
      widget.onChanged(isChecked); // 부모 상태 업데이트
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _checked(!isChecked);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoconutCheckbox(
              isSelected: isChecked,
              brightness: Brightness.dark,
              onChanged: _checked,
            ),
            const SizedBox(width: 8), // 체크박스와 텍스트 사이의 가로 간격 조정
            Expanded(
              child: Text(
                widget.item.title,
                style:
                    Styles.label.merge(const TextStyle(color: MyColors.white)),
                textAlign: TextAlign.start,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
