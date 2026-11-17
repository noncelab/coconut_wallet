import 'package:coconut_design_system/coconut_design_system.dart' hide CoconutAppBar;
import 'package:coconut_wallet/ui/coconut/coconut_app_bar.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/bottom_sheet/selectable_settings_row.dart';
import 'package:flutter/material.dart';

class SelectionItem<T> {
  final String title;
  final TextStyle? titleStyle;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final T value;
  final VoidCallback onTap;
  final String? sectionTitle;

  SelectionItem({
    required this.title,
    this.titleStyle,
    this.subtitle,
    this.subtitleStyle,
    required this.value,
    required this.onTap,
    this.sectionTitle,
  });
}

class SelectionBottomSheet<T> extends StatelessWidget {
  final String title;
  final List<SelectionItem<T>> items;
  final T selectedValue;
  final String? headerText;
  final ScrollController? scrollController;
  final bool showAppBar;

  const SelectionBottomSheet({
    super.key,
    required this.title,
    required this.items,
    required this.selectedValue,
    this.headerText,
    this.scrollController,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    // 목록을 끝까지 내려도 마지막 줄이 아래 시스템 영역(탐색 막대·홈 표시줄)에 가리지 않게 그만큼 띄운다.
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: colors.background,
      appBar:
          showAppBar ? CoconutAppBar.build(title: title, context: context, onBackPressed: null, isBottom: true) : null,
      body: ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(Sizes.size16, 0, Sizes.size16, bottomInset),
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

      final sectionTitle = item.sectionTitle;
      if (sectionTitle != null) {
        widgets.add(
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? Sizes.size8 : Sizes.size24, bottom: Sizes.size4),
            child: Text(sectionTitle, style: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText)),
          ),
        );
      } else if (i > 0) {
        widgets.add(Divider(color: context.coconutColors.primaryText.withValues(alpha: 0.12), height: 1));
      }

      widgets.add(
        SelectableSettingsRow(
          title: item.title,
          titleStyle: item.titleStyle,
          subtitle: item.subtitle,
          subtitleStyle: item.subtitleStyle,
          isSelected: isSelected,
          onTap: item.onTap,
        ),
      );
    }

    return widgets;
  }
}
