import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/text/label_value_row.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

/// 카드 안에서 값 하나를 보여 주고, 누르면 그 값을 고르는 시트를 여는 줄(날짜·시각·요일 같은 값).
/// 이름과 값이 한 줄에 들어가지 않으면 값을 다음 줄로 내린다. 단어 중간에서 끊지 않는다.
/// 누르는 높이는 글자 크기와 상관없이 48 이상이다.
class ValueSelectRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  final VoidCallback onPressed;

  /// 값 글자의 key(테스트에서 값만 찾을 때)
  final Key? valueKey;

  /// 줄 바탕. 없으면 홈 화면 바탕색(카드 안의 회색 칸)
  final Color? backgroundColor;

  const ValueSelectRow({
    super.key,
    required this.label,
    required this.value,
    required this.onPressed,
    this.icon,
    this.valueKey,
    this.backgroundColor,
  });

  static const minHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Semantics(
      button: true,
      label: label,
      value: value,
      onTap: onPressed,
      excludeSemantics: true,
      // 모양·눌림 색은 모으기 계획의 지금 날짜 줄과 같다(바탕 홈 배경, 모서리 10, 누르면 primaryText 16%)
      child: ShrinkAnimationButton(
        onPressed: onPressed,
        defaultColor: backgroundColor ?? colors.homeBackground,
        pressedOverlayColor: colors.primaryText,
        pressedOverlayOpacity: 0.16,
        borderRadius: 10,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: colors.secondaryTextStrong),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  // 이름은 왼쪽, 값은 오른쪽. 함께 안 들어가면 값이 이름 아래 줄로 간다.
                  child: LabelValueRow(
                    label: label,
                    labelStyle: CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong),
                    value: value,
                    valueStyle: CoconutTypography.body3_12_Bold.copyWith(color: colors.primaryText),
                    valueKey: valueKey,
                    gap: 8,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(CupertinoIcons.chevron_right, size: 14, color: colors.tertiaryText),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
