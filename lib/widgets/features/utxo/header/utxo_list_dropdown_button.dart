import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/loading/loading_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';

/// UTXO 목록 헤더/스티키 헤더/선택 모드 헤더에서 공용으로 쓰는 정렬 드롭다운 트리거.
///
/// [isEnabled]가 false면 로딩 인디케이터를 보여주고 버튼을 비활성화한다.
/// [alignRight]가 true면(기본값) 남는 공간을 오른쪽으로 밀어 우측 정렬하고,
/// false면 다른 위젯과 나란히 놓일 수 있도록 내용 크기만큼만 차지한다.
class UtxoListDropdownButton extends StatelessWidget {
  final GlobalKey dropdownGlobalKey;
  final String activeOption;
  final bool isEnabled;
  final VoidCallback onTapDropdown;
  final bool alignRight;

  const UtxoListDropdownButton({
    super.key,
    required this.dropdownGlobalKey,
    required this.activeOption,
    required this.isEnabled,
    required this.onTapDropdown,
    this.alignRight = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return Row(
      mainAxisSize: alignRight ? MainAxisSize.max : MainAxisSize.min,
      children: [
        if (alignRight) const Spacer(),
        if (!isEnabled)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: SizedBox(
              width: 14,
              height: 14,
              child: InlineLoadingIndicator(padding: EdgeInsets.zero, color: colors.secondaryText, radius: 8),
            ),
          ),
        CupertinoButton(
          key: dropdownGlobalKey,
          padding: const EdgeInsets.only(top: 7, bottom: 7),
          minSize: 0,
          onPressed: isEnabled ? onTapDropdown : null,
          child: Row(
            children: [
              Text(
                activeOption,
                style: CoconutTypography.body3_12.setColor(isEnabled ? colors.primaryText : colors.mutedText),
              ),
              CoconutLayout.spacing_200w,
              SvgPicture.asset(
                CommonNavigationIconPath.arrowDown,
                colorFilter: ColorFilter.mode(isEnabled ? colors.iconPrimary : colors.iconDisabled, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
