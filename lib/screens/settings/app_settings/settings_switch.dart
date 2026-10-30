import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:flutter/widgets.dart';

class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch({super.key, required this.isOn, required this.onChanged});

  final bool isOn;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: CoconutSwitch(
        isOn: isOn,
        activeTrackColor: colors.switchActiveTrack,
        activeThumbColor: colors.switchActiveThumb,
        inactiveTrackColor: colors.switchInactiveTrack,
        inactiveThumbColor: colors.switchInactiveThumb,
        onChanged: onChanged,
        scale: 0.75,
      ),
    );
  }
}
