import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:flutter/material.dart';

/// 핫월렛 생성·복원 화면의 아크 사용 카드
class ArkOptionSection extends StatelessWidget {
  const ArkOptionSection({
    super.key,
    required this.isEnabled,
    required this.autoRefresh,
    required this.onEnabledChanged,
  });

  final bool isEnabled;
  final bool autoRefresh;
  final ValueChanged<bool> onEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: colors.surface, borderRadius: BorderRadius.circular(12)),
      child: SingleButton(
        key: const ValueKey('hot-wallet-use-ark'),
        title: t.ark.option.title,
        titleStyle: CoconutTypography.body1_16_Bold.setColor(colors.primaryText),
        subtitle:
            !isEnabled
                ? t.ark.option.description
                : autoRefresh
                ? t.ark.option.auto_refresh_on
                : t.ark.option.auto_refresh_off,
        isVerticalSubtitle: true,
        subtitleStyle: CoconutTypography.body3_12.setColor(
          isEnabled && !autoRefresh ? colors.dangerText : colors.secondaryText,
        ),
        customPadding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
        onPressed: () => onEnabledChanged(!isEnabled),
        rightElement: CoconutSwitch(
          isOn: isEnabled,
          scale: 0.75,
          activeTrackColor: colors.switchActiveTrack,
          activeThumbColor: colors.switchActiveThumb,
          inactiveTrackColor: colors.switchInactiveTrack,
          inactiveThumbColor: colors.switchInactiveThumb,
          onChanged: onEnabledChanged,
        ),
      ),
    );
  }
}
