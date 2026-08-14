import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/widgets/common/loading/loading_indicator.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';

/// UTXO 목록 헤더/스티키 헤더에서 공용으로 쓰는 정렬 드롭다운 트리거.
///
/// [isEnabled]가 false면 로딩 인디케이터를 보여주고 버튼을 비활성화한다.
class UtxoListDropdownButton extends StatelessWidget {
  final GlobalKey dropdownGlobalKey;
  final String activeOption;
  final bool isEnabled;
  final VoidCallback onTapDropdown;

  const UtxoListDropdownButton({
    super.key,
    required this.dropdownGlobalKey,
    required this.activeOption,
    required this.isEnabled,
    required this.onTapDropdown,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;

    return Row(
      children: [
        const Spacer(),
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
