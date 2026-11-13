import 'dart:math' as math;

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/common/text/keep_words.dart';
import 'package:coconut_wallet/widgets/common/text/label_value_row.dart';
import 'package:flutter/material.dart';

/// 카드 안의 짧은 안내 한 칸: 아이콘 + 안내 글(+ 바로 할 수 있는 동작 하나).
/// 안내 글과 동작 버튼이 한 줄에 들어가면 나란히, 안 들어가면 버튼을 안내 글 아래로 내린다.
/// 긴 언어·큰 글자에서도 안내 글이 좁아져 글자 단위로 쪼개지지 않는다. 동작 버튼의 누르는 높이는 44 이상이다.
/// 아이콘은 늘 안내 글 첫 줄의 세로 가운데에 둔다.
class InlineNotice extends StatelessWidget {
  final IconData icon;
  final String message;

  /// 아이콘 색. 없으면 보조 글자색(상태 색이 필요한 곳만 넘긴다)
  final Color? iconColor;

  /// 아이콘 칸의 key(아이콘이 첫 줄에 맞는지 테스트할 때)
  final Key? iconKey;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Key? actionKey;

  /// 안내 칸 바탕. 없으면 홈 화면 바탕색(카드 안의 회색 칸). 바탕 없이 쓰려면 투명색
  final Color? backgroundColor;

  const InlineNotice({
    super.key,
    required this.icon,
    required this.message,
    this.iconColor,
    this.iconKey,
    this.actionLabel,
    this.onAction,
    this.actionKey,
    this.backgroundColor,
  });

  static const actionMinHeight = 44.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final style = CoconutTypography.body3_12.copyWith(color: colors.secondaryTextStrong);
    final background = backgroundColor ?? colors.homeBackground;
    final padded = background.a > 0;
    // 아이콘을 안내 글 첫 줄의 세로 가운데에 맞춘다(글자 크기 설정과 상관없이)
    final iconBox = SizedBox(
      key: iconKey,
      height: LabelValueRow.lineHeightOf(context, style),
      child: Center(child: Icon(icon, size: 16, color: iconColor ?? colors.secondaryTextStrong)),
    );
    // 줄바꿈 막기는 보이는 글에만 하고, 화면 읽기에는 원문을 넘긴다.
    final messageRow = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        iconBox,
        const SizedBox(width: 8),
        Expanded(child: Text(keepWords(message), semanticsLabel: message, style: style)),
      ],
    );
    final hasAction = actionLabel != null && onAction != null;
    final actionStyle = CoconutTypography.body3_12_Bold.copyWith(color: colors.primaryText);
    return Container(
      padding: padded ? const EdgeInsets.fromLTRB(14, 12, 14, 12) : EdgeInsets.zero,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 버튼을 옆에 둬도 안내 글 칸이 넉넉하면(폭의 45% 이상, 최소 110) 한 줄로 나란히 둔다.
          // 지금 쓰는 안내 글(권한 꺼짐 등) 기준의 값이다. 좁으면 버튼을 아래로 내린다.
          final messageArea =
              constraints.maxWidth -
              16 -
              8 -
              12 -
              (hasAction ? LabelValueRow.widthOf(context, actionLabel!, actionStyle) + 28 : 0);
          final oneLine = hasAction && messageArea >= math.max(110, constraints.maxWidth * 0.45);
          if (oneLine) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [Expanded(child: messageRow), const SizedBox(width: 12), _action(context, actionStyle)],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              messageRow,
              if (hasAction) ...[
                const SizedBox(height: 8),
                Align(alignment: AlignmentDirectional.centerEnd, child: _action(context, actionStyle)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _action(BuildContext context, TextStyle actionStyle) {
    final colors = context.coconutColors;
    return ShrinkAnimationButton(
      key: actionKey,
      onPressed: onAction!,
      defaultColor: colors.homeSurface,
      pressedOverlayColor: colors.homeSurfacePressOverlay,
      pressedOverlayOpacity: colors.homeSurfacePressOverlayOpacity,
      borderRadius: 10,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: actionMinHeight),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Center(widthFactor: 1, child: Text(actionLabel!, textAlign: TextAlign.center, style: actionStyle)),
        ),
      ),
    );
  }
}
