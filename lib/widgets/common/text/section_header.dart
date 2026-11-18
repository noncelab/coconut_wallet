import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:flutter/material.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 구역 제목. [onMore]가 있으면 오른쪽에 "더보기"를 두고, [moreEnabled]가 false면 흐리게 두고 누를 수 없게 한다.
class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onMore, this.moreEnabled = true});

  final String title;
  final VoidCallback? onMore;
  final bool moreEnabled;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final headerKey = key;
    final moreColor = moreEnabled ? colors.primaryText : colors.mutedText;
    final more = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Text(t.view_more, style: CoconutTypography.body2_14.setColor(moreColor)),
          const SizedBox(width: 6),
          SvgPicture.asset(
            CommonNavigationIconPath.arrowRight,
            width: 7,
            height: 12,
            colorFilter: ColorFilter.mode(moreColor, BlendMode.srcIn),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 6),
      child: Row(
        children: [
          Expanded(child: Text(title, style: CoconutTypography.heading4_18_Bold.setColor(colors.primaryText))),
          if (onMore != null)
            Semantics(
              button: true,
              enabled: moreEnabled,
              child: Transform.translate(
                offset: const Offset(8, 0),
                child: switch (moreEnabled) {
                  true => HomePressableRow(
                    key: headerKey == null ? null : ValueKey(('more', headerKey)),
                    onTap: onMore!,
                    child: more,
                  ),
                  false => KeyedSubtree(key: headerKey == null ? null : ValueKey(('more', headerKey)), child: more),
                },
              ),
            ),
        ],
      ),
    );
  }
}
