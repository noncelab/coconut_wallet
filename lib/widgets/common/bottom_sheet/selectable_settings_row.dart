import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 설정류 바텀싯(테마/단위/화폐/언어)에서 공통으로 쓰는 선택 가능한 행
///
/// title은 필수, subtitle은 선택, 선택된 상태에서 오른쪽에 체크 아이콘이 붙는다.
/// 터치 시 배경색 변화와 shrink 효과까지 이 위젯이 책임진다.
class SelectableSettingsRow extends StatelessWidget {
  const SelectableSettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleStyle,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final TextStyle? subtitleStyle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ShrinkAnimationButton(
      onPressed: () {
        vibrateExtraLight();
        onTap();
      },
      defaultColor: Colors.transparent,
      borderRadius: 0,
      borderWidth: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Sizes.size20),
        child: SelectableSettingsRowContent(
          title: title,
          subtitle: subtitle,
          subtitleStyle: subtitleStyle,
          isSelected: isSelected,
        ),
      ),
    );
  }
}

/// [SelectableSettingsRow]의 시각적 내용(제목/부제목/체크 아이콘)만 분리한 위젯
///
/// 스와이프 삭제처럼 탭 제스처를 직접 관리해야 하는 특수한 행(예: 코코넛 과육 테마 행)에서
/// 제스처 래퍼 없이 동일한 레이아웃만 재사용하고 싶을 때 쓴다.
class SelectableSettingsRowContent extends StatelessWidget {
  const SelectableSettingsRowContent({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleStyle,
    required this.isSelected,
  });

  final String title;
  final String? subtitle;

  // 지정하지 않으면 기본값(body3_12_Number/primaryText Color)을 쓴다.
  final TextStyle? subtitleStyle;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CoconutTypography.body2_14_Bold.setColor(colors.primaryText)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: subtitleStyle ?? CoconutTypography.body3_12_Number.setColor(colors.primaryText),
                  ),
              ],
            ),
          ),
        ),
        if (isSelected)
          Padding(
            padding: const EdgeInsets.only(right: Sizes.size8),
            child: SvgPicture.asset(
              CommonActionIconPath.check,
              colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
            ),
          ),
      ],
    );
  }
}
