import 'package:flutter/material.dart';
import 'package:coconut_wallet/ui/coconut/coconut_checklist_tile.dart';

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

  @override
  Widget build(BuildContext context) {
    return CoconutChecklistTile(
      title: widget.item.title,
      isChecked: isChecked,
      onChanged: (value) {
        setState(() {
          isChecked = value ?? false;
          widget.onChanged(isChecked);
        });
      },
    );
  }
}
