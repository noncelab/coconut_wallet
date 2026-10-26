import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/model/home/home_widget_settings.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class BalanceHistoryPeriodChips extends StatelessWidget {
  final HomeWidgetPeriod selected;
  final ValueChanged<HomeWidgetPeriod> onSelected;

  /// 칩 묶음 바탕. 없으면 화면 바탕색.
  final Color? backgroundColor;
  final Color? itemBackgroundColor;

  const BalanceHistoryPeriodChips({
    super.key,
    required this.selected,
    required this.onSelected,
    this.backgroundColor,
    this.itemBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.homeBackground,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: selected.index.toDouble()),
        duration:
            MediaQuery.disableAnimationsOf(context) || MediaQuery.accessibleNavigationOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder:
            (context, position, child) => _PeriodChipBackground(
              position: position,
              selectedColor: colors.primaryText,
              itemColor: itemBackgroundColor,
              child: child!,
            ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final period in HomeWidgetPeriod.values)
              GestureDetector(
                key: ValueKey('hodl-insights-period-${period.name}'),
                behavior: HitTestBehavior.opaque,
                onTap: () => onSelected(period),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      ),
    );
  }
}

class _PeriodChipBackground extends SingleChildRenderObjectWidget {
  final double position;
  final Color selectedColor;
  final Color? itemColor;

  const _PeriodChipBackground({
    required this.position,
    required this.selectedColor,
    required this.itemColor,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPeriodChipBackground(position, selectedColor, itemColor);

  @override
  void updateRenderObject(BuildContext context, _RenderPeriodChipBackground renderObject) {
    renderObject
      ..position = position
      ..selectedColor = selectedColor
      ..itemColor = itemColor
      ..markNeedsPaint();
  }
}

class _RenderPeriodChipBackground extends RenderProxyBox {
  double position;
  Color selectedColor;
  Color? itemColor;

  _RenderPeriodChipBackground(this.position, this.selectedColor, this.itemColor);

  @override
  void paint(PaintingContext context, Offset offset) {
    final row = child! as RenderFlex;
    final rects = <Rect>[];
    final paint = Paint();
    // Use laid-out chip bounds so translated labels and font scaling keep their original geometry.
    for (RenderBox? chip = row.firstChild; chip != null; chip = row.childAfter(chip)) {
      final rect = (chip.parentData! as FlexParentData).offset & chip.size;
      rects.add(rect);
    }
    final value = position.clamp(0.0, rects.length - 1.0);
    final selectedRect = Rect.lerp(rects[value.floor()], rects[value.ceil()], value - value.floor())!;
    if (itemColor != null) {
      for (final rect in rects) {
        if (rect == selectedRect) continue;
        context.canvas.drawRRect(
          RRect.fromRectAndRadius(rect.shift(offset), const Radius.circular(8)),
          paint..color = itemColor!,
        );
      }
    }
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(selectedRect.shift(offset), const Radius.circular(8)),
      paint..color = selectedColor,
    );
    super.paint(context, offset);
  }
}
