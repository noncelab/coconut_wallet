import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selectable_settings_row.dart';
import 'package:flutter/material.dart';

class SelectionItem<T> {
  final String title;
  final String? subtitle;
  final T value;
  final VoidCallback onTap;

  SelectionItem({required this.title, this.subtitle, required this.value, required this.onTap});
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
    final colors = context.coconutColors;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: CoconutAppBar.build(title: title, context: context, onBackPressed: null, isBottom: true),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: Sizes.size16),
        children: [
          if (headerText != null)
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: Sizes.size8),
                child: Text(headerText!, style: CoconutTypography.body3_12_Number.setColor(colors.primaryText)),
              ),
            ),
          ..._buildItemsWithDividers(context),
        ],
      ),
    );
  }

  List<Widget> _buildItemsWithDividers(BuildContext context) {
    List<Widget> widgets = [];

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final isSelected = item.value == selectedValue;

      widgets.add(
        SelectableSettingsRow(title: item.title, subtitle: item.subtitle, isSelected: isSelected, onTap: item.onTap),
      );

      if (i < items.length - 1) {
        widgets.add(Divider(color: context.coconutColors.primaryText.withValues(alpha: 0.12), height: 1));
      }
    }

    return widgets;
  }
}
