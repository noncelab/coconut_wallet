import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SelectionItem<T> {
  final String title;
  final String? subtitle;
  final T value;
  final VoidCallback onTap;

  SelectionItem({
    required this.title,
    this.subtitle,
    required this.value,
    required this.onTap,
  });
}

class SelectionBottomSheet<T> extends StatelessWidget {
  final String title;
  final List<SelectionItem<T>> items;
  final T selectedValue;
  final String? headerText;

  const SelectionBottomSheet({
    super.key,
    required this.title,
    required this.items,
    required this.selectedValue,
    this.headerText,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoconutColors.black,
      appBar: CoconutAppBar.build(
        title: title,
        context: context,
        onBackPressed: null,
        isBottom: true,
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: Sizes.size16, right: Sizes.size16),
        child: Column(
          children: [
            if (headerText != null)
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: Sizes.size8),
                  child: Text(
                    headerText!,
                    style: CoconutTypography.body3_12_Number.setColor(CoconutColors.white),
                  ),
                ),
              ),
            ..._buildItemsWithDividers()
          ],
        ),
      ),
    );
  }

  List<Widget> _buildItemsWithDividers() {
    List<Widget> widgets = [];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isSelected = item.value == selectedValue;

      widgets.add(_buildItem(item, isSelected));

      if (i < items.length - 1) {
        widgets.add(Divider(
          color: CoconutColors.white.withOpacity(0.12),
          height: 1,
        ));
      }
    }

    return widgets;
  }

  Widget _buildItem(SelectionItem<T> item, bool isSelected) {
    return GestureDetector(
      onTap: () {
        vibrateExtraLight();
        item.onTap();
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: Sizes.size20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white),
                  ),
                  if (item.subtitle != null)
                    Text(
                      item.subtitle!,
                      style: CoconutTypography.body3_12_Number.setColor(CoconutColors.white),
                    ),
                ],
              ),
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: Sizes.size8),
                child: SvgPicture.asset('assets/svg/check.svg'),
              ),
          ],
        ),
      ),
    );
  }
}
