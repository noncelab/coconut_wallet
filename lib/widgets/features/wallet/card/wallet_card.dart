import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/constants/icon_path.dart';
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/enums/wallet_enums.dart';
import 'package:coconut_wallet/model/wallet/multisig_wallet_item.dart';
import 'package:coconut_wallet/model/wallet/wallet_appearance.dart';
import 'package:coconut_wallet/model/wallet/wallet_item_base.dart';
import 'package:coconut_wallet/utils/mfp_format.dart';
import 'package:coconut_wallet/utils/wallet_visual_style_util.dart';
import 'package:coconut_wallet/widgets/common/buttons/shrink_animation_button.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart' show kHomeWidgetHeaderHeight;
import 'package:coconut_wallet/widgets/features/wallet/icon/wallet_icon_small.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

enum WalletCardSize { small, wide }

class WalletCard extends StatelessWidget {
  static const glyphOpacity = 0.4;

  final WalletItemBase wallet;
  final WalletAppearance appearance;
  final WalletCardSize size;
  final String? balanceDisplay;
  final String? secondaryText;
  final Widget? statusBadge;
  final VoidCallback? onPressed;

  const WalletCard({
    super.key,
    required this.wallet,
    required this.appearance,
    required this.size,
    this.balanceDisplay,
    this.secondaryText,
    this.statusBadge,
    this.onPressed,
  });

  List<Color>? _iconGradientColors() {
    if (wallet.walletType == WalletType.multiSignature) {
      return WalletVisualStyleUtil.getGradientColors((wallet as MultisigWalletItem).signers);
    }
    if (wallet.walletType == WalletType.taproot) {
      return TaprootCardStyle.from(wallet)?.iconGradientColors;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: size == WalletCardSize.wide ? _buildWide(context) : _buildSmall(context),
    );
    if (onPressed == null) {
      return DecoratedBox(
        decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(20)),
        child: SizedBox.expand(child: content),
      );
    }
    return ShrinkAnimationButton(
      defaultColor: colors.homeSurface,
      pressedOverlayColor: colors.homeSurfacePressOverlay,
      pressedOverlayOpacity: colors.homeSurfacePressOverlayOpacity,
      borderRadius: 20,
      onPressed: onPressed!,
      child: SizedBox.expand(child: content),
    );
  }

  Widget _buildIcon() {
    return WalletIconSmall(
      walletImportSource: wallet.walletImportSource,
      colorIndex: appearance.colorIndex,
      iconIndex: appearance.iconIndex,
      gradientColors: _iconGradientColors(),
    );
  }

  Widget _buildGlyph(BuildContext context) {
    final isHot = wallet.hasLocalKey;
    return Opacity(
      opacity: glyphOpacity,
      child: SvgPicture.asset(
        isHot ? FeatureWalletIconPath.hotWalletFire : FeatureWalletIconPath.watchOnlyEyes,
        key: Key(isHot ? 'wallet-card-glyph-hot' : 'wallet-card-glyph-watch-only'),
        width: 18,
        height: 18,
        colorFilter: ColorFilter.mode(context.coconutColors.secondaryText, BlendMode.srcIn),
      ),
    );
  }

  Widget _buildName(BuildContext context) {
    return Text(
      wallet.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: CoconutTypography.body2_14_Bold.copyWith(color: context.coconutColors.primaryText),
    );
  }

  Widget _buildWide(BuildContext context) {
    final colors = context.coconutColors;
    final mfp = walletMasterFingerprint(wallet);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildIcon(),
            CoconutLayout.spacing_200w,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildName(context),
                  if (mfp != null)
                    Text(
                      formatMfp(mfp),
                      key: const Key('wallet-card-mfp'),
                      style: CoconutTypography.body3_12_Number.copyWith(color: colors.secondaryText),
                    ),
                ],
              ),
            ),
            if (statusBadge != null) statusBadge!,
          ],
        ),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child:
                  balanceDisplay == null
                      ? const SizedBox.shrink()
                      : FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          balanceDisplay!,
                          key: const Key('wallet-card-balance'),
                          style: CoconutTypography.heading4_18_NumberBold.copyWith(color: colors.primaryText),
                        ),
                      ),
            ),
            _buildGlyph(context),
          ],
        ),
      ],
    );
  }

  Widget _buildSmall(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(),
            const SizedBox(width: 8),
            Expanded(
              child:
                  secondaryText == null
                      ? const SizedBox.shrink()
                      : Container(
                        height: kHomeWidgetHeaderHeight,
                        alignment: Alignment.centerRight,
                        child: Text(
                          secondaryText!,
                          key: const Key('wallet-card-secondary'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: CoconutTypography.body3_12_Bold.copyWith(
                            color: context.coconutColors.primaryText,
                            height: 1,
                          ),
                        ),
                      ),
            ),
            if (statusBadge != null) ...[const SizedBox(width: 4), statusBadge!],
          ],
        ),
        if (balanceDisplay != null) ...[
          const Spacer(flex: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              balanceDisplay!,
              key: const Key('wallet-card-balance'),
              style: CoconutTypography.heading4_18_NumberBold.copyWith(color: context.coconutColors.primaryText),
            ),
          ),
          const Spacer(flex: 2),
        ] else
          const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildName(context),
                  if (walletMasterFingerprint(wallet) case final mfp?)
                    Text(
                      formatMfp(mfp),
                      key: const Key('wallet-card-mfp'),
                      style: CoconutTypography.body3_12_Number.copyWith(color: context.coconutColors.secondaryText),
                    ),
                ],
              ),
            ),
            _buildGlyph(context),
          ],
        ),
      ],
    );
  }
}
