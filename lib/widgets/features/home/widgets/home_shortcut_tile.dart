import 'dart:math';

import 'package:coconut_design_system/coconut_design_system.dart' show CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 홈 바로가기 칸. 가운데 아이콘과 아래 이름, 아이콘이 없으면 이름만. 작은 아이콘도 24 자리를 차지해 이름 줄이 칸마다 같음
class HomeShortcutTile extends StatelessWidget {
  const HomeShortcutTile({
    super.key,
    required this.id,
    required this.label,
    required this.onPressed,
    this.iconPath,
    this.iconScale = 1,
  });

  /// 안쪽 위젯 키에 붙는 이름
  final String id;
  final String label;
  final String? iconPath;
  final double iconScale;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final iconPath = this.iconPath;
    final labelText = Text(
      label,
      textAlign: TextAlign.center,
      style: CoconutTypography.body3_12.copyWith(color: colors.primaryText),
    );
    return DecoratedBox(
      key: ValueKey('shortcut-background-$id'),
      decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(16)),
      child: SizedBox.expand(
        child: CupertinoButton(
          padding: const EdgeInsets.all(4),
          onPressed: onPressed,
          child:
              iconPath == null
                  ? FittedBox(fit: BoxFit.scaleDown, child: labelText)
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox.square(
                        dimension: 24 * max(1, iconScale),
                        child: Center(
                          child: SvgPicture.asset(
                            iconPath,
                            key: ValueKey('shortcut-icon-$id'),
                            width: 24 * iconScale,
                            height: 24 * iconScale,
                            colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: labelText)),
                    ],
                  ),
        ),
      ),
    );
  }
}
