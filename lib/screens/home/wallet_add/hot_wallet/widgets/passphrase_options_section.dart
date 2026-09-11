import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/common/buttons/single_button.dart';
import 'package:flutter/material.dart';

class PassphraseOptionsSection extends StatelessWidget {
  const PassphraseOptionsSection({
    super.key,
    required this.isEnabled,
    required this.onEnabledChanged,
    required this.options,
  });

  final bool isEnabled;
  final ValueChanged<bool> onEnabledChanged;
  final Widget options;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleButton(
          title: t.wallet_home_screen.hot_wallet_create.use_passphrase,
          subtitle: t.wallet_home_screen.hot_wallet_create.passphrase_description,
          isVerticalSubtitle: true,
          subtitleStyle: CoconutTypography.body3_12.setColor(context.coconutColors.secondaryText),
          customPadding: EdgeInsets.zero,
          backgroundColor: context.coconutColors.background,
          onPressed: () => onEnabledChanged(!isEnabled),
          rightElement: CoconutSwitch(
            isOn: isEnabled,
            scale: 0.75,
            activeTrackColor: context.coconutColors.switchActiveTrack,
            activeThumbColor: context.coconutColors.switchActiveThumb,
            inactiveTrackColor: context.coconutColors.switchInactiveTrack,
            inactiveThumbColor: context.coconutColors.switchInactiveThumb,
            onChanged: onEnabledChanged,
          ),
        ),
        if (isEnabled) ...[const SizedBox(height: 8), options],
      ],
    );
  }
}
