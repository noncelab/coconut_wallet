import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/providers/preferences/preference_provider.dart';
import 'package:coconut_wallet/utils/utxo_tier_theme.dart';
import 'package:coconut_wallet/utils/vibration_util.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class UtxoTierThemeBottomSheet extends StatelessWidget {
  const UtxoTierThemeBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<PreferenceProvider, UtxoTierTheme>(
      selector: (_, provider) => provider.utxoTierTheme,
      builder: (context, currentTheme, child) {
        return Scaffold(
          backgroundColor: CoconutColors.black,
          appBar: CoconutAppBar.build(
            title: t.settings_screen.utxo_tier_theme,
            context: context,
            onBackPressed: null,
            isBottom: true,
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.only(left: Sizes.size16, right: Sizes.size16, bottom: 80),
              child: Column(mainAxisSize: MainAxisSize.min, children: _buildItemsWithDividers(context, currentTheme)),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildItemsWithDividers(BuildContext context, UtxoTierTheme currentTheme) {
    final widgets = <Widget>[];
    const themes = UtxoTierThemes.all;
    for (var i = 0; i < themes.length; i++) {
      widgets.add(_buildItem(context, themes[i], currentTheme));
      if (i < themes.length - 1) {
        widgets.add(Divider(color: CoconutColors.white.withValues(alpha: 0.12), height: 1));
      }
    }
    return widgets;
  }

  Widget _buildItem(BuildContext context, UtxoTierTheme theme, UtxoTierTheme currentTheme) {
    final isSelected = currentTheme.id == theme.id;
    return GestureDetector(
      onTap: () {
        vibrateExtraLight();
        context.read<PreferenceProvider>().changeUtxoTierTheme(theme);
        Navigator.of(context).pop();
      },
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: Sizes.size20),
        child: Row(
          children: [
            _ThemeSwatchStrip(theme: theme),
            const SizedBox(width: 16),
            Expanded(child: Text(theme.name, style: CoconutTypography.body2_14_Bold.setColor(CoconutColors.white))),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(right: Sizes.size8),
                child: SvgPicture.asset('assets/svg/check.svg'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatchStrip extends StatelessWidget {
  final UtxoTierTheme theme;

  const _ThemeSwatchStrip({required this.theme});

  static const _tiers = [
    UtxoTier.whale,
    UtxoTier.whole,
    UtxoTier.huge,
    UtxoTier.large,
    UtxoTier.medium,
    UtxoTier.small,
    UtxoTier.tiny,
    UtxoTier.dust,
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children:
          _tiers.map((tier) {
            return Container(
              width: 8,
              height: 24,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(color: theme.bg(tier), borderRadius: BorderRadius.circular(2)),
            );
          }).toList(),
    );
  }
}
