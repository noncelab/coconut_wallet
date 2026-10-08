import 'package:coconut_design_system/coconut_design_system.dart' show CoconutLayout, CoconutTypography;
import 'package:coconut_wallet/design_system/context/coconut_theme_context_extension.dart';
import 'package:coconut_wallet/localization/strings.g.dart';
import 'package:coconut_wallet/widgets/features/home/widgets/home_widget_parts.dart';
import 'package:coconut_wallet/utils/text_utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/flutter_svg.dart';

class WalletOnboardingItem {
  final Widget icon;
  final String title;
  final String description;

  const WalletOnboardingItem({required this.icon, required this.title, required this.description});
}

/// 지갑이 없을 때 지갑을 추가하면 할 수 있는 일을 보여 주고, 첫 지갑 추가로 이끈다.
class WalletOnboardingView extends StatelessWidget {
  static const _buttonHeight = 56.0;
  static const _buttonBottom = 16.0;

  final String? heroIconPath;
  final String title;
  final String? subtitle;
  final List<WalletOnboardingItem> items;
  final VoidCallback onAddWallet;

  const WalletOnboardingView({
    super.key,
    this.heroIconPath,
    required this.title,
    required this.items,
    required this.onAddWallet,
    this.subtitle,
  });

  static Widget svgIcon(BuildContext context, String asset, {double scale = 1}) => SvgPicture.asset(
    asset,
    width: 24 * scale,
    height: 24 * scale,
    colorFilter: ColorFilter.mode(context.coconutColors.primaryText, BlendMode.srcIn),
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.coconutColors;
    final background = colors.homeBackground;
    return Stack(
      key: const Key('wallet-onboarding'),
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, _buttonHeight + _buttonBottom + 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (heroIconPath case final iconPath?) ...[
                  Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: colors.homeSurface, shape: BoxShape.circle),
                      child: SvgPicture.asset(
                        iconPath,
                        width: 32,
                        height: 32,
                        colorFilter: ColorFilter.mode(colors.primaryText, BlendMode.srcIn),
                      ),
                    ),
                  ),
                  CoconutLayout.spacing_500h,
                ],
                Text(
                  TextUtils.preventLineBreakInsideWords(title),
                  textAlign: TextAlign.center,
                  style: CoconutTypography.heading3_21_Bold.copyWith(color: colors.primaryText),
                ),
                if (subtitle != null) ...[
                  CoconutLayout.spacing_200h,
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: CoconutTypography.body2_14.copyWith(color: colors.secondaryText),
                  ),
                ],
                CoconutLayout.spacing_600h,
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                      decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(20)),
                      child: Row(
                        children: [
                          SizedBox.square(dimension: 28, child: Center(child: item.icon)),
                          CoconutLayout.spacing_400w,
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: CoconutTypography.body1_16_Bold.copyWith(color: colors.primaryText),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  TextUtils.preventLineBreakInsideWords(item.description),
                                  style: CoconutTypography.body3_12.copyWith(color: colors.secondaryText),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Container(
              key: const Key('wallet-onboarding-fade'),
              height: _buttonHeight + _buttonBottom + 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [background.withValues(alpha: 0.0), background],
                  stops: const [0.0, 0.5],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 20,
          right: 20,
          bottom: _buttonBottom,
          child: HomeWidgetPressable(
            key: const Key('wallet-onboarding-add'),
            onTap: onAddWallet,
            child: Container(
              height: _buttonHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: colors.homeSurface, borderRadius: BorderRadius.circular(16)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(CupertinoIcons.add, size: 18, color: colors.primaryText),
                  CoconutLayout.spacing_200w,
                  Text(
                    t.wallet_onboarding.add_first_wallet,
                    style: CoconutTypography.body2_14_Bold.copyWith(color: colors.primaryText),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
