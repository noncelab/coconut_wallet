import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:flutter/material.dart';

class BalanceHistoryPeriodChips extends StatelessWidget {
  final HomeWidgetPeriod selected;
  final ValueChanged<HomeWidgetPeriod> onSelected;

  /// 칩 묶음 바탕. 없으면 화면 바탕색.
  final Color? backgroundColor;

  const BalanceHistoryPeriodChips({super.key, required this.selected, required this.onSelected, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.homeBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final period in HomeWidgetPeriod.values)
            GestureDetector(
              key: ValueKey('hodl-insights-period-${period.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelected(period),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: period == selected ? colors.primaryText : null,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  homePeriodLabel(period),
                  style: CoconutTypography.caption_10.copyWith(
                    color: period == selected ? colors.background : colors.tertiaryText,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
