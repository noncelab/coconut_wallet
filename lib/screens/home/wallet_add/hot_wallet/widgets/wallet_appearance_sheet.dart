import 'package:coconut_design_system/coconut_design_system.dart';
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/utils/custom_wallet_icons.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WalletAppearanceSelection {
  const WalletAppearanceSelection({required this.colorIndex, required this.iconIndex});

  final int colorIndex;
  final int iconIndex;
}

class WalletAppearanceSheet extends StatefulWidget {
  const WalletAppearanceSheet({
    super.key,
    required this.walletName,
    required this.initialColorIndex,
    required this.initialIconIndex,
    required this.onDone,
  });

  final String walletName;
  final int initialColorIndex;
  final int initialIconIndex;
  final ValueChanged<WalletAppearanceSelection> onDone;

  @override
  State<WalletAppearanceSheet> createState() => _WalletAppearanceSheetState();
}

class _WalletAppearanceSheetState extends State<WalletAppearanceSheet> {
  late int _colorIndex = widget.initialColorIndex;
  late int _iconIndex = widget.initialIconIndex;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.65,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _preview(),
                    CoconutLayout.spacing_500h,
                    _title(t.wallet_home_screen.hot_wallet_create.color),
                    CoconutLayout.spacing_200h,
                    _colorPalette(),
                    CoconutLayout.spacing_500h,
                    _title(t.wallet_home_screen.hot_wallet_create.icon),
                    CoconutLayout.spacing_200h,
                    _iconPalette(),
                    CoconutLayout.spacing_300h,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SizedBox(
                width: double.infinity,
                child: ShrinkAnimationButton(
                  onPressed:
                      () => widget.onDone(WalletAppearanceSelection(colorIndex: _colorIndex, iconIndex: _iconIndex)),
                  defaultColor: context.coconutColors.buttonPrimaryBackground,
                  pressedColor: context.coconutColors.buttonPrimaryPressOverlay,
                  borderRadius: CoconutStyles.radius_200,
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: Text(
                        t.done,
                        style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.buttonPrimaryForeground),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _title(String text) =>
      Text(text, style: CoconutTypography.body2_14.setColor(context.coconutColors.secondaryText));

  Widget _preview() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.coconutColors.surface,
      borderRadius: BorderRadius.circular(CoconutStyles.radius_200),
    ),
    child: Row(
      children: [
        WalletIcon(
          walletImportSource: WalletImportSource.coconutVault,
          colorIndex: _colorIndex,
          iconIndex: _iconIndex,
          badgeSvgAssetPath: FeatureWalletIconPath.hotWalletFire,
          badgeSize: 18,
        ),
        CoconutLayout.spacing_300w,
        Expanded(
          child: Text(
            widget.walletName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: CoconutTypography.body1_16_Bold.setColor(context.coconutColors.primaryText),
          ),
        ),
      ],
    ),
  );

  Widget _colorPalette() => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 5,
      mainAxisSpacing: 10,
      crossAxisSpacing: 24,
    ),
    itemCount: CoconutColors.colorPalette.length,
    itemBuilder:
        (_, index) => _selectionCircle(
          selected: index == _colorIndex,
          onTap: () => setState(() => _colorIndex = index),
          child: DecoratedBox(
            decoration: BoxDecoration(shape: BoxShape.circle, color: CoconutColors.colorPalette[index]),
          ),
        ),
  );

  Widget _iconPalette() => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    padding: EdgeInsets.zero,
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 5,
      mainAxisSpacing: 10,
      crossAxisSpacing: 24,
    ),
    itemCount: CustomWalletIcons.totalCount,
    itemBuilder:
        (_, index) => Semantics(
          button: true,
          selected: index == _iconIndex,
          child: _selectionCircle(
            selected: index == _iconIndex,
            onTap: () => setState(() => _iconIndex = index),
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(shape: BoxShape.circle, color: context.coconutColors.iconBackgroundSubtle),
              child: SvgPicture.asset(
                CustomWalletIcons.getPathByIndex(index),
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(context.coconutColors.iconPrimary, BlendMode.srcIn),
              ),
            ),
          ),
        ),
  );

  Widget _selectionCircle({required bool selected, required VoidCallback onTap, required Widget child}) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            width: 42,
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: selected ? context.coconutColors.primaryText : Colors.transparent, width: 2),
            ),
            child: child,
          ),
        ),
      );
}
