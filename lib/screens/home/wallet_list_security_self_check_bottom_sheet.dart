import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/styles.dart';
import 'package:coconut_wallet/widgets/appbar/custom_appbar.dart';
import 'package:coconut_wallet/widgets/check_list.dart';

class SecuritySelfCheckBottomSheet extends StatefulWidget {
  final VoidCallback? onNextPressed;

  const SecuritySelfCheckBottomSheet({
    super.key,
    this.onNextPressed,
  });

  @override
  State<SecuritySelfCheckBottomSheet> createState() =>
      _SecuritySelfCheckBottomSheetState();
}

class _SecuritySelfCheckBottomSheetState
    extends State<SecuritySelfCheckBottomSheet> {
  final List<ChecklistItem> _items = [
    ChecklistItem(title: t.security_self_check_bottom_sheet.check1),
    ChecklistItem(title: t.security_self_check_bottom_sheet.check2),
    ChecklistItem(title: t.security_self_check_bottom_sheet.check3),
    ChecklistItem(title: t.security_self_check_bottom_sheet.check4),
    ChecklistItem(title: t.security_self_check_bottom_sheet.check5),
    ChecklistItem(title: t.security_self_check_bottom_sheet.check6),
    ChecklistItem(title: t.security_self_check_bottom_sheet.check7),
    ChecklistItem(title: t.security_self_check_bottom_sheet.check8),
    ChecklistItem(title: t.security_self_check_bottom_sheet.check9),
  ];

  // bool get _allItemsChecked {
  //   return _items.every((item) => item.isChecked);
  // }

  void _onChecklistItemChanged(bool? value, int index) {
    setState(() {
      _items[index].isChecked = value ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MyColors.black,
      appBar: CustomAppBar.build(
        title: t.self_security_check,
        context: context,
        onBackPressed: null,
        hasRightIcon: false,
        isBottom: true,
        showTestnetLabel: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecorations.boxDecoration,
                    child: Text(
                      t.security_self_check_bottom_sheet.guidance,
                      style: Styles.subLabel.merge(const TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.white)),
                    )),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  const double itemHeight = 40.0;
                  final double totalHeight = _items.length * itemHeight;
                  final bool needScrolling =
                      totalHeight > constraints.maxHeight;

                  return needScrolling
                      ? SingleChildScrollView(
                          child: Column(
                            children: _items.asMap().entries.map((entry) {
                              int index = entry.key;
                              ChecklistItem item = entry.value;
                              return ChecklistTile(
                                item: item,
                                onChanged: (bool? value) {
                                  _onChecklistItemChanged(value, index);
                                },
                              );
                            }).toList(),
                          ),
                        )
                      : Column(
                          children: _items.asMap().entries.map((entry) {
                            int index = entry.key;
                            ChecklistItem item = entry.value;
                            return ChecklistTile(
                              item: item,
                              onChanged: (bool? value) {
                                _onChecklistItemChanged(value, index);
                              },
                            );
                          }).toList(),
                        );
                },
              )
            ]),
          ),
        ),
      ),
    );
  }
}
